import SwiftUI

/// 동영상 목록의 단일 행 컴포넌트.
/// 썸네일 56×56 + 재생아이콘 오버레이 + 날짜·크기·재생시간 메타 + 선택 배지.
struct VideoRow: View {
    let item: VideoItem
    /// nil이면 "-- MB" 플레이스홀더 표시 (파일 크기 로딩 중)
    var formattedSize: String?
    var formattedDuration: String = ""
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                thumbnailView

                // 텍스트 메타
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.text1)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(item.formattedDate)
                            .font(.caption)
                            .foregroundStyle(Color.text3)

                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Color.text3)

                        // 파일 크기 — 로딩 중이면 placeholder
                        if let size = formattedSize {
                            Text(size)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.text2)
                                // 로드 완료 시 easeIn 전환
                                .transition(.opacity)
                        } else {
                            Text("-- MB")
                                .font(.caption)
                                .foregroundStyle(Color.text3)
                        }

                        if !formattedDuration.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Color.text3)
                            Text(formattedDuration)
                                .font(.caption)
                                .foregroundStyle(Color.text3)
                        }
                    }
                    .animation(.easeIn(duration: 0.2), value: formattedSize != nil)
                }

                Spacer()

                // 선택 배지 또는 chevron
                if isEditing {
                    selectionBadge
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text3)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 72)
            .background(
                isSelected
                    ? Color.brandLight
                    : Color(.systemBackground)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(isEditing ? "탭하여 선택" : "탭하여 미리보기")
    }

    // MARK: - 썸네일

    private var thumbnailView: some View {
        ZStack {
            VideoThumbnail(item: item, targetSize: CGSize(width: 112, height: 112))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 재생 아이콘 오버레이 (장식 — VoiceOver 숨김)
            Circle()
                .fill(.black.opacity(0.45))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)   // 시각적 중앙 보정
                )
                .accessibilityHidden(true)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: - 선택 배지

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.brand : Color.white.opacity(0.85))
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(Color(.systemGray4), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        // 선택 상태는 상위 accessibilityLabel로 전달
        .accessibilityHidden(true)
    }

    // MARK: - 접근성 설명

    private var accessibilityDescription: String {
        let sizeText = formattedSize ?? "크기 로딩 중"
        let selected = isSelected ? ", 선택됨" : ""
        return "\(item.displayTitle), \(sizeText), \(formattedDuration)\(selected)"
    }
}

// MARK: - VideoItem 뷰 헬퍼 extension

extension VideoItem {
    /// 날짜 기반 표시 제목
    var displayTitle: String {
        "동영상 \(formattedDate)"
    }

    /// 한국어 날짜 포맷 (2026. 6. 27.)
    var formattedDate: String {
        guard let date = creationDate else { return "날짜 없음" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}
