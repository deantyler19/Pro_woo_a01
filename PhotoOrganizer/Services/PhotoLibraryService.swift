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

    /// 보관함의 모든 사진을 최신순으로 불러온다.
    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }

        // 사진(.image) 로드
        let photoOptions = PHFetchOptions()
        photoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let photoResult = PHAsset.fetchAssets(with: .image, options: photoOptions)

        var items: [PhotoItem] = []
        items.reserveCapacity(photoResult.count)
        photoResult.enumerateObjects { asset, _, _ in
            items.append(PhotoItem(asset: asset))
        }
        photos = items

        // 동영상(.video)도 함께 로드
        let videoOptions = PHFetchOptions()
        videoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let videoResult = PHAsset.fetchAssets(with: .video, options: videoOptions)

        var videoItems: [VideoItem] = []
        videoItems.reserveCapacity(videoResult.count)
        videoResult.enumerateObjects { asset, _, _ in
            videoItems.append(VideoItem(asset: asset))
        }
        videos = videoItems
    }

    // MARK: - 스크린샷 fetch

    /// `mediaSubtypes`에 `.photoScreenshot`이 포함된 사진만 PHFetchOptions 레벨에서 필터링해 반환한다.
    /// 메모리에 올린 뒤 Swift filter를 쓰지 않고, NSPredicate로 DB에서 직접 걸러 성능을 확보한다.
    func fetchScreenshots() async -> [PhotoItem] {
        let options = PHFetchOptions()
        // PHAsset.mediaSubtypes는 NSNumber 비트마스크이므로 bitwise AND predicate 사용
        options.predicate = NSPredicate(
            format: "(mediaSubtypes & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: options)

        var items: [PhotoItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            items.append(PhotoItem(asset: asset))
        }
        return items
    }

    // MARK: - 파일 크기 로드

    /// `PHAssetResource`에서 파일 크기를 읽어 `VideoItem.fileSizeMB`를 채운다.
    /// 네트워크 접근을 허용하지 않아 iCloud 전용 항목은 nil을 유지한다.
    /// 파일 크기 I/O는 nonisolated static 메서드로 오프로드하고,
    /// 결과는 (id, MB) 딕셔너리로 모은 뒤 메인스레드에서 inout 배열에 반영한다.
    func loadFileSizes(for items: inout [VideoItem]) async {
        // 스냅샷으로 (id, asset) 페어를 캡처해 클로저 내부에서 actor-isolated 타입 접근을 피한다.
        let snapshots: [(String, PHAsset)] = items.map { ($0.id, $0.asset) }

        // 병렬 파일 크기 조회 — nonisolated static이므로 어느 executor에서나 안전
        var sizeMap: [String: Double] = [:]
        await withTaskGroup(of: (String, Double?).self) { group in
            for (itemID, asset) in snapshots {
                group.addTask {
                    let sizeBytes = await Self.fetchFileSizeBytes(asset: asset)
                    let sizeMB = sizeBytes.map { Double($0) / 1_048_576 }
                    return (itemID, sizeMB)
                }
            }
            for await (id, sizeMB) in group {
                if let mb = sizeMB { sizeMap[id] = mb }
            }
        }

        // withTaskGroup 완료 후 @MainActor 컨텍스트에서 순차적으로 inout 배열 갱신
        for i in items.indices {
            if let mb = sizeMap[items[i].id] {
                items[i].fileSizeMB = mb
            }
        }
    }

    /// PHAssetResource에서 파일 크기(bytes)를 읽는 nonisolated 도우미.
    /// continuation은 정확히 한 번만 resume한다.
    nonisolated private static func fetchFileSizeBytes(asset: PHAsset) async -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        // .video 타입 리소스를 우선 선택
        guard let resource = resources.first(where: { $0.type == .video }) ?? resources.first else {
            return nil
        }

        // PHAssetResourceManager는 콜백 기반이므로 continuation으로 감싼다.
        return await withCheckedContinuation { continuation in
            var resumed = false
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false  // iCloud 다운로드 금지

            // fileSize 키를 직접 읽는다(iOS 9+).
            if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                resumed = true
                continuation.resume(returning: fileSize)
                return
            }

            // fileSize 키가 없으면 데이터를 일부 받아 크기를 추정할 수도 있으나
            // 여기서는 실패 fallback으로 nil을 리턴한다(네트워크 없이 안전하게).
            if !resumed {
                resumed = true
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - 대용량 동영상 fetch

    /// duration 기준으로 정렬한 모든 동영상을 반환한다.
    /// 호출 시 `videos`가 로드돼 있으면 바로 사용, 없으면 fetch한다.
    func fetchLargeVideos(minDurationSeconds: TimeInterval = 60) async -> [VideoItem] {
        // 이미 로드된 videos 배열을 재사용한다.
        let source: [VideoItem] = videos.isEmpty ? await fetchVideosFromLibrary() : videos

        // duration 내림차순 정렬 (파일 크기는 비동기 로드 후 채워짐)
        return source.sorted { $0.duration > $1.duration }
    }

    /// 동영상만 PHFetchOptions로 직접 가져오는 내부 도우미.
    private func fetchVideosFromLibrary() async -> [VideoItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "duration", ascending: false)]
        let result = PHAsset.fetchAssets(with: .video, options: options)

        var items: [VideoItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            items.append(VideoItem(asset: asset))
        }
        return items
    }

    // MARK: - 썸네일

    /// 지정한 사진의 썸네일을 비동기로 가져온다.
    func requestThumbnail(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            var resumed = false
            func finish(_ image: UIImage?) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
            imageManager.requestImage(
                for: item.asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                if !isDegraded {
                    finish(image)
                } else if isCancelled || hasError {
                    finish(nil)
                }
            }
        }
    }

    /// 동영상 에셋의 썸네일을 비동기로 가져온다.
    /// 네트워크 비허용 상태에서 iCloud 전용 자산이면 고품질 콜백이 오지 않으므로,
    /// 취소·에러·iCloud 신호가 오면 즉시 nil로 종료해 continuation 누수를 막는다.
    func requestVideoThumbnail(for item: VideoItem, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            var resumed = false
            func finish(_ image: UIImage?) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
            imageManager.requestImage(
                for: item.asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                if !isDegraded {
                    // 최종(고품질) 결과 도착 → 그 값으로 종료
                    finish(image)
                } else if isCancelled || hasError || inCloud {
                    // 더 이상 콜백이 오지 않을 상황 → 즉시 종료(누수 방지)
                    finish(nil)
                }
                // 그 외 저품질 중간 결과는 무시하고 최종 콜백을 기다린다.
            }
        }
    }

    // MARK: - 삭제

    /// 사진을 삭제한다. 시스템이 사용자에게 삭제 확인 알림을 띄운다.
    /// - Returns: 삭제 성공 여부.
    @discardableResult
    func deleteAssets(_ items: [PhotoItem]) async -> Bool {
        guard !items.isEmpty else { return true }
        let assets = items.map(\.asset) as NSArray
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            await loadPhotos()
            return true
        } catch {
            return false
        }
    }

    /// 동영상 에셋을 삭제한다.
    @discardableResult
    func deleteVideoAssets(_ items: [VideoItem]) async -> Bool {
        guard !items.isEmpty else { return true }
        let assets = items.map(\.asset) as NSArray
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            await loadPhotos()  // photos + videos 모두 갱신
            return true
        } catch {
            return false
        }
    }
}
