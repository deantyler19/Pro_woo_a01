import SwiftUI
import UIKit

/// 아직 권한을 묻지 않은 상태에서 보여주는 안내 화면.
struct RequestAccessView: View {
    /// 권한 요청 동작.
    let onRequest: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("사진정리")
                .font(.largeTitle.bold())

            Text("날짜·장소별 정리와 중복 사진 찾기를 위해\n사진 보관함 접근 권한이 필요합니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                Task { await onRequest() }
            } label: {
                Text("사진 접근 허용")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// 권한이 거부된 상태에서 보여주는 안내 화면.
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("사진 접근이 꺼져 있습니다")
                .font(.title2.bold())

            Text("설정 앱에서 사진 접근을 허용하면\n정리 기능을 사용할 수 있습니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
