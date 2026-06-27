import SwiftUI

/// 다중 선택 후 삭제를 실행하는 하단 액션 바.
/// `PhotoGridScreen`과 `VideoListView` 등에서 공유한다.
struct DeleteActionBar: View {
    /// 현재 선택된 항목 수
    let selectedCount: Int
    /// "N장 선택됨" vs "N개 선택됨" 단위 문자열
    var countUnit: String = "장"
    /// 삭제 버튼 탭 콜백
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedCount)\(countUnit) 선택됨")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("삭제하면 복구가 어렵습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Label("삭제", systemImage: "trash.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.danger)
            // 버튼 높이 44pt 확보 (padding.vertical 12 + label height ≈ 44)
            .accessibilityLabel("선택한 \(selectedCount)\(countUnit) 삭제")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Rectangle())
        .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
