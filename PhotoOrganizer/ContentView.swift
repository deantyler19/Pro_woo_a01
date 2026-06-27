import SwiftUI
import Photos

/// 루트 뷰. 스플래시 → 권한 상태에 따라 메인 화면 또는 권한 요청 화면을 보여준다.
struct ContentView: View {
    @StateObject private var library = PhotoLibraryService()
    /// 앱 세션 성과 추적 스토어. 탭 트리 전체에 environmentObject로 공유.
    @StateObject private var statsStore = StatsStore()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            mainContent
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            await library.loadIfAuthorized()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch library.authorizationStatus {
        case .authorized, .limited:
            MainTabView()
                .environmentObject(library)
                .environmentObject(statsStore)
        case .denied, .restricted:
            PermissionDeniedView()
        case .notDetermined:
            RequestAccessView {
                await library.requestAuthorization()
            }
        @unknown default:
            RequestAccessView {
                await library.requestAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
}
