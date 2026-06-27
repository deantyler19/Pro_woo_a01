import SwiftUI

/// 검색어 입력을 일정 시간 지연시켜 과도한 필터 재계산을 막는 헬퍼.
///
/// `query`를 검색창에 바인딩하고, 필터링에는 `debounced`를 사용한다.
/// 타이핑이 멈추고 `delay`가 지난 뒤에만 `debounced`가 갱신되며,
/// 검색어를 비우면 즉시 반영해 결과가 빨리 돌아오게 한다.
@MainActor
final class DebouncedSearch: ObservableObject {
    /// 검색창에 바인딩하는 즉시 입력값.
    @Published var query: String = ""
    /// 디바운스가 적용된 값. 필터링에 사용한다.
    @Published private(set) var debounced: String = ""

    private var task: Task<Void, Never>?
    private let delay: Duration

    init(delay: Duration = .milliseconds(250)) {
        self.delay = delay
    }

    /// 새 입력값을 받아 디바운스 타이머를 갱신한다.
    func update(_ value: String) {
        task?.cancel()
        // 비우는 경우는 즉시 반영
        if value.isEmpty {
            debounced = ""
            return
        }
        task = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.debounced = value
        }
    }
}

extension View {
    /// 검색창 `query` 변경을 감지해 디바운서에 전달한다.
    func debouncingSearch(_ debouncer: DebouncedSearch) -> some View {
        onChange(of: debouncer.query) { _, newValue in
            debouncer.update(newValue)
        }
    }
}
