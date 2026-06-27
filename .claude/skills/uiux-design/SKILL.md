---
name: uiux-design
description: >
  UI/UX 디자이너 전문 스킬. 룩앤필 정의, 디자인 시스템(컬러·타이포·스페이싱·
  컴포넌트) 구축, 사용자 흐름(UX) 및 화면(UI) 설계, 정보 구조(IA), 인터랙션·
  마이크로카피, 접근성, Apple HIG 준수를 다룬다. SwiftUI 구현으로 이어지는
  디자인 토큰과 컴포넌트 명세를 만든다. 화면 디자인, 디자인 시스템, UX 흐름,
  접근성 개선이 필요할 때 사용한다.
---

# UI/UX 디자인 스킬

직관적이고 편리한 사용성으로 사용자 이탈을 막는다. 산출물은 감상이 아니라
**구현 가능한 명세**(디자인 토큰 + 컴포넌트 + 상태 정의)여야 한다.

## 작업 절차
1. **원칙 정의** — 제품 톤(예: 신뢰감 있는·깔끔한·빠른)과 디자인 3원칙.
2. **IA / 유저 플로우** — 화면 구조와 이동 경로, 빈/로딩/에러 상태까지.
3. **디자인 시스템** — 토큰(컬러·타이포·스페이싱·라운드·그림자) 정의.
4. **컴포넌트 명세** — 상태(default/pressed/disabled/selected)와 규격.
5. **접근성 검증** — 대비비, 다이내믹 타입, VoiceOver, 터치 타깃.
6. **핸드오프** — SwiftUI 토큰/모디파이어로 즉시 구현 가능하게 전달.

## 디자인 토큰 (이 프로젝트 기준)
```
컬러
  primary       #6366F1 (indigo-500)   브랜드/액션
  primaryLight  #EEEEFE                 선택 배경
  secondary     #A855F7 (violet-500)
  success       #10B981 (emerald-500)
  danger        #EF4444 (red-500)
  bg            #FAFAFD  surface #FFFFFF
  text1 #0F0F23  text2 #64647D  text3 #AAAABE
  border        #E4E4F2

타이포 (SF Pro / Dynamic Type)
  largeTitle 34 bold · title 22 bold · headline 17 semibold
  body 15 regular · subhead 13 · caption 11

스페이싱(4pt 그리드)  4 · 8 · 12 · 16 · 24 · 32
라운드  카드 14 · 버튼 12 · 칩/필 999
그림자  card: y8 blur16 black 8%
```

## 컴포넌트 명세 형식
```
컴포넌트: 그룹 카드(Row)
- 구성: 썸네일(56, r10) + 제목(headline) + 부제(subhead, text2) + chevron
- 높이: 72, 좌우 패딩 16, 요소 간격 12
- 상태: default / pressed(0.96 scale) / selected(primaryLight bg)
- 접근성: 전체 행이 하나의 버튼, label="<제목>, 사진 N장"
```

## UX 흐름 작성 규칙
- 모든 화면은 4상태를 정의: **정상 / 로딩 / 비어있음 / 에러(+권한거부)**.
- 첫 진입(온보딩·권한 요청)은 가치를 먼저 설명하고 권한을 요청.
- 파괴적 행동(삭제)은 확인 단계 + 되돌리기 안내 + 명확한 색(danger).
- 진행 시간이 긴 작업(스캔)은 진행률 + 부분 결과 점진 표시.

## 접근성 체크리스트 (필수)
- [ ] 텍스트/배경 대비 ≥ 4.5:1 (큰 텍스트 3:1).
- [ ] Dynamic Type 지원 — 고정 폰트 크기 남발 금지(.font(.headline) 우선).
- [ ] 터치 타깃 ≥ 44×44pt.
- [ ] VoiceOver 레이블·힌트, 장식 요소는 `.accessibilityHidden(true)`.
- [ ] 색만으로 정보 전달 금지(아이콘/텍스트 병행).
- [ ] 다크 모드 대응(시맨틱 컬러 또는 컬러셋 사용).

## Apple HIG 핵심
- 시스템 컴포넌트·SF Symbols 우선, 플랫폼 관습 존중.
- 네비게이션 일관성(탭=동등한 최상위 영역, 4±1개).
- 콘텐츠 우선, 불필요한 장식 절제(Deference / Clarity / Depth).

## SwiftUI 핸드오프 예시
```swift
extension Color {
    static let brand = Color(red: 0.39, green: 0.40, blue: 0.95)
    static let surface2 = Color(.secondarySystemBackground)
}
// 카드 모디파이어
extension View {
    func cardStyle() -> some View {
        self.padding(16)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }
}
```

## 도구 연동
- Figma MCP가 연결돼 있으면 `/figma-generate-design`으로 화면을 Figma에 생성·동기화 가능.
- 정적 목업이 필요하면 Pillow 스크립트로 PNG 미리보기를 만들어 검수.

## 원칙
- "예쁘다"가 아니라 "왜 이 결정인지" 근거(대비/관습/흐름)로 말한다.
- 디자인은 반드시 4상태와 접근성을 포함해야 "완성"이다.
- 토큰 우선 — 하드코딩 색·치수 대신 정의된 토큰을 참조한다.
