import SwiftUI

/// 세션 한정 성과 지표를 감성적으로 강조하는 뱃지 컴포넌트.
struct AchieveBadge: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let unit: String
    var isLoading: Bool = false

    /// value가 "0"이면 0 상태로 opacity를 낮춘다.
    private var isZero: Bool { value == "0" && !isLoading }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoading {
                SkeletonRect(width: 32, height: 32, cornerRadius: 8)
                SkeletonRect(height: 22, cornerRadius: 5)
                SkeletonRect(width: 60, height: 13, cornerRadius: 4)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.text1)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Color.text2)
                }

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.text2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(iconColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(iconColor.opacity(0.20), lineWidth: 1)
        )
        // 아직 정리 안 했음을 의미하는 0 상태는 opacity를 낮춰 표현
        .opacity(isZero ? 0.4 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? "로딩 중" : "\(label) \(value)\(unit)")
    }
}
