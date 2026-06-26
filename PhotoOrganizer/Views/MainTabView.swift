import SwiftUI

/// 날짜별 / 장소별 / 중복사진 세 탭으로 구성된 메인 화면.
struct MainTabView: View {
    @EnvironmentObject var library: PhotoLibraryService

    var body: some View {
        TabView {
            DateGroupView()
                .tabItem {
                    Label("날짜별", systemImage: "calendar")
                }

            LocationGroupView()
                .tabItem {
                    Label("장소별", systemImage: "map")
                }

            DuplicatesView()
                .tabItem {
                    Label("중복사진", systemImage: "square.on.square")
                }
        }
    }
}
