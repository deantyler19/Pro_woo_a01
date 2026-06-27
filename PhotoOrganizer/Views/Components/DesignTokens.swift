import SwiftUI

// MARK: - 컬러 토큰

extension Color {
    // 기존 팔레트
    static let brand        = Color(red: 0.39, green: 0.40, blue: 0.95) // #6366F1 인디고
    static let brandLight   = Color(red: 0.93, green: 0.93, blue: 0.99) // #EEEEFE
    static let brandSecond  = Color(red: 0.66, green: 0.33, blue: 0.97) // #A855F7
    static let success      = Color(red: 0.06, green: 0.73, blue: 0.51) // #10B981 에메랄드
    static let danger       = Color(red: 0.94, green: 0.27, blue: 0.27) // #EF4444 레드
    static let appBg        = Color(red: 0.98, green: 0.98, blue: 0.99) // #FAFAFD
    static let text1        = Color(red: 0.06, green: 0.06, blue: 0.14) // #0F0F23
    static let text2        = Color(red: 0.39, green: 0.39, blue: 0.49) // #64647D
    static let text3        = Color(red: 0.67, green: 0.67, blue: 0.75) // #AAAABE
    static let borderColor  = Color(red: 0.89, green: 0.89, blue: 0.95) // #E4E4F2

    // 신규 추가
    static let statBlue     = Color(red: 0.23, green: 0.51, blue: 0.96) // #3B82F6 블루-500
    static let warning      = Color(red: 0.96, green: 0.62, blue: 0.04) // #F59E0B 앰버-500
    static let warningLight = Color(red: 1.00, green: 0.98, blue: 0.92) // #FFFBEB

    // 스켈레톤 shimmer (다크모드 대응은 Asset Catalog 등록 권장 — Mac 빌드 필요)
    static let shimmerBase      = Color(red: 0.89, green: 0.89, blue: 0.95) // #E4E4F2
    static let shimmerHighlight = Color(red: 0.96, green: 0.96, blue: 0.98) // #F4F4FA
}

// MARK: - 카드 스타일 모디파이어

extension View {
    /// 통계 카드 공통 스타일: 배경·그림자·모서리 둥글림
    func cardStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            )
    }

    /// 섹션 헤더 공통 스타일
    func sectionHeaderStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Color.text1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
}
