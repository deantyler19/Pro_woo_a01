import Photos
import SwiftUI
import UIKit

/// 사진 보관함 접근·로딩·썸네일·삭제를 담당하는 서비스.
@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photos: [PhotoItem] = []
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false

    private let imageManager = PHCachingImageManager()

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - 권한

    /// 사용자에게 사진 접근 권한을 요청한다.
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            await loadPhotos()
        }
    }

    /// 이미 권한이 있으면 사진과 동영상을 불러온다.
    func loadIfAuthorized() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            await loadPhotos()
        }
    }

    // MARK: - 로드

    /// 보관함의 모든 사진·동영상을 최신순으로 불러온다.
    /// PHFetch·enumerate는 메인 스레드를 점유하므로 백그라운드에서 실행하고 결과만 반영한다.
    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        let (loadedPhotos, loadedVideos) = await Self.fetchAllAssets()
        photos = loadedPhotos
        videos = loadedVideos
    }

    nonisolated private static func fetchAllAssets() async -> ([PhotoItem], [VideoItem]) {
        await Task.detached(priority: .userInitiated) {
            let sort = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let photoOptions = PHFetchOptions()
            photoOptions.sortDescriptors = sort
            let photoResult = PHAsset.fetchAssets(with: .image, options: photoOptions)
            var photoItems: [PhotoItem] = []
            photoItems.reserveCapacity(photoResult.count)
            photoResult.enumerateObjects { asset, _, _ in photoItems.append(PhotoItem(asset: asset)) }

            let videoOptions = PHFetchOptions()
            videoOptions.sortDescriptors = sort
            let videoResult = PHAsset.fetchAssets(with: .video, options: videoOptions)
            var videoItems: [VideoItem] = []
            videoItems.reserveCapacity(videoResult.count)
            videoResult.enumerateObjects { asset, _, _ in videoItems.append(VideoItem(asset: asset)) }

            return (photoItems, videoItems)
        }.value
    }

    // MARK: - 스크린샷 fetch

    /// `mediaSubtypes`에 `.photoScreenshot`이 포함된 사진만 NSPredicate로 DB 레벨에서 걸러 반환한다.
    func fetchScreenshots() async -> [PhotoItem] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            // PHAsset.mediaSubtypes는 비트마스크이므로 bitwise AND predicate 사용
            options.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            var items: [PhotoItem] = []
            items.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in items.append(PhotoItem(asset: asset)) }
            return items
        }.value
    }

    // MARK: - 파일 크기 로드

    /// `PHAssetResource`에서 파일 크기를 읽어 `VideoItem.fileSizeMB`를 채운다.
    /// 네트워크 접근을 허용하지 않아 iCloud 전용 항목은 nil을 유지한다.
    func loadFileSizes(for items: inout [VideoItem]) async {
        // 스냅샷으로 (id, asset) 페어를 캡처해 병렬 조회한다.
        let snapshots: [(String, PHAsset)] = items.map { ($0.id, $0.asset) }

        var sizeMap: [String: Double] = [:]
        await withTaskGroup(of: (String, Double?).self) { group in
            for (itemID, asset) in snapshots {
                group.addTask {
                    let sizeBytes = Self.fileSizeBytes(of: asset)
                    let sizeMB = sizeBytes.map { Double($0) / 1_048_576 }
                    return (itemID, sizeMB)
                }
            }
            for await (id, sizeMB) in group {
                if let mb = sizeMB { sizeMap[id] = mb }
            }
        }

        // withTaskGroup 완료 후 @MainActor 컨텍스트에서 inout 배열 갱신
        for i in items.indices {
            if let mb = sizeMap[items[i].id] {
                items[i].fileSizeMB = mb
            }
        }
    }

    /// PHAssetResource의 'fileSize' 키(동기)에서 바이트 크기를 읽는다(iOS 9+).
    /// 반환 타입이 NSNumber이므로 안전하게 캐스팅한다. 키가 없으면 nil.
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
    /// (파일 크기는 비동기로 늦게 채워지므로 재생 시간을 "대용량" 기준의 1차 필터로 사용)
    func fetchLargeVideos(minDurationSeconds: TimeInterval = 60) async -> [VideoItem] {
        let source: [VideoItem] = videos.isEmpty ? await fetchVideosFromLibrary() : videos
        return source
            .filter { $0.duration >= minDurationSeconds }
            .sorted { $0.duration > $1.duration }
    }

    /// 동영상만 PHFetchOptions로 직접 가져오는 내부 도우미.
    private func fetchVideosFromLibrary() async -> [VideoItem] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
            let result = PHAsset.fetchAssets(with: .video, options: options)
            var items: [VideoItem] = []
            items.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in items.append(VideoItem(asset: asset)) }
            return items
        }.value
    }

    // MARK: - 썸네일

    /// 지정한 사진의 썸네일을 비동기로 가져온다.
    func requestThumbnail(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        await requestImage(asset: item.asset, targetSize: targetSize, allowsNetwork: true)
    }

    /// 동영상 에셋의 썸네일을 비동기로 가져온다.
    func requestVideoThumbnail(for item: VideoItem, targetSize: CGSize) async -> UIImage? {
        await requestImage(asset: item.asset, targetSize: targetSize, allowsNetwork: false)
    }

    /// 공통 이미지 요청.
    /// - Task가 취소되면 `PHImageRequestID`로 진행 중인 요청을 취소해 리소스 낭비를 막는다.
    /// - iCloud 전용·취소·에러 상황에서 continuation이 영영 대기하지 않도록 종료 신호를 처리한다.
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
                        // 최종(고품질) 결과 도착
                        finish(image)
                    } else if isCancelled || hasError || (inCloud && !allowsNetwork) {
                        // 더 이상 콜백이 오지 않을 상황 → 즉시 종료(누수 방지)
                        finish(nil)
                    }
                    // 그 외 저품질 중간 결과는 무시하고 최종 콜백을 기다린다.
                }
                // 요청 ID 저장. 저장 직전 이미 취소됐다면 즉시 취소한다.
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

    // MARK: - 삭제

    /// 사진을 삭제한다. 시스템이 사용자에게 삭제 확인 알림을 띄운다.
    @discardableResult
    func deleteAssets(_ items: [PhotoItem]) async -> Bool {
        await delete(items.map(\.asset))
    }

    /// 동영상 에셋을 삭제한다.
    @discardableResult
    func deleteVideoAssets(_ items: [VideoItem]) async -> Bool {
        await delete(items.map(\.asset))
    }

    private func delete(_ assets: [PHAsset]) async -> Bool {
        guard !assets.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            await loadPhotos()  // photos + videos 모두 갱신
            return true
        } catch {
            return false
        }
    }
}

/// 이미지 요청 ID를 스레드 안전하게 보관하는 박스.
/// Task 취소 시 PHImageManager 요청 취소에 사용한다.
private final class ImageRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var id: PHImageRequestID?
    private var cancelled = false

    /// 요청 ID를 저장한다. 저장 시점에 이미 취소됐으면 true 반환(즉시 취소 필요).
    func store(_ newID: PHImageRequestID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        id = newID
        return cancelled
    }

    /// 취소로 표시하고 저장된 요청 ID를 반환한다.
    func cancel() -> PHImageRequestID? {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        return id
    }
}
