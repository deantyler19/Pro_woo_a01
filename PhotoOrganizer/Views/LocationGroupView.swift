import SwiftUI

/// "장소별" 탭. GPS 메타데이터로 사진을 장소별로 묶어 보여준다.
struct LocationGroupView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @StateObject private var service = LocationService()
    @State private var hasRun = false

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
                } else {
                    List {
                        Section {
                            ForEach(service.groups) { group in
                                NavigationLink {
                                    PhotoGridScreen(title: group.name, items: group.items)
                                } label: {
                                    LocationRow(group: group)
                                }
                            }
                        }

                        if !service.noLocationItems.isEmpty {
                            Section("위치 정보 없음") {
                                NavigationLink {
                                    PhotoGridScreen(title: "위치 정보 없음", items: service.noLocationItems)
                                } label: {
                                    Label("위치 정보 없는 사진 \(service.noLocationItems.count)장", systemImage: "questionmark.circle")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("장소별")
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
}

private struct LocationRow: View {
    let group: LocationGroup

    var body: some View {
        HStack(spacing: 12) {
            if let first = group.items.first {
                PhotoThumbnail(item: first, targetSize: CGSize(width: 120, height: 120))
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
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
