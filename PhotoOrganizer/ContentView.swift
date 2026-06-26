import SwiftUI
import Photos

/// 루트 뷰. 권한 상태에 따라 메인 화면 또는 권한 요청 화면을 보여준다.
struct ContentView: View {
    @StateObject private var library = PhotoLibraryService()

    var body: some View {
        Group {
            switch library.authorizationStatus {
            case .authorized, .limited:
                MainTabView()
                    .environmentObject(library)
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
        .task {
            await library.loadIfAuthorized()
        }
    }
}

#Preview {
    ContentView()
}
