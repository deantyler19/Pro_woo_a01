import SwiftUI

/// 스크린샷 또는 대용량 동영상을 정리하는 화면.
/// `category` 파라미터로 두 모드를 하나의 뷰에서 분기한다.
struct CategoryCleanupView: View {
    let category: CleanupCategory

    @EnvironmentObject var library: PhotoLibraryService
    @EnvironmentObject var statsStore: StatsStore
    @StateObject private var vm = CategoryCleanupViewModel()
    @State private var showLimitedBanner = false

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                loadingView

            case .empty:
                emptyView

            case .error(let msg):
                errorView(message: msg)

            case .loaded:
                contentView
            }
        }
        .navigationTitle(vm.navigationTitle(for: category))
        .navigationBarTitleDisplayMode(.inline)
        // limited 배너는 safeAreaInset으로 콘텐츠 위에 겹치지 않고 밀어낸다.
        .safeAreaInset(edge: .top) {
            if showLimitedBanner {
                InfoBanner(
                    style: .warning,
                    message: "일부 사진에만 접근할 수 있어 목록이 불완전할 수 있습니다",
                    isDismissible: true,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showLimitedBanner = false
                        }
                    }
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .task {
            await vm.load(category: category, library: library)
            showLimitedBanner = (library.authorizationStatus == .limited)
        }
    }

    // MARK: - 콘텐츠 분기

    @ViewBuilder
    private var contentView: some View {
        switch category {
        case .screenshots:
            // 스크린샷: 기존 PhotoGridScreen 재사용
            PhotoGridScreen(
                title: vm.navigationTitle(for: category),
                items: vm.items
            )
        case .largeVideos:
            // 대용량 동영상: 신규 리스트 레이아웃
            VideoListView(vm: vm)
        }
    }

    // MARK: - 로딩 상태

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("항목을 불러오고 있습니다…")
                .font(.body)
                .foregroundStyle(Color.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("목록을 불러오고 있습니다")
    }

    // MARK: - 빈 상태

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: category.emptyIcon)
                .font(.system(size: 56))
                .foregroundStyle(Color.success)
                .accessibilityHidden(true)
            Text(category.emptyTitle)
                .font(.title2.bold())
                .foregroundStyle(Color.text1)
            Text(category.emptyBody)
                .font(.body)
                .foregroundStyle(Color.text2)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 오류 상태

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.danger)
                .accessibilityHidden(true)
            Text("불러오지 못했습니다")
                .font(.title2.bold())
                .foregroundStyle(Color.text1)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.text2)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await vm.load(category: category, library: library) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - VideoListView (대용량 동영상 목록)

/// 대용량 동영상 모드 전용 리스트 뷰.
/// `CategoryCleanupView`에서만 사용한다.
private struct VideoListView: View {
    @ObservedObject var vm: CategoryCleanupViewModel

    @EnvironmentObject var library: PhotoLibraryService
    @EnvironmentObject var statsStore: StatsStore

    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var showConfirm = false
    @State private var showDeleteError = false

    var body: some View {
        List {
            ForEach(vm.videoItems) { item in
                VideoRow(
                    item: item,
                    formattedSize: vm.fileSizes[item.id],
                    formattedDuration: vm.durations[item.id] ?? "",
                    isEditing: isEditing,
                    isSelected: selectedIDs.contains(item.id)
                ) {
                    if isEditing {
                        if selectedIDs.contains(item.id) {
                            selectedIDs.remove(item.id)
                        } else {
                            selectedIDs.insert(item.id)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "완료" : "선택") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                        if !isEditing { selectedIDs.removeAll() }
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    let isAll = selectedIDs.count == vm.videoItems.count
                    Button(isAll ? "전체 해제" : "전체 선택") {
                        selectedIDs = isAll ? [] : Set(vm.videoItems.map(\.id))
                    }
                }
            }
        }
        // 하단 삭제 바 — DeleteActionBar 공유 컴포넌트 사용
        .safeAreaInset(edge: .bottom) {
            if isEditing && !selectedIDs.isEmpty {
                DeleteActionBar(
                    selectedCount: selectedIDs.count,
                    countUnit: "개",
                    onDelete: { showConfirm = true }
                )
            }
        }
        // 삭제 확인 다이얼로그
        .confirmationDialog(
            "\(selectedIDs.count)개의 동영상을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task { await performDelete() }
            }
        }
        // 삭제 실패 알림
        .alert("삭제하지 못했습니다", isPresented: $showDeleteError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("동영상을 삭제하지 못했습니다. 다시 시도해 주세요.")
        }
    }

    // MARK: - 삭제 실행

    private func performDelete() async {
        let targetIDs = selectedIDs
        isEditing = false
        selectedIDs.removeAll()

        let success = await vm.deleteVideos(
            ids: targetIDs,
            library: library,
            statsStore: statsStore
        )
        if !success {
            showDeleteError = true
        }
    }
}
