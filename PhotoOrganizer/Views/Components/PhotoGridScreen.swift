import SwiftUI

/// 사진 묶음을 격자로 보여주는 재사용 화면.
struct PhotoGridScreen: View {
    let title: String
    let items: [PhotoItem]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(items) { item in
                    PhotoThumbnail(item: item)
                        .aspectRatio(1, contentMode: .fill)
                }
            }
            .padding(2)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
