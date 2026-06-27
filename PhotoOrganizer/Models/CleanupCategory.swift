/// 카테고리 정리 화면에서 취급하는 콘텐츠 유형.
enum CleanupCategory {
    case screenshots
    case largeVideos

    var title: String {
        switch self {
        case .screenshots: return "스크린샷"
        case .largeVideos: return "대용량 동영상"
        }
    }

    var emptyIcon: String { "checkmark.circle.fill" }

    var emptyTitle: String { "정리할 항목이 없습니다" }

    var emptyBody: String {
        switch self {
        case .screenshots: return "스크린샷이 발견되지 않았습니다."
        case .largeVideos: return "대용량 동영상이\n발견되지 않았습니다."
        }
    }
}
