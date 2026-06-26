import Photos
import CoreLocation

/// 사진 한 장을 나타내는 모델. `PHAsset`을 감싸 메타데이터에 쉽게 접근하게 한다.
struct PhotoItem: Identifiable, Hashable {
    let asset: PHAsset

    var id: String { asset.localIdentifier }

    /// 촬영(생성) 날짜
    var creationDate: Date? { asset.creationDate }

    /// 촬영 위치(GPS). 위치 정보가 없는 사진이면 nil.
    var location: CLLocation? { asset.location }

    /// 픽셀 크기
    var pixelSize: CGSize {
        CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
