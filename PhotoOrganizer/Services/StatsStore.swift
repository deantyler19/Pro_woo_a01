import Foundation

/// 앱 세션 동안의 정리 성과를 추적하는 스토어.
/// `@StateObject`로 `ContentView`에서 생성하고 `.environmentObject`로 주입한다.
/// 앱을 종료하면 초기화된다(의도적 설계 — 세션 내 성취감 피드백 목적).
@MainActor
final class StatsStore: ObservableObject {
    /// 이번 세션에서 삭제한 사진·동영상 합계
    @Published private(set) var deletedCount: Int = 0

    /// 이번 세션에서 절약 추정된 용량(bytes).
    /// 사진: 픽셀 w×h×3 바이트로 추정. 동영상: fileSizeMB가 있으면 그 값을 사용.
    @Published private(set) var estimatedSavedBytes: Int64 = 0

    // MARK: - 기록

    /// 삭제된 사진 목록을 기록한다. 픽셀 w×h×3 바이트로 용량을 추정한다.
    func recordDeletion(items: [PhotoItem]) {
        guard !items.isEmpty else { return }
        deletedCount += items.count

        // 무거운 픽셀 합산 연산은 Task.detached로 오프로드한다.
        let snapshots = items.map { ($0.asset.pixelWidth, $0.asset.pixelHeight) }
        Task.detached(priority: .userInitiated) { [weak self] in
            var total: Int64 = 0
            for (w, h) in snapshots {
                total += Int64(w) * Int64(h) * 3
            }
            await MainActor.run { [weak self] in
                self?.estimatedSavedBytes += total
            }
        }
    }

    /// 삭제된 동영상 목록을 기록한다. fileSizeMB가 있으면 그 값을, 없으면 픽셀 추정값을 사용한다.
    func recordVideoDeletion(items: [VideoItem]) {
        guard !items.isEmpty else { return }
        deletedCount += items.count

        let snapshots = items.map { ($0.asset.pixelWidth, $0.asset.pixelHeight, $0.fileSizeMB) }
        Task.detached(priority: .userInitiated) { [weak self] in
            var total: Int64 = 0
            for (w, h, sizeMB) in snapshots {
                if let mb = sizeMB {
                    total += Int64(mb * 1_048_576)
                } else {
                    // fileSizeMB 미로드 시 픽셀 추정 (비디오는 × 3프레임 × 30 추정)
                    total += Int64(w) * Int64(h) * 3
                }
            }
            await MainActor.run { [weak self] in
                self?.estimatedSavedBytes += total
            }
        }
    }

    // MARK: - 표현값 헬퍼

    /// 절약한 용량을 MB 단위 문자열로 반환한다.
    var savedMBString: String {
        let mb = Double(estimatedSavedBytes) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.1f", mb / 1024)  // GB 단위는 StatsView에서 분기
        }
        return String(format: "%.0f", mb)
    }

    /// GB 단위인지 여부. StatsView에서 단위 문자열 표시에 사용.
    var savedUnit: String {
        let mb = Double(estimatedSavedBytes) / 1_048_576
        return mb >= 1024 ? "GB" : "MB"
    }
}
