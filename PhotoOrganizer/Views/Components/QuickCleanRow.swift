import SwiftUI

/// 통계 화면에서 카테고리 정리 화면으로 원탭 진입하는 행 컴포넌트.
/// NavigationLink로 래핑해서 사용한다.
struct QuickCleanRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let unit: String
    var isLoading: Bool = false

    /// count가 0이면 비활성 상태로 표현한다.
    private var isEmpty: Bool { count == 0 && !isLoading }

    var body: some View {
        HStack(spacing: 12) {
            // 아이콘 컨테이너
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isEmpty ? Color(.tertiarySystemFill) : iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isEmpty ? Color.text3 : iconColor)
            }
            .accessibilityHidden(true)

            if isLoading {
                // 스켈레톤
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonRect(width: 80, height: 14, cornerRadius: 4)
                    SkeletonRect(width: 48, height: 12, cornerRadius: 4)
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isEmpty ? Color.text3 : Color.text1)
                    Text(isEmpty ? "없음" : "\(count)\(unit)")
                        .font(.subheadline)
                        .foregroundStyle(Color.text2)
                }

                Spacer()

                // HIG: push 전환이 있는 행에 chevron 필수
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.text3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())  // 전체 행 탭 영역 확보
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(count)\(unit)")
        .accessibilityHint(isEmpty ? "정리할 항목이 없습니다" : "탭하여 정리 시작")
        .accessibilityAddTraits(.isButton)
    }
}
