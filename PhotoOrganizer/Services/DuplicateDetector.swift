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

    private let imageManager = PHImageManager.default()

    func scan(photos: [PhotoItem]) async {
        isScanning = true
        progress = 0
        defer { isScanning = false }

        var hashes: [(item: PhotoItem, hash: UInt64)] = []
        hashes.reserveCapacity(photos.count)

        let total = max(photos.count, 1)
        for (index, item) in photos.enumerated() {
            if let hash = await computeHash(for: item) {
                hashes.append((item, hash))
            }
            progress = Double(index + 1) / Double(total)
        }

        groups = groupSimilar(hashes)
    }

    /// 해시 목록을 유사도 기준으로 묶는다.
    private func groupSimilar(_ hashes: [(item: PhotoItem, hash: UInt64)]) -> [DuplicateGroup] {
        var used = Set<Int>()
        var result: [DuplicateGroup] = []

        for i in hashes.indices {
            if used.contains(i) { continue }
            var group = [hashes[i].item]
            for j in (i + 1)..<hashes.count {
                if used.contains(j) { continue }
                if hammingDistance(hashes[i].hash, hashes[j].hash) <= similarityThreshold {
                    group.append(hashes[j].item)
                    used.insert(j)
                }
            }
            if group.count > 1 {
                used.insert(i)
                result.append(DuplicateGroup(items: group))
            }
        }
        // 중복이 많은 묶음을 먼저 보여준다.
        return result.sorted { $0.items.count > $1.items.count }
    }

    private func computeHash(for item: PhotoItem) async -> UInt64? {
        guard let image = await requestSmallImage(for: item) else { return nil }
        return averageHash(image)
    }

    /// 8×8 흑백 평균 해시(aHash)를 계산한다.
    private func averageHash(_ image: UIImage) -> UInt64? {
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

    private func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    private func requestSmallImage(for item: PhotoItem) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            var resumed = false
            imageManager.requestImage(
                for: item.asset,
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
