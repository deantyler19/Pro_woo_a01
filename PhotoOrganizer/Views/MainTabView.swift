import SwiftUI

/// 날짜별 / 장소별 / 얼굴별 / 중복사진 네 탭으로 구성된 메인 화면.
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

            FaceGroupView()
                .tabItem {
                    Label("얼굴별", systemImage: "person.2")
                }

            DuplicatesView()
                .tabItem {
                    Label("중복사진", systemImage: "square.on.square")
                }
        }
    }
}
