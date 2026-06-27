import Foundation
import Photos

/// `StatsView` 전용 뷰모델.
/// PhotoLibraryService와 StatsStore의 데이터를 뷰에 맞게 가공한다.
@MainActor
final class StatsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var photoCount: String = "–"
    @Published var videoCount: String = "–"
    @Published var totalGB: String = "–"
    @Published var screenshotCount: Int = 0
    @Published var largeVideoCount: Int = 0
    @Published var errorMessage: String? = nil

    // 세션 성과(삭제 수·절약 용량)는 StatsView가 StatsStore에서 직접 읽어
    // 항상 동기화된 값을 표시한다. (뷰모델에 복사본을 두면 갱신 타이밍이 어긋남)

    func load(library: PhotoLibraryService, statsStore: StatsStore) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 사진·동영상 카운트는 @MainActor이므로 직접 읽는다.
        photoCount = formatCount(library.photos.count)
        videoCount = formatCount(library.videos.count)

        // 스크린샷 카운트 — fetchScreenshots는 async이므로 await
        let screenshots = await library.fetchScreenshots()
        screenshotCount = screenshots.count

        // 대용량 동영상 카운트 (duration 기준 내림차순)
        let largeVideos = await library.fetchLargeVideos()
        largeVideoCount = largeVideos.count

        // 총 용량 추정: 무거운 연산은 Task.detached로 오프로드
        let photoAssets = library.photos.map { ($0.asset.pixelWidth, $0.asset.pixelHeight) }
        let estimatedGB: Double = await Task.detached(priority: .userInitiated) {
            var totalBytes: Int64 = 0
            for (w, h) in photoAssets {
                totalBytes += Int64(w) * Int64(h) * 3
            }
            return Double(totalBytes) / 1_073_741_824  // bytes → GB
        }.value

        totalGB = String(format: "%.1f", estimatedGB)
    }

    // MARK: - 포맷 헬퍼

    private func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
