import SwiftUI
import UIKit

/// 통계 대시보드 탭 화면.
/// 보관함 현황 / 이번 정리 성과 / 지금 정리할 수 있는 것 세 섹션으로 구성된다.
struct StatsView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @EnvironmentObject var statsStore: StatsStore
    @StateObject private var vm = StatsViewModel()
    @State private var showLimitedBanner = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                switch library.authorizationStatus {
                case .denied, .restricted:
                    // 에러 + 권한 거부: 전체 화면을 PermissionDeniedView로 교체
                    PermissionDeniedView()

                case .authorized, .limited, .notDetermined:
                    if let errorMsg = vm.errorMessage {
                        // 데이터 오류 상태
                        errorStateView(message: errorMsg)
                    } else {
                        mainContent
                    }

                @unknown default:
                    mainContent
                }
            }
            .navigationTitle("통계")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            // 탭 전환 시 .task가 매번 재실행되므로 최초 1회만 로드한다.
            // 명시적 새로고침은 .refreshable이 담당한다.
            guard !hasLoaded else { return }
            hasLoaded = true
            await vm.load(library: library)
            showLimitedBanner = (library.authorizationStatus == .limited)
        }
    }

    // MARK: - 메인 콘텐츠

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── limited 권한 배너 (화면 최상단) ──
                if showLimitedBanner {
                    InfoBanner(
                        style: .warning,
                        message: "일부 사진만 접근 가능합니다 — 전체 통계가 정확하지 않을 수 있어요",
                        actionLabel: "더 보기",
                        onAction: openSettings,
                        isDismissible: true,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showLimitedBanner = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── 섹션 1: 보관함 현황 ──
                Text("보관함 현황")
                    .sectionHeaderStyle()

                // Dynamic Type 초대형 크기에서 3열이 좁아지면 ViewThatFits가 자동 전환
                ViewThatFits {
                    // 기본: 3개 가로 배치
                    HStack(spacing: 12) {
                        statCards
                    }
                    .padding(.horizontal, 12)

                    // 폴백: 세로 스택
                    VStack(spacing: 12) {
                        statCards
                    }
                    .padding(.horizontal, 12)
                }

                // 총 용량은 픽셀 기반 추정치임을 명시(실제 파일 크기 아님)
                Text("* 총 용량은 픽셀 기반 추정치입니다")
                    .font(.caption2)
                    .foregroundStyle(Color.text3)
                    .padding(.horizontal, 16)

                sectionDivider

                // ── 섹션 2: 이번 정리 성과 ──
                VStack(alignment: .leading, spacing: 4) {
                    Text("이번 정리 성과")
                        .sectionHeaderStyle()
                    Text("앱을 종료하면 초기화됩니다")
                        .font(.caption)
                        .foregroundStyle(Color.text3)
                        .padding(.horizontal, 16)
                }

                if statsStore.deletedCount == 0 && !vm.isLoading {
                    // 빈 성과 상태 — 아직 정리 기록 없음
                    emptyAchievementView
                } else {
                    // 숫자·단위를 statsStore에서 직접 읽어 항상 동기화된 값을 표시한다.
                    let saved = statsStore.savedDisplay
                    HStack(spacing: 12) {
                        AchieveBadge(
                            icon: "trash.fill",
                            iconColor: .danger,
                            label: "삭제한 사진",
                            value: "\(statsStore.deletedCount)",
                            unit: "장",
                            isLoading: vm.isLoading
                        )
                        AchieveBadge(
                            icon: "externaldrive",
                            iconColor: .success,
                            label: "절약한 용량 (추정)",
                            value: saved.value,
                            unit: saved.unit,
                            isLoading: vm.isLoading
                        )
                    }
                    .padding(.horizontal, 16)
                }

                sectionDivider

                // ── 섹션 3: 지금 정리할 수 있는 것 ──
                Text("지금 정리할 수 있는 것")
                    .sectionHeaderStyle()

                quickCleanSection
            }
            .padding(.bottom, 32)
        }
        .background(Color.appBg)
        .refreshable {
            await vm.load(library: library)
        }
        .accessibilityLabel(vm.isLoading ? "보관함 통계를 불러오고 있습니다" : "통계")
    }

    // MARK: - StatCard 3개

    @ViewBuilder
    private var statCards: some View {
        StatCard(
            icon: "photo.fill",
            iconColor: .brand,
            title: "사진",
            value: vm.photoCount,
            unit: "장",
            isLoading: vm.isLoading
        )
        StatCard(
            icon: "video.fill",
            iconColor: .statBlue,
            title: "동영상",
            value: vm.videoCount,
            unit: "개",
            isLoading: vm.isLoading
        )
        StatCard(
            icon: "internaldrive.fill",
            iconColor: .success,
            title: "총 용량",
            value: vm.totalGB,
            unit: "GB",
            isLoading: vm.isLoading
        )
    }

    // MARK: - 섹션 구분선

    private var sectionDivider: some View {
        Divider()
            .opacity(0.3)
            .padding(.horizontal, 16)
    }

    // MARK: - 빈 성과 상태

    private var emptyAchievementView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.success)
                .accessibilityHidden(true)
            Text("아직 정리 기록이 없습니다")
                .font(.headline)
                .foregroundStyle(Color.text1)
            Text("사진을 정리하면 여기서 성과를 볼 수 있어요")
                .font(.subheadline)
                .foregroundStyle(Color.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 빠른 접근 섹션

    private var quickCleanSection: some View {
        VStack(spacing: 0) {
            if vm.isLoading {
                // 스켈레톤 로우 2개
                skeletonQuickRow
                Divider().padding(.leading, 68)
                skeletonQuickRow
            } else {
                NavigationLink(destination: CategoryCleanupView(category: .screenshots)) {
                    QuickCleanRow(
                        icon: "camera.viewfinder",
                        iconColor: .brand,
                        title: "스크린샷",
                        count: vm.screenshotCount,
                        unit: "장",
                        isLoading: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(vm.screenshotCount == 0)

                Divider().padding(.leading, 68)

                NavigationLink(destination: CategoryCleanupView(category: .largeVideos)) {
                    QuickCleanRow(
                        icon: "film.stack",
                        iconColor: .statBlue,
                        title: "대용량 동영상",
                        count: vm.largeVideoCount,
                        unit: "개",
                        isLoading: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(vm.largeVideoCount == 0)
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
    }

    private var skeletonQuickRow: some View {
        HStack(spacing: 12) {
            SkeletonRect(width: 40, height: 40, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(width: 80, height: 14, cornerRadius: 4)
                SkeletonRect(width: 48, height: 12, cornerRadius: 4)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .accessibilityHidden(true)
    }

    // MARK: - 오류 상태

    private func errorStateView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.danger)
                .accessibilityHidden(true)
            Text("통계를 불러오지 못했습니다")
                .font(.title2.bold())
                .foregroundStyle(Color.text1)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.text2)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await vm.load(library: library) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 설정 이동

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
