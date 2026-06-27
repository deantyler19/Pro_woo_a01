import SwiftUI

/// "중복사진" 탭. 유사·중복 사진을 찾아 묶고, 묶음별로 정리(삭제)할 수 있다.
struct DuplicatesView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @EnvironmentObject var statsStore: StatsStore
    @StateObject private var detector = DuplicateDetector()
    @State private var deletingGroupID: UUID?
    @State private var showDeleteError = false

    var body: some View {
        NavigationStack {
            Group {
                if detector.isScanning {
                    VStack(spacing: 16) {
                        ProgressView(value: detector.progress)
                            .padding(.horizontal, 40)
                        Text("중복 사진을 찾는 중… \(Int(detector.progress * 100))%")
                            .foregroundStyle(.secondary)
                    }
                } else if detector.groups.isEmpty {
                    ContentUnavailableView {
                        Label("중복 사진을 찾아보세요", systemImage: "square.on.square")
                    } description: {
                        Text("보관함을 분석해 비슷하거나 똑같은 사진을 묶어 드립니다.")
                    } actions: {
                        Button("분석 시작") {
                            Task { await detector.scan(photos: library.photos) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(detector.groups) { group in
                                DuplicateGroupRow(
                                    group: group,
                                    isDeleting: deletingGroupID == group.id,
                                    onCleanup: { await cleanup(group) }
                                )
                            }
                        } header: {
                            Text("총 \(detector.groups.count)개 묶음에서 정리 가능한 사진 \(removableCount)장")
                        }
                    }
                }
            }
            .navigationTitle("중복사진")
            .alert("삭제하지 못했습니다", isPresented: $showDeleteError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("사진을 삭제하지 못했습니다. 다시 시도해 주세요.")
            }
            .toolbar {
                if !detector.groups.isEmpty {
                    Button {
                        Task { await detector.scan(photos: library.photos) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    /// 각 묶음에서 첫 장을 제외한 나머지(= 정리 대상) 총합.
    private var removableCount: Int {
        detector.groups.reduce(0) { $0 + max($1.items.count - 1, 0) }
    }

    /// 묶음에서 첫 장(원본)만 남기고 나머지를 삭제한다.
    private func cleanup(_ group: DuplicateGroup) async {
        deletingGroupID = group.id
        defer { deletingGroupID = nil }

        let toDelete = Array(group.items.dropFirst())
        let success = await library.deleteAssets(toDelete)
        if success {
            // 삭제 성공 시 StatsStore에 성과 기록
            statsStore.recordDeletion(items: toDelete)
            detector.groups.removeAll { $0.id == group.id }
        } else {
            showDeleteError = true
        }
    }
}

private struct DuplicateGroupRow: View {
    let group: DuplicateGroup
    let isDeleting: Bool
    let onCleanup: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        ZStack(alignment: .topLeading) {
                            PhotoThumbnail(item: item, targetSize: CGSize(width: 200, height: 200))
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            if index == 0 {
                                Text("원본")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint, in: Capsule())
                                    .foregroundStyle(.white)
                                    .padding(4)
                            }
                        }
                    }
                }
            }

            HStack {
                Text("\(group.items.count)장이 비슷합니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    Task { await onCleanup() }
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("원본만 남기고 정리")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isDeleting)
            }
        }
        .padding(.vertical, 4)
    }
}
