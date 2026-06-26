import SwiftUI

/// 사진 묶음을 격자로 보여주는 재사용 화면.
/// 우상단 "선택" 버튼으로 다중 선택 모드를 활성화해 일괄 삭제할 수 있다.
struct PhotoGridScreen: View {
    let title: String
    let items: [PhotoItem]

    @EnvironmentObject var library: PhotoLibraryService
    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var deletedIDs:  Set<String> = []
    @State private var showConfirm  = false

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
        // 하단 삭제 바
        .safeAreaInset(edge: .bottom) {
            if isEditing && !selectedIDs.isEmpty {
                deleteBar
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
    }

    // MARK: - 하단 삭제 바

    private var deleteBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedIDs.count)장 선택됨")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("삭제하면 복구가 어렵습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                showConfirm = true
            } label: {
                Label("삭제", systemImage: "trash.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Rectangle())
        .shadow(color: .black.opacity(0.06), radius: 12, y: -4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 삭제

    private func deleteSelected() async {
        let toDelete = displayItems.filter { selectedIDs.contains($0.id) }
        // 즉시 UI에서 제거
        deletedIDs.formUnion(selectedIDs)
        selectedIDs.removeAll()
        isEditing = false
        // 실제 삭제 (시스템이 확인 다이얼로그를 보여줌)
        await library.deleteAssets(toDelete)
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
