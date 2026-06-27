import CoreLocation
import Foundation

/// 같은 장소에서 찍힌 사진들의 묶음.
struct LocationGroup: Identifiable {
    let id = UUID()
    var name: String
    var items: [PhotoItem]
    var representativeLocation: CLLocation?
}

/// GPS 좌표를 클러스터링하고 지명으로 변환해 "장소별 정리"를 만드는 서비스.
@MainActor
final class LocationService: ObservableObject {
    @Published var groups: [LocationGroup] = []
    @Published var noLocationItems: [PhotoItem] = []
    @Published var isProcessing = false

    private let geocoder = CLGeocoder()

    /// 좌표 반올림 단위(도). 0.1도 ≈ 약 11km 반경으로 묶는다.
    private let clusterPrecision = 10.0

    func organize(photos: [PhotoItem]) async {
        isProcessing = true
        defer { isProcessing = false }

        let located = photos.filter { $0.location != nil }
        noLocationItems = photos.filter { $0.location == nil }

        // 1) 좌표를 격자(grid)로 반올림해 군집을 만든다.
        var clusters: [String: [PhotoItem]] = [:]
        for item in located {
            guard let loc = item.location else { continue }
            let lat = (loc.coordinate.latitude * clusterPrecision).rounded() / clusterPrecision
            let lon = (loc.coordinate.longitude * clusterPrecision).rounded() / clusterPrecision
            let key = "\(lat),\(lon)"
            clusters[key, default: []].append(item)
        }

        // 2) 각 군집의 대표 좌표를 지명으로 변환한다.
        //    군집이 많으면 전체 완료까지 오래 걸리므로, 사진이 많은 군집부터
        //    처리하고 결과를 점진적으로 반영해 사용자가 먼저 볼 수 있게 한다.
        groups = []
        let ordered = clusters.values.sorted { $0.count > $1.count }
        for items in ordered {
            let representative = items.first?.location
            let name = await placeName(for: representative)
            groups.append(LocationGroup(name: name, items: items,
                                        representativeLocation: representative))
            // CLGeocoder 호출 제한(분당 약 50회)을 피하기 위해 잠시 대기.
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }

    /// 좌표를 사람이 읽을 수 있는 지명으로 변환한다.
    private func placeName(for location: CLLocation?) async -> String {
        guard let location else { return "위치 정보 없음" }
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return "알 수 없는 장소"
        }
        // 예: "서울특별시 강남구", "Jeju, 대한민국"
        let parts = [
            placemark.administrativeArea,
            placemark.locality ?? placemark.subAdministrativeArea,
            placemark.subLocality
        ].compactMap { $0 }

        let unique = parts.reduce(into: [String]()) { acc, part in
            if !acc.contains(part) { acc.append(part) }
        }
        return unique.isEmpty ? (placemark.name ?? "알 수 없는 장소") : unique.joined(separator: " ")
    }
}
