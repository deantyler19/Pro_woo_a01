import SwiftUI

/// 보관함 현황의 단일 수치를 강조 표시하는 카드 컴포넌트.
/// VoiceOver에서 카드 전체가 단일 요소로 읽힌다.
struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 아이콘 컨테이너 (장식 요소 — VoiceOver 숨김)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            if isLoading {
                // 스켈레톤 플레이스홀더
                SkeletonRect(height: 28, cornerRadius: 6)
                SkeletonRect(width: 48, height: 13, cornerRadius: 4)
            } else {
                // 숫자 값 (largeTitle 계열 크기, Dynamic Type 지원)
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.text1)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                // 단위 + 제목 (text3 → text2: 대비 4.5:1 이상 확보)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Color.text2)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.text2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        )
        // 카드 전체를 단일 접근성 요소로 묶는다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? "로딩 중" : "\(title) \(value)\(unit)")
    }
}
