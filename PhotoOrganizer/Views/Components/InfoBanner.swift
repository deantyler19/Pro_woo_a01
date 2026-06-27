import SwiftUI
import UIKit

// MARK: - 배너 스타일

/// 정보 배너의 시각적 스타일 분류.
enum BannerStyle {
    case warning    // limited 권한, 주의 정보
    case error      // 오류 상태
    case info       // 일반 안내

    var iconName: String {
        switch self {
        case .warning: return "lock.trianglebadge.exclamationmark.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .warning: return .warning
        case .error:   return .danger
        case .info:    return .brand
        }
    }

    /// 다크모드 대응: 시스템 컬러 기반 반투명 배경 사용.
    var backgroundColor: Color {
        switch self {
        case .warning: return Color(.systemYellow).opacity(0.12)
        case .error:   return Color(.systemRed).opacity(0.10)
        case .info:    return Color.brandLight.opacity(0.85)
        }
    }
}

// MARK: - InfoBanner 뷰

/// limited 권한 등 비파괴적 경고를 컨텍스트 내에서 표시하는 배너.
/// 화면 전체를 교체하지 않고 콘텐츠와 공존해 사용자 흐름을 유지한다.
struct InfoBanner: View {
    let style: BannerStyle
    let message: String
    /// 오른쪽 액션 링크 레이블 (nil이면 미표시)
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil
    /// 닫기 × 버튼 표시 여부
    var isDismissible: Bool = false
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: style.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(style.accentColor)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.text1)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel, let onAction {
                    Button(actionLabel, action: onAction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.accentColor)
                        .accessibilityLabel(actionLabel)
                }
            }

            Spacer(minLength: 0)

            if isDismissible {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.text3)
                        // 44pt 터치 타깃 확보
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("배너 닫기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(style.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style.accentColor.opacity(0.30), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        // 배너 전체를 단일 접근성 요소로 묶는다.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("경고: \(message)")
    }
}
