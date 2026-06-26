import SwiftUI

/// "날짜별" 탭. 사진을 연·월 단위로 묶고 검색을 지원한다.
struct DateGroupView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if library.isLoading {
                    ProgressView("사진을 불러오는 중…")
                } else if library.photos.isEmpty {
                    ContentUnavailableView("사진이 없습니다", systemImage: "photo")
                } else if filteredSections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    sectionList
                }
            }
            .navigationTitle("날짜별")
            .searchable(text: $searchText, prompt: "연도 또는 월로 검색")
        }
    }

    // MARK: - 섹션 리스트

    private var sectionList: some View {
        List {
            // 연도별로 묶어 섹션 헤더를 표시한다.
            ForEach(groupedByYear, id: \.year) { yearGroup in
                Section {
                    ForEach(yearGroup.sections) { section in
                        NavigationLink {
                            PhotoGridScreen(title: section.title, items: section.items)
                        } label: {
                            DateRow(section: section)
                        }
                    }
                } header: {
                    Text(String(yearGroup.year))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - 데이터 가공

    private var allSections: [DateSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: library.photos) { item -> DateComponents in
            guard let date = item.creationDate else { return DateComponents() }
            return calendar.dateComponents([.year, .month], from: date)
        }
        return grouped
            .map { DateSection(components: $0.key, items: $0.value) }
            .sorted { ($0.sortDate ?? .distantPast) > ($1.sortDate ?? .distantPast) }
    }

    private var filteredSections: [DateSection] {
        guard !searchText.isEmpty else { return allSections }
        return allSections.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedByYear: [(year: Int, sections: [DateSection])] {
        let byYear = Dictionary(grouping: filteredSections) {
            $0.components.year ?? 0
        }
        return byYear
            .map { (year: $0.key, sections: $0.value) }
            .sorted { $0.year > $1.year }
    }
}

// MARK: - 모델

struct DateSection: Identifiable {
    let components: DateComponents
    let items: [PhotoItem]

    var id: String { title }

    var sortDate: Date? { Calendar.current.date(from: components) }

    var title: String {
        guard let year = components.year, let month = components.month else {
            return "날짜 정보 없음"
        }
        return "\(year)년 \(month)월"
    }
}

// MARK: - 행 컴포넌트

private struct DateRow: View {
    let section: DateSection

    var body: some View {
        HStack(spacing: 12) {
            if let first = section.items.first {
                PhotoThumbnail(item: first, targetSize: CGSize(width: 120, height: 120))
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 3) {
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
