import Photos
import SwiftUI
import UIKit

/// 사진 보관함 접근·로딩·썸네일·삭제를 담당하는 서비스.
@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photos: [PhotoItem] = []
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

    /// 이미 권한이 있으면 사진을 불러온다.
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

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var items: [PhotoItem] = []
        items.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            items.append(PhotoItem(asset: asset))
        }
        photos = items
    }

    /// 지정한 사진의 썸네일을 비동기로 가져온다.
    func requestThumbnail(for item: PhotoItem, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            var resumed = false
            imageManager.requestImage(
                for: item.asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !resumed, !isDegraded else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }

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
}
