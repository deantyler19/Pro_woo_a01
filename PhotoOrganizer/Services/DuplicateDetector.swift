import Photos
import UIKit

/// 서로 중복(또는 매우 유사)으로 판단된 사진들의 묶음.
struct DuplicateGroup: Identifiable {
    let id = UUID()
    var items: [PhotoItem]
}

/// 지각적 해시(average hash)를 이용해 중복·유사 사진을 찾아내는 서비스.
///
/// 동작 원리:
/// 1. 각 사진을 8×8 흑백 이미지로 축소한 뒤 평균 밝기를 기준으로 64비트 해시를 만든다.
/// 2. 두 해시의 해밍 거리(다른 비트 수)가 임계값 이하이면 유사한 사진으로 본다.
/// 이렇게 하면 화질·크기가 조금 다른 사진도 같은 장면이면 중복으로 묶인다.
@MainActor
final class DuplicateDetector: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var progress: Double = 0

    /// 해밍 거리 임계값. 작을수록 "거의 동일한" 사진만, 클수록 더 느슨하게 묶는다.
    var similarityThreshold = 6

    /// 동시에 처리할 썸네일 수. 메모리 급증을 막기 위해 제한한다.
    private let maxConcurrent = 6

    func scan(photos: [PhotoItem]) async {
        isScanning = true
        progress = 0
        defer { isScanning = false }

        let total = max(photos.count, 1)
        var completed = 0
        // (원본 순서, item, hash) — 완료 순서가 뒤섞이므로 인덱스로 다시 정렬한다.
        var results: [(Int, PhotoItem, UInt64)] = []
        results.reserveCapacity(photos.count)

        // 최대 maxConcurrent개씩 병렬로 썸네일+해시를 계산한다(순차 대비 수 배 빠름).
        await withTaskGroup(of: (Int, PhotoItem, UInt64?).self) { group in
            var iterator = photos.enumerated().makeIterator()
            for _ in 0..<maxConcurrent {
                guard let (idx, item) = iterator.next() else { break }
                group.addTask { await self.hashTask(index: idx, item: item) }
            }
            while let (idx, item, hash) = await group.next() {
                if let hash { results.append((idx, item, hash)) }
                completed += 1
                progress = Double(completed) / Double(total)
                if let (nextIdx, nextItem) = iterator.next() {
                    group.addTask { await self.hashTask(index: nextIdx, item: nextItem) }
                }
            }
        }

        // 입력 순서(최신순)를 복원
        results.sort { $0.0 < $1.0 }
        let hashes = results.map { (item: $0.1, hash: $0.2) }

        let threshold = similarityThreshold
        groups = await Task.detached(priority: .userInitiated) {
            Self.groupSimilar(hashes, threshold: threshold)
        }.value
    }

    /// 한 장의 썸네일을 받아 해시를 계산한다. 여러 개가 동시에 실행된다.
    /// nonisolated이므로 @MainActor에 묶이지 않고 백그라운드에서 진짜 병렬로 돈다.
    nonisolated private func hashTask(index: Int, item: PhotoItem) async -> (Int, PhotoItem, UInt64?) {
        guard let image = await Self.requestSmallImage(for: item.asset) else { return (index, item, nil) }
        let hash = await Self.computeHash(from: image)
        return (index, item, hash)
    }

    /// 해시 목록을 유사도 기준으로 묶는다. (백그라운드에서 호출)
    /// 먼저 동일 해시끼리 O(n)으로 묶어 비교 대상을 "서로 다른 해시"로 줄인 뒤
    /// 해밍 거리 비교를 수행해 O(n²)의 n을 크게 낮춘다(결과는 동일).
    nonisolated private static func groupSimilar(
        _ hashes: [(item: PhotoItem, hash: UInt64)],
        threshold: Int
    ) -> [DuplicateGroup] {
        // 1) 동일 해시(정확 중복) 먼저 묶기 — 입력 순서 유지
        var byHash: [UInt64: [PhotoItem]] = [:]
        var distinct: [UInt64] = []
        for (item, hash) in hashes {
            if byHash[hash] == nil { distinct.append(hash) }
            byHash[hash, default: []].append(item)
        }

        // 2) 서로 다른 해시들만 해밍 거리로 병합
        var used = Set<Int>()
        var result: [DuplicateGroup] = []
        for i in distinct.indices {
            if used.contains(i) { continue }
            var items = byHash[distinct[i]] ?? []
            for j in (i + 1)..<distinct.count {
                if used.contains(j) { continue }
                if hammingDistance(distinct[i], distinct[j]) <= threshold {
                    items.append(contentsOf: byHash[distinct[j]] ?? [])
                    used.insert(j)
                }
            }
            if items.count > 1 {
                used.insert(i)
                result.append(DuplicateGroup(items: items))
            }
        }
        // 중복이 많은 묶음을 먼저 보여준다.
        return result.sorted { $0.items.count > $1.items.count }
    }

    /// 썸네일로부터 해시를 계산한다. detached 태스크에서 백그라운드 실행.
    nonisolated private static func computeHash(from image: UIImage) async -> UInt64? {
        await Task.detached(priority: .userInitiated) {
            averageHash(image)
        }.value
    }

    /// 8×8 흑백 평균 해시(aHash)를 계산한다. (백그라운드에서 호출)
    nonisolated private static func averageHash(_ image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }
        let width = 8, height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sum = pixels.reduce(0) { $0 + Int($1) }
        let mean = sum / pixels.count

        var hash: UInt64 = 0
        for (i, pixel) in pixels.enumerated() where Int(pixel) >= mean {
            hash |= (UInt64(1) << UInt64(i))
        }
        return hash
    }

    nonisolated private static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    /// 64×64 작은 썸네일을 요청한다. PHImageManager는 thread-safe하므로 nonisolated.
    /// 첫 콜백에서 즉시 resume하며(.fastFormat은 1회 콜백), 가드로 다중 resume을 막는다.
    nonisolated private static func requestSmallImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 64, height: 64),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
