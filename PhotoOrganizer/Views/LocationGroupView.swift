import SwiftUI

/// "장소별" 탭. GPS 메타데이터로 사진을 장소별로 묶고 검색을 지원한다.
struct LocationGroupView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @StateObject private var service = LocationService()
    @State private var hasRun = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if service.isProcessing {
                    ProgressView("장소를 분석하는 중…")
                } else if service.groups.isEmpty && service.noLocationItems.isEmpty {
                    ContentUnavailableView(
                        "분석할 사진이 없습니다",
                        systemImage: "map",
                        description: Text("위치 정보가 담긴 사진이 있으면 장소별로 묶어 드립니다.")
                    )
                } else if filteredGroups.isEmpty && filteredNoLocation.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    locationList
                }
            }
            .navigationTitle("장소별")
            .searchable(text: $searchText, prompt: "장소 이름으로 검색")
            .toolbar {
                Button {
                    Task { await service.organize(photos: library.photos) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(service.isProcessing)
            }
        }
        .task {
            guard !hasRun else { return }
            hasRun = true
            await service.organize(photos: library.photos)
        }
    }

    // MARK: - 리스트

    private var locationList: some View {
        List {
            if !filteredGroups.isEmpty {
                Section {
                    ForEach(filteredGroups) { group in
                        NavigationLink {
                            PhotoGridScreen(title: group.name, items: group.items)
                        } label: {
                            LocationRow(group: group)
                        }
                    }
                } header: {
                    Text("장소 \(filteredGroups.count)곳")
                }
            }

            if !filteredNoLocation.isEmpty && searchText.isEmpty {
                Section("위치 정보 없음") {
                    NavigationLink {
                        PhotoGridScreen(title: "위치 정보 없음", items: filteredNoLocation)
                    } label: {
                        Label("위치 정보 없는 사진 \(filteredNoLocation.count)장",
                              systemImage: "location.slash")
                    }
                }
            }
        }
    }

    // MARK: - 필터

    private var filteredGroups: [LocationGroup] {
        guard !searchText.isEmpty else { return service.groups }
        return service.groups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredNoLocation: [PhotoItem] { service.noLocationItems }
}

// MARK: - 행 컴포넌트

private struct LocationRow: View {
    let group: LocationGroup

    var body: some View {
        HStack(spacing: 12) {
            if let first = group.items.first {
                PhotoThumbnail(item: first, targetSize: CGSize(width: 120, height: 120))
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .padding(4)
                            .background(.tint, in: Circle())
                            .foregroundStyle(.white)
                            .offset(x: 4, y: 4)
                    }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.headline)
                Text("사진 \(group.items.count)장")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
