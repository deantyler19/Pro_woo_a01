import Photos

/// 동영상 한 편을 나타내는 모델. `PHAsset`을 감싸 메타데이터에 쉽게 접근하게 한다.
struct VideoItem: Identifiable, Hashable {
    let asset: PHAsset

    /// PHAsset.localIdentifier를 ID로 사용한다.
    var id: String { asset.localIdentifier }

    /// 촬영(생성) 날짜
    var creationDate: Date? { asset.creationDate }

    /// 재생 시간(초). PHAsset.duration에서 직접 읽는다.
    var duration: TimeInterval { asset.duration }

    /// 파일 크기(MB). PHAssetResource에서 비동기로 채운다.
    /// 로드 완료 전에는 nil을 유지해 플레이스홀더를 표시한다.
    var fileSizeMB: Double?

    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
