import SwiftUI

/// 앱 첫 실행 시 보여주는 인앱 스플래시 화면.
/// 시스템 LaunchScreen.storyboard가 사라진 뒤 잠깐 표시되며 사진 권한 로딩을 자연스럽게 가립니다.
struct SplashView: View {
    let onFinish: () -> Void

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        ZStack {
            // 그라디언트 배경
            LinearGradient(
                colors: [
                    Color(red: 0.39, green: 0.20, blue: 0.87),
                    Color(red: 0.28, green: 0.46, blue: 0.71)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 아이콘
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage(systemName: "photo.stack.fill")!)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Spacer().frame(height: 28)

                // 앱 이름
                Text("사진정리")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer().frame(height: 8)

                // 부제
                Text("날짜 · 장소 · 중복 정리")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(subtitleOpacity)

                Spacer()

                // 하단 점 로딩 인디케이터
                BouncingDots()
                    .opacity(subtitleOpacity)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            // 아이콘 팝인
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            // 제목 슬라이드업
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
            // 부제 + 로딩 점
            withAnimation(.easeOut(duration: 0.3).delay(0.45)) {
                subtitleOpacity = 1.0
            }
            // 0.8초 후 메인 화면으로 전환
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onFinish()
            }
        }
    }
}

/// 세 점이 순서대로 통통 튀는 로딩 애니메이션.
private struct BouncingDots: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .offset(y: animate ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.45)
                        .repeatForever()
                        .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    SplashView(onFinish: {})
}
