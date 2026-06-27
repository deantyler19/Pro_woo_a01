# 사진정리 앱 — 전문 개발팀 (에이전트 & 스킬)

직무별 전문 에이전트와 스킬을 구성했습니다. 각 에이전트는 자기 직무 스킬을
먼저 읽고 그 절차·체크리스트에 따라 일합니다.

| # | 직무 | 에이전트 (`.claude/agents/`) | 스킬 (`.claude/skills/`) | 핵심 역할 |
|---|------|------------------------------|--------------------------|-----------|
| 1 | PM / 기획 | `product-manager` | `product-planning` | 비즈니스 모델, PRD, 사용자 스토리, 우선순위(RICE/MoSCoW), KPI, 로드맵 |
| 2 | UI/UX 디자이너 | `uiux-designer` | `uiux-design` | 디자인 시스템, UX 흐름, 컴포넌트 명세, 접근성, HIG, SwiftUI 핸드오프 |
| 3 | 프론트엔드 개발 | `mobile-frontend-dev` | `mobile-frontend` | SwiftUI 구현, 동시성 안전, 성능·메모리, 상태관리, 접근성 |
| 4 | 백엔드 개발 | `backend-engineer` | `backend-api` | API 설계, 인증/인가, DB, 인앱결제, 보안, 관측성 |
| 5 | QA / 테스터 | `ios-qa-reviewer` | `ios-qa-review` | 정적 검증, 크래시·UI멈춤·논리버그 탐지, 심각도별 리포트 |

## 사용 방법

### 에이전트 호출
작업 성격에 맞는 직무를 지정해 호출합니다. 예:
- "PM 에이전트로 Pro 구독 기능 PRD 써줘"
- "QA 에이전트로 검증해줘" → `ios-qa-reviewer`
- "백엔드 엔지니어로 로그인 API 설계해줘"

### 스킬 직접 사용
메인 세션에서도 `/product-planning`, `/uiux-design`, `/mobile-frontend`,
`/backend-api`, `/ios-qa-review` 스킬을 직접 불러 그 전문 지침을 적용할 수 있습니다.

## 협업 흐름 (예시)
```
기획(PM) → 화면설계(UI/UX) → 구현(프론트/백엔드) → 검증(QA) → 수정 → 릴리스
   PRD        디자인 토큰        SwiftUI/API        리포트     반영
```

## 공통 원칙
- 각 에이전트는 **자기 스킬 문서를 먼저 읽고** 그 절차를 따른다.
- 기존 코드/문서를 파악한 뒤 작업해 중복·불일치를 피한다.
- 비즈니스 모델·과금·외부 데이터 전송 등 되돌리기 어려운 결정은 사용자 승인 후 진행.
- 이 환경(Linux)은 iOS 빌드 불가 → 빌드·런타임 검증은 "Mac 필요"로 명시.
