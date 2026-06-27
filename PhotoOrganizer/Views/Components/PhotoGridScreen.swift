import SwiftUI

/// 사진 묶음을 격자로 보여주는 재사용 화면.
/// 우상단 "선택" 버튼으로 다중 선택 모드를 활성화해 일괄 삭제할 수 있다.
struct PhotoGridScreen: View {
    let title: String
    let items: [PhotoItem]

    @EnvironmentObject var library: PhotoLibraryService
    @EnvironmentObject var statsStore: StatsStore
    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var deletedIDs:  Set<String> = []
    @State private var showConfirm  = false
    @State private var showDeleteError = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var displayItems: [PhotoItem] {
        items.filter { !deletedIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(displayItems) { item in
                    SelectableThumbnail(
                        item: item,
                        isEditing: isEditing,
                        isSelected: selectedIDs.contains(item.id)
                    ) {
                        guard isEditing else { return }
                        if selectedIDs.contains(item.id) {
                            selectedIDs.remove(item.id)
                        } else {
                            selectedIDs.insert(item.id)
                        }
                    }
                    .aspectRatio(1, contentMode: .fill)
                }
            }
            .padding(2)
            .padding(.bottom, isEditing ? 100 : 0)
        }
        .navigationTitle(isEditing
            ? (selectedIDs.isEmpty ? "선택" : "\(selectedIDs.count)장 선택됨")
            : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 선택 / 완료 버튼
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "완료" : "선택") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                        if !isEditing { selectedIDs.removeAll() }
                    }
                }
            }
            // 전체 선택 (편집 모드일 때만)
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    let isAll = selectedIDs.count == displayItems.count
                    Button(isAll ? "전체 해제" : "전체 선택") {
                        selectedIDs = isAll ? [] : Set(displayItems.map(\.id))
                    }
                }
            }
        }
        // 하단 삭제 바 — DeleteActionBar로 추출해 공유
        .safeAreaInset(edge: .bottom) {
            if isEditing && !selectedIDs.isEmpty {
                DeleteActionBar(
                    selectedCount: selectedIDs.count,
                    countUnit: "장",
                    onDelete: { showConfirm = true }
                )
            }
        }
        .confirmationDialog(
            "\(selectedIDs.count)장의 사진을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task { await deleteSelected() }
            }
        }
        .alert("삭제하지 못했습니다", isPresented: $showDeleteError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("사진을 삭제하지 못했습니다. 다시 시도해 주세요.")
        }
    }

    // MARK: - 삭제

    private func deleteSelected() async {
        let toDelete = displayItems.filter { selectedIDs.contains($0.id) }
        let targetIDs = selectedIDs
        isEditing = false

        // 실제 삭제 (시스템이 확인 다이얼로그를 보여줌). 성공했을 때만 UI에서
        // 제거해 화면 상태와 보관함을 일치시킨다. 사용자가 취소하면 그대로 둔다.
        let success = await library.deleteAssets(toDelete)
        if success {
            // 삭제 성공 시 StatsStore에 기록
            statsStore.recordDeletion(items: toDelete)
            deletedIDs.formUnion(targetIDs)
        } else {
            showDeleteError = true
        }
        selectedIDs.removeAll()
    }
}

// MARK: - 선택 가능한 썸네일

private struct SelectableThumbnail: View {
    let item: PhotoItem
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        PhotoThumbnail(item: item)
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    selectionBadge
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay {
                if isEditing && isSelected {
                    Color.accentColor.opacity(0.25)
                }
            }
            .onTapGesture(perform: onTap)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white.opacity(0.85))
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(Color.gray.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
    }
}
