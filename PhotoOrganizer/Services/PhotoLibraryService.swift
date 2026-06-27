import Photos
import SwiftUI
import UIKit

/// 사진 보관함 접근·로딩·썸네일·삭제를 담당하는 서비스.
/// 외부(다른 앱·시스템)에서 보관함이 바뀌면 `PHPhotoLibraryChangeObserver`로 자동 반영한다.
@MainActor
final class PhotoLibraryService: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photos: [PhotoItem] = []
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false

    private let imageManager = PHCachingImageManager()
    /// 변경 감지를 위해 마지막 fetch 결과를 보관한다. 백그라운드 콜백에서 접근하므로 락으로 보호.
    private let fetchStore = FetchResultStore()

    override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - 권한

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            await loadPhotos()
        }
    }

    func loadIfAuthorized() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            await loadPhotos()
        }
    }

    // MARK: - 로드

    /// 보관함의 모든 사진·동영상을 최신순으로 불러온다. fetch·enumerate는 백그라운드에서 실행한다.
    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        let result = await Self.fetchAssets()
        fetchStore.photos = result.photoResult
        fetchStore.videos = result.videoResult
        photos = result.photos
        videos = result.videos
    }

    nonisolated private static func fetchAssets() async
        -> (photoResult: PHFetchResult<PHAsset>, photos: [PhotoItem],
            videoResult: PHFetchResult<PHAsset>, videos: [VideoItem]) {
        await Task.detached(priority: .userInitiated) {
            let sort = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let photoOptions = PHFetchOptions(); photoOptions.sortDescriptors = sort
            let videoOptions = PHFetchOptions(); videoOptions.sortDescriptors = sort
            let pRes = PHAsset.fetchAssets(with: .image, options: photoOptions)
            let vRes = PHAsset.fetchAssets(with: .video, options: videoOptions)
            return (pRes, photoItems(from: pRes), vRes, videoItems(from: vRes))
        }.value
    }

    nonisolated private static func photoItems(from result: PHFetchResult<PHAsset>) -> [PhotoItem] {
        var items: [PhotoItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in items.append(PhotoItem(asset: asset)) }
        return items
    }

    nonisolated private static func videoItems(from result: PHFetchResult<PHAsset>) -> [VideoItem] {
        var items: [VideoItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in items.append(VideoItem(asset: asset)) }
        return items
    }

    // MARK: - 변경 감지 (PHPhotoLibraryChangeObserver)

    /// 보관함 변경 시 호출(백그라운드 스레드). changeDetails는 콜백 내에서 동기적으로 계산해야 한다.
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        var newPhotos: [PhotoItem]?
        var newVideos: [VideoItem]?

        if let pr = fetchStore.photos,
           let details = changeInstance.changeDetails(for: pr) {
            let after = details.fetchResultAfterChanges
            fetchStore.photos = after
            newPhotos = Self.photoItems(from: after)
        }
        if let vr = fetchStore.videos,
           let details = changeInstance.changeDetails(for: vr) {
            let after = details.fetchResultAfterChanges
            fetchStore.videos = after
            newVideos = Self.videoItems(from: after)
        }

        guard newPhotos != nil || newVideos != nil else { return }
        let p = newPhotos, v = newVideos
        Task { @MainActor [weak self] in
            if let p { self?.photos = p }
            if let v { self?.videos = v }
        }
    }

    // MARK: - 스크린샷 fetch

    /// `.photoScreenshot` 서브타입만 NSPredicate로 DB 레벨에서 걸러 반환한다.
    func fetchScreenshots() async -> [PhotoItem] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            return photoItems(from: result)
        }.value
    }

    // MARK: - 파일 크기 로드

    func loadFileSizes(for items: inout [VideoItem]) async {
        let snapshots: [(String, PHAsset)] = items.map { ($0.id, $0.asset) }
        var sizeMap: [String: Double] = [:]
        await withTaskGroup(of: (String, Double?).self) { group in
            for (itemID, asset) in snapshots {
                group.addTask {
                    let bytes = Self.fileSizeBytes(of: asset)
                    return (itemID, bytes.map { Double($0) / 1_048_576 })
                }
            }
            for await (id, mb) in group {
                if let mb { sizeMap[id] = mb }
            }
        }
        for i in items.indices {
            if let mb = sizeMap[items[i].id] { items[i].fileSizeMB = mb }
        }
    }

    /// PHAssetResource의 'fileSize' 키(동기)에서 바이트 크기를 읽는다.
    nonisolated private static func fileSizeBytes(of asset: PHAsset) -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .video }) ?? resources.first else {
            return nil
        }
        if let number = resource.value(forKey: "fileSize") as? NSNumber {
            return number.int64Value
        }
        return nil
    }

    // MARK: - 대용량 동영상 fetch

    /// 지정 길이(기본 60초) 이상인 동영상만 길이 내림차순으로 반환한다.
    func fetchLargeVideos(minDurationSeconds: TimeInterval = 60) async -> [VideoItem] {
        let source: [VideoItem] = videos.isEmpty ? await fetchVideosFromLibrary() : videos
        return source
            .filter { $0.duration >= minDurationSeconds }
            .sorted { $0.duration > $1.duration }
    }

    private func fetchVideosFromLibrary() async -> [VideoItem] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
            let result = PHAsset.fetchAssets(with: .video, options: options)
            return videoItems(from: result)
        }.value
    }

    // MARK: - 썸네일 (+ 프리페치 캐싱)

    /// 격자 표시 전 썸네일을 미리 캐싱해 스크롤 시 즉시 표시되게 한다.
    func startCaching(_ items: [PhotoItem], targetSize: CGSize) {
        imageManager.startCachingImages(
            for: items.map(\.asset),
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    /// 화면을 벗어날 때 캐시를 비운다(메모리 회수).
    func stopAllCaching() {
        imageManager.stopCachingAllImages()
    }

    func requestThumbnail(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        await requestImage(asset: item.asset, targetSize: targetSize, allowsNetwork: true)
    }

    func requestVideoThumbnail(for item: VideoItem, targetSize: CGSize) async -> UIImage? {
        await requestImage(asset: item.asset, targetSize: targetSize, allowsNetwork: false)
    }

    /// 공통 이미지 요청. Task 취소 시 PHImageRequestID로 요청을 취소해 리소스 낭비를 막고,
    /// iCloud 전용·취소·에러 상황에서 continuation이 영영 대기하지 않도록 종료 신호를 처리한다.
    private func requestImage(asset: PHAsset, targetSize: CGSize, allowsNetwork: Bool) async -> UIImage? {
        let manager = imageManager
        let box = ImageRequestBox()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = allowsNetwork
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .fast
                var resumed = false
                func finish(_ image: UIImage?) {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: image)
                }
                let id = manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                    let hasError = info?[PHImageErrorKey] != nil
                    let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    if !isDegraded {
                        finish(image)
                    } else if isCancelled || hasError || (inCloud && !allowsNetwork) {
                        finish(nil)
                    }
                }
                if box.store(id) {
                    manager.cancelImageRequest(id)
                }
            }
        } onCancel: {
            if let id = box.cancel() {
                manager.cancelImageRequest(id)
            }
        }
    }

    // MARK: - 삭제 (증분 반영)

    @discardableResult
    func deleteAssets(_ items: [PhotoItem]) async -> Bool {
        await delete(items.map(\.asset))
    }

    @discardableResult
    func deleteVideoAssets(_ items: [VideoItem]) async -> Bool {
        await delete(items.map(\.asset))
    }

    /// 삭제 후 전체 라이브러리를 다시 fetch하지 않고, 메모리 배열에서 해당 항목만 제거한다.
    /// (외부 변경은 photoLibraryDidChange가 별도로 반영)
    private func delete(_ assets: [PHAsset]) async -> Bool {
        guard !assets.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            let ids = Set(assets.map(\.localIdentifier))
            photos.removeAll { ids.contains($0.id) }
            videos.removeAll { ids.contains($0.id) }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 보조 타입

/// 변경 감지를 위한 PHFetchResult 보관소. 백그라운드 콜백에서 접근하므로 락으로 보호한다.
private final class FetchResultStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _photos: PHFetchResult<PHAsset>?
    private var _videos: PHFetchResult<PHAsset>?

    var photos: PHFetchResult<PHAsset>? {
        get { lock.lock(); defer { lock.unlock() }; return _photos }
        set { lock.lock(); defer { lock.unlock() }; _photos = newValue }
    }
    var videos: PHFetchResult<PHAsset>? {
        get { lock.lock(); defer { lock.unlock() }; return _videos }
        set { lock.lock(); defer { lock.unlock() }; _videos = newValue }
    }
}

/// 이미지 요청 ID를 스레드 안전하게 보관하는 박스. Task 취소 시 요청 취소에 사용.
private final class ImageRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var id: PHImageRequestID?
    private var cancelled = false

    func store(_ newID: PHImageRequestID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        id = newID
        return cancelled
    }

    func cancel() -> PHImageRequestID? {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        return id
    }
}
