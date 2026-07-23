# 03. Product Requirements Document

## 1. 문서 정보

- 제품: KinFlow(가칭)
- 버전: 1.0
- 기준일: 2026-07-21
- 목표 릴리스: Flutter Android Store MVP, 이후 iOS 재검토와 독립 Web Companion Beta
- 플랫폼: Tier 1 Android, Deferred iOS·iPadOS/Web Companion/Flutter Desktop
- 초기 언어: en, ko
- 요구사항 ID 접두사: `PRD-`, 세부 기능은 `FR-`
- 승인 범위: 대한민국 단일 시장, Android/dev·prod/Google 로그인, 개인 운영, 성인 계정 사용자와 성인 2인 Activation 우선(D-002, D-013, D-032, D-039, D-051~D-054)

## 2. 목표

| ID | 목표 | 측정 |
|---|---|---|
| PRD-G01 | 가족 두 명 이상이 집안일 책임과 완료 상태를 공유 | 활성화 가구율, 두 번째 성인 행동률 |
| PRD-G02 | 오늘의 집안일과 일정을 한 화면에서 이해 | Today 재방문, task success |
| PRD-G03 | 반복 작업을 매번 재입력하지 않고 현지 시간대로 정확히 생성 | 반복 오류·수정·알림 누락률 |
| PRD-G04 | P1에서 자녀에게 최소 권한으로 참여 경험 제공 | 보호자 gate 우회 0, 자녀 task completion |
| PRD-G05 | 한 명의 결제로 선택된 한 가구에 안정적으로 Plus 제공 | entitlement mismatch, 복원 성공률 |
| PRD-G06 | 글로벌 출시의 기본 요건인 개인정보·삭제·접근성·i18n 충족 | release gate 통과 |
| PRD-G07 | Android에서 가구 데이터·권한·entitlement를 일관되게 제공하고 후속 플랫폼으로 계약을 확장 | Android contract test 통과, 후속 platform contract parity |

## 3. 비목표

Store MVP는 다음을 해결하지 않는다.

- 가족 메신저 또는 소셜 네트워크
- 실시간 위치 추적
- 용돈·결제·가계부
- 의료·복약·돌봄 기록
- 외부 캘린더 양방향 동기화
- 학교·기업용 복잡한 스케줄링
- 독립 자녀 로그인과 자녀 간 비공개 상호작용
- 완전한 offline-first 협업
- 초기 Windows·macOS·Linux 네이티브 앱
- 모든 플랫폼에서 픽셀 단위로 동일한 UI
- Web Beta의 필수 조건으로서 Web Push 또는 Web 유료 결제
- Managed Child 프로필과 child mode(P1; H-05·법률·Store 검토 후 재승인)

## 4. 사용자와 역할

| 역할 | 인증 | 핵심 능력 |
|---|---|---|
| Owner | 성인 로그인 | 가구 소유권·삭제·billing household 선택·모든 관리 |
| Admin | 성인 로그인 | 구성원·초대·집안일·일정 관리. 소유권/가구 삭제/결제 이전 제외 |
| Member | 성인 로그인 | 허용된 항목 생성·편집, 자기/가족 상태 확인 |
| Managed Child (P1) | 독립 인증 없음 | 허용된 공유 기기 모드에서 자기 할 일 보기·완료 |

정확한 권한은 `07_DOMAIN_RULES_AND_STATE_MACHINES.md`를 따른다.

## 5. 핵심 사용자 흐름

### F1. 최초 활성화

1. 성인이 Google 로그인을 완료한다.
2. 가구를 만들고 이름·기본 시간대를 설정한다.
3. 고엔트로피 링크로 다른 성인을 초대한다.
4. 상대가 로그인 후 초대를 확인하고 가구에 가입한다.
5. template 또는 직접 입력으로 집안일 세 개를 만든다.
6. 서로 다른 두 명이 각자 항목을 완료한다.
7. 다음 날 Today를 다시 확인한다.

### F2. 관리형 자녀(P1 후속 흐름, Store MVP 비범위)

1. Owner/Admin이 Managed Child를 만들고 보호자를 연결한다.
2. 보호자가 공유 기기에서 자녀 모드로 전환한다.
3. 자녀는 자기에게 배정된 항목과 제한된 가족 일정만 본다.
4. 자녀가 완료하면 audit에는 acting member와 authenticated adult session을 구분해 남긴다.
5. 설정·구독·초대·삭제로 나가려면 보호자 gate를 통과한다.

### F3. 구독

1. 성인이 Plus 기능을 선택한다.
2. paywall이 가격·기간·자동 갱신·가구 적용 범위를 설명한다.
3. 구매 후 서버가 purchaser와 선택된 household를 검증해 entitlement를 materialize한다.
4. 모든 가구 구성원은 다음 refresh에서 Plus를 확인한다.
5. 만료·billing issue 시 기존 데이터는 유지되고 제한 정책이 설명된다.

## 6. Store MVP 기능 요구사항 요약

| 영역 | 요구사항 | 상세 |
|---|---|---|
| 인증 | Google 로그인, 세션 복원, 로그아웃, 계정 삭제 | FR-AUTH-* |
| 가구 | 생성, 초대, 수락, 역할, 소유권, 구성원 제거 | FR-HH-* |
| 자녀(P1) | 관리형 프로필, guardian 관계, member mode, parental gate | FR-CHILD-* |
| 집안일 | CRUD, 배정, due, 반복, occurrence, 완료·승인 | FR-CHORE-* |
| 일정 | timed/all-day, 참석/가시성, 반복, 회차 예외 | FR-CAL-* |
| Today | 집안일·일정 통합, 필터, timezone, 빈/오류 상태 | FR-TODAY-* |
| 알림 | 푸시 동의, token, reminder, quiet hours, deep link | FR-NOTIF-* |
| 구독 | offerings, purchase, restore, webhook, household entitlement | FR-SUB-* |
| 설정 | 프로필, 언어, 시간대, 알림, export/delete, support | FR-SET-* |
| 플랫폼 | i18n, accessibility, privacy disclosures, analytics consent | FR-PLAT-* |

전체 목록은 `06_FUNCTIONAL_REQUIREMENTS.md`에 있다.

## 7. 주요 제품 정책

### 7.1 한 사용자–한 활성 가구

Store MVP UI는 한 로그인 사용자가 하나의 활성 가구에 참여하도록 제한한다. DB는 미래 확장을 막지 않되, 초대 수락 시 이미 활성 가구가 있으면 가입 전에 명확한 선택/지원 경로를 제공한다. 자동 탈퇴시키지 않는다.

### 7.2 데이터 가시성

기본적으로 성인 가구 구성원은 가구의 집안일과 공유 일정을 본다. 비공개 개인 일정은 MVP에 포함하지 않는다. P1의 Managed Child는 정책상 허용된 필드와 항목만 본다.

### 7.3 완료와 승인

- 일반 항목은 담당자 또는 권한 있는 성인이 완료할 수 있다.
- P1의 `approval_required=true` 자녀 배정 항목은 자녀 완료 후 `awaiting_approval`이 되고 보호자가 승인/반려한다.
- 누가 언제 완료/승인/되돌렸는지 이력을 남긴다.

### 7.4 반복

반복 정의는 series에 저장하고 가까운 미래의 occurrence를 materialize한다. 한 회차 수정은 exception으로 저장한다. Store MVP 편집 범위는 이번 회차와 전체 시리즈다.

### 7.5 만료

구독 만료는 데이터 삭제를 의미하지 않는다. 사용자는 기존 데이터를 보고, export/delete하고, Free 한도 내에서 계속 사용할 수 있다. 한도 초과 데이터는 read-only가 될 수 있으나 임의 삭제하지 않는다.

## 8. 비기능 요구사항

| ID | 요구사항 |
|---|---|
| NFR-SEC-01 | 가구 소유 데이터는 RLS와 교차 가구 무결성 제약으로 격리한다. |
| NFR-SEC-02 | 비밀은 모바일 번들에 포함하지 않고 서버 전용 secret manager에서 관리한다. |
| NFR-PRIV-01 | 위치·연락처·광고 ID를 수집하지 않고 로그/분석 payload를 allowlist한다. |
| NFR-PERF-01 | 정상 네트워크에서 Today 첫 유의미 콘텐츠 p75 2.5초 이하를 목표로 한다. |
| NFR-REL-01 | mutation은 재시도·중복 요청에 안전하며 핵심 job은 멱등성을 가진다. |
| NFR-A11Y-01 | WCAG 2.2 AA 지향, 스크린리더·동적 글자·44pt/48dp touch target 검증. |
| NFR-I18N-01 | 문자열·복수·날짜·숫자를 locale-aware하게 처리하고 RTL 구조 검사를 한다. |
| NFR-OBS-01 | PII 없는 구조화 로그, release/environment correlation, 핵심 SLO 대시보드 제공. |
| NFR-COMP-01 | 구버전 앱과 호환되는 expand/contract migration을 사용한다. |
| NFR-DEL-01 | 계정 삭제 요청 상태와 법적 보관 예외를 사용자에게 설명하고 추적한다. |

## 9. 분석 이벤트 원칙

- 이벤트 이름은 행동을 나타내고 텍스트 내용은 전송하지 않는다.
- household/member ID는 분석 공급자에 원본으로 보내지 않고 필요 시 회전 가능한 pseudonymous ID를 사용한다.
- P1의 Managed Child mode에서는 제3자 분석 SDK를 기본 비활성화한다.
- 성능·오류 이벤트와 마케팅 분석을 분리한다.

## 10. 출시 성공 기준

- Phase 00~08의 종료 Gate 통과
- Critical/High 미해결 보안·데이터 손실 버그 0건
- 핵심 8개 E2E 흐름 Android 통과
- sandbox 결제 lifecycle 및 webhook replay 통과
- account deletion 앱/웹 경로 검증
- 스토어 개인정보·Data Safety·연령 선언이 SDK inventory와 일치
- beta 목표 지표 및 qualitative trust 기준 충족
- rollback, kill switch, on-call 문서와 지원 응답 경로 준비

## 11. 미해결 항목

`DECISIONS.md`의 `OPEN` 항목은 PRD보다 우선한다. 제품팀은 결정을 추측해서 구현하지 않고 관련 Phase Gate에서 확정한다.

## 12. v1.0 Native-first Platform 요구사항

### 12.1 플랫폼 제품 범위

- Tier 1 모바일은 Store MVP 전체 기능을 제공한다.
- Tier 2 Web Companion Beta는 Mobile Store MVP 이후 인증, 가구, 초대, 집안일, Today, 일정, 설정, entitlement 확인을 제공한다.
- Web Companion은 설치를 요구하지 않으며, session/cache/keyboard/accessibility/운영 SLO를 별도 통과한다.
- 네이티브 데스크톱은 수요 Gate 전 비목표다.

### 12.2 비기능 요구사항

| ID | 요구사항 | 출시 기준 |
|---|---|---|
| NFR-PLAT-001 | 공통 도메인·권한·API 계약은 플랫폼 SDK에 의존하지 않는다 | import boundary·contract test |
| NFR-PLAT-002 | platform capability는 adapter로 격리한다 | provider contract와 fallback evidence |
| NFR-PLAT-003 | 모바일·웹에서 같은 사용자·가구·occurrence·entitlement 의미를 가진다 | cross-platform E2E 불일치 0 |
| NFR-WEB-001 | Web production/staging은 HTTPS, PKCE, redirect allowlist, CSP baseline을 사용한다 | Web Beta security Gate |
| NFR-WEB-002 | compact·medium·expanded layout과 keyboard-only 핵심 흐름을 제공한다 | Playwright/manual a11y |
| NFR-WEB-003 | 초기 Web Companion은 사용자 API 응답의 광범위 persistent cache를 금지한다 | cache inspection·logout purge |
| NFR-WEB-004 | direct route load·refresh·back/forward·session expiry를 처리한다 | Playwright route suite |
| NFR-REL-001 | Mobile Store MVP와 Web Beta/GA는 독립 승인한다 | release checklist 분리 |
| NFR-REL-002 | 모든 PR은 Flutter analyze/test를 통과하고, platform RC는 각 build·기기·browser matrix를 통과한다 | CI/RC evidence |

### 12.3 Web Beta 성공 기준

- 초대 수락과 핵심 shared task가 지원 browser에서 완료된다.
- keyboard-only task success가 정의된 핵심 흐름에서 100%다.
- cross-account/cache residue 심각 결함 0건이다.
- 모바일과 Web의 Today·occurrence·entitlement 불일치 0건이다.
- Web Push가 없어도 알림 inbox/email fallback으로 중요한 이벤트를 놓치지 않는다.

### 12.4 Web Companion Beta 성공 기준

- 지원 browser matrix와 200% zoom/screen reader 검증을 통과한다.
- 새 배포와 API schema compatibility, session recovery, cache purge drill이 완료된다.
- web-specific SLO와 alert owner가 있다.
- unsupported capability가 사용자에게 설명되고 모바일 대체 경로가 있다.
