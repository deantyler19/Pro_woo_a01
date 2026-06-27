# 디자인 명세: StatsView & CategoryCleanupView

작성일: 2026-06-27  
기준 스킬: `.claude/skills/uiux-design/SKILL.md`  
기존 토큰 기반(`#6366F1` 인디고 팔레트), Apple HIG / SwiftUI 핸드오프 포함

---

## 0. 디자인 원칙 (이 두 화면 한정)

| 원칙 | 적용 |
|------|------|
| **신뢰감** | 통계는 숫자가 크고 명확하게, 로딩 중 Skeleton으로 레이아웃 안정감 유지 |
| **빠른 판단** | 카드 3개 → 성과 2개 → 빠른 접근 2행으로 정보 밀도를 단계적으로 높임 |
| **안전한 파괴** | 삭제는 이 화면에서 발생하지 않지만, limited 배너로 신뢰 상태를 먼저 표시 |

---

## 1. 디자인 토큰 (추가분)

기존 토큰(SKILL.md)을 그대로 상속하되 아래를 추가한다.

```
컬러 추가
  warning        #F59E0B  (amber-500)  — limited 권한 배너 배경
  warningLight   #FFFBEB              — limited 배너 배경(라이트 모드)
  statBlue       #3B82F6  (blue-500)  — 동영상 카드 아이콘 (사진=primary, 동영상=blue, 용량=emerald)
  achieveGold    #F59E0B  (amber-500) — 성과 뱃지 강조 (삭제 N장)
  achieveGreen   #10B981 (emerald-500)— 성과 뱃지 강조 (절약 X MB) → 기존 success 토큰 재사용

스켈레톤
  shimmerBase    #E4E4F2  (= 기존 border 토큰)
  shimmerHighlight #F4F4FA

타이포 추가
  statNumber     34 bold (largeTitle) — StatCard 숫자
  statUnit       13 regular (subhead) — StatCard 단위 레이블
  badgeValue     22 bold (title)      — 성과 뱃지 숫자

스페이싱 추가
  sectionGap     24                   — 섹션 간 수직 여백
  cardInner      16                   — 카드 내부 패딩 (= 기존 스페이싱 토큰 재사용)

아이콘 크기
  tabIcon        28pt                 — 탭바 SF Symbol 사이즈 (시스템 기본 따름)
```

---

## 2. StatsView — 통계 대시보드

### 2-1. 탭 아이콘 결정

**chart.bar.fill** 사용.

근거: SF Symbols 내 차트·통계를 가장 보편적으로 표현하는 심볼로, iOS 시스템 앱(건강, 스크린타임)이 동일 아이콘을 채택해 "분석·요약" 인지가 즉각적이다. `waveform` 또는 `sum` 대안 검토했으나 "사진 정리 결과 요약"의 맥락에서 bar chart가 가장 직관적이다.

탭 레이블: **"통계"** (4자 이내, 기존 탭과 일관)

```
탭바 구성 (5탭 최대치 — HIG 허용):
  1. 날짜별    calendar
  2. 장소별    map
  3. 얼굴별    person.2
  4. 중복사진  square.on.square
  5. 통계      chart.bar.fill   ← 신규
```

### 2-2. 레이아웃 구조 (정상 상태)

```
NavigationStack
  ScrollView(.vertical)
    ┌─ 섹션 헤더: "보관함 현황"  (headline, text1)
    │
    ├─ HStack(spacing: 12)  ← 카드 3개 가로 배치
    │    StatCard(icon: "photo.fill",       color: primary,  title: "사진",  value: "2,341", unit: "장")
    │    StatCard(icon: "video.fill",        color: statBlue, title: "동영상", value: "187",   unit: "개")
    │    StatCard(icon: "internaldrive.fill", color: success,  title: "총 용량", value: "12.4", unit: "GB")
    │
    ├─ Divider (opacity 0.3)  ← 섹션 구분
    │
    ├─ 섹션 헤더: "이번 정리 성과"  (headline, text1)
    │    부제: "앱을 종료하면 초기화됩니다"  (caption, text3)
    │
    ├─ HStack(spacing: 12)  ← 성과 뱃지 2개
    │    AchieveBadge(icon: "trash.fill",   color: danger,   label: "삭제한 사진", value: "34",   unit: "장")
    │    AchieveBadge(icon: "externaldrive",color: success,  label: "절약한 용량", value: "412",  unit: "MB")
    │
    ├─ Divider (opacity 0.3)
    │
    ├─ 섹션 헤더: "지금 정리할 수 있는 것"  (headline, text1)
    │
    ├─ VStack(spacing: 0)  ← 카테고리 진입 행
    │    QuickCleanRow(icon: "camera.viewfinder", color: primary,  title: "스크린샷",   count: 89,  unit: "장")
    │    Divider.inset(leading: 56)
    │    QuickCleanRow(icon: "film.stack",        color: statBlue, title: "대용량 동영상", count: 12, unit: "개")
    │
    └─ (bottom padding 32)
```

### 2-3. 4상태 정의

#### 정상 (Normal)
위 레이아웃 그대로. 숫자는 애니메이션 없이 즉시 표시 (숫자 카운트업은 이 앱 맥락에 불필요한 인지 부하).

#### 로딩 (Loading)
- StatCard 3개 자리에 `SkeletonCard` (동일 크기, shimmerBase → shimmerHighlight 가로 스윕 애니메이션, 1.2s 반복)
- AchieveBadge 2개 자리: 높이 80 SkeletonRect
- QuickCleanRow 2개: 높이 56 SkeletonRow
- 섹션 헤더 텍스트는 실제 텍스트 표시 (레이아웃 고정 역할)
- VoiceOver: "보관함 통계를 불러오고 있습니다" 단일 레이블

#### 빈 상태 (Empty)
- 사진이 0장인 경우 (edge case)
- 보관함 현황 카드: value = "0" 표시 (빈 상태라도 카드 구조 유지 — 사용자가 언제든 사진 추가 후 의미 있는 값 확인 가능)
- 성과 섹션: `EmptyStateView` 교체 — icon: `checkmark.circle.fill`(success), title: "아직 정리 기록이 없습니다", body: "사진을 정리하면 여기서 성과를 볼 수 있어요"
- QuickCleanRow: count=0 행은 표시하되 gray tint, 탭 시 "정리할 항목이 없습니다" 토스트

#### 에러 + 권한 거부 (Error / Permission)

**limited 권한**: 화면 최상단에 `InfoBanner(style: .warning)` 표시 (섹션들 위)
```
InfoBanner
  icon: lock.trianglebadge.exclamationmark.fill (warning 컬러)
  text: "일부 사진만 접근 가능합니다 — 전체 통계가 정확하지 않을 수 있어요"
  action: "더 보기" → 설정 이동
```

**denied/restricted**: 전체 화면을 `PermissionDeniedView` (기존 컴포넌트 재사용)로 교체.

**네트워크·데이터 오류**: 카드 영역에 `ErrorStateCard`
```
icon: exclamationmark.triangle.fill (danger)
title: "통계를 불러오지 못했습니다"
button: "다시 시도"  (primary 버튼)
```

---

## 3. CategoryCleanupView — 카테고리 정리

### 3-1. 진입 경로

```
StatsView → QuickCleanRow 탭
  → CategoryCleanupView(category: .screenshots | .largeVideos)
```

`category` enum으로 화면을 하나로 통합, 내부에서 분기한다. NavigationStack push 전환(오른쪽에서 슬라이드인) — 뒤로가기는 시스템 back gesture.

### 3-2. 레이아웃 구조

**스크린샷 모드** (PhotoGridScreen 재사용)
```
NavigationStack
  PhotoGridScreen(
    title: "스크린샷 \(count)장",
    items: screenshotItems
  )
  .safeAreaInset(edge: .top) {
    if isLimited { InfoBanner(style: .warning) }
  }
```
PhotoGridScreen은 기존 컴포넌트를 그대로 사용한다. 재사용 근거: 격자 선택·삭제 흐름이 동일하므로 코드 중복 없이 일관된 UX 제공.

**대용량 동영상 모드** (신규 List 레이아웃)
```
NavigationStack
  List {
    ForEach(videoItems) { item in
      VideoRow(item: item)
    }
  }
  .listStyle(.plain)
  .safeAreaInset(edge: .top) {
    if isLimited { InfoBanner(style: .warning) }
  }
  .toolbar { 선택/완료 버튼 (PhotoGridScreen과 동일 패턴) }
  .safeAreaInset(edge: .bottom) {
    if isEditing && !selectedIDs.isEmpty { deleteBar }
  }
```

List를 선택한 이유: 동영상은 파일명·날짜·크기·재생시간 4가지 메타데이터를 한눈에 보여야 해서 격자보다 행 레이아웃이 정보 밀도와 터치 정확도 모두 유리하다.

### 3-3. VideoRow 컴포넌트 명세

```
구성:
  [ 썸네일 56×56, r8 ]  [ 재생아이콘 오버레이 24pt ]
  [ 제목(subhead, 1줄, lineLimit 1) ]
  [ 날짜(caption, text3) + 구분점 + 크기MB(caption, text2.bold) + 재생시간(caption, text3) ]
  [ chevron.right(text3) ]

치수:
  행 높이: 72pt 최소 (Dynamic Type 시 자동 확장)
  썸네일: width 56, height 56, cornerRadius 8, contentMode .fill
  좌우 패딩: 16  요소 간격: 12
  재생아이콘: "play.fill" SF Symbol, white, 14pt, 썸네일 중앙 오버레이
             배경: 검정 0.45 opacity circle 28pt
  선택 배지: SelectableThumbnail과 동일 패턴 (우상단 22pt 원)

상태:
  default   → 배경 systemBackground
  pressed   → scale(0.98), 0.1s ease
  selected  → primaryLight(#EEEEFE) 배경 tint
  loading   → 썸네일 자리 SkeletonRect(56×56, r8), 텍스트 자리 SkeletonLine 2개
  error     → 썸네일 자리 회색 배경 + "video.slash" 아이콘

파일 크기 로딩 placeholder:
  크기가 아직 계산 중이면 "-- MB" 표시 (text3), 완료 시 "412 MB" (text2.bold)로 전환
  전환 애니메이션: .animation(.easeIn(duration: 0.2), value: sizeLoaded)

접근성:
  전체 행 하나의 Button
  accessibilityLabel: "\(title), \(formattedSize), \(formattedDuration)"
  accessibilityHint: isEditing ? "탭하여 선택" : "탭하여 미리보기"
  썸네일 재생 오버레이: .accessibilityHidden(true)
```

### 3-4. 4상태 정의

#### 정상 (Normal)
VideoRow 목록 또는 PhotoGridScreen 격자 표시.

#### 로딩 (Loading — 파일 스캔 중)
- List 상단 `ProgressView` + "대용량 동영상을 찾고 있습니다…" (body, text2)
- 이미 찾은 항목은 바로 아래 VideoRow로 점진 표시 (LazyVStack)
- 스캔 완료 시 자연스럽게 완전한 목록으로 전환

#### 빈 상태 (Empty)
```
VStack(spacing: 16)
  Image(systemName: "checkmark.circle.fill")  ← success 색
    .font(.system(size: 56))
  Text("정리할 항목이 없습니다")   (title2, text1)
  Text("스크린샷 또는 대용량 동영상이\n발견되지 않았습니다.")  (body, text2, multiline center)
```
근거: 빈 상태는 문제가 아닌 성공 상태이므로 긍정 아이콘(체크) 사용.

#### 에러 + 권한 거부 (Error / Permission)
- limited: 상단 `InfoBanner(style: .warning)` + 목록 표시 (접근 가능한 항목만)
- denied: `PermissionDeniedView` 전체 화면 교체
- 스캔 실패: 인라인 에러 뷰 + "다시 시도" 버튼

---

## 4. 컴포넌트 명세 전체 (상태·규격)

### 4-1. StatCard

```
목적: 보관함 현황의 단일 수치를 강조 표시
구성:
  [ 아이콘 SF Symbol 22pt, 카드 컬러 ]
  [ value 숫자 (34 bold, text1) ]
  [ unit  레이블 (13 regular, text3) ]
  [ title 제목 (13 semibold, text2) ]

치수:
  너비: (화면너비 - 48) / 3  ← HStack spacing 12, 좌우 패딩 12
  높이: 100 최소 (Dynamic Type 시 자동 확장)
  내부 패딩: 12 전방향
  cornerRadius: 14 (카드 토큰)
  background: systemBackground
  shadow: y8 blur16 black 8% (card 토큰)
  아이콘 컨테이너: 36×36 원, 카드 컬러 10% 불투명 배경

상태:
  default   → 위 스펙 그대로
  skeleton  → shimmerBase 배경 + 가로 스윕 shimmer (1.2s 반복)
  no-data   → value = "–"  (text3 색)

VoiceOver:
  accessibilityLabel: "\(title) \(value)\(unit)"
  accessibilityElement: true (카드 전체가 단일 요소)
  아이콘: .accessibilityHidden(true)

다크 모드:
  background → Color(.systemBackground) (시맨틱)
  아이콘 컨테이너 배경 → 컬러.opacity(0.15) (다크에서 자동 조정)
```

### 4-2. AchieveBadge (성과 뱃지)

```
목적: 세션 한정 성과 지표를 감성적으로 강조
구성:
  [ 아이콘 SF Symbol 20pt, badge 컬러 ]
  [ value  (22 bold, text1) + unit (13 regular, text3) 인라인 ]
  [ label  (13 semibold, text2) ]

치수:
  너비: (화면너비 - 44) / 2  (좌우 패딩 16, 간격 12)
  높이: 80 최소
  내부 패딩: 16 좌우, 14 상하
  cornerRadius: 14
  background: badge 컬러 8% 불투명 (라이트), 12% (다크)
  border: badge 컬러 20% 불투명, 1pt stroke

상태:
  default   → 위 스펙
  zero      → value = "0", 전체 opacity 0.4 (아직 정리 안 했음)
  skeleton  → StatCard와 동일 shimmer

VoiceOver:
  accessibilityLabel: "\(label) \(value)\(unit)"
  세션 한정 설명은 화면 레벨 accessibilityElement로 별도 처리
```

### 4-3. QuickCleanRow (빠른 접근 행)

```
목적: 통계 화면에서 카테고리 정리 화면으로 원탭 진입
구성:
  [ 아이콘 컨테이너 40×40, r10, 배경 컬러 15% ]
  [ 제목 (17 semibold, headline, text1) ]
  [ 부제 (15 regular, body, text2): "N장" 또는 "N개" ]
  [ chevron.right 13pt, text3 ]
  + NavigationLink 전체 행 래핑

치수:
  높이: 56 최소
  좌우 패딩: 16  요소 간격: 12
  배경: systemBackground
  구분선: 행 사이 Divider, leading 56 (아이콘 너비) inset

상태:
  default   → 위 스펙
  pressed   → scale(0.98), opacity(0.85), 0.1s ease
  zero      → 부제 "없음", tint gray, 탭 비활성화
  skeleton  → 아이콘 36×36 원 shimmer + 텍스트 SkeletonLine 2개

VoiceOver:
  accessibilityLabel: "\(title) \(count)개"
  accessibilityHint: "탭하여 정리 시작"
  accessibilityRole: .button
```

### 4-4. InfoBanner (권한 알림 배너)

```
목적: limited 권한 등 비파괴적 경고를 컨텍스트 내에서 표시
      전체 화면 대체 없이 콘텐츠와 공존 → 사용자 작업 흐름 유지

구성:
  [ 아이콘 SF Symbol 16pt, style 컬러 ]
  [ 텍스트 (14 regular, text1) + 액션 링크 (14 semibold, style 컬러) ]
  [ 닫기 × 버튼 44×44 터치 타깃 (optional, isDismissible) ]

스타일 enum:
  .warning  → warningLight 배경, warning 아이콘/텍스트/border
  .error    → danger 10% 배경,  danger 아이콘/border
  .info     → primaryLight 배경, primary 아이콘/border

치수:
  좌우 패딩: 16  상하 패딩: 12
  아이콘↔텍스트 간격: 8
  cornerRadius: 12
  border: 1pt, style 컬러 30%

상태:
  visible     → 위 스펙
  dismissing  → .transition(.opacity.combined(with: .move(edge: .top)))

VoiceOver:
  accessibilityLabel: "경고: \(message)"
  액션 버튼: accessibilityLabel: "설정에서 권한 변경"
  닫기 버튼: accessibilityLabel: "배너 닫기"

다크 모드:
  배경을 하드코딩 hex 대신 Color(.systemYellow).opacity(0.15) 등 시맨틱 근사값 사용
  또는 Asset Catalog에 warningLight 다크 variant 등록
```

### 4-5. SkeletonModifier (shimmer)

```
목적: 로딩 중 콘텐츠 자리를 채워 레이아웃 안정감 + 로딩 인식 제공
      기존 ProgressView()보다 위치 정보를 유지해 인지적 점프 최소화

구현 방식: View extension .shimmer()
  → overlay: LinearGradient(shimmerBase → shimmerHighlight → shimmerBase)
  → withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false))
     이동: offset.x -100% → +100%

SkeletonCard:  cornerRadius 14, 최소 높이 100
SkeletonRect:  cornerRadius 8, 임의 크기
SkeletonLine:  높이 12, cornerRadius 6, 너비 다양 (full / 60% / 40%)

접근성:
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("로딩 중")
  .reducedMotion: animate 꺼서 고정 shimmerBase 색만 표시
```

---

## 5. 접근성 체크리스트

### 5-1. 색 대비

| 요소 | 전경 | 배경 | 대비비 | 판정 |
|------|------|------|--------|------|
| StatCard 숫자 text1 #0F0F23 | `#0F0F23` | `#FFFFFF` | 18.4:1 | PASS |
| StatCard unit text3 #AAAABE | `#AAAABE` | `#FFFFFF` | 2.8:1 | 작은글씨 FAIL → **13pt는 일반 텍스트 기준 4.5:1 충족 필요** → text2(#64647D) 사용으로 교체, 대비 5.7:1 PASS |
| AchieveBadge label text2 | `#64647D` | warningLight `#FFFBEB` | 4.6:1 | PASS |
| InfoBanner warning icon | `#F59E0B` | `#FFFBEB` | 2.1:1 | 아이콘 단독 실패 → **텍스트 병행 필수** (이미 설계에 포함) |
| QuickCleanRow 제목 text1 | `#0F0F23` | `#FFFFFF` | 18.4:1 | PASS |
| VideoRow 크기 text2 bold | `#64647D` | `#FFFFFF` | 5.7:1 | PASS |
| 삭제바 "삭제" 흰글씨 on danger | `#FFFFFF` | `#EF4444` | 4.0:1 | 큰 텍스트(17 bold) 기준 3:1 → PASS |

> StatCard `unit` 레이블을 text3 → text2로 토큰 교체. 결정 근거: 11pt caption 크기에서 #AAAABE는 WCAG AA 기준 미달이므로 한 단계 진한 text2(#64647D)로 격상. 시각적 계층은 font weight(bold vs regular)로 유지.

### 5-2. Dynamic Type

- 모든 폰트는 `.font(.headline)` 등 시맨틱 + 커스텀은 `UIFontMetrics` 스케일
- StatCard `value` 34pt는 `largeTitle` 스케일 사용 → 접근성 텍스트 크기에서 자동 확장
- HStack 카드 3개: 초대형 텍스트(xxxL)에서 VStack 2열로 자동 전환하려면 `ViewThatFits` 또는 `@ScaledMetric` 활용 권장
- VideoRow 높이는 고정값 아닌 최솟값(`frame(minHeight: 72)`)

### 5-3. VoiceOver

- StatCard: 전체가 단일 accessibilityElement, label = "사진 2,341장"
- AchieveBadge: "삭제한 사진 34장" / "절약한 용량 412MB"
- QuickCleanRow: role = .button, hint = "탭하여 정리 시작"
- VideoRow: label = "제목, 412MB, 3분 25초", 재생 오버레이 아이콘 .accessibilityHidden(true)
- InfoBanner: 배너 전체 .accessibilityElement, label = "경고: 일부 사진만 접근 가능합니다"
- Shimmer 영역: .accessibilityLabel("로딩 중")
- 장식 아이콘(카드 배경 아이콘 등): .accessibilityHidden(true)

### 5-4. 터치 타깃

| 요소 | 실제 크기 | 타깃 충족 |
|------|-----------|-----------|
| QuickCleanRow | 높이 56pt, 풀 너비 | PASS |
| VideoRow | 높이 72pt, 풀 너비 | PASS |
| InfoBanner 닫기 × | 44×44pt 명시 | PASS |
| StatCard | 최소 100pt 높이 | PASS (비인터랙티브, 탭 없음) |
| 삭제 바 "삭제" 버튼 | 44pt 이상 | PASS |

### 5-5. 다크 모드

- 모든 배경: `Color(.systemBackground)`, `Color(.secondarySystemBackground)` 시맨틱
- 텍스트: `.primary`, `.secondary` 또는 토큰 컬러셋(Asset Catalog)
- 카드 그림자: 다크모드에서 y8 blur16 black 0.04 (8% → 4% 자동 조정 권장)
- InfoBanner 배경: Asset Catalog에 Light/Dark 두 값 등록 필수
- shimmerBase/shimmerHighlight: Light `#E4E4F2`/`#F4F4FA`, Dark `#2C2C3E`/`#3A3A4E`

### 5-6. 색 단독 정보 전달 금지

- 성과 뱃지: 삭제(danger 빨강) — 항상 `trash.fill` 아이콘 병행
- 상태 구분: limited 배너는 아이콘 + 텍스트 + 색 모두 사용
- 선택 상태: 파란 배경 + 체크마크 아이콘 병행 (기존 SelectableThumbnail 패턴 유지)

---

## 6. SwiftUI 핸드오프 스니펫

### 6-1. 디자인 토큰 Extension

```swift
// DesignTokens.swift
import SwiftUI

extension Color {
    // 기존
    static let brand        = Color(red: 0.39, green: 0.40, blue: 0.95) // #6366F1
    static let brandLight   = Color(red: 0.93, green: 0.93, blue: 0.99) // #EEEEFE
    static let brandSecond  = Color(red: 0.66, green: 0.33, blue: 0.97) // #A855F7
    static let success      = Color(red: 0.06, green: 0.73, blue: 0.51) // #10B981
    static let danger       = Color(red: 0.94, green: 0.27, blue: 0.27) // #EF4444
    static let appBg        = Color(red: 0.98, green: 0.98, blue: 0.99) // #FAFAFD
    static let text1        = Color(red: 0.06, green: 0.06, blue: 0.14) // #0F0F23
    static let text2        = Color(red: 0.39, green: 0.39, blue: 0.49) // #64647D
    static let text3        = Color(red: 0.67, green: 0.67, blue: 0.75) // #AAAABE
    static let borderColor  = Color(red: 0.89, green: 0.89, blue: 0.95) // #E4E4F2

    // 신규 추가
    static let statBlue     = Color(red: 0.23, green: 0.51, blue: 0.96) // #3B82F6
    static let warning      = Color(red: 0.96, green: 0.62, blue: 0.04) // #F59E0B
    static let warningLight = Color(red: 1.00, green: 0.98, blue: 0.92) // #FFFBEB

    // shimmer (Asset Catalog으로 옮기길 권장 — 다크 대응)
    static let shimmerBase      = Color(red: 0.89, green: 0.89, blue: 0.95)
    static let shimmerHighlight = Color(red: 0.96, green: 0.96, blue: 0.98)
}

// MARK: - 카드 모디파이어
extension View {
    func cardStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .padding(16)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    func sectionHeaderStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Color.text1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }
}
```

### 6-2. ShimmerModifier

```swift
// ShimmerModifier.swift
import SwiftUI

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if !reduceMotion {
                        LinearGradient(
                            stops: [
                                .init(color: Color.shimmerBase, location: 0),
                                .init(color: Color.shimmerHighlight, location: 0.4),
                                .init(color: Color.shimmerBase, location: 0.8),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width)
                    }
                }
                .clipped()
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// 로딩 여부에 따라 shimmer를 조건부 적용
    func shimmer(when isLoading: Bool) -> some View {
        isLoading ? AnyView(modifier(ShimmerModifier())) : AnyView(self)
    }
}

// MARK: - Skeleton 기본 블록
struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.shimmerBase)
            .frame(width: width, height: height)
            .shimmer()
            .accessibilityHidden(true)
    }
}
```

### 6-3. StatCard

```swift
// StatCard.swift
import SwiftUI

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 아이콘 컨테이너
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            if isLoading {
                SkeletonRect(height: 28, cornerRadius: 6)
                SkeletonRect(width: 48, height: 13, cornerRadius: 4)
            } else {
                // 숫자
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.text1)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                // 단위 + 제목
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Color.text2)     // text3 → text2: 대비 4.5:1 확보
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.text2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? "로딩 중" : "\(title) \(value)\(unit)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCard(icon: "photo.fill",        iconColor: .brand,    title: "사진",   value: "2,341", unit: "장")
        StatCard(icon: "video.fill",        iconColor: .statBlue, title: "동영상", value: "187",   unit: "개")
        StatCard(icon: "internaldrive.fill", iconColor: .success,  title: "총 용량", value: "12.4", unit: "GB")
    }
    .padding(12)
    .background(Color.appBg)
}
```

### 6-4. AchieveBadge

```swift
// AchieveBadge.swift
import SwiftUI

struct AchieveBadge: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let unit: String
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoading {
                SkeletonRect(width: 32, height: 32, cornerRadius: 8)
                SkeletonRect(height: 22, cornerRadius: 5)
                SkeletonRect(width: 60, height: 13, cornerRadius: 4)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.text1)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Color.text2)
                }

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.text2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 80)
        .background(iconColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(iconColor.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? "로딩 중" : "\(label) \(value)\(unit)")
    }
}
```

### 6-5. InfoBanner

```swift
// InfoBanner.swift
import SwiftUI
import UIKit

enum BannerStyle {
    case warning, error, info

    var iconName: String {
        switch self {
        case .warning: return "lock.trianglebadge.exclamationmark.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .warning: return .warning
        case .error:   return .danger
        case .info:    return .brand
        }
    }

    var backgroundColor: Color {
        switch self {
        case .warning: return Color(.systemYellow).opacity(0.12)
        case .error:   return Color(.systemRed).opacity(0.10)
        case .info:    return Color.brandLight
        }
    }
}

struct InfoBanner: View {
    let style: BannerStyle
    let message: String
    var actionLabel: String? = nil
    var onAction: (() -> Void)? = nil
    var isDismissible: Bool = false
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: style.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(style.accentColor)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.text1)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel, let onAction {
                    Button(actionLabel, action: onAction)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.accentColor)
                        .accessibilityLabel(actionLabel)
                }
            }

            Spacer(minLength: 0)

            if isDismissible {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.text3)
                        .frame(width: 44, height: 44)    // 44pt 터치 타깃
                }
                .accessibilityLabel("배너 닫기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(style.backgroundColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style.accentColor.opacity(0.30), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("경고: \(message)")
    }
}
```

### 6-6. VideoRow

```swift
// VideoRow.swift
import SwiftUI

struct VideoRow: View {
    let item: PhotoItem           // PHAsset 기반 모델
    var formattedSize: String?    // nil = 로딩 중
    var formattedDuration: String = ""
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 썸네일 + 재생 오버레이
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

                        Text("·").foregroundStyle(Color.text3).font(.caption)

                        // 파일 크기 placeholder
                        if let size = formattedSize {
                            Text(size)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.text2)
                        } else {
                            Text("-- MB")
                                .font(.caption)
                                .foregroundStyle(Color.text3)
                        }

                        if !formattedDuration.isEmpty {
                            Text("·").foregroundStyle(Color.text3).font(.caption)
                            Text(formattedDuration)
                                .font(.caption)
                                .foregroundStyle(Color.text3)
                        }
                    }
                }

                Spacer()

                // 선택 배지 또는 chevron
                if isEditing {
                    selectionBadge
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text3)
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
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())  // 전체 행 탭 영역 확보
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(isEditing ? "탭하여 선택" : "탭하여 미리보기")
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - 썸네일
    private var thumbnailView: some View {
        ZStack {
            PhotoThumbnail(item: item, targetSize: CGSize(width: 112, height: 112))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 재생 아이콘 오버레이
            Circle()
                .fill(.black.opacity(0.45))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)  // 시각적 중앙 보정
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
                    .strokeBorder(Color.gray.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityHidden(true)  // 선택 상태는 상위 레이블로 전달
    }

    private var accessibilityDescription: String {
        let size = formattedSize ?? "크기 로딩 중"
        return "\(item.displayTitle), \(size), \(formattedDuration)"
    }
}

// PhotoItem extension — 뷰 전용 헬퍼
extension PhotoItem {
    var displayTitle: String {
        // PHAsset 파일명 또는 날짜 기반 fallback
        "동영상 \(formattedDate)"
    }

    var formattedDate: String {
        guard let date = creationDate else { return "날짜 없음" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }
}
```

### 6-7. StatsView 전체 뼈대

```swift
// StatsView.swift
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var library: PhotoLibraryService
    @StateObject private var vm = StatsViewModel()
    @State private var showLimitedBanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // limited 배너
                    if showLimitedBanner {
                        InfoBanner(
                            style: .warning,
                            message: "일부 사진만 접근 가능합니다 — 전체 통계가 정확하지 않을 수 있어요",
                            actionLabel: "더 보기",
                            onAction: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            },
                            isDismissible: true,
                            onDismiss: {
                                withAnimation { showLimitedBanner = false }
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── 섹션 1: 보관함 현황 ──
                    Text("보관함 현황")
                        .sectionHeaderStyle()

                    HStack(spacing: 12) {
                        StatCard(
                            icon: "photo.fill", iconColor: .brand,
                            title: "사진", value: vm.photoCount, unit: "장",
                            isLoading: vm.isLoading
                        )
                        StatCard(
                            icon: "video.fill", iconColor: .statBlue,
                            title: "동영상", value: vm.videoCount, unit: "개",
                            isLoading: vm.isLoading
                        )
                        StatCard(
                            icon: "internaldrive.fill", iconColor: .success,
                            title: "총 용량", value: vm.totalGB, unit: "GB",
                            isLoading: vm.isLoading
                        )
                    }
                    .padding(.horizontal, 12)

                    Divider().opacity(0.3).padding(.horizontal, 16)

                    // ── 섹션 2: 이번 정리 성과 ──
                    VStack(alignment: .leading, spacing: 4) {
                        Text("이번 정리 성과")
                            .sectionHeaderStyle()
                        Text("앱을 종료하면 초기화됩니다")
                            .font(.caption)
                            .foregroundStyle(Color.text3)
                            .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        AchieveBadge(
                            icon: "trash.fill", iconColor: .danger,
                            label: "삭제한 사진", value: "\(vm.sessionDeletedCount)", unit: "장",
                            isLoading: vm.isLoading
                        )
                        AchieveBadge(
                            icon: "externaldrive", iconColor: .success,
                            label: "절약한 용량", value: vm.sessionSavedMB, unit: "MB",
                            isLoading: vm.isLoading
                        )
                    }
                    .padding(.horizontal, 16)

                    Divider().opacity(0.3).padding(.horizontal, 16)

                    // ── 섹션 3: 지금 정리할 수 있는 것 ──
                    Text("지금 정리할 수 있는 것")
                        .sectionHeaderStyle()

                    VStack(spacing: 0) {
                        NavigationLink(destination: CategoryCleanupView(category: .screenshots)) {
                            QuickCleanRow(
                                icon: "camera.viewfinder", iconColor: .brand,
                                title: "스크린샷", count: vm.screenshotCount, unit: "장",
                                isLoading: vm.isLoading
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 56 + 16 + 12)  // 아이콘 폭 + 패딩 + 간격

                        NavigationLink(destination: CategoryCleanupView(category: .largeVideos)) {
                            QuickCleanRow(
                                icon: "film.stack", iconColor: .statBlue,
                                title: "대용량 동영상", count: vm.largeVideoCount, unit: "개",
                                isLoading: vm.isLoading
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .background(Color.appBg)
            .navigationTitle("통계")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await vm.load(library: library)
                showLimitedBanner = (library.authorizationStatus == .limited)
            }
        }
    }
}
```

### 6-8. CategoryCleanupView 뼈대

```swift
// CategoryCleanupView.swift
import SwiftUI

enum CleanupCategory {
    case screenshots
    case largeVideos

    var title: String {
        switch self {
        case .screenshots: return "스크린샷"
        case .largeVideos: return "대용량 동영상"
        }
    }

    var emptyIcon: String { "checkmark.circle.fill" }
    var emptyTitle: String { "정리할 항목이 없습니다" }
    var emptyBody: String { "스크린샷 또는 대용량 동영상이\n발견되지 않았습니다." }
}

struct CategoryCleanupView: View {
    let category: CleanupCategory
    @EnvironmentObject var library: PhotoLibraryService
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
        .safeAreaInset(edge: .top) {
            if showLimitedBanner {
                InfoBanner(
                    style: .warning,
                    message: "일부 사진에만 접근할 수 있어 목록이 불완전할 수 있습니다",
                    isDismissible: true,
                    onDismiss: { withAnimation { showLimitedBanner = false } }
                )
                .padding(.top, 8)
            }
        }
        .task {
            await vm.load(category: category, library: library)
            showLimitedBanner = (library.authorizationStatus == .limited)
        }
    }

    // 스크린샷 → PhotoGridScreen 재사용, 대용량 동영상 → VideoList
    @ViewBuilder
    private var contentView: some View {
        switch category {
        case .screenshots:
            PhotoGridScreen(title: vm.navigationTitle(for: category), items: vm.items)
        case .largeVideos:
            VideoListView(vm: vm)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("항목을 불러오고 있습니다…")
                .font(.body)
                .foregroundStyle(Color.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
    }

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
    }
}

// VideoListView는 CategoryCleanupView 내부에서만 사용
private struct VideoListView: View {
    @ObservedObject var vm: CategoryCleanupViewModel
    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var showConfirm = false

    var body: some View {
        List {
            ForEach(vm.items) { item in
                VideoRow(
                    item: item,
                    formattedSize: vm.fileSizes[item.id],
                    formattedDuration: vm.durations[item.id] ?? "",
                    isEditing: isEditing,
                    isSelected: selectedIDs.contains(item.id)
                ) {
                    guard isEditing else { return }
                    if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
                    else { selectedIDs.insert(item.id) }
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
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing && !selectedIDs.isEmpty {
                deleteBar
            }
        }
        .confirmationDialog(
            "\(selectedIDs.count)개의 동영상을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { /* vm.delete(selectedIDs) */ }
        }
    }

    private var deleteBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedIDs.count)개 선택됨")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("삭제하면 복구가 어렵습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) { showConfirm = true } label: {
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
}
```

### 6-9. MainTabView 업데이트 (탭 5번 추가)

```swift
// MainTabView.swift — 5번째 탭 추가
TabView {
    DateGroupView()
        .tabItem { Label("날짜별", systemImage: "calendar") }

    LocationGroupView()
        .tabItem { Label("장소별", systemImage: "map") }

    FaceGroupView()
        .tabItem { Label("얼굴별", systemImage: "person.2") }

    DuplicatesView()
        .tabItem { Label("중복사진", systemImage: "square.on.square") }

    StatsView()                                     // ← 신규
        .tabItem { Label("통계", systemImage: "chart.bar.fill") }
}
```

---

## 7. UX 흐름 결정 근거 요약

| 결정 | 근거 |
|------|------|
| StatCard 3개 가로 배치 | 수치 비교(사진·동영상·용량)가 목적이므로 나란히 배치해 한눈에 비교 가능. 격자보다 좁은 너비를 허용하는 숫자 데이터에 적합 |
| AchieveBadge 세션 한정 부제 | "이번 세션에만 유효"를 숨기면 재진입 시 빈 상태 혼란 → 작은 caption으로 프레이밍하되 강조는 숫자에 집중 |
| QuickCleanRow chevron | HIG: 다음 화면으로 push하는 모든 행에 chevron. 탭 가능성을 색만으로 표현하지 않음 |
| 동영상 = List, 스크린샷 = Grid | 동영상은 메타데이터(크기·길이)가 선택의 핵심이므로 행 레이아웃이 정보 가독성 우세. 스크린샷은 시각적 내용 확인이 목적이므로 기존 격자 재사용 |
| InfoBanner 화면 상단, 전체 대체 아님 | limited 권한은 기능을 완전 차단하지 않으므로 컨텍스트 내 경고로 처리. 전체 화면 교체는 denied/restricted에만 적용 |
| Shimmer 방향 left→right | 읽기 방향과 일치해 자연스러운 로딩 흐름 인지. 상하 방향은 스크롤과 혼동 우려 |
| unit 레이블 text3 → text2 교체 | 13pt에서 #AAAABE(text3)는 WCAG AA 기준 대비비 2.8:1로 미달. #64647D(text2)로 변경하면 5.7:1로 PASS. 시각 계층은 font weight 차이로 유지 |
