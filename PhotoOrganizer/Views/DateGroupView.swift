import SwiftUI

/// "날짜별" 탭. 사진을 연·월 단위로 묶어 목록으로 보여준다.
struct DateGroupView: View {
    @EnvironmentObject var library: PhotoLibraryService

    var body: some View {
        NavigationStack {
            Group {
                if library.isLoading {
                    ProgressView("사진을 불러오는 중…")
                } else if library.photos.isEmpty {
                    ContentUnavailableView("사진이 없습니다", systemImage: "photo")
                } else {
                    List(sections) { section in
                        NavigationLink {
                            PhotoGridScreen(title: section.title, items: section.items)
                        } label: {
                            DateRow(section: section)
                        }
                    }
                }
            }
            .navigationTitle("날짜별")
        }
    }

    /// 연·월로 묶은 섹션을 최신순으로 반환한다.
    private var sections: [DateSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: library.photos) { item -> DateComponents in
            guard let date = item.creationDate else { return DateComponents() }
            return calendar.dateComponents([.year, .month], from: date)
        }
        return grouped
            .map { DateSection(components: $0.key, items: $0.value) }
            .sorted { ($0.sortDate ?? .distantPast) > ($1.sortDate ?? .distantPast) }
    }
}

/// 연·월 섹션 모델.
struct DateSection: Identifiable {
    let components: DateComponents
    let items: [PhotoItem]

    var id: String { title }

    var sortDate: Date? {
        Calendar.current.date(from: components)
    }

    var title: String {
        guard let year = components.year, let month = components.month else {
            return "날짜 정보 없음"
        }
        return "\(year)년 \(month)월"
    }
}

private struct DateRow: View {
    let section: DateSection

    var body: some View {
        HStack(spacing: 12) {
            if let first = section.items.first {
                PhotoThumbnail(item: first, targetSize: CGSize(width: 120, height: 120))
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.headline)
                Text("사진 \(section.items.count)장")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
