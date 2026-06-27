---
name: mobile-frontend
description: >
  모바일 프론트엔드 개발 전문 스킬. iOS 네이티브(Swift/SwiftUI), Android
  네이티브(Kotlin/Compose), 크로스플랫폼(Flutter, React Native)으로 사용자가
  보고 터치하는 화면·기능을 OS에 최적화해 구현한다. 상태관리, 비동기 동시성,
  네비게이션, 성능·메모리, 접근성, 디자인 토큰 적용을 다룬다. UI 화면 구현,
  컴포넌트 개발, 프론트엔드 기능 추가·리팩터링 시 사용한다.
---

# 모바일 프론트엔드 개발 스킬

사용자가 직접 만지는 화면과 기능을, 각 OS 관습과 성능 특성에 맞게 구현한다.
이 저장소의 1차 타깃은 **iOS(SwiftUI)** 이며, 크로스플랫폼 선택지도 안내한다.

## 기술 선택 가이드
| 상황 | 추천 |
|------|------|
| OS 깊은 기능(PhotoKit/Vision/위젯) 활용, 최고 성능 | **iOS 네이티브 SwiftUI** |
| Android도 동시 출시, 단일 코드 선호 | Flutter(고성능 UI) / React Native(웹 친화) |
| 팀이 웹/JS 경험 풍부 | React Native |
이 사진 앱은 PhotoKit·Vision 의존도가 높아 **네이티브 SwiftUI가 정답**.

## SwiftUI 아키텍처 규칙
- **상태 소유권**: `@StateObject`(생성·소유) vs `@ObservedObject`(주입) vs
  `@EnvironmentObject`(트리 공유). 소유 객체를 ObservedObject로 두지 말 것(재생성 버그).
- **단방향 흐름**: View → (intent) → Service(@MainActor ObservableObject) → @Published → View.
- **뷰는 얇게**: 무거운 computed property를 `body`에서 매번 재계산하지 않기.
- **재사용 컴포넌트화**: 썸네일·그리드·행을 분리해 중복 제거.

## 동시성(Concurrency) 안전 규칙 — 가장 흔한 버그원
- 무거운 CPU 작업(이미지 해싱, Vision 추론, 픽셀 처리)은 **절대 @MainActor에서
  직접 실행 금지**. `nonisolated` + `Task.detached(priority:.userInitiated)`로 오프로드.
- `withCheckedContinuation`은 **정확히 한 번** resume — 다중 콜백(PHImageManager
  `.opportunistic`)에 `resumed` 가드 필수, 에러/미수신 시 fallback resume.
- `@Published` 갱신은 메인에서 — `@MainActor` 클래스로 보장.
- 클로저 캡처 retain cycle 주의(`[weak self]` 또는 값 캡처).

## 성능 / 메모리
- 썸네일은 표시 크기에 맞는 `targetSize`로 요청(원본 로딩 금지).
- `LazyVGrid`/`List`로 지연 로딩, `PHCachingImageManager` 캐시 활용.
- 대량 루프 전 작은 썸네일(64~180px)로 다운샘플 후 처리.
- `CGContext`/그래픽 컨텍스트 생성·해제 균형.

## 접근성 / 다국어
- `.font(.headline)` 등 시맨틱 폰트로 Dynamic Type 지원.
- VoiceOver 레이블, 터치 타깃 44pt, 다크모드 시맨틱 컬러.
- 사용자 노출 문자열은 하드코딩이라도 한 곳에 모으고, 추후 `Localizable`로 이전.

## 권한 / 시스템 연동(iOS)
- 사용 API마다 `INFOPLIST_KEY_*UsageDescription` 필수(사진/위치/카메라).
- `.authorized`와 `.limited`를 함께 처리. 거부 시 설정 이동 안내.
- 삭제·저장은 `PHPhotoLibrary.performChanges` + `PHAssetChangeRequest`로 시스템 확인 경유.
- 앱 아이콘 에셋은 `UIImage(named:)`로 못 불러옴 → 로고는 별도 이미지셋.

## 구현 체크리스트(작업 완료 정의)
- [ ] 정상/로딩/빈/에러(+권한거부) 4상태 모두 구현.
- [ ] 무거운 작업 백그라운드 오프로드 확인.
- [ ] continuation 단일 resume 보장.
- [ ] 디자인 토큰 사용(하드코딩 색·치수 최소화).
- [ ] 접근성(Dynamic Type·VoiceOver·대비) 통과.
- [ ] 파괴적 액션에 확인·실패 피드백.
- [ ] `ios-qa-review` 스킬 체크리스트로 자가 점검.

## 크로스플랫폼 메모
- Flutter: `flutter create`, 위젯 트리·`setState`/Riverpod/Bloc, 플랫폼 채널로 네이티브 연동.
- React Native: `@react-native-community` 모듈, MediaLibrary 등은 Expo 모듈 활용.
- 두 경우 모두 PhotoKit 수준의 메타데이터·중복검출은 네이티브 플러그인 필요.

## 원칙
- OS 관습을 존중하고 시스템 컴포넌트를 우선 사용한다.
- 주변 코드 스타일(네이밍·주석 밀도·구조)에 맞춰 작성한다.
- 구현 후 반드시 자가 QA(동시성·상태·접근성)를 돌린다.
