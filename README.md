# 사진정리 (PhotoOrganizer)

아이폰 사진 보관함을 **날짜 · 장소 · 중복** 기준으로 정리해 주는 iOS 앱입니다.
SwiftUI와 Apple PhotoKit으로 만든 네이티브 앱이라 사진의 메타데이터(촬영 날짜, GPS 위치)에 직접 접근합니다.

## 주요 기능

| 탭 | 기능 |
|----|------|
| 📅 **날짜별** | 사진을 연·월 단위로 자동 그룹화하여 목록으로 보여줍니다. |
| 📍 **장소별** | 사진의 GPS 좌표를 군집화하고 지명(역지오코딩)으로 변환해 장소별로 묶습니다. 위치 정보가 없는 사진은 따로 모아 줍니다. |
| 🔁 **중복사진** | 지각적 해시(average hash)로 비슷하거나 똑같은 사진을 찾아 묶고, 묶음별로 원본 1장만 남기고 정리할 수 있습니다. |

## 동작 방식

- **날짜 정리** — `PHAsset.creationDate`를 `Calendar`로 연·월 그룹화.
- **장소 정리** — `PHAsset.location`(GPS)을 0.1° 격자(약 11km)로 묶고, 대표 좌표를 `CLGeocoder`로 지명 변환. 지오코더 호출 제한을 피하려 군집마다 약간의 간격을 둡니다.
- **중복 정리** — 각 사진을 8×8 흑백으로 축소해 평균 밝기 기준 64비트 해시를 만들고, 두 해시의 해밍 거리가 임계값(기본 6) 이하이면 유사 사진으로 묶습니다. 화질·크기가 조금 달라도 같은 장면이면 잡아냅니다.
- **삭제** — `PHAssetChangeRequest.deleteAssets`를 사용하므로, 실제 삭제 전에 iOS가 사용자에게 시스템 확인 알림을 띄웁니다. (사용자 동의 없이는 삭제되지 않습니다.)

## 프로젝트 구조

```
PhotoOrganizer/
├── PhotoOrganizerApp.swift        # 앱 진입점
├── ContentView.swift              # 권한 상태에 따른 루트 분기
├── Models/
│   └── PhotoItem.swift            # PHAsset 래퍼 모델
├── Services/
│   ├── PhotoLibraryService.swift  # 권한·로딩·썸네일·삭제
│   ├── LocationService.swift      # 좌표 클러스터링 + 역지오코딩
│   └── DuplicateDetector.swift    # 지각적 해시 기반 중복 검출
└── Views/
    ├── MainTabView.swift          # 3개 탭
    ├── DateGroupView.swift        # 날짜별
    ├── LocationGroupView.swift    # 장소별
    ├── DuplicatesView.swift       # 중복사진
    ├── PermissionViews.swift      # 권한 요청/거부 화면
    └── Components/
        ├── PhotoThumbnail.swift   # 썸네일 로더
        └── PhotoGridScreen.swift  # 사진 격자 화면
```

## 빌드 및 실행 방법

> ⚠️ iOS 앱은 빌드·실행에 **macOS + Xcode**가 필요합니다. (현재 개발 환경은 Linux라 이 저장소에서는 빌드만 빠져 있고 소스는 모두 포함되어 있습니다.)

1. macOS에서 **Xcode 16 이상**을 설치합니다. (이 프로젝트는 파일 시스템 동기화 그룹을 사용하므로 Xcode 16+ 필요)
2. `PhotoOrganizer.xcodeproj`를 Xcode로 엽니다.
3. 상단에서 **Signing & Capabilities** → 본인의 Apple 개발자 팀을 선택합니다.
4. 실행 대상으로 iPhone 시뮬레이터 또는 실제 기기를 선택합니다.
   - 시뮬레이터에는 기본 샘플 사진이 들어 있어 날짜/중복 기능을 바로 확인할 수 있습니다. (위치 메타데이터가 있는 사진은 실제 기기에서 더 풍부합니다.)
5. **⌘R**로 실행합니다.

## 요구 사항

- iOS 17.0 이상
- Xcode 16 이상
- 사진 보관함 접근 권한 (앱 첫 실행 시 요청)

## 앞으로 추가하면 좋은 기능

- 앨범으로 자동 분류해 저장하기
- 중복 묶음에서 "어떤 사진을 남길지" 직접 선택
- 즐겨찾기/스크린샷/대용량 영상 등 카테고리별 정리
- iCloud 사진 다운로드 진행 상태 표시
