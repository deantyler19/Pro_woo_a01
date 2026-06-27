import Foundation
import Photos

/// `CategoryCleanupView` 전용 뷰모델.
/// 스크린샷 / 대용량 동영상 각 카테고리의 로드·삭제·상태를 관리한다.
@MainActor
final class CategoryCleanupViewModel: ObservableObject {

    // MARK: - 뷰 상태 열거

    enum ViewState {
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published var state: ViewState = .loading

    /// 사진 카테고리(스크린샷) 항목
    @Published var items: [PhotoItem] = []

    /// 동영상 항목
    @Published var videoItems: [VideoItem] = []

    /// 동영상 파일 크기 표시 문자열 (id → "N MB")
    @Published var fileSizes: [String: String] = [:]

    /// 동영상 재생 시간 표시 문자열 (id → "N분 N초")
    @Published var durations: [String: String] = [:]

    // MARK: - 로드

    func load(category: CleanupCategory, library: PhotoLibraryService) async {
        state = .loading
        fileSizes = [:]
        durations = [:]

        switch category {
        case .screenshots:
            let result = await library.fetchScreenshots()
            items = result
            videoItems = []
            state = result.isEmpty ? .empty : .loaded

        case .largeVideos:
            var result = await library.fetchLargeVideos()
            items = []

            // 재생시간 먼저 채운다 (PHAsset.duration은 동기 접근 가능)
            for item in result {
                durations[item.id] = formatDuration(item.duration)
            }

            videoItems = result

            if result.isEmpty {
                state = .empty
                return
            }

            state = .loaded

            // 파일 크기는 백그라운드에서 채우면서 점진 반영
            await loadFileSizes(for: &result, library: library)
        }
    }

    // MARK: - 파일 크기 점진 로드

    private func loadFileSizes(for items: inout [VideoItem], library: PhotoLibraryService) async {
        await library.loadFileSizes(for: &items)

        // 완료된 사이즈를 딕셔너리로 변환
        var newSizes: [String: String] = [:]
        for item in items {
            if let mb = item.fileSizeMB {
                newSizes[item.id] = formatFileSize(mb)
            }
        }

        withAnimation(.easeIn(duration: 0.2)) {
            fileSizes = newSizes
        }
        // videoItems의 fileSizeMB도 갱신. O(n²) 선형 검색 대신 딕셔너리로 O(n) 룩업.
        let updatedByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for i in videoItems.indices {
            if let updated = updatedByID[videoItems[i].id] {
                videoItems[i] = updated
            }
        }
    }

    // MARK: - 삭제 (사진)

    func deletePhotos(
        ids: Set<String>,
        library: PhotoLibraryService,
        statsStore: StatsStore
    ) async -> Bool {
        let toDelete = items.filter { ids.contains($0.id) }
        let success = await library.deleteAssets(toDelete)
        if success {
            statsStore.recordDeletion(items: toDelete)
            items.removeAll { ids.contains($0.id) }
            if items.isEmpty { state = .empty }
        }
        return success
    }

    // MARK: - 삭제 (동영상)

    func deleteVideos(
        ids: Set<String>,
        library: PhotoLibraryService,
        statsStore: StatsStore
    ) async -> Bool {
        let toDelete = videoItems.filter { ids.contains($0.id) }
        let success = await library.deleteVideoAssets(toDelete)
        if success {
            statsStore.recordVideoDeletion(items: toDelete)
            videoItems.removeAll { ids.contains($0.id) }
            if videoItems.isEmpty { state = .empty }
        }
        return success
    }

    // MARK: - 내비게이션 타이틀

    func navigationTitle(for category: CleanupCategory) -> String {
        switch category {
        case .screenshots:
            return items.isEmpty ? "스크린샷" : "스크린샷 \(items.count)장"
        case .largeVideos:
            return videoItems.isEmpty ? "대용량 동영상" : "대용량 동영상 \(videoItems.count)개"
        }
    }

    // MARK: - 포맷 헬퍼

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        if m == 0 { return "\(s)초" }
        return "\(m)분 \(s)초"
    }

    private func formatFileSize(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
