import SwiftUI

/// 동영상 한 편의 썸네일을 비동기로 로드해 보여주는 뷰.
/// `VideoItem`을 받는다는 점에서 `PhotoThumbnail`과 구분된다.
struct VideoThumbnail: View {
    let item: VideoItem
    var targetSize = CGSize(width: 112, height: 112)

    @EnvironmentObject var library: PhotoLibraryService
    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                // 썸네일 로드 실패 상태
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        Image(systemName: "video.slash")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.text3)
                    )
            } else {
                // 로딩 중 스켈레톤
                Rectangle()
                    .fill(Color.shimmerBase)
                    .shimmer()
            }
        }
        .task(id: item.id) {
            if let loaded = await library.requestVideoThumbnail(for: item, targetSize: targetSize) {
                image = loaded
            } else {
                loadFailed = true
            }
        }
    }
}
