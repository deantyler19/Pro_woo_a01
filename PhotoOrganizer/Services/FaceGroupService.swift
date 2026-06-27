import Photos
import Vision
import UIKit

/// 얼굴 그룹 모델. Photos의 People 앨범이거나 Vision 스캔 결과.
struct FaceGroup: Identifiable {
    let id = UUID()
    var name: String
    var subtitle: String
    var items: [PhotoItem]
    var faceCount: Int   // 0=없음, 1=혼자, 2=둘, 3+=여럿
}

/// 얼굴별 사진 그룹화 서비스.
///
/// 1순위: Photos.app의 People 스마트 앨범(iOS가 자동 생성)을 불러온다.
/// 2순위: People 앨범이 비어 있으면 Vision으로 각 사진의 얼굴 수를 검출해
///        혼자·둘이서·여럿이·사람없음 4그룹으로 묶는다.
@MainActor
final class FaceGroupService: ObservableObject {
    @Published var groups: [FaceGroup] = []
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var sourceIsPeopleAlbum = false

    private let imageManager = PHImageManager.default()

    /// Photos.app People 앨범 불러오기.
    func loadPeopleAlbums() {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumPeople,
            options: nil
        )

        var fetched: [FaceGroup] = []
        result.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            guard assets.count > 0 else { return }
            var items: [PhotoItem] = []
            assets.enumerateObjects { asset, _, _ in items.append(PhotoItem(asset: asset)) }
            fetched.append(FaceGroup(
                name: collection.localizedTitle ?? "알 수 없음",
                subtitle: "사진 \(items.count)장",
                items: items,
                faceCount: 1
            ))
        }

        sourceIsPeopleAlbum = !fetched.isEmpty
        groups = fetched.sorted { $0.items.count > $1.items.count }
    }

    /// Vision 기반 얼굴 수 스캔.
    func scanFaces(photos: [PhotoItem]) async {
        isScanning = true
        progress = 0
        defer { isScanning = false }

        var buckets: [Int: [PhotoItem]] = [0: [], 1: [], 2: [], 3: []]
        let total = max(photos.count, 1)

        for (idx, item) in photos.enumerated() {
            // 썸네일 로딩(PhotoKit, 백그라운드) → CGImage 추출 → Vision 추론은
            // detached 태스크에서 실행해 메인 스레드 멈춤을 방지한다.
            var n = 0
            if let image = await requestSmall(item), let cg = image.cgImage {
                n = await Self.detectFaceCount(cg)
            }
            let key = min(n, 3)
            buckets[key, default: []].append(item)
            progress = Double(idx + 1) / Double(total)
        }

        let labels: [(Int, String, String)] = [
            (1, "인물 사진 (1인)", "셀카·단체 인물 사진"),
            (2, "둘이서",          "두 사람이 등장하는 사진"),
            (3, "여럿이 함께",     "세 명 이상 등장하는 사진"),
            (0, "사람 없음",       "얼굴이 감지되지 않은 사진"),
        ]

        groups = labels.compactMap { (key, name, sub) in
            guard let items = buckets[key], !items.isEmpty else { return nil }
            return FaceGroup(name: name, subtitle: sub, items: items, faceCount: key)
        }
        sourceIsPeopleAlbum = false
    }

    // MARK: - Private

    /// CGImage에서 얼굴 수를 검출한다. Vision 추론은 CPU 집약·동기이므로
    /// detached 태스크(백그라운드)에서 실행한다.
    nonisolated private static func detectFaceCount(_ cg: CGImage) async -> Int {
        await Task.detached(priority: .userInitiated) {
            await withCheckedContinuation { cont in
                var done = false
                let req = VNDetectFaceRectanglesRequest { req, err in
                    guard !done else { return }
                    done = true
                    guard err == nil,
                          let res = req.results as? [VNFaceObservation] else {
                        cont.resume(returning: 0); return
                    }
                    cont.resume(returning: res.count)
                }
                do {
                    try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
                } catch {
                    if !done { done = true; cont.resume(returning: 0) }
                }
            }
        }.value
    }

    private func requestSmall(_ item: PhotoItem) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opt = PHImageRequestOptions()
            opt.isNetworkAccessAllowed = false
            opt.deliveryMode = .fastFormat
            opt.resizeMode   = .fast
            var done = false
            imageManager.requestImage(
                for: item.asset,
                targetSize: CGSize(width: 180, height: 180),
                contentMode: .aspectFill,
                options: opt
            ) { img, _ in
                guard !done else { return }
                done = true
                cont.resume(returning: img)
            }
        }
    }
}
