import SwiftUI

/// 사진 한 장의 썸네일을 비동기로 로드해 보여주는 뷰.
struct PhotoThumbnail: View {
    let item: PhotoItem
    var targetSize = CGSize(width: 300, height: 300)

    @EnvironmentObject var library: PhotoLibraryService
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .overlay(ProgressView())
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: item.id) {
            image = await library.requestThumbnail(for: item, targetSize: targetSize)
        }
    }
}
