---
name: ios-qa-review
description: >
  iOS / SwiftUI 앱 코드를 정적 검증하는 전문 QA 스킬. PhotoKit, Vision,
  CoreLocation, Swift Concurrency(@MainActor/async-await), SwiftUI 상태관리,
  메모리/성능, 권한·개인정보, Xcode 프로젝트 설정을 체계적으로 점검한다.
  Swift/SwiftUI 코드를 리뷰하거나, 컴파일 없이 버그·크래시·성능 문제를 찾거나,
  PhotoKit/Vision 기반 사진 앱을 검증할 때 사용한다.
---

# iOS / SwiftUI QA 리뷰 스킬

macOS·Xcode 없이 (예: Linux CI) Swift 소스를 **정적 분석**으로 검증하기 위한
체크리스트와 판단 기준이다. 컴파일러를 대신할 수는 없으므로, 컴파일러가 잡는
오류보다 **런타임 크래시·UI 멈춤·논리 버그·리소스 누수**처럼 정적으로 추론
가능한 고위험 항목에 집중한다.

## 작업 절차

1. **인벤토리** — `*.swift`, `*.pbxproj`, `*.storyboard`, `Assets.xcassets`,
   `Info.plist` 키를 모두 나열한다.
2. **계층별 점검** — 아래 체크리스트를 영역별로 적용한다.
3. **심각도 분류** — 🔴 Critical(크래시/데이터 손실) / 🟠 Major(기능 오작동·
   UI 멈춤) / 🟡 Minor(품질·일관성) / 🔵 Info(개선 제안).
4. **보고** — 파일:라인, 근거, 재현 조건, 수정 방향을 표로 제시한다.
5. **검증 한계 명시** — 정적 분석으로 확인 못 한 항목(실제 빌드/런타임)을
   반드시 따로 적는다.

## 핵심 체크리스트

### 1. Swift Concurrency (가장 흔한 버그원)
- `withCheckedContinuation`을 **정확히 한 번만** resume 하는가?
  (PhotoKit `.opportunistic`은 콜백 다회 호출 → 가드 필수)
- `@MainActor` 클래스/함수에서 **CPU 무거운 작업**(이미지 해싱, Vision 추론,
  픽셀 처리)을 돌리지 않는가? → UI 프리즈. `nonisolated`/`Task.detached`로 오프로드.
- `async let`/`TaskGroup` 누락으로 직렬 처리되어 느려지지 않는가?
- 클로저 캡처에서 `self` 강참조로 인한 retain cycle 여부.
- `Task {}` 안에서 `@MainActor` 상태를 안전하게 갱신하는가?

### 2. PhotoKit
- `PHPhotoLibrary.requestAuthorization(for:)`의 **readWrite vs read** 레벨이
  실제 동작(삭제/저장)과 일치하는가? 삭제하려면 readWrite + `NSPhotoLibraryUsageDescription`.
- `.limited` 권한 상태를 `.authorized`와 함께 처리하는가?
- `PHAsset.fetchAssets`에 `PHFetchOptions.sortDescriptors`가 있는가?
- `PHImageManager.requestImage`의 `deliveryMode`/`isNetworkAccessAllowed`가
  의도와 맞는가? (iCloud 사진은 네트워크 필요)
- `deleteAssets`는 `PHAssetChangeRequest.deleteAssets` + `performChanges`로
  시스템 확인 다이얼로그를 띄우는가? (임의 삭제 금지)
- `PHCachingImageManager` 사용 시 캐시 시작/중지 균형.

### 3. Vision / CoreImage
- `VNImageRequestHandler.perform`은 **백그라운드**에서 호출하는가? (동기·CPU 집약)
- 결과 캐스팅(`as? [VNFaceObservation]`) 실패·에러를 안전하게 처리하는가?
- 대량 루프에서 썸네일 크기를 충분히 줄여 메모리 폭증을 막는가?

### 4. CoreLocation
- `CLGeocoder`의 분당 호출 제한(~50회)을 고려해 throttle 하는가?
- 역지오코딩 실패/네트워크 없음 시 fallback 문자열이 있는가?
- 좌표 클러스터링 키 생성 시 부동소수 반올림이 안정적인가?

### 5. SwiftUI 상태 관리
- `@StateObject`(소유) vs `@ObservedObject`(주입) vs `@EnvironmentObject`를
  올바르게 구분하는가? (소유 객체를 `@ObservedObject`로 두면 재생성 버그)
- `environmentObject` 주입 누락으로 런타임 크래시("No ObservableObject of type
  … found") 위험은 없는가? 모든 하위 뷰가 필요한 EnvironmentObject를 받는가?
- `.task`/`.onAppear`에서 중복 실행 가드(`hasRun`)가 있는가?
- 리스트 `ForEach`의 `id`가 안정적이고 고유한가?
- `@ViewBuilder` switch에서 모든 케이스를 다루는가?

### 6. 메모리 / 성능
- 썸네일 `targetSize`가 표시 크기에 맞게 작은가? (원본 로딩 금지)
- 큰 배열을 매 `body` 평가마다 재계산하지 않는가? (무거운 computed property 주의)
- 이미지 컨텍스트(`CGContext`, `UIGraphicsImageContext`) 해제 균형.

### 7. 권한 / 개인정보 / 설정
- 사용하는 모든 민감 API에 대응하는 `INFOPLIST_KEY_*UsageDescription`이 있는가?
  (사진, 위치, 카메라 등)
- `GENERATE_INFOPLIST_FILE = YES`일 때 키가 build settings에 있는가?
- 배포 타깃(`IPHONEOS_DEPLOYMENT_TARGET`)이 사용 API의 가용 버전과 맞는가?
  (예: `ContentUnavailableView` iOS 17+, `reverseGeocodeLocation` async iOS 15+)
- 앱 아이콘 에셋(`AppIcon`)과 런치스크린 참조가 실제 파일과 일치하는가?
- `UIImage(named: "AppIcon")`는 **앱 아이콘 에셋을 로드하지 못한다** —
  스플래시 로고는 별도 이미지셋이 필요하다(흔한 함정).

### 8. Xcode 프로젝트 무결성
- `project.pbxproj`의 모든 객체 ID가 24자 hex로 유일한가?
- 파일시스템 동기화 그룹(`PBXFileSystemSynchronizedRootGroup`, objectVersion 77,
  Xcode 16+) 사용 시 소스가 자동 포함되는가?
- `INFOPLIST_KEY_UILaunchStoryboardName` ↔ 실제 storyboard 파일명 일치.
- 중복 Info.plist 충돌(`GENERATE_INFOPLIST_FILE` + 수동 plist) 없는가?

## 보고 형식

```
## QA 검증 결과 — <대상>

### 요약
- 검토 파일: N개 / 발견: 🔴 a  🟠 b  🟡 c  🔵 d

### 발견 항목
| # | 심각도 | 위치 | 문제 | 수정 방향 |
|---|--------|------|------|-----------|

### 정적 분석으로 확인 못 한 것 (빌드/런타임 필요)
- ...
```

## 원칙
- 추측이 아니라 **코드 근거**로 말한다(파일:라인 인용).
- 거짓 양성을 줄인다 — 확신이 낮으면 심각도를 낮추고 그 이유를 적는다.
- 컴파일 검증 불가를 숨기지 않는다 — 한계를 정직하게 보고한다.
