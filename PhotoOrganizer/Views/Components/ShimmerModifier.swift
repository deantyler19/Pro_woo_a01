import SwiftUI

// MARK: - Shimmer 뷰 모디파이어

/// 로딩 중 콘텐츠 자리를 채워 레이아웃 안정감을 주는 shimmer 애니메이션.
/// `reduceMotion`이 켜져 있으면 애니메이션을 끄고 shimmerBase 고정색만 보여준다.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if !reduceMotion {
                        LinearGradient(
                            stops: [
                                .init(color: Color.shimmerBase,      location: 0.0),
                                .init(color: Color.shimmerHighlight,  location: 0.4),
                                .init(color: Color.shimmerBase,      location: 0.8),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        // gradient 폭을 2배로 늘려 부드러운 스윕 효과를 낸다.
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width)
                    }
                }
                .clipped()
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// shimmer 애니메이션을 적용한다.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// 로딩 여부에 따라 shimmer를 조건부 적용한다.
    func shimmer(when isLoading: Bool) -> some View {
        isLoading ? AnyView(modifier(ShimmerModifier())) : AnyView(self)
    }
}

// MARK: - Skeleton 기본 블록

/// 직사각형 스켈레톤 플레이스홀더.
struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.shimmerBase)
            .frame(width: width, height: height)
            .shimmer()
            .accessibilityHidden(true)
    }
}

/// 텍스트 줄 형태의 스켈레톤 플레이스홀더.
struct SkeletonLine: View {
    /// 0.0~1.0 비율. nil이면 전체 너비.
    var widthFraction: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = widthFraction.map { geo.size.width * $0 } ?? geo.size.width
            SkeletonRect(width: w, height: 12, cornerRadius: 6)
        }
        .frame(height: 12)
    }
}
