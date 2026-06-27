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

    /// Photos.app People 앨범 불러오기.
    /// 앨범·사진 fetch와 enumerate는 메인 스레드를 점유하므로 백그라운드에서 실행한다.
    func loadPeopleAlbums() async {
        let fetched = await Self.fetchPeopleAlbums()
        sourceIsPeopleAlbum = !fetched.isEmpty
        groups = fetched.sorted { $0.items.count > $1.items.count }
    }

    nonisolated private static func fetchPeopleAlbums() async -> [FaceGroup] {
        await Task.detached(priority: .userInitiated) {
            let result = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumPeople,
                options: nil
            )

            // 앨범 내 사진 순서를 결정적으로 만들기 위해 정렬 옵션을 지정한다.
            let assetOptions = PHFetchOptions()
            assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            var fetched: [FaceGroup] = []
            result.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: assetOptions)
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
            return fetched
        }.value
    }

    /// 동시에 처리할 사진 수. 메모리 급증을 막기 위해 제한한다.
    private let maxConcurrent = 6

    /// Vision 기반 얼굴 수 스캔. 최대 maxConcurrent개씩 병렬로 처리한다(순차 대비 수 배 빠름).
    func scanFaces(photos: [PhotoItem]) async {
        isScanning = true
        progress = 0
        defer { isScanning = false }

        let total = max(photos.count, 1)
        var completed = 0
        // (원본 순서, item, 얼굴 수) — 완료 순서가 뒤섞이므로 인덱스로 보관 후 정렬한다.
        var results: [(Int, PhotoItem, Int)] = []
        results.reserveCapacity(photos.count)

        await withTaskGroup(of: (Int, PhotoItem, Int).self) { group in
            var iterator = photos.enumerated().makeIterator()
            for _ in 0..<maxConcurrent {
                guard let (idx, item) = iterator.next() else { break }
                group.addTask { await self.faceCountTask(index: idx, item: item) }
            }
            while let triple = await group.next() {
                results.append(triple)
                completed += 1
                progress = Double(completed) / Double(total)
                if let (nextIdx, nextItem) = iterator.next() {
                    group.addTask { await self.faceCountTask(index: nextIdx, item: nextItem) }
                }
            }
        }

        // 입력 순서(최신순) 복원 후 얼굴 수 기준 버킷팅
        results.sort { $0.0 < $1.0 }
        var buckets: [Int: [PhotoItem]] = [0: [], 1: [], 2: [], 3: []]
        for (_, item, n) in results {
            buckets[min(n, 3), default: []].append(item)
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

    /// 한 장의 썸네일을 받아 얼굴 수를 검출한다. 여러 개가 동시에 실행된다.
    /// nonisolated이므로 @MainActor에 묶이지 않고 백그라운드에서 진짜 병렬로 돈다.
    nonisolated private func faceCountTask(index: Int, item: PhotoItem) async -> (Int, PhotoItem, Int) {
        guard let image = await Self.requestSmall(item.asset), let cg = image.cgImage else {
            return (index, item, 0)
        }
        let n = await Self.detectFaceCount(cg)
        return (index, item, n)
    }

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

    /// 180×180 작은 썸네일을 요청한다. PHImageManager는 thread-safe하므로 nonisolated.
    nonisolated private static func requestSmall(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opt = PHImageRequestOptions()
            opt.isNetworkAccessAllowed = false
            opt.deliveryMode = .fastFormat
            opt.resizeMode   = .fast
            var done = false
            PHImageManager.default().requestImage(
                for: asset,
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
