import SwiftUI

/// "얼굴별" 탭. People 앨범 또는 Vision 스캔으로 인물별 사진을 묶는다.
struct FaceGroupView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @StateObject private var service = FaceGroupService()
    @State private var hasRun = false

    var body: some View {
        NavigationStack {
            Group {
                if service.isScanning {
                    scanningView
                } else if service.groups.isEmpty {
                    emptyView
                } else {
                    groupList
                }
            }
            .navigationTitle("얼굴별")
            .toolbar {
                if !service.groups.isEmpty {
                    Button {
                        Task { await service.scanFaces(photos: library.photos) }
                    } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .task {
            guard !hasRun else { return }
            hasRun = true
            await service.loadPeopleAlbums()
            if service.groups.isEmpty {
                await service.scanFaces(photos: library.photos)
            }
        }
    }

    // MARK: - 하위 뷰

    private var scanningView: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("얼굴을 분석하는 중…")
                .font(.headline)
            ProgressView(value: service.progress)
                .padding(.horizontal, 48)
            Text("\(Int(service.progress * 100))%")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding()
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("얼굴별 정리", systemImage: "person.2.circle")
        } description: {
            Text("사진에서 얼굴을 감지해\n혼자·둘이서·여럿이 함께로 묶어 드립니다.")
        } actions: {
            Button("얼굴 스캔 시작") {
                Task { await service.scanFaces(photos: library.photos) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var groupList: some View {
        List {
            if service.sourceIsPeopleAlbum {
                Section {
                    ForEach(service.groups) { group in
                        NavigationLink {
                            PhotoGridScreen(title: group.name, items: group.items)
                        } label: { FaceGroupRow(group: group) }
                    }
                } header: {
                    Text("사진 앱 인물 앨범")
                }
            } else {
                Section {
                    ForEach(service.groups) { group in
                        NavigationLink {
                            PhotoGridScreen(title: group.name, items: group.items)
                        } label: { FaceGroupRow(group: group) }
                    }
                } header: {
                    Text("얼굴 수 기준 \(service.groups.reduce(0){$0+$1.items.count})장 분석 완료")
                }
            }
        }
    }
}

private struct FaceGroupRow: View {
    let group: FaceGroup

    private var icon: String {
        switch group.faceCount {
        case 0:  return "photo"
        case 1:  return "person.circle.fill"
        case 2:  return "person.2.fill"
        default: return "person.3.fill"
        }
    }

    private var iconColor: Color {
        switch group.faceCount {
        case 0:  return .secondary
        case 1:  return .accentColor
        case 2:  return Color(red: 0.66, green: 0.33, blue: 0.97)
        default: return Color(red: 0.06, green: 0.73, blue: 0.51)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.headline)
                Text(group.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FaceGroupView()
        .environmentObject(PhotoLibraryService())
}
