# KinFlow Flutter 앱 제품·마스터 스펙 v1.0

> **버전 주의:** 이 문서의 `v1.0`은 KinFlow 앱 스펙 버전이다. Flutter 프레임워크 기준선은 `Flutter SDK 3.44.7 stable`, 포함 Dart는 `Dart SDK 3.12.2`다. 자세한 규칙은 `VERSIONING_CONVENTIONS.md`를 따른다.


> **Markdown 전용판 안내:** 비-Markdown 원본 계약과 검증표는 `<원본명>.md`의 코드 블록에 있습니다. 실제 구현 전에 `MD_ONLY_FORMAT_GUIDE.md`에 따라 원본 파일로 추출하고 검증합니다.


- 기준일: 2026-07-21
- 계약 버전: 2026-07-21
- 제품: 글로벌 가족 집안일·공유 일정 구독 앱
- 플랫폼: Flutter iOS/Android 우선, Web Companion 후속
- 최근 제품 범위 결정: 2026-07-23 — 대한민국 단일 시장·Seoul 리전, 성인 2인 Activation 우선, Managed Child P1


---

# KinFlow Flutter 앱 개발 스펙 v1.0 — START HERE

- 상태: `ACCEPTED — FLUTTER IMPLEMENTATION BASELINE`
- 기준일: 2026-07-23
- 제품 전략: 가족용 집안일·공유 일정 구독 앱
- 출시 전략: iOS·Android 네이티브 앱 우선, Web Companion 후속, 네이티브 데스크톱은 수요 Gate 이후
- Phase 00 제품 결정: 대한민국 단일 시장·Seoul 리전, 성인 계정 Store MVP, 성인 2인 Activation 우선; Managed Child는 P1

## 1. 무엇이 바뀌었나

v0.4의 Expo/Web Companion 중심 클라이언트 기준을 폐기하고 Flutter Native-first 기준으로 새로 작성했다. 제품 비전, Household 권한 모델, Managed Child, PostgreSQL/RLS, 반복 일정, 서버 알림, RevenueCat household entitlement, 삭제·내보내기 원칙은 보존한다.

교체된 핵심은 다음과 같다.

| 이전 기준 | v1.0 기준 |
|---|---|
| Expo + React Native + TypeScript | Flutter SDK 3.44.7 stable + Dart SDK 3.12.2 |
| Expo Router | go_router |
| TanStack Query / React state | Riverpod + Repository/Use Case |
| EAS Build/Submit/Update | GitHub Actions + Fastlane + Store release |
| Web Companion를 조기 공식 플랫폼으로 운영 | 모바일 Store MVP 우선, Web Companion은 독립 후속 Gate |
| Windows/macOS/Linux는 Web Companion으로만 검증 | Flutter Desktop 확장 가능 구조, 실제 출시는 수요 Gate 후 |

## 2. 처음 읽는 순서

1. `DECISIONS.md` — 변경하면 안 되는 제품·아키텍처 결정
2. `SPEC_BASELINE.md` — Flutter·Dart·플랫폼·품질 기준
3. `docs/01_PRODUCT_BRIEF.md`와 `docs/03_PRD.md` — 제품 목표와 MVP
4. `docs/20_PLATFORM_AND_CLIENT_ARCHITECTURE.md` — Flutter 클라이언트 구조
5. `docs/21_TECH_STACK_VERSION_AND_DEPENDENCY_POLICY.md` — 패키지와 업그레이드 정책
6. `docs/24_BACKEND_DATABASE_AND_API_IMPLEMENTATION_SPEC.md` — Supabase·RLS·Edge Function 계약
7. `IMPLEMENTATION_PLAN.md` — Phase 00~10 실행 순서
8. 현재 Phase 문서 한 개
9. `contracts/` — 기계 판독 계약
10. `prompts/MASTER_AGENT_PROMPT.md` — 바이브코딩 최초 지시문

## 3. 에이전트에게 제공하는 방법

저장소 전체를 제공할 수 있으면 이 패키지를 저장소 루트에 둔다. 한 파일만 제공할 수 있으면 `IMPLEMENTATION_SPEC.md`를 사용한다. 제품 의도까지 함께 이해해야 하면 `MASTER_SPEC.md`를 사용한다.

최초 지시는 다음 원칙을 포함해야 한다.

```text
문서 전체를 읽되 지금은 Phase 00만 수행한다.
DECISIONS.md의 ACCEPTED 결정을 임의로 바꾸지 않는다.
OPEN 결정은 코드로 추측하지 않고 안전한 비활성 상태로 남긴다.
Phase Gate의 자동·수동 검증 증거가 없으면 완료라고 하지 않는다.
```

## 4. 구현을 시작하기 전 반드시 확정할 항목

- 앱의 최종 이름·Bundle ID·Package name·도메인
- 성인 대상 Store questionnaire의 법률·Privacy 검토(D-013의 제품 범위는 승인됨)
- Free/Plus 한도, 월간·연간 가격, 무료 체험
- 개인정보 보관·삭제 기간
- 보호자 PIN 복구 정책
- Apple/Google 개발자 계정 소유 주체

최초 출시 국가는 대한민국, Supabase production region은 Seoul `ap-northeast-2`로 승인됐다. 이 결정은 법적 운영 주체나 console owner 미지정을 해소하지 않는다.

## 5. 절대 하지 말아야 할 것

- 모든 플랫폼을 첫날부터 동시에 출시하지 않는다.
- Flutter UI에서 Supabase·RevenueCat·FCM SDK를 직접 호출하지 않는다.
- 클라이언트가 보낸 householdId, role, actingMemberId, isPlus를 신뢰하지 않는다.
- Managed Child를 일반 로그인 계정으로 만들지 않는다.
- 반복 일정을 단일 RRULE 문자열과 한 행으로만 구현하지 않는다.
- 모바일 구독 상태만으로 가구 전체 Plus 권한을 열지 않는다.
- `--dart-define`에 서버 비밀을 넣지 않는다.
- Store 심사를 우회하는 런타임 코드 업데이트를 MVP에 도입하지 않는다.
- Web Companion을 SEO·법률·마케팅 사이트로 사용하지 않는다.

## 6. 산출물

- 제품·기술 문서와 Phase 계획
- Flutter toolchain·pubspec·analysis 설정 예시
- OpenAPI·DB·RLS·오류·이벤트 계약
- 요구사항·권한·결제·반복·플랫폼 검증 매트릭스
- 코딩 에이전트 프롬프트와 검토 템플릿
- 모바일 Store 출시와 후속 Web/Desktop Gate


---

# 00. 기존 설계의 문제와 Flutter 전환 수정안

## 1. 전환 배경

KinFlow의 핵심은 가족이 매일 빠르게 확인하고 완료하는 행동, 푸시 알림, 앱스토어 구독, 초대 링크, 태블릿 사용이다. Web Companion 설치를 주요 채널로 가정하면 사용자 획득·재방문·알림·결제의 불확실성이 제품 위험으로 전이된다. 따라서 v1.0은 Flutter Native-first로 기준을 재설정한다.

## 2. 수정한 핵심 문제

| ID | 심각도 | 문제 | 위험 | v1.0 해결 |
|---|---:|---|---|---|
| GAP-001 | Critical | 모바일과 웹을 동시에 GA하려는 범위 | QA·심사·기능 격차로 출시 지연 | Store MVP → Web Companion 독립 Gate |
| GAP-002 | High | PWA 설치와 Web Push를 핵심 retention 가설로 둠 | iOS 설치 발견성·권한 전환 불확실 | 앱스토어 네이티브 설치와 push를 Tier 1로 설정 |
| GAP-003 | High | 여러 플랫폼 지원을 동일 UI·동시 출시로 해석 | 최소 공통분모 UX | 공통 domain, adaptive UI, 플랫폼별 capability |
| GAP-004 | High | client state layer에 도메인 규칙이 섞일 가능성 | 테스트·데스크톱 확장 어려움 | domain/application/data/presentation 경계 |
| GAP-005 | High | Widget이 Supabase·RevenueCat·FCM 직접 호출 | 권한·재시도·테스트 분산 | Port/Repository/Use Case 강제 |
| GAP-006 | Critical | 클라이언트 role/household/entitlement 신뢰 | 교차 가구·유료 기능 우회 | 서버 membership·RLS·entitlement 재계산 |
| GAP-007 | Critical | Managed Child를 로그인 계정처럼 구현할 가능성 | 아동 개인정보·복구·푸시 위험 | 보호자 관리형 profile + acting context |
| GAP-008 | High | 초대 짧은 코드를 권한 token으로 사용 | brute force·재사용 | 고엔트로피 token hash + 만료·회수·rate limit |
| GAP-009 | High | 반복 시리즈를 한 행/RRULE로 단순화 | DST·예외·이력 손상 | series/revision/occurrence/exception 분리 |
| GAP-010 | High | 기기 local schedule가 알림의 권위자 | 앱 종료·절전·기기 변경 누락 | 서버 job + outbox + FCM/APNs |
| GAP-011 | Critical | RevenueCat customerInfo만으로 household Plus 결정 | 계정·가구 전환 mismatch | 서버 household entitlement materialization |
| GAP-012 | High | 런타임 코드 패치 도구를 기본 배포로 고려 | native 호환·Store 정책·rollback 위험 | MVP 제외, Store release + kill switch |
| GAP-013 | High | 모든 플랫폼 폴더와 plugin을 첫날 활성화 | build surface와 plugin 호환성 폭증 | ios/android/web만 scaffold, desktop 후속 |
| GAP-014 | High | 공개 법률·마케팅 페이지를 Flutter Web으로 구현 | SEO·초기 로딩·접근성 비용 | Astro 정적 사이트 분리 |
| GAP-015 | Medium | package version을 문서가 장기간 고정 | 보안·호환 drift | Flutter SDK exact, package는 Phase 01 검증 후 lock |
| GAP-016 | High | code generation drift 관리 부재 | DTO·Provider 코드 불일치 | generated files commit + CI regeneration diff |
| GAP-017 | Critical | 앱 bundle에 환경 비밀을 넣을 가능성 | 키 탈취 | 공개 config만 dart-define, 비밀 server-side |
| GAP-018 | High | logout 후 local cache/provider identity 잔존 | 다른 가족 데이터 노출 | scope purge contract와 E2E |
| GAP-019 | High | iOS/Android compile 성공을 실제 기능 검증으로 오인 | 결제·푸시·딥링크 실패 | 실제 기기·sandbox·cold-start Gate |
| GAP-020 | Medium | 데스크톱을 “지원 가능”과 “출시 약속”으로 혼동 | 지원 부담 | 수요 Gate와 별도 release train |

## 3. v1.0 원칙

1. 네이티브 모바일이 제품의 첫 번째 유통 채널이다.
2. Flutter는 플랫폼 수를 늘리는 도구지만 출시 범위를 자동으로 늘리지 않는다.
3. 공통화 대상은 도메인·API·권한·디자인 토큰이며, 모든 UI가 같을 필요는 없다.
4. Web Companion은 설치 없이 브라우저에서 쓰는 보조 앱이다.
5. public website와 authenticated product app을 분리한다.
6. desktop은 코드 구조만 준비하고 실제 수요가 생긴 뒤 활성화한다.
7. 각 Phase는 자동 테스트, 실제 기기 검증, 증거, rollback을 가진다.


---

# 01. Product Brief

## 1. 한 문장 정의

**KinFlow는 가족이 오늘 해야 할 집안일과 함께 움직여야 할 일정을 한곳에서 보고, 담당·완료·알림을 분명하게 만드는 가족 운영 앱이다.**

## 2. 문제

가족 운영 정보는 메신저, 개인 캘린더, 메모, 구두 부탁에 흩어진다. 이때 생기는 핵심 문제는 “무엇을 해야 하는지 모름”보다 다음과 같다.

- 부탁한 사람과 맡은 사람이 다르게 이해한다.
- 완료 여부가 보이지 않아 재촉과 반복 질문이 생긴다.
- 일정과 집안일이 분리되어 오늘의 전체 부담을 알기 어렵다.
- 자녀에게 책임을 나누고 싶지만 성인 계정 권한을 줄 수는 없다.
- 한 명이 앱을 설치해도 나머지 가족이 참여하지 않으면 가치가 사라진다.

## 3. 핵심 사용자

### Primary ICP

- 2명 이상의 성인이 함께 살거나 가족 운영을 공동 책임짐
- 주간 집안일이 반복되고 가족 일정 조율이 잦음
- 현재 메신저·공유 캘린더·메모를 섞어 사용함
- 한 명이 coordinator 역할을 과도하게 맡고 있음
- 스마트폰 사용에 익숙하고 가족을 초대할 의사가 있음

### Secondary

- 보호자가 관리하는 학령기 자녀가 있는 가족
- 떨어져 사는 가족을 돌보지만 초기에는 같은 가구 단위로 운영 가능한 경우
- 룸메이트·커플: 사용은 가능하지만 초기 메시지와 정책의 중심은 가족

Store MVP는 성인 계정 사용자만 대상으로 한다. Managed Child와 child mode는 제품 방향에는 남기되 P1로 연기하고 H-05 및 법률·Store 검토 후 다시 승인한다(D-013).

### 비대상

- 교대 근무 스케줄링이 핵심인 기업·팀
- 의료·돌봄 기록, 위치 추적, 금전 관리가 필수인 사용자
- 자녀의 독립 계정과 비공개 메시지가 필수인 가족

## 4. Jobs to Be Done

| 상황 | 사용자가 원하는 진전 | 성공 신호 |
|---|---|---|
| 오늘 가족이 해야 할 일을 정할 때 | 한 화면에서 담당과 마감을 정하고 모두가 보게 하고 싶다 | 같은 질문·재촉 감소 |
| 반복 집안일을 관리할 때 | 매번 다시 만들지 않아도 다음 회차가 정확히 나타나길 원한다 | 반복 누락·중복 감소 |
| 가족 일정이 겹칠 때 | 집안일과 약속을 함께 보고 현실적인 하루를 정하고 싶다 | 일정 충돌 조기 발견 |
| 자녀에게 일을 맡길 때 | 결제·초대·삭제 권한 없이 자기 할 일만 보게 하고 싶다 | 보호자 개입 없이 완료 기록 |
| 앱 비용을 낼 때 | 한 사람이 결제해도 한 가족이 혜택을 받고 데이터가 인질이 되지 않길 원한다 | 복원·만료·탈퇴 시 혼란 없음 |

## 5. 가치 제안

1. **Today first**: 캘린더나 목록보다 오늘 가족 전체의 행동을 먼저 보여준다.
2. **명시적 책임**: 담당자, 마감, 완료, 승인 상태를 분명히 한다.
3. **가족 단위 설계**: 개인 생산성 앱에 공유를 덧붙이지 않고 초대·권한·구독을 가구 단위로 설계한다.
4. **자녀 친화적이지만 보호자 중심**: 자녀에게 필요한 행동만 노출하고 민감한 기능은 보호한다.
5. **데이터를 인질로 삼지 않는 구독**: 만료 후에도 기존 데이터 열람·내보내기·삭제가 가능하다.

## 6. 제품 원칙

- **한 번 입력, 모두가 이해**: 제목보다 담당·시간·상태의 모호함을 줄인다.
- **재촉보다 가시성**: 죄책감 유발 알림과 공개 순위를 피한다.
- **가족 관계를 망치지 않는 디자인**: 점수는 선택적이며 비교·벌점보다 협력을 우선한다.
- **권한은 UI가 아니라 서버가 보장**한다.
- **자녀 데이터는 최소화**하고 제3자 SDK를 기본적으로 배제한다.
- **시간대와 반복은 제품 기능**이며 단순 문자열 변환이 아니다.
- **먼저 검증하고 확장**한다. 사용하지 않는 글로벌 복잡도를 미리 구현하지 않는다.

## 7. 핵심 경험과 활성화

### North-star 행동

`주간 활성 가구 중, 2명 이상이 참여하고 3개 이상의 공유 항목을 만들며 1개 이상을 완료한 가구 비율`

### Activation 정의

가입 후 7일 내 다음을 모두 충족한 가구:

1. 성인 1명이 가구 생성
2. 다른 실제 성인 1명이 초대 수락
3. 3개 이상의 집안일 생성
4. 서로 다른 2명이 적어도 1개씩 완료
5. 둘 중 한 명이 다음 날 다시 Today 방문

P1에서 관리형 자녀를 도입하더라도 자녀만 추가하고 두 번째 성인이 참여하지 않은 경우는 제품 활성화와 구분해 측정한다.

## 8. 사업 모델 가설

- 구독 단위는 개인이 아니라 **한 개의 가구**다.
- 결제자는 한 명이지만 가구 구성원이 혜택을 공유한다.
- Free는 핵심 가치 검증이 가능해야 하며, Plus는 가족 규모·반복 자동화·고급 알림·내역 같은 지속적 가치에 과금한다.
- 정확한 한도와 가격은 인터뷰·prototype·paywall smoke test 후 확정한다.
- Store MVP에는 광고가 없다.

## 9. 차별화 가설

| 대안 | 장점 | 공백 | KinFlow 가설 |
|---|---|---|---|
| 메신저 | 이미 모두 사용 | 구조·완료 상태·반복 약함 | 대화를 대체하지 않고 운영 사실을 구조화 |
| 공유 캘린더 | 일정 시각화 | 집안일 책임·완료 흐름 약함 | 일정과 할 일을 Today에서 결합 |
| 개인 할 일 앱 | 강한 task 기능 | 가족 권한·자녀·가구 결제 약함 | household를 1급 도메인으로 취급 |
| 가족 organizer | 기능 풍부 | 복잡하거나 지역·플랫폼 제한 가능 | 초기 사용 성공과 명료한 핵심 흐름 집중 |

## 10. 성공 지표

### 제품

- Invite accept rate
- Activated household rate
- D7/D30 household retention
- 주간 가구당 생성·완료 항목 수
- 담당 없는 항목 비율
- overdue 후 48시간 이내 처리율
- 초대 후 두 번째 성인의 첫 행동까지 시간

### 품질

- 세션 crash-free rate
- 핵심 mutation 성공률과 p95
- notification 중복·지연률
- entitlement 불일치 건수
- account deletion SLA 준수율
- 가구 데이터 격리 보안 테스트 실패 0건

### 사업

- paywall view → trial/purchase
- trial → paid
- 월간 churn과 billing issue recovery
- paid household당 실제 활성 구성원 수
- support contact per 100 paid households

## 11. 가장 위험한 가설

1. 가족 coordinator가 다른 성인을 실제로 초대할 수 있다.
2. 두 번째 성인이 독립적으로 앱을 다시 사용할 이유가 있다.
3. 집안일과 일정의 결합이 단일 카테고리 앱보다 낫다.
4. 자녀 모드가 사용 가치가 있으면서도 규제·운영 부담을 감당할 수 있다.
5. 가구 단위 구독이 개인 생산성 구독보다 이해하기 쉽다.
6. 유료 전환에 필요한 가치가 “기능 잠금”이 아니라 지속적인 가족 운영 편의로 설명된다.

검증 방법과 중단 기준은 `02_PRODUCT_DISCOVERY_AND_VALIDATION.md`에 정의한다.

## 12. 플랫폼 가치 가설

KinFlow의 핵심 행동은 “가족이 빠르게 확인·완료”하는 모바일 경험이지만, 다음 작업은 큰 화면과 브라우저가 더 적합할 수 있다.

- 여러 반복 집안일의 일괄 설정
- 주간 가족 일정 검토
- 긴 설명·구성원·권한 관리
- 앱 설치 전 초대 수락
- 개인정보 내보내기·삭제·구독 상태 확인

가설은 **모든 가족이 모든 플랫폼을 사용한다**가 아니다. 첫 번째 가설은 모바일 앱만으로 핵심 루프가 성립하는지이며, 두 번째 가설은 coordinator가 후속 Web Companion의 큰 화면에서 계획할 때 추가 가치가 생기는지다. 성공은 코드 공유율보다 다음으로 측정한다.

- Web에서 만든 항목이 모바일에서 정상 사용되는 교차 플랫폼 가구 비율
- 초대 링크의 설치 없는 Web 수락 성공률
- coordinator의 expanded layout task 완료 시간
- Web 사용이 두 번째 가족 구성원의 모바일 참여를 증가시키는지 여부
- 플랫폼 간 entitlement·시간대·상태 불일치 0건

Windows·macOS·Linux 네이티브 앱은 Store MVP 가설이 아니다. Web Companion으로 해결되지 않는 OS 알림·오프라인·키오스크·메뉴바 수요가 정량적으로 증명될 때 Flutter Desktop을 검토한다.

## 13. Native-first 성공 기준

- 초대받은 두 번째 성인이 앱 설치 후 24시간 안에 첫 행동을 완료한다.
- 모바일 푸시 허용 여부와 무관하게 Today 재방문 루프가 성립한다.
- iPad/Android tablet에서 coordinator task가 phone보다 효율적이다.
- Web Companion 없이도 Store MVP 활성화·구독 가설을 검증할 수 있다.
- Flutter 기술 공유율이 아니라 사용자 task success, crash-free, entitlement 정확성으로 판단한다.


---

# 02. 제품 발견 및 가설 검증 계획

## 1. 목적

코드를 많이 만들기 전에 다음 질문에 증거로 답한다.

- 실제로 누가 가장 아픈 문제를 느끼는가?
- 초대한 가족이 참여하는가?
- 집안일과 일정이 하나의 Today에 있을 때 더 유용한가?
- 관리형 자녀 모드가 정말 구매·유지 이유인가?
- 어떤 기능을 무료로 남겨야 네트워크 가치가 만들어지는가?

## 2. 가설 등록부

| ID | 가설 | 위험 | 검증 방법 | 통과 기준 | 실패 시 행동 |
|---|---|:---:|---|---|---|
| H-01 | coordinator는 주 3회 이상 가족 일을 메신저/메모로 재촉한다 | High | 문제 인터뷰 12~15명 | 60% 이상이 최근 2주 구체 사례 제시 | 타깃 또는 문제 재정의 |
| H-02 | 초대받은 성인도 7일 내 독립적으로 Today를 다시 연다 | Critical | concierge pilot 8가구 | 5가구 이상에서 두 번째 성인이 2일 이상 행동 | 개인 coordinator 도구로 pivot 검토 |
| H-03 | 담당·완료 가시성이 재촉 부담을 줄인다 | High | 2주 pilot 전후 설문·인터뷰 | 50% 이상이 체감 감소, 반대 심각 사례 없음 | 알림·책임 표현 재설계 |
| H-04 | 일정과 집안일의 Today 통합이 유의미하다 | Medium | clickable prototype A/B task | 통합안 task success/선호 우세 | 캘린더 출시 후로 이동 |
| H-05 | Managed Child가 필요한 가구는 공유 기기 방식을 수용한다 | High | 자녀 있는 6가구 prototype | 4가구 이상 사용 의향, 보호자 gate 이해 | 자녀 기능 P1 이동 |
| H-06 | 가구 구독 개념을 사용자가 이해한다 | High | paywall comprehension test | 80%가 “한 결제로 어느 가족이 혜택 받는지” 정확히 설명 | 명칭·정책 변경 |
| H-07 | Plus 후보 중 최소 하나가 반복적 지불 가치를 만든다 | Critical | 가격 인터뷰·smoke test | 후보 하나가 명확한 상위 선호와 구매 의향 | 구독 전면 재검토 |
| H-08 | 영어·한국어로 동일 핵심 흐름을 이해한다 | Medium | 양 언어 usability | 핵심 task success 80% 이상 | 카피·IA 수정 |

## 3. 연구 대상과 모집

### 세그먼트

- 자녀 없는 동거/부부 4가구
- 어린 자녀가 있는 가족 4가구
- 학령기 자녀가 있는 가족 4가구
- 돌봄·다세대 조율이 있는 가족 2~3가구

각 연구에서 coordinator만 인터뷰하지 말고 초대받는 두 번째 성인을 포함한다. 같은 가구의 의견을 독립적으로 수집해 “한 명의 강한 선호”가 가족 전체 요구로 오해되지 않게 한다.

### 제외

- 제품 팀 지인만으로 표본 구성
- 미래 의향만 묻는 설문
- 기능 목록을 먼저 보여주고 필요 여부를 묻는 방식

## 4. 문제 인터뷰 가이드

1. 최근 2주 동안 가족에게 반복해서 부탁하거나 확인한 일을 떠올려 달라.
2. 처음 어떻게 전달했고, 누가 맡았으며, 완료 여부를 어떻게 알았는가?
3. 실패하거나 다퉜던 순간은 무엇이었는가?
4. 현재 사용하는 메신저·캘린더·메모 중 버리지 못하는 이유는 무엇인가?
5. 다른 가족이 새 앱을 설치하지 않는 가장 큰 이유는 무엇인가?
6. 자녀에게 일을 맡길 때 어떤 정보와 권한까지 허용하는가?
7. 가족 운영 도구에 비용을 낸 경험과 해지 이유는 무엇인가?

“이 앱을 쓰겠는가?”보다 과거 행동, 대체재 비용, 실제 초대 가능성을 묻는다.

## 5. Prototype 검증

### 필수 task

- 가구 만들고 배우자 초대
- 이번 주 쓰레기 배출을 상대에게 반복 배정
- 자녀 프로필 추가 후 자녀 모드로 자기 할 일 완료
- 토요일 가족 일정 추가 후 Today에서 충돌 확인
- 잘못 완료한 회차 되돌리기
- 유료 플랜이 어느 가구에 적용되는지 설명
- 계정 삭제와 가구 삭제의 차이 찾기

### 기록

- task success/failure
- 첫 클릭과 잘못된 경로
- 도움 요청 횟수
- 주요 문구 이해
- 보호자 gate 우회 시도
- 신뢰를 잃는 순간

## 6. Concierge pilot

### 운영

- 실제 앱 전에는 단순 prototype 또는 최소 구현으로 8가구를 14일 운영한다.
- 연구자가 초기 집안일 template를 구성해 주되, 가족이 직접 수정하게 한다.
- 모든 가구에는 실제 성인 2명 이상이 참여해야 한다.
- 자녀 데이터는 가명·최소 정보만 사용한다.

### 관찰 지표

- 초대 전송→수락 시간
- 두 번째 성인의 첫 생성/완료 행동
- 재촉 메시지 빈도 변화
- 반복 항목 수정/삭제 패턴
- 알림 mute 비율
- 이탈 시점과 이유
- 일정 기능이 실제로 사용된 날

### 주간 질적 질문

- 이번 주 앱 없이 처리했을 일은 무엇인가?
- 앱 때문에 새롭게 한 행동은 무엇인가?
- 가장 신뢰하지 못한 정보는 무엇인가?
- 가족 갈등을 늘린 표현이 있었는가?

## 7. 가격·패키지 검증

### 순서

1. 기능 목록이 아니라 현재 대안의 비용과 불편을 파악한다.
2. Free/Plus 2개 패키지만 제시한다.
3. 월간·연간의 절대 가격보다 가구 단위 적용 이해를 먼저 검증한다.
4. fake purchase 대신 명확한 “관심 등록” 또는 sandbox에서만 테스트한다.
5. 가격은 국가별 tier와 세금을 고려해 Store 설정 직전 확정한다.

### 후보 가치

- 구성원·활성 반복 수 확대
- 고급 반복과 여러 알림
- 완료 내역·가족 리포트
- 일정/집안일 template
- 추가 가구 또는 고급 자동화(P1)

데이터 내보내기, 삭제, 기본 보안, 접근성은 유료 잠금으로 사용하지 않는다.

## 8. 의사결정 규칙

- **Proceed**: 핵심 가설 H-01, H-02, H-03 통과. 심각한 신뢰·권한 문제 없음.
- **Narrow**: 문제는 강하지만 초대 참여가 낮으면 coordinator-first 제품으로 범위를 줄이고 두 번째 성인 activation을 다시 설계.
- **Defer child**: child mode의 가치가 낮거나 정책 부담이 과도하면 Managed Child를 P1로 옮기고 일반 성인 가족만 출시.
- **Defer calendar**: H-04가 통과하지 않으면 Store MVP를 chores+Today로 제한.
- **Stop subscription work**: H-07이 통과하지 않으면 결제 integration을 시작하지 않고 무료 pilot을 연장.

## 9. 산출물

- `evidence/discovery/interview-notes/`
- `evidence/discovery/hypothesis-scorecard.md`
- `evidence/discovery/prototype-results.md`
- `evidence/discovery/pilot-results.md`
- `adr/ADR-0001-mvp-scope.md`
- 업데이트된 `DECISIONS.md`

개인 식별 정보, 자녀 실명, 원문 녹취는 저장소에 넣지 않는다.

## 10. 플랫폼 수요 검증

| ID | 가설 | 검증 | 통과 기준 | 실패 시 행동 |
|---|---|---|---|---|
| H-09 | coordinator는 주간 계획·일괄 편집을 큰 화면에서 더 빠르게 수행한다 | 동일 task 모바일/Web prototype 비교 | task time 또는 오류율이 의미 있게 개선 | expanded UI를 Web Beta 후순위화 |
| H-10 | 앱 미설치 초대 수신자는 Web에서 가입을 시작하면 수락률이 높다 | invitation funnel 비교 | Web fallback이 수락 완료 또는 설치 연결 개선 | Web public invite를 단순 안내로 축소 |
| H-11 | 한 가구가 모바일과 Web을 섞어 써도 상태·시간·권한을 이해한다 | 5가구 cross-platform pilot | 심각한 불일치/신뢰 손상 0, task success 80% 이상 | Web Beta 중단·contract 수정 |
| H-12 | Web Companion이 coordinator의 주간 계획 시간을 줄인다 | phone/tablet/Web 동일 task 비교 | 시간 또는 오류율이 의미 있게 개선 | Web Companion을 read-mostly로 축소 |
| H-13 | 네이티브 push가 가족 재참여에 유의미하다 | permission funnel·delivery·open 측정 | 주요 reminder의 전달·재방문 개선 | 알림 빈도·가치 제안 재설계 |
| H-14 | 유료 Web 결제 경로가 필요한 사용자 비율이 존재한다 | paywall comprehension/interest | 명확한 구매 의향과 국가별 운영 가능성 | Web은 entitlement read-only 유지 |

### Prototype viewport

- compact mobile
- tablet/medium
- expanded desktop browser
- keyboard-only
- 200% browser zoom
- iOS Safari와 Android Chrome의 invite fallback

플랫폼 가설이 실패해도 공통 API·도메인 설계를 폐기하지 않는다. Web Companion의 release priority만 낮춘다.

## 11. Flutter 플랫폼 검증

- 저가 Android 실제 기기와 최신 iPhone을 모두 사용한다.
- phone과 tablet에서 같은 task를 비교하되 layout 동일성을 성공 기준으로 삼지 않는다.
- desktop/web 수요는 모바일 활성 사용자 인터뷰와 event data 이후 검증한다.
- Flutter package 선택은 prototype 속도보다 실제 기기 안정성·접근성·유지보수로 평가한다.


---

# 03. Product Requirements Document

## 1. 문서 정보

- 제품: KinFlow(가칭)
- 버전: 1.0
- 기준일: 2026-07-21
- 목표 릴리스: Flutter Mobile Store MVP, 이후 독립 Web Companion Beta
- 플랫폼: Tier 1 iOS·iPadOS·Android, Tier 2 Web Companion, Deferred Flutter Desktop
- 초기 언어: en, ko
- 요구사항 ID 접두사: `PRD-`, 세부 기능은 `FR-`
- 승인 범위: 대한민국 단일 시장, 성인 계정 사용자, 성인 2인 Activation 우선(D-013, D-039, D-051)

## 2. 목표

| ID | 목표 | 측정 |
|---|---|---|
| PRD-G01 | 가족 두 명 이상이 집안일 책임과 완료 상태를 공유 | 활성화 가구율, 두 번째 성인 행동률 |
| PRD-G02 | 오늘의 집안일과 일정을 한 화면에서 이해 | Today 재방문, task success |
| PRD-G03 | 반복 작업을 매번 재입력하지 않고 현지 시간대로 정확히 생성 | 반복 오류·수정·알림 누락률 |
| PRD-G04 | P1에서 자녀에게 최소 권한으로 참여 경험 제공 | 보호자 gate 우회 0, 자녀 task completion |
| PRD-G05 | 한 명의 결제로 선택된 한 가구에 안정적으로 Plus 제공 | entitlement mismatch, 복원 성공률 |
| PRD-G06 | 글로벌 출시의 기본 요건인 개인정보·삭제·접근성·i18n 충족 | release gate 통과 |
| PRD-G07 | Flutter 모바일 플랫폼에서 동일 가구 데이터·권한·entitlement를 일관되게 제공하고 후속 Web Companion으로 계약을 확장 | iOS/Android mismatch 0, Web contract parity |

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

1. 성인이 이메일 OTP 또는 플랫폼 로그인을 완료한다.
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
| 인증 | OTP, Apple/Google, 세션 복원, 로그아웃, 계정 삭제 | FR-AUTH-* |
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
- 핵심 8개 E2E 흐름 iOS/Android 통과
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


---

# 04. 범위, 로드맵 및 Release Train

## 1. 범위 관리 원칙

- 릴리스의 목표는 기능 개수가 아니라 **가족 단위 가치가 끝까지 작동하는 것**이다.
- 보안·삭제·결제 무결성·접근성은 “나중에 다듬기” 항목이 아니다.
- 각 train은 feature flag 뒤에서 배포할 수 있어야 한다.
- 문서에 없는 기능은 backlog이지 암묵적 MVP가 아니다.

## 2. Release Train

| Train | 대상 | 제품 결과 | 배포 채널 |
|---|---|---|---|
| R0 Prototype | 연구 참여자 | 초대·Today·집안일 이해 검증 | Figma/로컬 prototype |
| R1 Internal Alpha | 개발자·내부 테스터 | auth, 가구, 단건 chore end-to-end | dev client/internal |
| R2 Household Alpha | 5~8 실제 가구 | 반복 chore와 두 번째 성인 retention | closed internal |
| R3 Closed Beta | 20~50 가구 | calendar, push, 성인 가구 안정성 | TestFlight/Play closed |
| R4 Paid Beta | 제한 국가·초대 | sandbox에서 검증된 subscription을 소수 production 사용자에게 노출 | phased feature flag |
| R5 Store MVP | 선정 국가 | 영어·한국어 공개 출시 | App Store/Google Play |
| R6 P1 | 유지율·H-05·정책 Gate 후 | Managed Child, Guest, multi-household, 고급 반복/자동화 | 점진 업데이트 |

## 3. Train별 범위

### R1 Internal Alpha

- 이메일 OTP 또는 dev 인증
- 가구 생성
- 직접 구성원 seed 또는 안전한 초대 최소 흐름
- 단건 집안일 CRUD·완료
- Today 기본 목록
- RLS smoke test

**제외:** 자녀, 반복, 일정, 푸시, 결제.

### R2 Household Alpha

- 실제 초대 링크와 수락
- 역할·구성원 제거
- 반복 집안일·occurrence
- 두 번째 성인의 독립적 사용
- 기본 감사 이력
- 읽기 캐시·네트워크 오류 상태

### R3 Closed Beta

- timed/all-day 일정과 기본 반복
- Today 통합
- 관리형 자녀·guardian·parental gate
- 푸시·quiet hours·deep link
- 영어·한국어와 accessibility
- export/delete staging rehearsal

### R4 Paid Beta

- Store sandbox에서 검증된 paywall
- production SKU를 feature flag로 제한 노출
- purchase/restore/renewal/cancel/billing issue/expiration/transfer 대응
- support runbook과 manual reconciliation
- 기존 데이터 만료 정책 검증

### R5 Store MVP

R3와 R4의 검증 범위, 스토어 정책·법률·운영 준비를 포함한다. 계정 사용자는 성인으로 한정하고 Managed Child/child mode는 포함하지 않는다(D-013). 스토어 상세 범위는 `15_RELEASE_AND_STORE_SUBMISSION_PLAN.md`를 따른다.

## 4. P1 후보

우선순위는 출시 데이터로 다시 계산한다.

- Guest와 기간 제한 초대
- 다중 가구 전환과 추가 가구 유료 옵션
- “이번 이후” 반복 수정
- template marketplace가 아닌 내부 template 확장
- 가족 주간 리포트
- 위젯/워치/웹 read-only
- 제한적 chore offline outbox
- 외부 캘린더 단방향 import
- Managed Child, guardian 관계, child mode, parental gate(H-05·법률·Store 검토 후 별도 Gate)

## 5. Scope Cut 규칙

출시 목표를 줄여야 할 때 아래 순서로 cut한다.

1. Realtime 즉시 반영 → 수동/foreground refresh
2. 여러 reminder → 한 개의 안정적 reminder
3. 복잡한 반복 패턴 → daily/weekly/monthly subset
4. calendar 반복 → 단건/all-day만 유지
5. calendar 전체를 P1로 이동하고 chores+Today 출시

Managed Child와 child mode는 이미 P1로 이동했으므로 Store MVP scope cut 후보가 아니라 비범위다(D-013).

다음은 cut할 수 없다.

- 가구 격리 RLS와 무결성
- 초대 토큰 안전성
- 계정 삭제·구독 고지
- 결제 entitlement 검증
- 핵심 접근성
- 오류·빈 상태
- rollback/kill switch

## 6. 변경 통제

새 기능 제안은 다음을 포함해야 한다.

- 해결할 사용자 문제와 증거
- 관련 요구사항·데이터·권한 변경
- 자녀/개인정보/스토어 영향
- 구독 및 기존 사용자 영향
- migration과 rollback
- 기존 train에서 cut할 항목

승인된 변경은 `DECISIONS.md`, 관련 PRD/Phase, traceability matrix를 함께 갱신한다.

## 7. v1.0 Flutter Release Train

기존 R1~R4는 공통 기능 검증에 유지한다. R5부터 모바일과 Web을 분리한다.

| Train | 대상 | 필수 범위 | Gate |
|---|---|---|---|
| R5M Mobile Store MVP | iOS·Android | 성인용 Store MVP, push, native billing, privacy/store | G2 |
| R6W Web Companion Beta | Web | HTTPS auth, core household/chores/calendar, responsive/keyboard, session/cache purge | G9 |
| R7D Native Desktop Review | Windows/macOS/Linux | 수요·ROI·plugin·보안·배포 ADR만 | G10 |

### Train 분리 규칙

- Web Companion 미완료는 R5M Mobile Store MVP를 자동 차단하지 않는다.
- 공통 DB/API contract 결함은 두 Train 모두 차단할 수 있다.
- cross-platform data/authorization mismatch는 관련 모든 Train의 blocker다.
- Web Push와 Web paid purchase는 Web Companion Beta 필수 범위가 아니다.
- Web Companion Beta 전 browser accessibility, session recovery, cross-account purge를 완료한다.


---

# 05. UX, 정보 구조 및 사용자 흐름

## 1. UX 목표

- 앱을 열고 5초 안에 “오늘 누가 무엇을 해야 하는지” 이해한다.
- 생성 폼에서 책임·시간·반복의 모호함을 없앤다.
- P1 자녀 기능에서는 자녀와 성인 모드의 차이가 명확하되 자녀를 낙인찍지 않는다.
- 실패·오프라인·동기화 상태를 숨기지 않는다.
- 유료 제한과 권한 제한을 같은 메시지로 표현하지 않는다.

## 2. 탭 구조

Store MVP의 기본 탭:

1. **Today** — 집안일·일정 통합, 가장 가까운 행동
2. **Chores** — 목록, 반복 template/series, 완료 내역
3. **Calendar** — 월/주보다 agenda 중심에서 시작, 생성
4. **Family** — 성인 구성원, 초대, 역할
5. **Settings** — 계정, 알림, 언어/시간대, 구독, 개인정보

P1의 Managed Child mode에서는 Today와 제한된 Chores만 노출한다. Calendar는 자녀에게 공개된 가족 일정만 Today 카드로 보여줄 수 있으며 Family/Settings는 보호자 gate 뒤에 둔다.

## 3. Global navigation 상태

- household context는 상단 또는 profile switcher에 표시한다.
- 네트워크 끊김은 비차단 banner로 알리고 온라인 전용 action은 이유와 함께 disable한다.
- entitlement 만료는 전체 앱을 막지 않고 제한되는 action 직전에 설명한다.
- P1에서 active child mode는 지속적으로 식별 가능한 시각/텍스트 표시가 있어야 한다.
- deep link가 권한 없는 화면을 열면 빈 화면이 아니라 안전한 설명과 홈 경로를 제공한다.

## 4. 온보딩 흐름

### 4.1 성인 가입

```text
Welcome → 로그인 방법 → 인증 완료 → 이름/locale/timezone 확인
→ 가구 만들기 또는 초대 수락 → 알림 설명(시스템 prompt 전) → Today
```

- 시스템 알림 prompt는 가치 설명 후, 사용자가 reminder를 켜려는 시점에 요청한다.
- 소셜 로그인 실패 시 이메일 OTP 대체 경로를 제공한다.
- 초대 deep link로 시작한 사용자는 인증 후 원래 초대로 돌아온다.

### 4.2 가구 만들기

- 가구 이름
- 기본 시간대(IANA, 기기 추론 후 확인)
- 선택적 집안일 template
- “가족 초대”를 activation의 핵심 CTA로 제시

### 4.3 초대 수락

- 초대한 가구 이름과 inviter display name
- 참여 시 보이는 정보와 역할
- 이미 다른 활성 가구가 있는 경우 자동 이동 금지
- 만료·회수·이미 사용·정원 초과의 구분된 오류

## 5. Today 화면

### 순서

1. overdue chores
2. 지금/다음 일정
3. 오늘 마감 chores
4. 오늘의 나머지 일정
5. 완료된 항목(collapsed)

### 카드 필드

- 종류 icon+텍스트
- 제목
- 담당자 avatar/이름
- 현지 시간 또는 “All day”
- 반복 표시
- 완료/승인 상태
- 동기화 pending 표시(지원하는 action만)

### 필터

- Everyone / Me
- 필요할 경우 구성원 filter
- filter는 가시성 권한을 넓히지 않는다.

### 상태

- loading skeleton
- 진짜 빈 상태: “첫 집안일 만들기”
- 오늘만 빈 상태: 다음 예정 항목과 생성 CTA
- offline stale 상태: 마지막 동기화 시각
- partial error: 한 영역 실패 시 다른 영역 유지

## 6. 생성·편집 폼

### 공통 패턴

- 빠른 생성에는 제목, 담당, 날짜만 먼저 제공
- 고급 옵션은 progressive disclosure
- 저장 전 timezone/종일/반복 요약 문장 제공
- destructive action은 결과 범위 표시
- 권한 오류와 validation 오류를 구분

### 반복 편집 문구

- “이번 항목만 변경”
- “전체 반복 항목 변경”
- “이번 이후 모두 변경”은 Store MVP에 표시하지 않는다.

전체 반복 변경 시 과거 완료 이력은 수정하지 않는다는 점을 명시한다.

## 7. 관리형 자녀 UX(P1 계약, Store MVP 비범위)

### 자녀 모드 진입

1. 성인 profile switcher에서 자녀 선택
2. 자녀에게 보이는 범위를 설명
3. 모드 전환
4. device-local short-lived child mode session 발급

### 보호자 gate

다음 action은 PIN 또는 최근 성인 인증을 요구한다.

- 자녀 모드 종료 후 성인 화면 접근
- 구성원/초대/역할
- 구독/구매/복원
- 계정·가구 삭제와 export
- 알림·개인정보·identity 설정
- 자녀 프로필 수정

PIN은 서버 계정 비밀번호를 대체하지 않는다. 결제·소유권·삭제처럼 고위험 action은 실제 최근 인증을 요구한다.

### 자녀 카피

- “실패”, “벌점”, “순위” 중심 표현 금지
- 완료 후 보호자 승인 필요 시 `확인 기다리는 중`처럼 중립적으로 표현
- 공개 가족 비교는 기본 비활성화

## 8. 구독 UX

paywall은 다음을 같은 화면에서 명확히 보여준다.

- 어떤 기능이 늘어나는지
- 어느 가구에 적용되는지
- 월/연 가격과 청구 주기
- trial이 있으면 종료일과 자동 갱신
- 구독 관리·복원 경로
- 만료 후 데이터 처리
- Apple Family Sharing과 앱 내부 Family Plan이 다를 경우 그 차이

구매 실패·pending·이미 다른 가구에 적용된 구매·복원 결과를 구분한다.

## 9. 삭제·탈퇴 UX

- **가구 나가기**: 자기 membership 종료. Owner는 소유권 이전 전 불가.
- **계정 삭제**: 로그인 identity와 개인 프로필 삭제 요청. 다른 가구 영향 설명.
- **가구 삭제**: Owner만 가능, 모든 구성원의 공유 데이터에 영향.
- **Managed Child 삭제**: 보호자 전용, 완료 이력은 익명화 보존 가능성 설명.

confirm 문구는 정확한 객체 이름을 보여주고, 삭제 가능한 cooling-off 정책이 있으면 상태와 취소 경로를 표시한다.

## 10. 접근성

- icon-only action에는 접근성 label과 hint 제공
- status를 색만으로 표현하지 않음
- screen reader traversal이 시각 순서와 일치
- 200% 글자 확대에서 핵심 action 누락 없음
- iOS 44pt, Android 48dp 수준의 touch target 지향
- reduce motion에서 불필요한 animation 제거
- 오류는 focus 이동과 텍스트로 알림
- 캘린더 날짜 선택은 screen reader로 날짜·선택 상태를 읽음

## 11. 국제화

- 영어를 source locale로 사용하되 한국어를 동시 검수
- 문장 조합 대신 완전한 번역 문구 사용
- ICU plural과 변수 명명
- 12/24시간, 주 시작 요일, 월/일 순서, 숫자·통화 locale 반영
- 30% 긴 pseudo locale과 RTL mirror smoke test
- 이름 순서를 고정하지 않음

## 12. 핵심 E2E UX 시나리오

1. 초대 deep link → 신규 가입 → 수락 → Today
2. 두 성인이 집안일을 만들고 상대가 완료
3. 반복 집안일 한 회차만 변경
4. P1: 자녀 모드에서 완료 → 보호자 승인
5. DST 변경 주간에도 08:00 반복 일정이 현지 08:00 유지
6. 오프라인에서 읽고 온라인 전용 action 설명 확인
7. Plus 구매 후 다른 구성원이 entitlement 확인
8. 계정 삭제 요청 후 모든 기기 세션 무효화

## 13. 반응형 Web Companion UX

### 13.1 Navigation

| Viewport | 기본 navigation | 콘텐츠 |
|---|---|---|
| compact | bottom tab 또는 compact header | 단일 열, 화면 전환 |
| medium | tab/rail | 1~2열 |
| expanded | sidebar/rail | master-detail 또는 split view |

탭 순서와 route 의미는 플랫폼 간 일관되게 유지한다. expanded layout은 더 많은 정보를 동시에 보여줄 수 있지만 권한이나 데이터 의미를 바꾸지 않는다.

### 13.2 Browser interaction

- Today·집안일 완료·일정 생성·초대 수락을 keyboard-only로 수행할 수 있다.
- focus는 route 전환 시 page heading으로, dialog 종료 시 trigger로 돌아간다.
- browser back/forward가 앱 상태를 깨뜨리지 않는다.
- direct URL과 새로고침을 지원한다.
- hover-only action을 금지한다.
- destructive action은 Enter 오작동을 막고 명시적 confirmation을 사용한다.

### 13.3 Capability 상태

사용자에게 다음 상태를 구분해 보여준다.

- 사용할 수 있음
- 권한 필요
- 이 브라우저/플랫폼에서 지원하지 않음
- 일시적 장애
- 플랜 또는 역할상 사용할 수 없음

예: Web Push 미지원은 “Plus 필요”가 아니며 인앱 알림·이메일 대체 경로를 제공한다.

### 13.4 Web Companion

- 브라우저 URL 접근을 기본으로 하고 설치를 제품 목표로 삼지 않는다.
- 새 배포와 API 계약이 호환되지 않으면 진행 중인 입력을 보존한 뒤 안전한 reload 또는 재인증을 유도한다.
- offline에서는 오래된 데이터임을 표시하고 민감 mutation을 비활성화한다.
- 로그아웃·계정 전환 후 이전 가족 데이터가 browser storage·memory·back-forward cache에 보이지 않아야 한다.

### 13.5 추가 E2E UX

- E2E-W01: desktop browser에서 가구 생성→초대→집안일 완료
- E2E-W02: invite URL direct load→로그인→가입→mobile에서 확인
- E2E-W03: keyboard-only Today→집안일 생성/완료
- E2E-W04: browser refresh/back/session expiry 복구
- E2E-W05: unsupported notification/billing fallback
- E2E-W06: Web Companion 새 배포 감지→호환성 확인→session 유지 또는 안전한 재인증

## 14. Flutter adaptive UX

- compact: bottom NavigationBar, single-pane task flow
- medium/tablet: NavigationRail 또는 wider bottom navigation, optional supporting pane
- expanded Web/Desktop: persistent rail/sidebar와 master-detail
- 플랫폼별 control adaptation은 허용하되 정보 구조와 상태 의미는 동일하다.
- iOS에서 Android UI를 모방하거나 반대로 강제하지 않는다.
- 키보드, 마우스, touch, screen reader를 입력 capability로 분리한다.


---

# 06. 기능 요구사항 상세

상태는 구현 시 traceability matrix와 함께 갱신한다. 모든 `MUST` 요구사항은 Store MVP 출시 Gate이고 `P1`은 Store MVP 비범위다.

## 1. 인증 (`FR-AUTH`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-AUTH-001 | MUST | 이메일 OTP 가입/로그인 | 만료·재사용·rate limit·잘못된 코드 구분, 로그에 코드 없음 |
| FR-AUTH-002 | MUST | iOS Sign in with Apple | nonce/state 검증, relay email 변경/삭제 이벤트 처리 경로 |
| FR-AUTH-003 | MUST | Android Google 로그인 | token audience/issuer 검증, 취소/실패 fallback |
| FR-AUTH-004 | MUST | 세션 복원·refresh | 만료·revoke 시 안전한 로그아웃, deep link intent 보존 |
| FR-AUTH-005 | MUST | 로그아웃 | device token 연결 해제, local sensitive cache 정리 |
| FR-AUTH-006 | MUST | 최근 인증 | 계정 삭제·소유권·결제 가구 이전에 re-auth |
| FR-AUTH-007 | MUST | identity 중복 방지/연결 정책 | 동일 검증 이메일의 자동 병합 금지, 사용자 확인 및 복구 경로 |
| FR-AUTH-008 | MUST | 계정 삭제 요청 | 앱 내 경로, 상태 추적, 세션 무효화, 웹 요청 경로 |
| FR-AUTH-009 | SHOULD | 로그인 공급자 추가/제거 | 최소 한 개 복구 가능한 identity 유지 |

## 2. 가구와 초대 (`FR-HH`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-HH-001 | MUST | 가구 생성 | Owner membership과 가구가 단일 transaction으로 생성 |
| FR-HH-002 | MUST | 기본 시간대 | 유효 IANA zone만 허용, 변경 영향 설명 |
| FR-HH-003 | MUST | 고엔트로피 초대 링크 | 원문 token DB 저장 금지, hash·expiry·max uses·revoke |
| FR-HH-004 | MUST | 짧은 초대 코드(선택) | rate limit, lockout, generic error, 링크보다 짧은 만료 |
| FR-HH-005 | MUST | 초대 미리보기·수락 | 로그인 전 최소 정보, 수락은 transaction/idempotent |
| FR-HH-006 | MUST | 구성원 역할 변경 | Owner/Admin만, 마지막 Owner 제거 금지, audit |
| FR-HH-007 | MUST | 구성원 제거/나가기 | 향후 assignment 처리 정책, token/device 접근 즉시 차단 |
| FR-HH-008 | MUST | 소유권 이전 | 최근 인증, 새 Owner 확인, atomic transfer |
| FR-HH-009 | MUST | 가구 삭제 | Owner 전용, 영향 확인, background deletion 상태 |
| FR-HH-010 | SHOULD | 정원 제한 | Free/Plus 한도와 안전한 downgrade 동작 |

## 3. 관리형 자녀 (`FR-CHILD`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-CHILD-001 | P1 | Managed Child 생성 | 최소 display name/avatar만, birthdate 기본 수집 안 함 |
| FR-CHILD-002 | P1 | guardian 연결 | 최소 한 명, 다른 가구 member 연결 불가 |
| FR-CHILD-003 | P1 | active member mode | device별 짧은 수명 context, 화면에 지속 표시 |
| FR-CHILD-004 | P1 | 자녀 action allowlist | 자기 항목 보기/완료 외 민감 mutation 서버 거부 |
| FR-CHILD-005 | P1 | 보호자 gate | 설정·결제·초대·삭제 접근 차단, high-risk re-auth |
| FR-CHILD-006 | P1 | approval workflow | 필요 항목은 awaiting approval, guardian 승인/반려 |
| FR-CHILD-007 | P1 | audit actor 구분 | authenticated user와 acting managed member 모두 기록 |
| FR-CHILD-008 | P1 | 자녀 삭제·익명화 | 공유 이력 무결성과 개인정보 최소화 균형 |

## 4. 집안일 (`FR-CHORE`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-CHORE-001 | MUST | 단건 생성/조회/수정/삭제 | 제목, 담당, due, notes, approval; 권한/validation |
| FR-CHORE-002 | MUST | 여러 담당자 또는 단일 담당 정책 | 현재 기본 단일 primary assignee; unassigned 허용 여부 명시 |
| FR-CHORE-003 | MUST | 상태 전이 | open→completed/awaiting_approval→approved/reopened 규칙 |
| FR-CHORE-004 | MUST | 완료·되돌리기 | 멱등 mutation, completed_by/at, 권한과 audit |
| FR-CHORE-005 | MUST | 반복 series | daily/weekly/monthly subset, local time semantics |
| FR-CHORE-006 | MUST | occurrence 생성 | horizon job, unique series+occurrence key, 재실행 안전 |
| FR-CHORE-007 | MUST | 한 회차 예외 | skip/reschedule/reassign가 시리즈 원본을 오염시키지 않음 |
| FR-CHORE-008 | MUST | 전체 시리즈 변경 | 미래 미완료 회차 재생성, 과거 완료 이력 유지 |
| FR-CHORE-009 | MUST | 목록/필터 | Today/upcoming/overdue/completed, assignee filter |
| FR-CHORE-010 | SHOULD | template | 초기 template는 앱 내 정적/서버 seed, 개인정보 없음 |

## 5. 일정 (`FR-CAL`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-CAL-001 | MUST | timed event CRUD | start<end, UTC instant+IANA timezone |
| FR-CAL-002 | MUST | all-day event | local date, exclusive end date, timezone 이동 안정 |
| FR-CAL-003 | MUST | 참석/대상 구성원 | 같은 가구 member만, child visibility 정책 |
| FR-CAL-004 | MUST | 기본 반복 | daily/weekly/monthly, DST 현지 시각 보존 |
| FR-CAL-005 | MUST | occurrence/exception | 이번 회차 수정·취소, unique key |
| FR-CAL-006 | MUST | 전체 series 수정 | 과거 이력 보존, 미래 materialization 갱신 |
| FR-CAL-007 | MUST | agenda/calendar 조회 | locale week start, pagination, loading/empty/error |
| FR-CAL-008 | SHOULD | 충돌 표시 | 같은 구성원의 overlap 힌트, 저장 차단은 아님 |

## 6. Today (`FR-TODAY`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-TODAY-001 | MUST | chores+events 통합 | 사용자 local day 경계로 한 응답/조합, 안정 정렬 |
| FR-TODAY-002 | MUST | Everyone/Me filter | 권한 확장 없음, managed child는 자기 범위 |
| FR-TODAY-003 | MUST | quick complete | 낙관적 UI 후 서버 결과 조정, 중복 탭 안전 |
| FR-TODAY-004 | MUST | stale/offline 표시 | 마지막 성공 sync와 수행 불가 action 설명 |
| FR-TODAY-005 | MUST | partial failure | 일정 실패가 chore 목록 전체를 숨기지 않음 |

## 7. 알림 (`FR-NOTIF`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-NOTIF-001 | MUST | permission education | system prompt 전 설명, 거절 후 settings 경로 |
| FR-NOTIF-002 | MUST | device token lifecycle | 사용자/기기/environment 연결, logout/revoke cleanup |
| FR-NOTIF-003 | MUST | due/event reminder | intent 생성과 send 분리, latest state 확인 |
| FR-NOTIF-004 | MUST | quiet hours/timezone | 사용자 local 규칙, DST·여행 시 재평가 |
| FR-NOTIF-005 | MUST | deep link | 로그인/가구/권한 검증 후 안전한 destination |
| FR-NOTIF-006 | MUST | 중복 방지 | idempotency key, provider receipt, retry cap |
| FR-NOTIF-007 | SHOULD | 알림 category 설정 | assignment/due/event/approval 별 opt-in |

## 8. 구독 (`FR-SUB`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-SUB-001 | MUST | offerings/paywall | store 반환 가격·기간 사용, 하드코딩 금지 |
| FR-SUB-002 | MUST | 구매 | RevenueCat user ID=로그인 사용자 ID, pending/failed 처리 |
| FR-SUB-003 | MUST | restore | restore behavior와 계정 충돌 설명, sandbox 테스트 |
| FR-SUB-004 | MUST | webhook ingest | authorization, environment, event id 멱등, raw event 안전 보관 |
| FR-SUB-005 | MUST | household entitlement | 서버가 purchaser→한 paid household 연결, 만료 계산 |
| FR-SUB-006 | MUST | renewal/cancel/billing issue/expiration | 상태별 grace와 UI, 데이터 미삭제 |
| FR-SUB-007 | MUST | transfer/leave policy | cooldown, Owner/billing owner 관계, support override audit |
| FR-SUB-008 | MUST | manage subscription | 플랫폼별 관리 화면 deep link와 안내 |
| FR-SUB-009 | MUST | server reconciliation | webhook 누락/순서 역전 시 공급자 API 재조회 가능 |
| FR-SUB-010 | OPEN | Apple Family Sharing | SKU 생성 전 결정과 별도 테스트 |

## 9. 설정·개인정보 (`FR-SET`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-SET-001 | MUST | 프로필 | display name/avatar, 최소 정보 |
| FR-SET-002 | MUST | 언어·시간대 | 즉시 반영, 반복 semantics 경고 |
| FR-SET-003 | MUST | 데이터 export | machine-readable+human-readable, 보안 다운로드 만료 |
| FR-SET-004 | MUST | 계정 삭제 | 앱·웹 경로, 상태/보관 예외, 토큰 revoke |
| FR-SET-005 | MUST | 개인정보/약관/지원 | 앱 내 접근, 버전·동의 기록 필요 시 저장 |
| FR-SET-006 | MUST | 구독 상태 | 어느 가구에 적용, 갱신/만료, 복원/관리 |
| FR-SET-007 | SHOULD | 진단 정보 복사 | PII 없이 app/build/device/environment/incident ID |

## 10. 플랫폼 (`FR-PLAT`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-PLAT-001 | MUST | 영어·한국어 | missing key test, pseudo locale, locale date/plural |
| FR-PLAT-002 | MUST | 접근성 | screen reader, dynamic type, touch target, contrast, reduced motion |
| FR-PLAT-003 | MUST | analytics governance | event allowlist, child mode disable, SDK inventory |
| FR-PLAT-004 | MUST | feature flags | remote server-authoritative flags, safe defaults |
| FR-PLAT-005 | MUST | app update compatibility | 최소 지원 version/forced update는 emergency만 |
| FR-PLAT-006 | MUST | legal/store disclosures | 실제 SDK·수집·삭제 흐름과 일치 |

## 11. 공통 오류 계약

모든 사용자 노출 오류는 다음 분류를 가진다.

- `VALIDATION_ERROR`
- `AUTH_REQUIRED` / `RECENT_AUTH_REQUIRED`
- `PERMISSION_DENIED`
- `HOUSEHOLD_MISMATCH`
- `INVITE_EXPIRED` / `INVITE_REVOKED` / `INVITE_LIMIT_REACHED`
- `CONFLICT` / `STALE_VERSION`
- `OFFLINE_REQUIRED`
- `PLAN_LIMIT_REACHED`
- `BILLING_PENDING` / `ENTITLEMENT_CONFLICT`
- `RATE_LIMITED`
- `PROVIDER_UNAVAILABLE`
- `UNKNOWN`

사용자 문구와 내부 코드/incident ID를 분리하고, 민감한 존재 여부를 outsider에게 노출하지 않는다.

## 12. v1.0 Universal App 추가 요구사항

| ID | 우선순위 | 요구사항 | 수용 기준 |
|---|:---:|---|---|
| FR-AUTH-010 | MUST | Web OTP/OAuth PKCE callback | HTTPS, redirect allowlist, state/PKCE 검증, callback 후 민감 URL 제거 |
| FR-AUTH-011 | MUST | Web session·cache 수명주기 | logout/account switch/removed member에서 query·browser·SW 사용자 cache 삭제 |
| FR-NOTIF-008 | MUST | Web 인앱 알림 및 fallback | Web Push 없이도 중요한 intent를 inbox와 설정된 email로 확인 |
| FR-NOTIF-009 | SHOULD | Web Push provider | secure context, permission, subscribe/rotate/unsubscribe, click allowlist, dedupe |
| FR-SUB-011 | MUST | Cross-platform entitlement 표시 | 모바일 구매가 Web에, Web 구매가 모바일에 서버 검증 후 동일하게 반영 |
| FR-SUB-012 | SHOULD | Web purchase provider | D-039 승인 후 가격·세금·환불·계정 연결을 명시하고 server entitlement 생성 |
| FR-SET-008 | MUST | Web Companion 세션·알림 설정 | 알림 capability, 캐시/로그아웃 설명, 공개 privacy 링크 제공 |
| FR-PLAT-007 | MUST | Flutter native mobile build | 동일 저장소에서 iOS IPA·Android AAB production build 성공; Web은 후속 Gate |
| FR-PLAT-008 | MUST | Capability registry | 알림·결제·저장소·링크·background의 지원 상태와 provider 선택을 중앙 관리 |
| FR-PLAT-009 | MUST | Responsive layout | compact·medium·expanded에서 핵심 task가 잘림 없이 완료 |
| FR-PLAT-010 | MUST | Keyboard와 focus | Web 핵심 task keyboard-only, visible focus, dialog focus return |
| FR-PLAT-011 | MUST | Direct URL과 route recovery | direct load, refresh, back/forward, 404/forbidden/session expiry 처리 |
| FR-PLAT-012 | MUST | Web Companion safe deployment | immutable asset, API compatibility, 새 배포 감지, session recovery, rollback evidence |
| FR-PLAT-013 | MUST | Safe cache scope | 초기 Web은 broad API persistent cache 금지, logout/account switch purge |
| FR-PLAT-014 | MUST | Platform fallback | unsupported capability가 조용히 실패하지 않고 이유·대안 표시 |
| FR-PLAT-015 | MUST | Cross-platform contract parity | occurrence, timezone, role, entitlement 결과가 플랫폼 간 동일 |
| FR-PLAT-016 | MUST | Independent release gates | Mobile Store, Web Companion Beta, Desktop Review의 범위·증거·승인을 별도 관리 |

## 13. Flutter 구현 요구사항

| ID | 우선순위 | 요구사항 | 수용 기준 |
|---|:---:|---|---|
| FR-FLT-001 | MUST | Flutter/Dart baseline | Flutter SDK 3.44.7 exact, analyzer warning 0, lockfile 고정 |
| FR-FLT-002 | MUST | Flavor 분리 | dev/staging/prod app ID, Firebase, Supabase, RevenueCat key가 혼합되지 않음 |
| FR-FLT-003 | MUST | Layer boundary | domain에서 Flutter/Riverpod/Supabase import 0 |
| FR-FLT-004 | MUST | Riverpod ownership | 서버·UI 상태 owner가 명시되고 duplicate state 없음 |
| FR-FLT-005 | MUST | Generated code integrity | build_runner 재생성 후 git diff 0 |
| FR-FLT-006 | MUST | Native deep link | iOS Universal Links, Android App Links, auth/invite cold start E2E |
| FR-FLT-007 | MUST | Native notification | denied/authorized/token rotation/foreground/background/terminated E2E |
| FR-FLT-008 | MUST | Native billing | purchase/restore/refund/expiry/account switch sandbox matrix |
| FR-FLT-009 | MUST | Adaptive tablet | landscape, split screen, large text에서 핵심 task 완료 |
| FR-FLT-010 | MUST | Store build | signed staging IPA/AAB를 실제 기기에 설치하고 smoke 검증 |


---

# 07. 도메인 규칙과 상태 머신

## 1. 핵심 불변조건

### 가구

- 한 가구에는 정확히 한 명의 Owner가 있다.
- Owner는 활성·인증된 성인 member여야 한다.
- 가구 생성과 Owner membership 생성은 atomic하다.
- 마지막 Owner는 삭제·탈퇴·강등될 수 없다.
- 모든 가구 종속 참조는 같은 `household_id`에 속해야 한다.

### 구성원

- 성인 member는 `user_id`를 가질 수 있고 Managed Child는 가져서는 안 된다.
- 동일 user가 동일 household에 중복 active membership을 가질 수 없다.
- Store MVP에서 한 user의 active household는 최대 하나다.
- 제거된 member의 과거 활동은 actor snapshot 또는 anonymized member ID로 보존한다.

### 자녀/보호자

- Managed Child는 최소 한 명의 active adult guardian을 가진다.
- guardian과 child는 같은 household여야 한다.
- child mode action은 authenticated adult session과 acting child 모두를 요구한다.
- child는 role, invitation, billing, privacy, export/delete mutation을 실행할 수 없다.

### 구독

- 한 활성 purchase owner는 기본적으로 한 paid household만 가진다.
- 한 household의 effective plan은 유효한 server entitlement record로 계산한다.
- 클라이언트 SDK 상태는 힌트이며 권한의 최종 근거가 아니다.
- 동일 provider event는 한 번만 효과를 발생시킨다.

## 2. 역할 권한 매트릭스

| Action | Owner | Admin | Member | Managed Child |
|---|:---:|:---:|:---:|:---:|
| 가구 보기 | ✓ | ✓ | ✓ | 제한 |
| 가구 이름/시간대 수정 | ✓ | ✓ | — | — |
| 초대 생성/회수 | ✓ | ✓ | — | — |
| 역할 변경 | ✓ | 제한 | — | — |
| Owner 이전 | ✓ | — | — | — |
| 구성원 제거 | ✓ | ✓* | — | — |
| 가구 삭제 | ✓ | — | — | — |
| Managed Child 생성/수정 | ✓ | ✓ | — | — |
| 집안일 생성 | ✓ | ✓ | ✓ | — |
| 모든 집안일 수정/삭제 | ✓ | ✓ | 제한 | — |
| 자기 배정 완료 | ✓ | ✓ | ✓ | ✓ |
| 자녀 완료 승인 | guardian | guardian | guardian만 | — |
| 일정 생성 | ✓ | ✓ | ✓ | — |
| 구독 구매/가구 연결 | ✓/성인 | 성인** | 성인** | — |
| export/계정 삭제 | 자기 계정 | 자기 계정 | 자기 계정 | 보호자 |

`*` Admin은 Owner나 자신보다 높은 권한을 제거할 수 없다.  
`**` 실제 정책은 billing household 선택과 Owner 승인 Gate에 따른다.

## 3. Membership 상태

```text
invited → active → left
             ├── removed
             └── suspended (운영/보안 예외)
```

- `invited`는 membership이 아니라 invitation으로 구현하는 것을 권장한다.
- `removed/left` 이후 access token이 남아 있어도 RLS가 즉시 접근을 거부한다.
- 재가입은 새 membership 또는 명시적 복구 정책을 사용하며 과거 role을 자동 복원하지 않는다.

## 4. 초대 상태

```text
created → opened → accepted
   ├── expired
   ├── revoked
   └── exhausted
```

규칙:

- 원문 token은 생성 응답에서 한 번만 제공하고 DB에는 hash만 저장한다.
- acceptance는 token lock/검증/membership 생성/use_count 증가를 transaction으로 수행한다.
- 동일 사용자의 재시도는 같은 결과를 반환하는 멱등성을 가진다.
- outsider에게 가구 존재·구성원 이메일을 과도하게 노출하지 않는다.

## 5. Chore occurrence 상태

```text
open ───────────────► completed ─────► reopened
 │                         │
 │ approval_required       │ adult undo
 ▼                         ▼
awaiting_approval ─► approved ───────► reopened
        └──────────► rejected ───────► open
```

### 전이 규칙

- `open→completed`: 담당 성인 또는 권한 있는 관리자.
- `open→awaiting_approval`: Managed Child가 approval-required item 완료.
- `awaiting_approval→approved/rejected`: 연결 guardian 또는 권한 있는 성인.
- 모든 전이는 version/updated_at 기반 stale-write 방지와 idempotency key를 사용한다.
- 완료 이력은 series 수정으로 삭제하지 않는다.

## 6. 일정 상태

- 일정 series는 `active`, `cancelled`, `archived` 상태를 가진다.
- occurrence는 generated 기본값과 exception overlay로 계산한다.
- 한 회차 취소는 series 삭제가 아니라 exception이다.
- 전체 series 삭제는 미래 occurrence를 취소하되 과거 감사/알림 기록 보관 정책을 따른다.

## 7. 반복 시간 의미

### Timed event

저장 요소:

- recurrence timezone: IANA zone
- local start time/date pattern
- duration 또는 local end rule
- canonical UTC instant per occurrence

예: “매주 월요일 오전 8시 서울”은 DST가 있는 지역으로 이동해도 원래 recurrence timezone의 오전 8시 기준인지, household timezone을 따라갈지 명시한다. 기본은 **series 생성 시 timezone에 고정**이다.

### All-day

- `start_date` 포함, `end_date_exclusive` 제외 규칙
- UTC 자정으로 변환해 저장하지 않는다.
- 사용자가 다른 시간대로 여행해도 날짜가 바뀌지 않는다.

### 월간

“매월 31일” 기본 정책:

- 31일이 없는 달은 그 달을 skip한다.
- “마지막 날”은 별도 규칙이다.
- 임의로 30일/28일로 당기지 않는다.

### Series 수정

- 이번 회차: exception만 생성/수정
- 전체 시리즈: 과거 완료/발생 이력은 유지, 변경 시점 이후 미래 회차 재계산
- 이번 이후: Store MVP 제외

## 8. Materialization

- 가까운 과거 일부와 미래 horizon을 occurrence table에 생성한다.
- job 재실행은 `(series_id, recurrence_id)` unique key로 중복을 막는다.
- series 변경 시 미래 미완료 occurrence를 안전하게 invalidate/rebuild한다.
- notification intent는 occurrence가 확정된 뒤 생성한다.
- horizon 끝에 다가오기 전에 background job이 연장한다.

## 9. 구독 상태 머신

```text
none → trialing/active → grace/billing_issue → active
                  ├── cancelled_but_active → expired
                  ├── refunded/revoked → inactive
                  └── transferred → source inactive / destination reconciled
```

`cancelled`는 즉시 만료가 아니라 현재 기간 종료일까지 active일 수 있다. Provider event 순서가 뒤바뀔 수 있으므로 event timestamp만으로 단순 덮어쓰지 않고 provider 상태를 재조회할 수 있어야 한다.

### Household entitlement 상태

- `free`
- `plus_active`
- `plus_grace`
- `plus_expired_over_limit`
- `plus_suspended`(fraud/support/manual)

effective plan 계산에는 provider entitlement, product mapping, environment, expiration, manual override의 우선순위를 명시한다.

## 10. 삭제 상태 머신

```text
requested → cooling_off(optional) → processing → completed
                                  └→ blocked_by_retention → completed_later
requested → cancelled (허용 기간 내)
processing → failed_retryable / manual_review
```

- 요청 즉시 새 세션 발급을 막거나 위험 action을 제한한다.
- 완료 시 auth token, refresh token, device token, invite token을 revoke한다.
- 세금·결제·보안상 보관해야 하는 데이터는 목적·기간·접근을 분리하고 앱 데이터와 unlink한다.
- 가구 삭제와 사용자 삭제는 서로 다른 workflow다.

## 11. 동시성·멱등성

- 생성 mutation은 client-generated id 또는 idempotency key를 지원한다.
- update에는 version 또는 `updated_at` precondition을 사용한다.
- 완료 버튼 연타, webhook duplicate, job retry가 중복 side effect를 만들지 않는다.
- conflict 시 자동 last-write-wins로 숨기지 않고 사용자에게 최신 상태를 보여준다.

## 12. 감사 이벤트

민감 action:

- role/owner 변경
- invite 생성·회수·수락
- managed child 생성·guardian 변경·child action
- subscription household link/transfer/manual override
- export/delete 요청과 완료
- notification consent/token 변경

감사 레코드는 actor user, acting member, household, action, target type/id, request/incident ID, timestamp, 결과를 가지며 제목·설명 등 콘텐츠는 넣지 않는다.

## 13. 플랫폼 불변조건

1. `platform`은 권한 근거가 아니다. 같은 인증자·가구·역할은 모바일과 웹에서 같은 서버 권한을 가진다.
2. capability availability와 product entitlement를 구분한다. 예를 들어 Web Push 미지원과 Plus 미가입은 다른 상태다.
3. occurrence ID, due date, all-day date, timezone 의미는 모든 클라이언트에서 동일하다.
4. client-local completion은 서버 version/idempotency 검증 전 확정 상태가 아니다.
5. 알림 intent는 provider 독립이고 delivery endpoint만 플랫폼별이다.
6. 구매 provider는 entitlement의 source가 아니라 검증 이벤트 source다. 실제 기능 권한은 서버 household entitlement다.
7. logout, auth user 변경, household 제거는 모든 플랫폼에서 사용자 범위 cache와 pending mutation을 폐기한다.
8. unsupported capability 전이는 사용자에게 보이는 상태로 모델링한다.
9. 모바일 앱 또는 Web Companion의 contract version이 서버 최소 호환 범위를 벗어나면 mutation을 안전하게 차단하고 업데이트 또는 reload를 안내한다.
10. 플랫폼별 presentation 차이가 audit actor, domain event, role transition을 바꾸지 않는다.

## 17. 클라이언트 런타임 독립 규칙

도메인 상태 전이는 Dart sealed type 또는 pure function으로 표현하되 Flutter Widget, Riverpod Provider, Supabase DTO와 독립적이어야 한다. 같은 invariant를 Edge Function과 DB constraint/RLS가 다시 보호한다. 클라이언트 domain test는 사용자 편의를 검증하며 서버 권한 검증을 대체하지 않는다.


---

# KinFlow Flutter 앱 구현 스펙 v1.0

- 기준일: 2026-07-21
- 계약 버전: 2026-07-21
- 상태: ACCEPTED IMPLEMENTATION BASELINE
- 사용법: 한 파일만 제공 가능한 코딩 에이전트용


---

# KinFlow 제품·아키텍처 결정 v1.0

상태: `ACCEPTED`, `PROVISIONAL`, `OPEN`, `DEFERRED`.

| ID | 상태 | 결정 | 이유·영향 | 재검토 Gate |
|---|---|---|---|---|
| D-001 | ACCEPTED | 클라이언트는 Flutter SDK 3.44.7 stable + Dart SDK 3.12.2 Native-first 구조다. | iOS·Android 품질과 향후 desktop 확장을 한 코드베이스로 준비한다. | Flutter가 핵심 요구를 차단할 때 |
| D-002 | ACCEPTED | Store MVP 공식 플랫폼은 iOS/iPadOS/Android다. | 설치·푸시·구독·재방문이 제품 핵심이다. | 지속 |
| D-003 | ACCEPTED | Web은 PWA 주력 채널이 아니라 모바일 출시 후 Web Companion으로 제공한다. | PWA 설치 전환을 핵심 가설로 두지 않는다. | G9 |
| D-004 | DEFERRED | Windows/macOS/Linux native는 수요 Gate 후 Flutter Desktop으로 검토한다. | 초기 QA와 release surface를 제한한다. | G10 |
| D-005 | ACCEPTED | 공개 제품·약관·삭제·지원 사이트는 Flutter Web이 아니라 Astro 정적 사이트다. | SEO, 접근성, 로딩, 정책 페이지 운영에 유리하다. | 사이트가 동적 제품으로 커질 때 |
| D-006 | ACCEPTED | 상태·DI는 Riverpod, 라우팅은 go_router다. | 테스트 가능한 의존성 경계와 딥링크를 표준화한다. | major upgrade ADR |
| D-007 | ACCEPTED | 모델은 Freezed/json_serializable을 사용하고 generated code drift를 CI에서 검사한다. | 외부 계약 파싱과 immutable state를 일관화한다. | 코드 생성 비용이 장애일 때 |
| D-008 | ACCEPTED | Supabase Auth/PostgreSQL/RLS/Edge Functions를 유지한다. | 기존 관계형 권한·반복·구독 모델을 보존한다. | 규모·법률·가용성 요구 변화 |
| D-009 | ACCEPTED | Edge Functions는 TypeScript/Deno로 유지한다. | 결제 웹훅·작업 큐·관리 API 생태계와 기존 계약을 보존한다. | 서버 플랫폼 교체 시 |
| D-010 | ACCEPTED | 장기 역할 모델은 Owner, Admin, Member, Managed Child다. Store MVP 활성 역할은 D-013을 따르고 Guest는 P1 이후다. | 범위 기반 권한 복잡도를 줄이면서 후속 역할 계약을 보존한다. | P1 |
| D-011 | ACCEPTED | Managed Child는 독립 로그인하지 않는다. | 아동 동의·복구·추적 위험을 줄인다. | 독립 기기 수요 검증 후 |
| D-012 | ACCEPTED | 공유 기기 child mode는 보호자 PIN과 server acting context를 사용한다. | 자녀가 결제·초대·삭제에 접근하지 못하게 한다. | 지속 |
| D-013 | ACCEPTED | Store MVP 계정 사용자는 성인으로 한정하고 Kids Category를 선택하지 않는다. Managed Child와 child mode는 P1로 연기하며 H-05와 법률·Store 검토 후 재승인한다. | 초기 개인정보·정책·권한 surface를 줄이고 성인 2인 가설을 우선 검증한다. | P1 scope Gate / 각 Store RC |
| D-014 | ACCEPTED | 위치·연락처·광고 SDK를 Store MVP에서 사용하지 않는다. | 데이터 최소화와 자녀 안전. | 새 기능 DPIA |
| D-015 | ACCEPTED | 초대는 고엔트로피 링크 토큰, 짧은 코드는 보조다. | 추측·재사용 공격 방지. | 지속 |
| D-016 | PROVISIONAL | 한 사용자 UI는 한 개 활성 household를 우선 지원한다. DB는 다중 가구를 허용한다. | Today·구독·초대 복잡도 감소. | Beta |
| D-017 | ACCEPTED | 오프라인은 read cache 우선이며 역할·초대·삭제·결제·시리즈 수정은 온라인 전용이다. | 보안·충돌 비용을 제한한다. | Phase 05 |
| D-018 | PROVISIONAL | chore 완료만 제한적 outbox 후보로 둔다. | 핵심 행동의 네트워크 내성. | Phase 05 Gate |
| D-019 | ACCEPTED | 반복 정의와 materialized occurrence를 분리한다. | Today·알림·예외·이력 보존. | 지속 |
| D-020 | ACCEPTED | 반복 수정은 Store MVP에서 이번 회차/전체 시리즈만 지원한다. | 시리즈 분할 복잡도 제한. | P1 |
| D-021 | ACCEPTED | 모바일 push는 FCM/APNs, 로컬 표시는 flutter_local_notifications를 사용한다. | iOS·Android 공통 서버 발송 경로. | 공급자 장애/비용 변화 |
| D-022 | ACCEPTED | 서버 scheduled job과 notification_outbox가 알림의 권위자다. | 앱 종료·절전 상태에서도 일관된 발송. | 지속 |
| D-023 | ACCEPTED | 백그라운드 앱 작업은 opportunistic refresh만 수행하며 알림 정확성에 의존하지 않는다. | OS 제한 회피. | 지속 |
| D-024 | ACCEPTED | RevenueCat App User ID는 auth user ID이며 household ID가 아니다. | 구매 복원·계정 수명주기 분리. | 지속 |
| D-025 | ACCEPTED | Plus 권한은 서버 household entitlement가 최종 결정한다. | 구매자와 가족 혜택을 분리한다. | 지속 |
| D-026 | PROVISIONAL | Apple Family Sharing은 초기 SKU에서 비활성화한다. | 앱 내부 household 공유와 중복 가능. | SKU 생성 전 |
| D-027 | OPEN | 가격, Free 한도, 체험, 연간 할인율을 확정한다. | Phase 06 차단. | Phase 06 시작 전 |
| D-028 | ACCEPTED | 구독 만료 시 공동 데이터는 보존하고 프리미엄 신규 생성만 제한한다. | 데이터 인질화 방지. | 가격 정책 확정 후 |
| D-029 | ACCEPTED | GitHub Actions가 CI, Fastlane이 store delivery 기준이다. | 투명하고 vendor-neutral한 pipeline. | 운영 부담이 임계값 초과 시 |
| D-030 | ACCEPTED | MVP는 런타임 코드 패치/OTA 도구를 사용하지 않는다. | Store 정책·native 호환·rollback 위험 감소. | 안정화 후 별도 ADR |
| D-031 | ACCEPTED | 긴급 차단은 서버 feature flag/kill switch로 수행한다. | 앱 심사 없이 위험 기능을 끈다. | 지속 |
| D-032 | ACCEPTED | environment는 dev/staging/prod flavor와 별도 app identifier를 사용한다. | 데이터·결제·푸시 혼선 방지. | 지속 |
| D-033 | ACCEPTED | 공개 설정만 `--dart-define-from-file`에 넣고 서버 비밀은 Supabase/GitHub secret에 둔다. | 앱 bundle 비밀 노출 방지. | 지속 |
| D-034 | ACCEPTED | Sentry를 오류 추적에 사용하되 PII allowlist/redaction을 강제한다. | 운영 가시성과 개인정보 균형. | SDK privacy review |
| D-035 | PROVISIONAL | Managed Child mode에서는 외부 analytics를 비활성화한다. | 아동 행동의 제3자 전송 최소화. | 법률 검토 |
| D-036 | ACCEPTED | 영어·한국어 동시 출시, pseudo locale와 RTL 구조 검증을 수행한다. | 글로벌 확장 기반. | 추가 언어 전 |
| D-037 | ACCEPTED | iOS/iPadOS 최소 16.0, Android 최소 API 24, target API 36을 기준으로 한다. | 2026 Store 요건과 유지보수 균형. | 각 RC |
| D-038 | ACCEPTED | iOS 제출은 Xcode 26+/iOS 26 SDK 기준으로 검증한다. | 2026 App Store 제출 요건 대응. | 각 RC |
| D-039 | ACCEPTED | 최초 공개 출시는 대한민국 단일 시장으로 하고 Supabase production region은 Seoul `ap-northeast-2`로 한다. | 초기 고객에 가까운 리전을 사용하고 운영·법률 범위를 한 시장으로 제한한다. | 두 번째 국가 추가 전 |
| D-040 | ACCEPTED | 계정 삭제는 앱 내 시작과 공개 웹 요청 경로를 모두 제공한다. | Store 제출과 접근성. | 지속 |
| D-041 | ACCEPTED | 계정 삭제와 household 삭제를 분리한다. | 공동 데이터 오삭제 방지. | 지속 |
| D-042 | ACCEPTED | DB migration은 forward-only expand/contract이며 구버전 앱 호환 기간을 둔다. | 모바일 업데이트 지연 대응. | 지속 |
| D-043 | ACCEPTED | Flutter Web Companion은 broad offline cache를 사용하지 않는다. | 공유 PC 잔존 데이터 위험 감소. | G9 |
| D-044 | ACCEPTED | Web Push와 Web 결제는 Web Companion Beta의 필수 조건이 아니다. | 모바일 출시와 웹 보조 기능을 분리. | G10 이후 별도 Gate |
| D-045 | PROVISIONAL | 지속 로컬 cache가 필요하면 Drift를 우선 평가한다. 도입 전 threat model이 필요하다. | native/web 확장성과 purge 제어. | Phase 05 |
| D-046 | ACCEPTED | calendar UI package는 현재 유지보수·접근성 검토를 통과한 경우에만 채택한다. domain recurrence는 package에 의존하지 않는다. | UI package lock-in 방지. | Phase 04 |
| D-047 | ACCEPTED | domain/application은 Flutter와 Riverpod에 독립적이다. | testability와 desktop/web 확장성. | 지속 |
| D-048 | ACCEPTED | 모든 mutation은 optimistic version 또는 idempotency key를 사용한다. | 중복·동시 수정 안전성. | 지속 |
| D-049 | ACCEPTED | 사용자·가구 전환 시 local state, cache, FCM token binding, RevenueCat identity를 재조정한다. | 교차 계정 데이터 노출 방지. | 지속 |
| D-050 | DEFERRED | 위젯, Apple Watch, Wear OS는 Store MVP 이후 quick action 범위로 검토한다. | 핵심 앱 출시 집중. | P1/P2 |
| D-051 | ACCEPTED | 첫 제품 검증과 구현 vertical slice는 성인 2인의 가구 생성·초대 수락·집안일 3개 생성·서로 1개 이상 완료·다음 날 Today 재방문으로 제한한다. | 가족 제품의 선행 가설인 두 번째 성인의 독립 참여를 가장 작은 비용으로 검증한다. | H-01~H-03 결과 review |


---

# KinFlow 앱 구현 스펙 기준선 v1.0 — Flutter SDK 3.44.7

- 상태: `ACCEPTED — IMPLEMENTATION BASELINE`
- 기준일: 2026-07-21
- 변경 방식: ADR + 영향 분석 + 회귀 검증 계획

## 1. 기준선 우선순위

1. `DECISIONS.md`의 ACCEPTED 결정
2. 이 문서
3. `contracts/`의 기계 판독 계약
4. `docs/20_*`~`docs/30_*` 구현 스펙
5. 제품·도메인 문서
6. Phase 계획

OPEN 결정은 구현자가 임의로 확정하지 않는다. 해당 기능은 안전한 기본값, feature flag 또는 미구현 adapter로 남긴다.

## 2. 확정 기술 기준

| 영역 | 기준 |
|---|---|
| Flutter SDK | 3.44.7 stable exact pin |
| Dart SDK | Flutter SDK 3.44.7에 포함된 Dart SDK 3.12.2, 독립 업그레이드 금지 |
| 앱 언어 | Dart sound null safety |
| 모바일 | iOS/iPadOS 16.0+, Android API 24+, target API 36 |
| Web Companion | Chrome/Edge/Firefox 최신 2개 major, Safari 16.4+ |
| 상태·DI | Riverpod 3 stable 계열 |
| 라우팅 | go_router stable 계열 |
| 모델·직렬화 | Freezed + json_serializable |
| 백엔드 | Supabase Auth, PostgreSQL, RLS, Edge Functions |
| 서버 함수 언어 | TypeScript/Deno |
| 구독 | RevenueCat Flutter SDK + 서버 household entitlement |
| 원격 알림 | Firebase Cloud Messaging, APNs 연동 |
| 로컬 알림 | flutter_local_notifications |
| 오류 추적 | Sentry Flutter |
| 배포 | GitHub Actions + Fastlane; Web immutable deployment |
| 테스트 | flutter_test, integration_test, Maestro, Playwright, pgTAP |

패키지 patch 버전은 Phase 01에서 최신 안정 호환성을 검증한 뒤 `pubspec.lock`으로 exact 고정한다. Flutter SDK만 독립적으로 자동 업그레이드하지 않는다.

## 3. 플랫폼 전략

### Tier 1: Store MVP

- iPhone 및 iPad
- Android phone 및 tablet
- 성인 가구 생성·초대·집안일·일정·Today·알림·구독·삭제 지원
- Managed Child와 child mode는 P1 계약으로 보존하되 Store MVP에는 구현·노출하지 않음(D-013)

### Tier 2: Web Companion

- 모바일 Store MVP 이후 독립 Beta
- PC에서 Today, 집안일, 일정, 가족 관리
- 설치형 Web Companion를 핵심 KPI로 두지 않음
- 광범위한 offline cache와 Web Push는 별도 Gate

### Deferred: Native desktop

Flutter가 Windows/macOS/Linux를 지원하더라도 첫 출시 범위가 아니다. 월간 데스크톱 사용량, OS 알림, 오프라인, 메뉴바·트레이·키오스크 수요를 측정한 뒤 Phase 10 Gate에서 결정한다.

## 4. 저장소 구조

```text
/
├─ apps/
│  ├─ kinflow_app/              # Flutter: ios/android/web 우선
│  └─ public_site/              # Astro: marketing/legal/delete/support
├─ supabase/
│  ├─ migrations/
│  ├─ functions/
│  ├─ tests/
│  └─ seed.sql
├─ contracts/
├─ docs/
├─ phases/
├─ e2e/
│  ├─ maestro/
│  └─ playwright/
├─ scripts/
└─ evidence/
```

초기 Flutter 앱 내부:

```text
lib/
├─ app/                         # bootstrap, router, theme, localization
├─ core/                        # 공통 error, result, clock, IDs, platform ports
├─ features/
│  └─ <feature>/
│     ├─ domain/
│     ├─ application/
│     ├─ data/
│     └─ presentation/
└─ main_{dev,staging,prod}.dart
```

## 5. 비협상 아키텍처 규칙

1. domain은 Flutter, Riverpod, Supabase, RevenueCat, Firebase를 import하지 않는다.
2. Widget과 Provider는 공급자 SDK를 직접 호출하지 않는다.
3. Riverpod Notifier는 도메인 규칙 저장소가 아니라 use case 조정자다.
4. 외부 JSON은 Freezed/json_serializable DTO로 파싱하고 domain entity로 변환한다.
5. 모든 가구 소유 row는 `household_id`, RLS, 교차 가구 제약을 가진다.
6. 초대 수락·Owner 이전·역할·Managed Child acting·삭제·구독은 RPC/Edge transaction이다.
7. 서버가 membership, role, acting context, entitlement를 재계산한다.
8. 날짜는 UTC instant, local date/time, IANA timezone을 구분한다.
9. 반복 occurrence는 서버가 materialize하며 클라이언트 계산은 preview다.
10. 푸시 알림은 서버 작업 큐가 권위자이며 기기 예약은 보조다.
11. 기능 권한은 RevenueCat client snapshot이 아니라 서버 household entitlement가 최종 근거다.
12. 비밀은 앱 bundle, `--dart-define`, 로그, 분석 이벤트에 포함하지 않는다.
13. 로그아웃·가구 변경·구성원 제거 시 사용자 범위 cache와 provider identity를 제거한다.
14. DB migration은 forward-only expand/contract다.
15. 런타임 코드 패치 도구는 MVP baseline이 아니다.

## 6. Capability ports

- AuthSessionPort
- NotificationPort
- BillingPort
- EntitlementPort
- SecureStoragePort
- DeepLinkPort
- AnalyticsPort
- ErrorReporterPort
- ConnectivityHintPort
- LocalCachePort
- AppVersionPort
- ParentalGatePort

미지원 기능은 성공 no-op이 아니라 `unsupported(reason, fallback)` 결과를 반환한다.

## 7. Flutter 코드 규칙

- `dart format` 결과를 커밋한다.
- analyzer warning 0, `implicit-casts: false`, `strict-casts: true`에 준하는 엄격도.
- `dynamic`과 `!` 사용은 경계 검증 직후 외에는 금지.
- `BuildContext`를 async gap 너머로 보관하지 않는다.
- Widget에 비즈니스 mutation을 작성하지 않는다.
- generated `.g.dart`, `.freezed.dart`는 커밋하고 CI에서 재생성 drift를 검사한다.
- 화면 문자열·날짜 형식·plural은 ARB/gen_l10n을 사용한다.
- 테스트에서 실제 시간·UUID·네트워크를 직접 사용하지 않는다.

## 8. 필수 PR 검증

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter test integration_test -d <configured-device>
dart run build_runner build --delete-conflicting-outputs
supabase db reset
supabase test db
flutter build appbundle --flavor staging
flutter build web --release --dart-define-from-file=config/staging.json
```

모든 PR에서 iOS archive를 만들 필요는 없지만 RC에서는 macOS runner에서 `flutter build ipa`가 필수다.

## 9. 출시 Gate

- G0 Decision Gate
- G1 Foundation Gate
- G2 Household Alpha
- G3 Chores Value
- G4 Calendar Value
- G5 Reliability Gate
- G6 Billing Gate
- G7 Compliance Gate
- G8 Beta Exit / Mobile RC
- G9 Mobile Store Launch
- G10 Web Companion Beta
- G11 Native Desktop Review


---

# 08. 기술 아키텍처

- 상태: ACCEPTED
- 기준일: 2026-07-21
- 목적: Flutter 모바일 앱, 후속 Web Companion, Supabase 백엔드의 경계와 의존 방향을 고정한다.

## 1. 아키텍처 목표

KinFlow 아키텍처는 다음 품질을 우선한다.

1. 가족 간 데이터가 household 경계를 절대 넘지 않는다.
2. iOS와 Android에서 같은 도메인 규칙을 사용한다.
3. 모바일 Store MVP를 Web/Desktop보다 먼저 안정적으로 출시한다.
4. 클라이언트 SDK 교체가 도메인 규칙을 흔들지 않는다.
5. 반복 일정, 역할 변경, 결제처럼 고위험 mutation은 서버 transaction으로 처리한다.
6. 바이브코딩 에이전트가 작은 vertical slice 단위로 구현하고 검증할 수 있다.

## 2. 시스템 컨텍스트

```text
Flutter mobile app ─┐
Flutter Web companion ─┼─ HTTPS/WSS ─ Supabase platform
Public website ────────┘                 ├─ Auth
                                         ├─ PostgreSQL + RLS
                                         ├─ Edge Functions
                                         ├─ Storage
                                         └─ Realtime (선택적)

Apple App Store / Google Play ─ RevenueCat ─ webhook ─ entitlement worker
APNs / FCM ─ notification worker ─ notification inbox/device registrations
Sentry / analytics ─ privacy-filtered operational events
```

## 3. 클라이언트 의존 방향

```text
Presentation (Widget, Router, Provider)
                  ↓
Application (Use case, orchestration, state machine)
                  ↓
Domain (Entity, value object, policy, repository port)
                  ↑
Data/Infrastructure (Supabase, RevenueCat, Firebase, secure storage)
```

금지 규칙:

- `domain/`은 Flutter, Riverpod, Supabase, RevenueCat, Firebase, `dart:html`을 import하지 않는다.
- Widget은 Supabase client나 billing SDK를 직접 호출하지 않는다.
- DTO는 presentation으로 누출하지 않는다.
- Provider는 domain invariant를 새로 정의하지 않고 use case를 조정한다.
- 플랫폼별 구현은 interface/port 뒤에 둔다.

## 4. 주요 bounded context

| Context | 책임 | 주요 Aggregate |
|---|---|---|
| Identity | 로그인, 세션, 계정 상태 | UserAccount, Session |
| Household | 가구, 역할, 초대, 보호자 관리 프로필 | Household, Membership, Invite |
| Chores | 집안일 정의, 발생 회차, 완료·승인 | ChoreSeries, ChoreOccurrence |
| Calendar | 일정, 참석자, 반복·예외 | EventSeries, EventOccurrence |
| Today | 날짜 경계에 따른 통합 읽기 모델 | TodaySnapshot |
| Notifications | 알림 선호, inbox, device token, delivery | NotificationJob |
| Billing | 구매, 복원, household entitlement | BillingAccount, Entitlement |
| Privacy | 내보내기, 계정·가구 삭제 | DeletionRequest, ExportJob |

Context 간 쓰기는 가능한 한 명시적 command/RPC로 처리한다. Today는 다른 context의 source of truth가 아니라 read model이다.

## 5. 데이터 흐름 원칙

### 5.1 일반 조회

- RLS가 충분한 단순 조회는 Supabase query를 사용한다.
- 목록에는 stable pagination cursor와 deterministic order를 사용한다.
- 앱은 모든 family row에 household context를 명시한다.
- cache key는 최소 `userId + householdId + resource + query`를 포함한다.

### 5.2 고위험 mutation

다음은 RPC 또는 Edge Function transaction으로 처리한다.

- 초대 생성·수락·회수
- Owner 이전, 역할 변경, 구성원 제거
- Managed Child 대신 행동하기
- 반복 시리즈 수정과 occurrence 재생성
- 계정·가구 삭제와 내보내기
- billing household 연결과 entitlement 갱신
- idempotency가 필요한 외부 webhook 처리

### 5.3 이벤트와 작업 큐

DB transaction에서 domain event/outbox row를 기록하고 worker가 후속 작업을 수행한다.

```text
business transaction
  ├─ source row 변경
  └─ outbox event 기록
          ↓
worker claims row with lease
          ↓
external delivery
          ↓
succeeded / retry_at / dead_letter
```

외부 알림이나 webhook 성공을 DB transaction 안에서 기다리지 않는다.

## 6. 런타임과 환경

| 환경 | Flutter flavor | Bundle/Package | Supabase | Firebase | RevenueCat |
|---|---|---|---|---|---|
| local/dev | `dev` | 개발 전용 ID | local/dev | dev project | test project |
| staging | `staging` | staging ID | staging | staging project | sandbox/test |
| production | `prod` | production ID | production | production project | production |

환경 간 계정·token·database·analytics project를 공유하지 않는다. 공개 client configuration만 빌드에 포함한다. service role, webhook secret, signing secret은 CI secret 또는 server secret manager에만 둔다.

## 7. 모바일과 Web Companion의 차이

| Capability | Mobile Store MVP | Web Companion |
|---|---|---|
| Auth | Universal/App Links, secure token store | HTTPS redirect, browser session |
| Push | APNs/FCM | 후속 Web Push 또는 inbox/email fallback |
| Billing | Store purchase/restore | 처음에는 entitlement 조회; paid web는 별도 결정 |
| Offline | read cache, 제한된 safe outbox | stale 표시, broad persistent API cache 금지 |
| Background | OS가 허용하는 best-effort | foreground/session 기반 |
| Public SEO | 제공하지 않음 | 별도 Astro 사이트 |

## 8. Realtime 정책

Realtime은 사용자 가치가 명확한 화면에만 사용한다.

- Today와 household member 변경은 후보이다.
- subscription reconnect 후 전체 refetch를 수행한다.
- Realtime event는 권위 있는 mutation 응답을 대체하지 않는다.
- 동일 event 중복 수신을 허용하고 idempotent reducer를 사용한다.
- 앱 background에서는 불필요한 channel을 해제한다.

## 9. 버전 호환성

클라이언트는 다음 헤더/필드를 제공한다.

```text
X-KinFlow-Client-Version
X-KinFlow-Contract-Version
X-KinFlow-Platform
X-KinFlow-Idempotency-Key (mutation별)
```

서버는 `minimum_supported_client_version`과 contract range를 remote configuration에서 제공할 수 있다. 호환되지 않는 mutation은 명확한 update-required 오류로 차단하며, 읽기와 내보내기/삭제 접근은 가능한 범위에서 유지한다.

## 10. 실패 격리

- billing 장애가 chores/calendar 읽기를 막지 않는다.
- push 장애가 in-app inbox 생성을 막지 않는다.
- analytics 장애가 핵심 mutation을 실패시키지 않는다.
- Today read model 생성 실패 시 원본 chores/calendar 목록으로 fallback한다.
- server clock과 DB timestamp를 권위 기준으로 사용한다.

## 11. Architecture Gate

Phase 01 종료 전 다음 증거가 필요하다.

- dependency graph 검사에서 domain 금지 import 0
- dev/staging/prod flavor 각각 boot smoke test
- Supabase local migration + RLS test 성공
- iOS simulator와 Android emulator signed-in shell 실행
- crash/error reporting이 개인정보 필터 후 staging으로 수집
- generated code 재생성 후 diff 0


---

# 09. 데이터 모델과 Row Level Security

- 상태: ACCEPTED
- Source of Truth: `contracts/database-schema.sql`, `contracts/rls-contract.sql`

## 1. 핵심 원칙

1. 가구 소유 데이터는 모두 `household_id`를 가진다.
2. UUID를 안다고 접근할 수 없어야 한다.
3. UI에서 버튼을 숨기는 것은 권한 통제가 아니다.
4. `USING`과 `WITH CHECK`를 모두 검증한다.
5. 다른 household row를 연결하는 foreign key를 허용하지 않는다.
6. Owner lifecycle과 billing lifecycle은 일반 CRUD가 아니다.
7. service role은 최소 worker/administrative path에서만 사용한다.

## 2. 주요 테이블

| 영역 | 테이블 | 핵심 컬럼 |
|---|---|---|
| Identity | `profiles` | user_id, locale, timezone, deletion_state |
| Household | `households` | id, name, timezone, owner_membership_id, plan_state |
| Membership | `household_memberships` | household_id, user_id/profile_id, role, status |
| Child | `managed_members` | household_id, display_name, guardian_membership_id, status |
| Invite | `household_invites` | token_hash, short_code_hash, expires_at, max_uses, revoked_at |
| Chores | `chore_series`, `chore_revisions`, `chore_occurrences` | schedule, assignee, state, due_at |
| Calendar | `event_series`, `event_revisions`, `event_occurrences`, `event_participants` | local intent, timezone, start/end |
| Notifications | `notification_jobs`, `notification_deliveries`, `device_registrations`, `notification_inbox` | dedupe_key, status, provider |
| Billing | `billing_customers`, `store_transactions`, `household_entitlements`, `billing_events` | provider identity, valid_until |
| Privacy | `export_requests`, `deletion_requests`, `audit_events` | state, scope, actor, retention |
| Reliability | `idempotency_keys`, `outbox_events`, `worker_leases` | operation, response_hash, retry_at |

## 3. Household 관계 무결성

단순 `id` foreign key 대신 다음 패턴 중 하나를 사용한다.

```sql
UNIQUE (household_id, id)
FOREIGN KEY (household_id, assignee_member_id)
  REFERENCES household_memberships (household_id, id)
```

Managed member, event participant, chore assignee, notification recipient가 모두 같은 household인지 DB가 검증해야 한다. PostgreSQL 제약만으로 표현하기 어려운 경우 최소 범위의 trigger를 사용하고 pgTAP으로 검증한다.

## 4. 역할 모델

| 역할 | 기본 권한 |
|---|---|
| Owner | 가구 삭제, Owner 이전, billing household 지정, 모든 관리 |
| Admin | 초대·구성원·대부분 콘텐츠 관리, Owner 전용 작업 제외 |
| Member | 허용된 집안일·일정 생성/수정, 자신의 완료·응답 |
| Managed Child | 독립 auth identity 없음; guardian-gated acting context에서 제한 작업 |

Store MVP에 Guest 역할은 없다.

## 5. RLS helper 규칙

Helper function은 다음 특성을 갖는다.

- 안정적인 이름과 명시적 schema
- 필요 시 `security definer` + 빈 `search_path`
- 호출자 입력만으로 권한을 결정하지 않음
- auth.uid()와 active membership을 서버에서 조회
- billing entitlement와 role helper를 분리
- 함수 단위 권한과 회귀 테스트

예시 개념:

```sql
is_active_household_member(household_id uuid)
has_household_role(household_id uuid, roles text[])
can_act_as_managed_member(household_id uuid, managed_member_id uuid)
household_has_entitlement(household_id uuid, entitlement_key text)
```

## 6. Managed Child acting context

클라이언트의 `acting_member_id`는 힌트일 뿐이다. 서버는 다음을 확인한다.

1. 인증된 성인이 해당 household의 active member인지
2. managed member가 같은 household인지
3. guardian relation 또는 허용 역할인지
4. 요청한 action이 managed mode에서 허용되는지
5. parental gate가 필요한 action인지

감사 기록은 `authenticated_user_id`, `actor_membership_id`, `acting_managed_member_id`, `request_id`를 함께 보존한다.

## 7. 삭제와 참조

계정 삭제가 공동 가족 데이터를 무조건 cascade 삭제하지 않는다.

- 작성자 표시는 tombstone/anonymize 가능
- 공동 일정·집안일은 household 정책에 따라 유지
- 마지막 Owner는 이전 또는 household 삭제를 명시적으로 선택
- 법적 보존 대상 billing record는 제한된 별도 scope로 유지
- 모든 token, device registration, cache scope, invite는 폐기

## 8. 낙관적 동시성

수정 가능한 핵심 row에는 `version` 또는 `updated_at` 기반 expected value를 사용한다.

```text
client reads version 7
client sends expectedVersion=7
server updates only where version=7
success -> version 8
mismatch -> CONFLICT_VERSION with latest summary
```

반복 시리즈와 역할·entitlement는 last-write-wins를 사용하지 않는다.

## 9. Index 정책

- 모든 RLS membership lookup 경로에 index
- `(household_id, status, due_at)` 및 Today query index
- occurrence materialization 범위 query index
- outbox `(status, retry_at)` partial index
- webhook/provider transaction unique index
- invite token hash unique index
- `created_at` 단독 index를 무분별하게 추가하지 않는다.

실제 query plan과 production-like seed로 검증한다.

## 10. RLS 검증

`matrices/RLS_AUTHORIZATION_MATRIX.csv`의 각 행을 자동 테스트로 구현한다. 최소 actor set:

- anonymous
- authenticated outsider
- active owner/admin/member
- managed child acting context
- removed/suspended membership
- different household member
- service role worker

각 action은 정상 허용뿐 아니라 다음 공격을 포함한다.

- body/query/path에 다른 household UUID 주입
- 다른 가구의 assignee/participant ID 연결
- role/isPlus/actingMember 조작
- soft-deleted row 접근
- 직접 table mutation으로 RPC 우회

## 11. Migration 정책

- forward-only expand/contract
- destructive migration 전 dual-read/write 또는 backfill
- migration마다 rollback이 아니라 recovery plan 기록
- 이전 앱 버전과 최소 한 release window 호환
- schema dump 직접 수정 금지; migration file이 권위
- production 적용 전 local/staging backup·restore drill


---

# 10. API, 동기화, 알림, 오류 계약

- 상태: ACCEPTED
- Source of Truth: `contracts/openapi-edge.yaml`, `contracts/error-catalog.yaml`, `contracts/domain-events.yaml`

## 1. API 스타일

- 단순 RLS-safe read: Supabase client query
- transaction command: PostgreSQL RPC
- 외부 provider/webhook, 장기 작업, admin orchestration: Edge Function
- 모든 command는 stable error code와 request ID를 반환한다.
- 외부로 노출되는 Edge Function은 OpenAPI 계약을 갖는다.

## 2. 공통 요청 메타데이터

| 항목 | 용도 |
|---|---|
| Authorization | Supabase access token |
| X-KinFlow-Request-Id | client/server correlation |
| X-KinFlow-Idempotency-Key | 재시도 가능한 command dedupe |
| X-KinFlow-Client-Version | 최소 지원 버전 판단 |
| X-KinFlow-Contract-Version | API 호환성 판단 |
| X-KinFlow-Platform | ios/android/web/desktop |
| X-KinFlow-Timezone | 표시 힌트; 저장 권위는 별도 payload |

## 3. 응답 envelope

```json
{
  "data": {},
  "meta": {
    "requestId": "uuid",
    "serverTime": "2026-07-21T00:00:00Z",
    "contractVersion": "1.0"
  }
}
```

오류:

```json
{
  "error": {
    "code": "CONFLICT_VERSION",
    "messageKey": "errors.conflictVersion",
    "retryable": false,
    "details": {},
    "requestId": "uuid"
  }
}
```

사용자용 문자열은 서버 message를 그대로 표시하지 않고 `messageKey`를 locale resource로 변환한다.

## 4. Idempotency

대상:

- 초대 수락
- 완료 처리/취소
- 반복 시리즈 변경
- 결제 restore/link
- deletion/export 요청
- webhook 처리
- notification job 생성

같은 사용자·operation·idempotency key가 재전송되면 같은 결과를 반환한다. payload hash가 다르면 `IDEMPOTENCY_KEY_REUSED`를 반환한다. key TTL과 response retention을 operation별로 정의한다.

## 5. 동기화 모델

MVP는 완전한 offline-first가 아니다.

### 읽기

- 최근 household snapshot을 memory 또는 제한된 local DB에 보관 가능
- cache row는 userId/householdId/contractVersion으로 namespace
- stale timestamp를 UI에 표시
- logout/account/household switch 시 purge

### 쓰기

- 역할, 초대, 결제, 삭제, recurrence definition은 online-only
- chore completion outbox는 별도 Gate 통과 후에만 허용
- outbox item은 auth subject, household, expected version, TTL, idempotency key를 포함
- 재인증 또는 membership 변경 시 자동 재생하지 않는다.

## 6. Realtime 재동기화

1. initial query
2. realtime subscription 연결
3. event 수신 시 cache invalidation 또는 deterministic patch
4. reconnect 후 cursor/delta가 없다면 full refetch
5. app resume 시 critical screen refetch

순서가 뒤바뀐 event와 중복 event를 허용한다.

## 7. 알림 파이프라인

```text
Domain event/outbox
  → notification rule evaluator
  → notification job (dedupe key)
  → recipient preference/quiet hours
  → inbox row 생성
  → platform delivery attempt
  → provider receipt 처리
```

in-app inbox 생성이 push provider 성공에 의존하지 않는다.

## 8. 모바일 알림 구현

- FCM을 Flutter 공통 entry로 사용하고 iOS는 APNs capability를 구성한다.
- foreground/background/terminated 상태를 각각 테스트한다.
- token rotation과 invalid token 제거를 구현한다.
- notification payload에는 최소 식별자만 포함하고 민감한 가족 내용을 넣지 않는다.
- tap 시 deep link route를 서버 권한 재검증 후 연다.
- local notification은 사용자 기기 편의이며 server due job의 권위를 대체하지 않는다.

## 9. Quiet hours와 시간대

- household reminder 기준과 사용자 quiet hours를 분리한다.
- 일정 원래 timezone과 수신자 timezone을 구분한다.
- DST 전환 시 중복/누락이 없도록 occurrence instant를 사용한다.
- 발송 지연이 허용 범위를 넘으면 inbox에는 남기고 stale push를 생략할 수 있다.

## 10. 오류 분류

| 분류 | 예시 | Client 정책 |
|---|---|---|
| Validation | INVALID_INPUT | field error, 자동 재시도 금지 |
| Auth | SESSION_EXPIRED | session refresh 또는 로그인 |
| Authorization | HOUSEHOLD_ACCESS_DENIED | cache purge + 안전 화면 |
| Conflict | CONFLICT_VERSION | 최신 데이터 표시, 사용자 재결정 |
| Rate limit | RATE_LIMITED | Retry-After 준수 |
| Dependency | PROVIDER_UNAVAILABLE | bounded retry, 핵심 데이터 유지 |
| Invariant | LAST_OWNER_REQUIRED | 설명 후 허용 경로 제공 |
| Update | CLIENT_UPDATE_REQUIRED | store update 안내 |

## 11. 재시도 정책

- 네트워크·5xx·provider transient만 exponential backoff + jitter
- 4xx validation/authz는 자동 재시도하지 않는다.
- mutation retry에는 idempotency key 필수
- background retry 횟수와 TTL을 제한한다.
- 사용자 행동을 무한 spinner로 가리지 않는다.

## 12. Contract test

- OpenAPI schema positive/negative test
- stable error catalog coverage
- idempotency replay/payload mismatch
- auth/household injection
- app old/new contract compatibility
- notification duplicate/out-of-order receipt
- provider timeout and dead letter
- deep link from stale/deleted resource


---

# 11. 보안, 개인정보, 자녀 보호

- 상태: ACCEPTED
- 주의: 법률 자문이 아니며 출시 국가와 대상 연령 확정 후 전문가 검토가 필요하다.

## 1. Threat model

보호 대상:

- 가족 관계, 이름, 집안일, 일정, 시간대
- auth token과 deep link token
- 결제·구독 연계 정보
- managed child 표시명과 활동 기록
- 삭제·내보내기 산출물

주요 위협:

- household UUID 주입과 RLS 우회
- 초대 token 추측·재사용
- 공유 기기의 계정 전환 후 데이터 잔존
- 보호자 gate 우회
- 알림 payload를 통한 잠금 화면 노출
- webhook 위조·replay
- 로그/analytics에 PII 저장
- 손상된 dependency 또는 signing credential

## 2. 인증과 세션

- Supabase Auth를 identity authority로 사용한다.
- 모바일 token은 OS secure storage에 보관한다.
- refresh token을 log/crash event에 포함하지 않는다.
- logout, account deletion, membership removal 시 local cache와 device token을 정리한다.
- 세션 refresh 실패 시 민감 화면을 잠그고 stale 데이터를 가리지 않는다.
- biometric은 편의 unlock일 뿐 server auth를 대체하지 않는다.

## 3. 초대 보안

- 최소 128-bit random token
- DB에는 hash만 저장
- 짧은 코드는 보조 입력 수단이며 rate limit 적용
- expiry, revoke, max use, target email 선택 옵션
- 수락 전 로그인 identity와 household 이름을 재확인
- 중복·동시 수락은 transaction/idempotency로 방지
- 초대 URL에는 PII를 넣지 않는다.

## 4. Managed Child 원칙(P1 계약)

Managed Child는 Store MVP 비범위다. P1에서 재승인될 경우에도 독립 로그인 계정이 아니다.

- 보호자가 household 안에서 만든 프로필
- 이메일, OAuth identity, 개인 push token 없음
- 공유 기기에서 guardian가 member mode로 전환
- settings, invite, billing, deletion, export는 parental gate
- 외부 analytics는 child mode에서 기본 차단 또는 최소 집계
- location, chat, medical, school record 수집 금지

Store MVP에는 자녀 프로필·child mode·자녀 대상 마케팅을 노출하지 않는다. P1은 H-05와 법률·Store 검토를 통과하기 전 production에 활성화하지 않는다.

## 5. Parental gate

- PIN 또는 OS-level authentication을 사용할 수 있다.
- PIN hash/secret은 안전하게 저장하며 plaintext log 금지
- brute-force backoff와 recovery policy 필요
- 앱 재설치/기기 변경 후 recovery를 보호자가 통제
- acting context 시작·종료를 UI에 지속적으로 표시
- 일정 시간 비활성 또는 앱 background 후 자동 종료 가능

## 6. 데이터 최소화

MVP에서 수집하지 않는 정보:

- 정확한 위치
- 연락처 주소록 전체
- 사진/비디오
- 건강·의료 정보
- 학교 성적
- 광고 ID
- 불필요한 생년월일

프로필에는 표시명과 선택적 avatar 정도만 필요하다. 진짜 법적 이름을 요구하지 않는다.

## 7. 암호화와 secret

- transit: TLS
- at rest: provider-managed encryption + 최소 접근
- 앱에 포함 가능한 Supabase anon/publishable key는 RLS를 전제로 한다.
- service role, RevenueCat webhook secret, APNs key, store credentials는 client에 포함 금지
- CI secret 접근은 protected environment와 최소 인원
- secret rotation 및 incident procedure 문서화

## 8. Logging과 analytics

금지:

- access/refresh token
- invite raw token
- full household/event/chore title
- child display name
- email 원문
- payment receipt 원문

허용:

- pseudonymous user/household identifier
- stable error code
- screen/feature name
- timing, retry count, provider status
- request ID

Sentry before-send hook에서 PII scrubber를 적용한다.

## 9. 모바일 보안

- Universal Links/App Links 도메인 검증
- exported Android component 최소화
- iOS Keychain/Android Keystore 기반 secure storage
- 화면 캡처 차단은 민감 화면에 한해 UX·접근성을 고려해 선택
- rooted/jailbroken 기기를 무조건 차단하지 않되 위험 telemetry와 고위험 action 재인증 검토
- production build에서 debug menu와 verbose network log 제거

## 10. Web Companion 보안

- HTTPS, secure cookie/session strategy, PKCE
- broad family API persistent cache 금지
- logout/account/household switch purge
- CSP, frame-ancestors, referrer policy
- BFCache/tab restore에서 session 재검증
- 공용 PC 로그인 유지 선택을 명확히 표시

## 11. 삭제와 내보내기

- 앱 안에서 계정 삭제 시작 가능
- 공개 웹 삭제 요청 경로 제공
- 공동 household 데이터와 개인 identity를 분리
- 마지막 Owner resolution
- active subscription 안내
- export 다운로드 URL은 short-lived, one-time 또는 auth 재검증
- 삭제 처리 상태와 예상 범위를 사용자에게 보여준다.

## 12. Security Gate

출시 전 최소 검증:

- RLS matrix 100% 자동화
- 다른 household ID injection E2E
- invite brute force/rate limit/replay
- webhook signature/replay/out-of-order
- local storage/cache forensic check
- child mode parental gate bypass test
- SAST, dependency/license scan, secret scan
- backup restore와 breach response tabletop


---

# 12. 구독과 Household Entitlement

- 상태: ACCEPTED
- 모바일 Provider: RevenueCat + Apple App Store + Google Play
- Web paid purchase: OPEN, Mobile MVP 차단 요소 아님

## 1. 제품 원칙

KinFlow Plus는 개인 구매가 아니라 선택된 household에 혜택을 제공한다. 구매자, 로그인 사용자, Household Owner, billing owner, paid household는 서로 다른 개념이다.

## 2. 식별자

| 식별자 | 의미 |
|---|---|
| `auth_user_id` | KinFlow 로그인 identity |
| RevenueCat App User ID | 로그인 후 auth_user_id 기반 stable identity |
| `store_transaction_id` | Apple/Google transaction |
| `billing_customer_id` | 서버에서 관리하는 결제 identity |
| `billing_household_id` | 혜택을 연결한 household |
| `household_entitlement` | 서버가 materialize한 최종 기능 권한 |

anonymous RevenueCat user로 purchase를 완료하게 두지 않는다. 로그인 이전 paywall은 상품 정보만 보여주고 구매 전 identity를 확정한다.

## 3. 권위 흐름

```text
mobile purchase/restore
  → RevenueCat SDK 결과
  → RevenueCat webhook 또는 server verification
  → idempotent billing event
  → store transaction/customer 상태
  → billing household assignment policy
  → household_entitlement materialization
  → client refetch
```

클라이언트 SDK의 `CustomerInfo`만으로 server mutation 권한이나 household Plus 한도를 열지 않는다.

## 4. 상태 모델

`household_entitlement.status` 예시:

- `inactive`
- `trialing`
- `active`
- `grace_period`
- `billing_issue`
- `expired`
- `revoked`

필드:

- entitlement_key
- source/provider
- purchaser_user_id
- billing_household_id
- valid_from/valid_until
- will_renew
- last_verified_at
- provider_event_id
- state_reason

## 5. 구매 사용자 흐름

1. 로그인과 active household 확인
2. 상품과 가격을 store에서 조회
3. household 혜택 범위와 자동 갱신 설명
4. 구매 진행
5. SDK success를 임시 pending으로 표시
6. 서버 entitlement 확인
7. timeout 시 중복 구매를 유도하지 않고 복원/상태 갱신 제공

## 6. 복원과 계정 변경

반드시 별도 테스트한다.

- 앱 재설치 후 같은 KinFlow 계정
- 같은 store 계정, 다른 KinFlow 계정
- 다른 store 계정, 같은 KinFlow 계정
- purchaser가 household를 떠남
- Household Owner 변경
- billing household 변경 요청
- 구매가 다른 RevenueCat App User ID에 연결됨

자동 이전 정책은 사업 결정 없이는 구현하지 않는다. 충돌 시 안전하게 잠그고 지원 경로를 제공한다.

## 7. Store lifecycle

- trial 시작/전환
- active renewal
- grace period
- billing issue
- cancellation but valid until
- expiration
- refund/revoke
- upgrade/downgrade
- price consent
- family sharing 여부

각 상태에서 서버 entitlement와 UI 문구가 일치해야 한다.

## 8. Webhook

- signature/authorization 검증
- provider event ID unique
- duplicate는 idempotent success
- out-of-order event를 event time과 authoritative refresh로 처리
- unknown product/customer는 quarantine
- failure retry와 dead letter
- 민감 receipt 원문 log 금지

## 9. Feature gate

- 서버: Plus 전용 mutation과 한도를 강제
- 클라이언트: UX용 visibility/upsell
- offline cache의 오래된 Plus 상태로 destructive mutation을 허용하지 않음
- entitlement downgrade 시 기존 데이터는 유지하되 새 생성/확장을 제한하는 정책을 명시

## 10. Free/Plus OPEN 결정

출시 전 확정:

- household 최대 구성원
- active recurring chores/events 한도
- history retention 또는 advanced reminder
- 월간/연간 가격과 trial
- 국가·통화·세금
- refund/support policy

가격이나 제한은 앱 코드에 흩어놓지 않고 remote catalog + server policy로 관리한다.

## 11. Sandbox와 출시 Gate

Apple Sandbox/TestFlight와 Google license tester에서 `matrices/BILLING_TEST_MATRIX.csv` 전체를 실행한다. 특히 purchase success만으로 통과하지 않는다.

증거:

- transaction/provider event ID redacted log
- webhook 처리 상태
- entitlement DB snapshot
- purchaser/household UI
- 재설치·restore 화면 녹화
- refund/expiry/grace 시나리오


---

# 13. 분석, 관측성, 실험

- 상태: ACCEPTED

## 1. 목표

분석은 가족의 실제 가치와 시스템 신뢰성을 측정하며, 아동 프로필이나 가족 콘텐츠를 수집하기 위한 수단이 아니다.

## 2. North Star와 핵심 지표

- Activated Household: 7일 안에 성인 2명 이상 가입 + chore/event 생성 + 완료/확인
- Weekly Coordinated Household: 한 주에 2명 이상이 서로 다른 기기에서 핵심 행동 수행
- Week 4 household retention
- invite acceptance rate
- chore completion latency
- Today successful load rate
- notification useful-action conversion
- trial-to-paid, paid household retention, refund rate

## 3. 이벤트 규칙

이벤트 이름은 `domain_object.action.outcome` 형태를 권장한다.

예:

```text
household.create.succeeded
invite.accept.failed
chore.complete.succeeded
calendar.occurrence.opened
billing.purchase.pending_server_confirmation
```

공통 속성:

- event_version
- platform/app_version
- locale/timezone bucket
- pseudonymous user/household ID
- actor role category
- request ID
- result/error code

콘텐츠 제목, 이메일, child 이름, raw token은 금지한다.

## 4. Managed Child analytics

- child mode에서는 외부 behavioral analytics 기본 off
- 필수 운영 event는 child identity 없이 household-level aggregate
- 광고/추적 SDK 사용 금지
- 대상 연령 법률 검토 전 실험 참여 금지

## 5. 관측성

| 신호 | 도구/소스 | 목적 |
|---|---|---|
| Crash | Sentry/Store console | release 품질 |
| Error | structured server/client error | 원인과 영향 범위 |
| Trace | request ID, Edge Function timing | latency bottleneck |
| DB | query latency, lock, RLS failure | backend health |
| Jobs | queue depth, retry, dead letter | notification/billing reliability |
| Billing | webhook lag, entitlement mismatch | revenue risk |
| Push | provider success, invalid token | delivery health |

## 6. SLO 예시

- authenticated Today API availability 99.9%/30d
- Today p95 server response ≤ 800ms (정의된 데이터 규모)
- critical mutation success ≥ 99.5% excluding validation/authz
- notification job 95%가 scheduled time ±5분 내 provider 제출
- entitlement webhook 99%가 10분 내 materialize
- crash-free sessions ≥ 99.7% mobile release

정확한 수치는 Beta 데이터 후 승인한다.

## 7. Alert

- symptom 기반, 사용자 영향 기준
- owner와 runbook link 필수
- alert storm 방지
- low-volume billing/security는 절대 건수와 비율 모두 사용
- child/privacy breach 의심은 즉시 incident 분류

## 8. 실험 Gate

실험 전 다음을 문서화한다.

- 가설과 사용자 가치
- primary/guardrail metric
- 표본·기간·중단 기준
- 개인정보·아동 영향
- 서버 feature flag와 rollback
- 실험 종료 후 정리

pricing, child UX, account deletion, security gate는 일반 A/B 실험 대상으로 다루지 않는다.


---

# 14. 테스트와 검증 계획

- 상태: ACCEPTED

## 1. 테스트 피라미드

| 층 | 도구 | 대상 |
|---|---|---|
| Pure domain | `flutter_test` | value object, recurrence policy, state transition |
| Application | `flutter_test`, mocktail | use case, repository port, error mapping |
| Widget | `flutter_test` | 화면 상태, semantics, adaptive layout |
| Data adapter | local Supabase/mock server | DTO, mapper, SDK error, retry |
| DB/RLS | pgTAP/SQL harness | policy, constraint, function, migration |
| Contract | OpenAPI/schema test | Edge Function request/response/errors |
| Mobile integration | `integration_test` | authenticated vertical slice |
| Mobile E2E | Maestro + 실제 기기 | deep link, permission, purchase, notification |
| Web E2E | Playwright | Web Companion와 공개 삭제/약관 |
| Operational | scripted drill | backup/restore, rollback, webhook replay |

## 2. PR 필수 Gate

```text
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
supabase db reset
DB/RLS/contract tests
flutter build apk --debug --flavor dev
flutter build web --release (Web 영향 변경 또는 scheduled CI)
secret/dependency/license scan
```

macOS runner가 필요한 iOS build는 protected branch 또는 nightly/RC에서 수행한다.

## 3. Phase별 테스트 우선순위

- Phase 01: boot, flavor isolation, dependency boundary, codegen
- Phase 02: auth lifecycle, invite abuse, RLS matrix, child acting context
- Phase 03: chore recurrence/complete/conflict/Today
- Phase 04: DST, all-day, exception, series revision
- Phase 05: FCM states, duplicate job, quiet hours, offline purge
- Phase 06: billing lifecycle와 entitlement mismatch
- Phase 07: deletion/export, accessibility, localization, security
- Phase 08: load, recovery, upgrade, chaos, device matrix
- Phase 09: signed Store RC, sandbox, submission, staged rollout

## 4. 기기 매트릭스

최소:

- 최신 iPhone + 지원 최소 iOS 기기/Simulator
- iPad portrait/landscape/split view
- 최신 Pixel/Samsung 계열 + Android API 24 emulator
- Android tablet
- low-memory Android physical device
- large text, dark mode, reduced motion
- slow/unstable network, airplane mode, timezone 변경

## 5. 브라우저 매트릭스

Web Companion Beta 전:

- latest stable Chrome/Edge/Firefox/Safari
- keyboard only
- 200% zoom
- screen reader 대표 조합
- private browsing/storage denial
- logout/account switch/BFCache/tab restore

## 6. 시간과 반복 검증

`matrices/TIME_RECURRENCE_TEST_MATRIX.csv`를 기준으로 다음을 포함한다.

- DST gap/overlap
- 사용자·가구 timezone 차이
- 여행 중 device timezone 변경
- all-day date
- 월말/윤년
- single occurrence edit/cancel
- whole series future revision
- 완료된 과거 occurrence 보존
- materialization job retry/idempotency

## 7. 권한 검증

`matrices/RLS_AUTHORIZATION_MATRIX.csv`의 모든 행을 자동화한다. UI E2E만으로 RLS 검증을 대체하지 않는다. service-role test는 명시적 test helper와 isolated credential을 사용한다.

## 8. 결제 검증

- 실제 sandbox/test store product
- install/reinstall/restore
- account switch
- purchaser leaves household
- owner/billing owner change
- grace/billing issue/expiry/refund
- webhook duplicate/out-of-order/delay
- offline purchase confirmation pending

## 9. 접근성 검증

- semantic labels/roles/state
- focus order와 visible focus
- 200% text scale에서 clipping 없음
- touch target
- color contrast
- screen reader로 가입→Today→완료 task
- iPad/Android tablet orientation
- 키보드 shortcuts는 보조이며 필수 task를 가리지 않음

## 10. 증거

각 Gate는 `evidence/phase-XX/`에 다음을 남긴다.

- command와 exit code
- test report/coverage
- build artifact metadata
- redacted screenshot/video
- DB migration hash
- device/OS/browser version
- known issue와 승인자
- rollback/recovery 결과

## 11. 완료 금지 조건

- skipped/flaky test 원인 미기록
- production-like RLS test 미실행
- SDK mock만으로 결제/푸시 완료 주장
- emulator만으로 Store RC 완료 주장
- generated code drift
- Open decision를 임의 구현


---

# 15. 출시와 Store 제출 계획

- 상태: ACCEPTED
- 전략: Mobile Store MVP 먼저, Web Companion과 Desktop은 독립 Gate

## 1. Release train

| Train | 범위 | Gate |
|---|---|---|
| Internal Alpha | 핵심 vertical slice, dev/staging | G1-G4 |
| Family Beta | 실제 가족, TestFlight/Play internal | G5-G7 |
| Mobile RC | signed IPA/AAB, privacy/billing/ops | G8 |
| Store Launch | staged iOS/Android release | G9 |
| Web Companion Beta | mobile 안정화 후 browser app | G10 |
| Desktop Review | 수요 데이터 기반 ADR | G11 |

## 2. 버전 규칙

- semantic product version + monotonically increasing build number
- iOS/Android product version은 가능한 한 정렬
- DB/API contract version은 앱 version과 독립
- release branch freeze 후 critical fix만 cherry-pick
- feature flag로 incomplete capability를 안전하게 off

## 3. iOS 준비

- Apple Developer/App Store Connect 소유권 확정
- production Bundle ID, capabilities, Associated Domains, Push Notifications
- privacy manifest와 required reason API 검토
- subscription group/product/localization
- account deletion in-app flow
- restore purchases
- review notes와 test account
- iPhone/iPad screenshots, support/privacy URLs
- current Store 제출 SDK/Xcode 요구사항을 RC 전에 재검증

## 4. Android 준비

- Play Console, package name, app signing
- target SDK/current policy 재검증
- App Links, FCM, notification permission
- subscription base plans/offers
- Data Safety, target audience/content declarations
- in-app account deletion과 public deletion URL
- phone/tablet screenshots, internal/closed testing track
- pre-launch report와 device compatibility

## 5. RC build

- clean checkout, locked Flutter SDK, `pubspec.lock`
- production flavor configuration
- signed reproducible build metadata
- SBOM/dependency/license report
- `flutter build ipa --release --flavor prod`
- `flutter build appbundle --release --flavor prod`
- artifact checksum과 provenance 저장
- 실제 기기 설치 후 cold start/auth/invite/Today/push/billing/deletion smoke

## 6. 제출 전 Gate

- 모든 blocker/critical defect 0
- RLS matrix와 billing matrix pass
- backup restore drill pass
- privacy/legal 문서 승인
- support/runbook/on-call owner 확인
- production secrets와 webhook 검증
- analytics/alert dashboard 확인
- feature flags default 상태 확인
- rollback version과 DB compatibility 확인

## 7. 점진 출시

권장:

1. 내부 직원/테스터
2. 제한된 국가 또는 1~5%
3. 10~25%
4. 50%
5. 100%

각 단계에서 crash-free, auth, Today, mutation, notification, entitlement, support ticket를 확인한다. Apple/Google rollout 메커니즘 차이를 runbook에 반영한다.

## 8. 중단 기준

- household 데이터 노출/권한 우회
- account deletion 실패 또는 데이터 잔존
- paid user entitlement 광범위 불일치
- crash-free 또는 startup 급락
- notification 폭주/중복
- migration 데이터 손상
- legal/store policy 위반 가능성

## 9. Rollback

- 이전 client binary rollout halt/rollback 가능 범위 확인
- feature flag kill switch
- backward-compatible DB migration
- webhook/worker pause
- notification job drain/quarantine
- 고객 안내와 entitlement manual remediation 절차

Store binary를 즉시 되돌릴 수 없는 상황을 전제로 server compatibility와 kill switch를 준비한다.

## 10. Web Companion 출시

Mobile 안정화 후 별도 수행한다.

- immutable asset + atomic deploy
- CSP/headers/session/cache 검증
- browser matrix와 accessibility
- API 최소 호환 범위
- rollback deployment
- public website와 앱 경로 분리
- PWA 설치율을 출시 KPI로 삼지 않는다.


---

# 16. 운영, 지원, 장애 대응 Runbook

- 상태: ACCEPTED

## 1. 운영 소유권

각 production subsystem은 owner, backup owner, dashboard, alert, runbook을 갖는다.

- Auth/Household/RLS
- Chores/Calendar/Recurrence
- Notifications
- Billing/Entitlement
- Privacy deletion/export
- Mobile release
- Web Companion

## 2. 장애 등급

| 등급 | 예시 | 대응 |
|---|---|---|
| SEV-0 | household 간 데이터 노출, signing/secret compromise | 즉시 차단, incident commander, legal/privacy escalation |
| SEV-1 | 로그인/Today/결제 광범위 장애, 데이터 손상 | rollout 중단, 24/7 대응 |
| SEV-2 | 일부 기능/국가/플랫폼 장애 | owner 대응, workaround |
| SEV-3 | 경미한 defect/성능 저하 | backlog와 예정 수정 |

## 3. 초기 대응

1. incident ID와 commander 지정
2. 사용자 영향과 시작 시점 확인
3. rollout/worker/webhook/feature flag 변경 여부 확인
4. 증거 보존, 민감 log 공유 제한
5. 안전한 완화 실행
6. 상태 업데이트 cadence 결정
7. 복구 후 데이터 정합성 검증

## 4. 주요 Runbook

### Auth 장애

- Supabase status와 token refresh error 확인
- destructive mutation 일시 차단
- stale session 데이터를 안전하게 잠금
- status 안내와 retry backoff

### RLS/데이터 노출 의심

- 관련 endpoint/table 즉시 disable 또는 deny-all policy
- service role job 정지
- audit/request ID 보존
- 영향 household 범위 계산
- legal/privacy process 시작

### Recurrence job 지연

- queue depth/lease/dead letter
- materialization horizon 확인
- idempotent backfill
- 알림 stale suppression
- 사용자 Today fallback

### Notification 폭주

- worker kill switch
- dedupe key 검증
- pending job quarantine
- provider throttle
- 이미 발송된 잘못된 메시지 대응

### Billing mismatch

- purchase UI를 무조건 닫지 않고 pending 상태 안내
- webhook lag/provider status
- authoritative customer refresh
- entitlement recompute
- 중복 결제 방지
- manual remediation audit

### 삭제/내보내기 지연

- job state와 blocked dependency 확인
- download URL invalidation
- 법적 SLA와 사용자 안내
- retry/manual completion audit

## 5. 백업과 복구

- production backup schedule/retention 문서화
- 정기 restore drill을 별도 isolated project에서 수행
- RPO/RTO 목표 승인
- restore 후 RLS, membership, recurrence, entitlement 정합성 검사
- migration 전에 restore point와 recovery procedure 확인

## 6. 고객 지원 도구

운영자 도구는 기본적으로 read-only이며 다음 원칙을 따른다.

- support identity와 이유 기록
- 최소 household metadata
- raw content와 child data 최소 노출
- entitlement refresh 같은 action은 승인과 감사 기록
- 사용자를 가장하거나 RLS를 우회하는 일반 UI 금지

## 7. Post-incident

5영업일 이내 또는 심각도에 맞춰:

- timeline
- root cause와 contributing factors
- 탐지/완화 지연
- 사용자 영향
- 데이터 정합성 결과
- corrective action, owner, due date
- runbook/test/alert 문서 갱신

비난보다 시스템 개선을 우선하되 보안·개인정보 책임은 명확히 한다.


---

# 17. 수동 설정 체크리스트

코딩 에이전트가 외부 콘솔 설정을 완료했다고 가정하면 안 된다. 각 항목은 담당자, 환경, 완료일, 증거 링크를 갖는다.

## 1. 조직과 계정

- [ ] Apple Developer 조직과 권한
- [ ] App Store Connect 사용자/역할
- [ ] Google Play Console 조직과 권한
- [ ] Google Cloud/Firebase 조직과 billing
- [ ] Supabase 조직과 production region
- [ ] RevenueCat 조직과 project
- [ ] GitHub organization, protected branch, environments
- [ ] 도메인·DNS·support email

## 2. 앱 식별자

- [ ] iOS dev/staging/prod Bundle ID
- [ ] Android dev/staging/prod applicationId
- [ ] 앱 표시 이름과 상표 검색
- [ ] Universal Links/App Links 도메인
- [ ] URL scheme collision 검토

## 3. Supabase

- [ ] local/staging/production project
- [ ] Auth provider와 redirect allowlist
- [ ] SMTP와 이메일 template
- [ ] migration deployment identity
- [ ] backup/PITR 정책
- [ ] Edge Function secrets
- [ ] RLS default deny 검증
- [ ] log retention/access 정책

## 4. Firebase/Push

- [ ] dev/staging/prod Firebase project
- [ ] iOS APNs key/certificate 연결
- [ ] Android `google-services.json`
- [ ] iOS `GoogleService-Info.plist`
- [ ] notification permission 문구
- [ ] FCM service credential server secret
- [ ] token rotation/invalid token dashboard

## 5. RevenueCat/Stores

- [ ] Store subscription group/products
- [ ] RevenueCat product/entitlement/offering
- [ ] App User ID policy
- [ ] webhook endpoint와 secret
- [ ] sandbox/license tester 계정
- [ ] restore/transfer policy 승인
- [ ] Apple Family Sharing 결정
- [ ] price/trial/localization 승인

## 6. CI/CD와 서명

- [ ] Flutter SDK 3.44.7 lock
- [ ] macOS runner와 Xcode 26
- [ ] Android keystore/Play App Signing
- [ ] App Store API key/Fastlane auth
- [ ] protected production environment
- [ ] secret rotation/backup owner
- [ ] artifact retention/provenance

## 7. 법률·정책

- [ ] 개인정보 처리방침
- [ ] 이용약관
- [ ] 계정 삭제 공개 URL
- [ ] 데이터 보관·삭제 정책
- [ ] 대상 연령/mixed-audience 검토
- [ ] App Privacy/Data Safety 답변
- [ ] 구독 고지와 환불 안내
- [ ] 지원/문의/침해 신고 경로

## 8. 출시 자산

- [ ] 아이콘/스플래시
- [ ] iPhone/iPad/Android phone/tablet screenshot
- [ ] 영문·한국어 store metadata
- [ ] review test account와 설명
- [ ] support/privacy/terms URL
- [ ] accessibility statement

## 9. 운영

- [ ] Sentry project와 PII scrubber
- [ ] analytics project와 child-mode policy
- [ ] alerts/on-call/runbook
- [ ] status page/incident communication
- [ ] backup restore drill
- [ ] support admin 최소 권한


---

# 18. 추적성, 위험, Definition of Done

- 상태: ACCEPTED

## 1. 추적 체계

각 요구사항은 다음 연결을 가져야 한다.

```text
Requirement ID
→ Decision/ADR
→ Phase/Work Package
→ Code module/API/DB migration
→ Automated test
→ Manual evidence
→ Release Gate
→ Risk item
```

`matrices/REQUIREMENTS_TRACEABILITY.csv`, `SPEC_TRACEABILITY.csv`, `RISK_REGISTER.csv`가 인덱스 역할을 한다.

## 2. 변경 규칙

- 제품·보안·결제·아동·삭제 결정은 ADR 없이 변경 금지
- contract 변경은 schema/type/test/migration/docs를 같은 PR에 포함
- 새로운 dependency는 목적, 대안, license, platform support, maintenance 평가
- Phase 범위 밖 구현은 feature flag 또는 별도 change request

## 3. Work Package Definition of Ready

- 요구사항과 제외 범위가 식별됨
- 선행 decision이 ACCEPTED
- 데이터/권한 영향 분석
- 테스트와 증거 위치 정의
- rollback/recovery 경로 정의
- 외부 console dependency 준비

## 4. Work Package Definition of Done

- acceptance criteria 구현
- format/analyze/test/codegen 성공
- DB/RLS/contract test 성공
- iOS/Android 관련 build 또는 실기기 검증
- accessibility/localization/error/offline 상태 검토
- security/privacy review
- evidence 저장
- 문서/traceability 업데이트
- known issue와 owner 기록

## 5. Phase Definition of Done

- Phase scope 100% 또는 승인된 deferral
- exit Gate 전부 통과
- blocker/critical defect 0
- migration/recovery 검증
- performance budget 확인
- 수동 setup 미완료가 다음 Phase를 차단하는지 명시
- 다음 Phase handoff report

## 6. Release Definition of Done

- signed production candidate
- store sandbox purchase/restore
- RLS/billing/time matrices
- deletion/export end-to-end
- privacy/legal/store metadata 승인
- backup/restore 및 incident tabletop
- rollout/rollback owner
- SLO dashboard/alerts
- release notes/support brief

## 7. 주요 위험 범주

- household isolation failure
- child privacy/mixed-audience misclassification
- recurrence/DST corruption
- store entitlement mismatch
- shared-device cache leakage
- plugin platform incompatibility
- signing credential compromise
- Store SDK/target policy 변화
- scope explosion across mobile/web/desktop
- AI-generated code with unverified behavior

각 위험에는 likelihood, impact, owner, mitigation, trigger, residual risk를 기록한다.

## 8. AI/Vibe-coding 품질 규칙

- “완료”는 실행 로그와 artifact로 증명한다.
- 존재하지 않는 SDK/API를 추측하지 않는다.
- generated code와 migration을 생략하지 않는다.
- TODO를 silent success로 처리하지 않는다.
- 사용자 요청과 문서가 충돌하면 상위 결정과 보안 원칙을 우선하고 DECISIONS에 기록한다.
- 대규모 일괄 생성보다 작은 vertical slice와 reviewable diff를 사용한다.


---

# 19. 기준 자료와 출시 직전 정책 점검

- 상태: MAINTAINED
- 기준일: 2026-07-21

## 1. 기술 기준 자료

- Flutter stable release와 Dart release notes
- Flutter supported deployment platforms
- Flutter adaptive/responsive, deep link, build/release 문서
- Supabase Flutter/Auth/Postgres/RLS/Edge Function 문서
- RevenueCat Flutter SDK, restore behavior, webhook 문서
- Firebase Cloud Messaging Flutter 문서
- Apple Developer/App Store Review/Subscription/Privacy 문서
- Google Play target API, Billing, Data Safety, Families 문서
- WCAG 2.2와 플랫폼 접근성 지침

구체 링크는 `docs/99_REFERENCES.md`에서 관리한다.

## 2. 변경 가능성이 높은 항목

RC 시작 직전에 공식 출처로 다시 확인한다.

- Flutter stable와 지원 OS/browser matrix
- Xcode/iOS SDK 제출 요구사항
- Google Play target API deadline
- Store billing SDK 요구사항
- privacy manifest/required reason API
- App Privacy/Data Safety 질문
- account deletion 요구사항
- Families/mixed-audience/아동 법률
- RevenueCat SDK/store compatibility
- Supabase platform deprecation/security advisory

## 3. 정책 확인 절차

1. 담당자가 공식 문서 URL과 확인일을 기록
2. 변경사항과 기존 설계 영향 분석
3. blocker이면 ADR/implementation plan 갱신
4. build/test/store metadata 변경
5. evidence에 screenshot 또는 exported policy summary 저장

블로그·검색 요약만으로 정책을 확정하지 않는다.

## 4. 지역·아동 점검

최초 국가와 대상 연령이 확정되면 다음을 별도 검토한다.

- 미국 COPPA
- EU/EEA GDPR 아동 동의 연령과 데이터 주체 권리
- 영국 Children’s Code
- Apple Kids Category/Google Families 적용 여부
- 데이터 국외 이전, DPA, 보관 기간
- 결제 세금·환불·소비자 고지

## 5. 오픈소스와 라이선스

- dependency license inventory
- Store와 상업 사용 적합성
- copyleft/asset/font license 검토
- 앱 내 acknowledgements 필요 여부
- discontinued/unmaintained plugin 대체 계획

## 6. 출처 변경 기록

정책 또는 toolchain이 변경되면 `CHANGELOG.md`, `DECISIONS.md`, 관련 matrix와 Phase Gate를 함께 갱신한다.


---

# 20. Flutter 플랫폼·클라이언트 아키텍처

- 상태: ACCEPTED
- Tier 1: iOS/iPadOS/Android
- Tier 2: Flutter Web Companion
- Deferred: Flutter Windows/macOS/Linux

## 1. Native-first 원칙

KinFlow의 핵심 채널은 App Store와 Google Play다. Web은 설치형 PWA 획득 채널이 아니라 PC에서 가족 일정과 집안일을 관리하는 companion이다. Flutter가 지원하는 플랫폼 수와 실제 출시 플랫폼 수를 혼동하지 않는다.

## 2. 지원 기준

| 플랫폼 | Store MVP | 최소 기준 | 검증 |
|---|---:|---|---|
| iPhone/iPad | 예 | iOS 16+ 제품 기준 | Xcode 26, 최신/최소 대표 기기 |
| Android phone/tablet | 예 | API 24+ runtime, target API 36 | emulator + 실제 저사양/최신 기기 |
| Web | 후속 | 최신 주요 browser | Playwright + 수동 접근성 |
| Windows/macOS/Linux | 아니오 | 수요 Gate 후 결정 | plugin audit/PoC 이후 |

Flutter 공식 지원 범위보다 제품 최소 버전을 높이는 것은 허용하며, 낮추려면 별도 compatibility test가 필요하다.

## 3. 앱 시작 구조

```text
main_dev.dart
main_staging.dart
main_prod.dart
      ↓
bootstrap(AppEnvironment)
      ├─ WidgetsFlutterBinding
      ├─ logging/Sentry privacy filter
      ├─ Firebase initialization
      ├─ Supabase initialization
      ├─ RevenueCat initialization after auth identity policy
      ├─ ProviderScope overrides
      └─ runApp(KinFlowApp)
```

초기화 실패를 하나의 blank screen으로 만들지 않는다. 필수/선택 의존성을 구분하고 recovery UI를 제공한다.

## 4. Capability port

```dart
abstract interface class NotificationService { ... }
abstract interface class BillingService { ... }
abstract interface class SecureStorage { ... }
abstract interface class DeepLinkSource { ... }
abstract interface class BackgroundScheduler { ... }
abstract interface class ConnectivityMonitor { ... }
abstract interface class AnalyticsSink { ... }
abstract interface class ParentalGate { ... }
```

플랫폼 구현은 `infrastructure/platform/`에 둔다. conditional import는 최소화하고 capability registry가 지원 여부를 노출한다.

## 5. Navigation

`go_router`를 사용한다.

주요 route:

```text
/splash
/auth/sign-in
/auth/callback
/onboarding/household
/invite/:token
/today
/chores
/chores/:occurrenceId
/calendar
/calendar/:occurrenceId
/family
/settings
/settings/subscription
/settings/privacy
```

규칙:

- auth redirect loop 방지
- invite와 auth callback cold start 처리
- deep link target을 열기 전 membership/RLS 재검증
- child mode에서 금지 route redirect
- 삭제된 resource는 안전한 not-found 상태
- navigator key를 전역 mutation escape hatch로 사용하지 않는다.

## 6. Riverpod 상태 소유권

- session: auth feature의 single provider
- active household: household feature의 single provider
- server collection: repository query + async notifier/cache
- form draft: screen-local state
- transient UI: widget/local provider
- entitlement: server snapshot provider

동일 데이터를 여러 provider에서 복제하지 않는다. provider dependency cycle을 CI architecture test로 검토한다.

## 7. Adaptive layout

폭 고정 기기 이름이 아니라 available space와 입력 capability를 사용한다.

| Size class | 예시 UI |
|---|---|
| compact | bottom NavigationBar, single pane, modal/full-screen form |
| medium | NavigationRail 또는 wider navigation, optional detail pane |
| expanded | persistent rail/sidebar, master-detail, keyboard shortcuts |

- 화면 회전과 split view에 반응한다.
- `MediaQuery.textScaler` 큰 글꼴에서도 핵심 action을 숨기지 않는다.
- hover가 있다고 touch가 없다고 가정하지 않는다.
- Cupertino adaptation은 interaction convention에 선택적으로 사용한다.

## 8. 앱 생명주기

- resume: session/active household/critical screen refresh
- inactive/background: sensitive acting mode timeout, analytics flush, unsafe mutation 금지
- terminated push tap: bootstrap 후 route replay
- memory pressure: non-critical cache release
- app upgrade: local schema migration과 cache contract check

## 9. Local persistence

초기 선택은 secure key-value + 제한된 query cache다. local SQL DB 도입은 offline value와 migration cost가 확인된 후 ADR로 결정한다.

- token/parental secret: secure storage
- preferences: platform preferences
- family data cache: encrypted 또는 최소화된 local store, namespace 필수
- outbox: 별도 Gate, TTL/idempotency/auth binding

## 10. Web Companion

- 동일 Flutter domain/application 코드를 가능한 범위에서 공유
- public marketing/legal site와 분리
- browser secure session과 cache purge
- Web Push/paid purchase/offline 설치는 초기 필수 아님
- SEO가 필요한 화면은 Astro site에서 제공
- browser back/refresh/deep link를 정상적인 navigation으로 처리

## 11. Desktop 확장 Gate

다음 데이터가 있어야 PoC를 시작한다.

- Web 사용자 중 desktop active 비중
- native notification/system tray 요구
- offline desktop 업무
- wall display/kiosk 수요
- plugin의 Windows/macOS/Linux support
- 별도 signing/store/update 운영 비용

Gate 전에는 desktop folder가 존재해도 release support를 약속하지 않는다.


---

# 21. 기술 스택, 버전, 의존성 정책

- 상태: ACCEPTED
- 기준일: 2026-07-21

## 1. Toolchain baseline

| 항목 | 기준 |
|---|---|
| Flutter SDK | 3.44.7 stable exact |
| Dart | Flutter에 포함된 3.12 계열 |
| iOS build | Xcode 26, current App Store SDK requirement 재검증 |
| Android | min API 24, target API 36, current Play deadline 재검증 |
| Java | Flutter/Android Gradle Plugin 호환 LTS |
| CocoaPods | locked CI bootstrap version 또는 Bundler policy |
| Supabase CLI | repository에서 고정 |
| GitHub Actions | commit SHA pin 또는 승인된 major |

`contracts/toolchain.json`이 기계 판독 기준이다.

## 2. Flutter package baseline

| 범주 | 선택 | 역할 |
|---|---|---|
| State/DI | `flutter_riverpod`, `riverpod_annotation` | 상태 소유권과 dependency injection |
| Routing | `go_router` | declarative routes/deep links |
| Models | `freezed_annotation`, `json_annotation` | immutable DTO/state |
| Codegen | `build_runner`, `freezed`, `json_serializable`, `riverpod_generator` | 생성 코드 |
| Backend | `supabase_flutter` | Auth/PostgREST/Realtime/Storage |
| Billing | `purchases_flutter` | App Store/Play purchase |
| Push | `firebase_core`, `firebase_messaging` | FCM/APNs bridge |
| Local notification | `flutter_local_notifications` | foreground/local presentation |
| Secure storage | `flutter_secure_storage` | token/secret |
| Connectivity | platform-approved connectivity package | UX hint; truth source 아님 |
| Error | `sentry_flutter` | crash/error |
| Localization | Flutter `gen_l10n`, `intl` | ARB/i18n |
| Testing | `flutter_test`, `integration_test`, `mocktail` | automated tests |

패키지 정확한 patch 버전은 Phase 01에서 Flutter SDK 3.44.7과 공식 호환성을 확인한 뒤 `pubspec.yaml`과 `pubspec.lock`에 고정한다.

## 3. Dependency 추가 Gate

PR 설명에 다음을 포함한다.

- 해결하는 문제와 사용 범위
- 표준 SDK로 해결하지 못하는 이유
- iOS/Android/Web/Desktop support
- 최근 유지보수와 issue 상태
- license와 transitive dependency
- binary size/native permission 영향
- 대체/제거 전략
- testability와 mocking 방법

단일 convenience 함수 때문에 큰 package를 추가하지 않는다.

## 4. Version 정책

- toolchain exact pin
- runtime package는 compatible range + lockfile
- production build는 lockfile 변경 금지
- bot 자동 upgrade는 PR과 CI를 통과해야 함
- major upgrade는 별도 ADR와 migration branch
- Flutter stable upgrade는 RC 중 수행하지 않음
- security advisory는 예외 expedited path

## 5. Generated code

- 생성 파일 commit
- 생성 파일 직접 편집 금지
- CI에서 codegen 후 diff 0
- generator version lock
- DTO 변경 시 mapper/domain/contract test 동시 수정

## 6. Platform plugin 정책

- 최소 지원 OS에서 실제 검증
- 권한/Info.plist/Manifest 변경 문서화
- background handler의 isolate/entry-point 요구 검증
- web/desktop unsupported일 때 compile-safe fallback
- plugin이 abandoned되면 adapter 뒤에서 교체 가능

## 7. Dependency 보안

- dependency audit와 license inventory
- GitHub Action SHA pinning 권장
- signing/build secret을 package script에 노출 금지
- package post-install/code generation 검토
- unknown binary download 금지
- SBOM을 RC artifact에 포함

## 8. Public website

별도 `apps/public_site`는 Astro + TypeScript를 권장한다. Flutter app dependency와 release cadence를 분리하고, 법률·지원 페이지가 JavaScript 없이도 읽히도록 정적 출력한다.

## 9. 업그레이드 절차

1. release notes/security advisory 검토
2. compatibility branch
3. codegen/format/analyze/unit/DB test
4. iOS/Android build와 실제 기기 smoke
5. billing/push/deep link regression
6. Web 영향 시 browser matrix
7. binary size/startup 비교
8. ADR/changelog/toolchain update


---

# 22. 저장소, 모듈, 코드 구조 스펙

- 상태: ACCEPTED

## 1. 권장 저장소

```text
kinflow/
├─ apps/
│  ├─ kinflow_app/
│  │  ├─ lib/
│  │  ├─ test/
│  │  ├─ integration_test/
│  │  ├─ ios/
│  │  ├─ android/
│  │  └─ web/
│  └─ public_site/
├─ packages/
│  ├─ kinflow_domain/
│  ├─ kinflow_design_system/
│  ├─ kinflow_api_contracts/
│  └─ kinflow_test_support/
├─ supabase/
│  ├─ migrations/
│  ├─ functions/
│  ├─ tests/
│  └─ seed.sql
├─ contracts/
├─ docs/
├─ phases/
├─ e2e/
│  ├─ maestro/
│  └─ playwright/
├─ scripts/
└─ evidence/
```

초기 팀이 작으면 Flutter packages를 앱 내부에서 시작할 수 있지만 domain/design/contracts 경계는 유지한다. 실제 분리는 Phase 01 ADR로 확정한다.

## 2. Feature 구조

```text
lib/features/chores/
├─ domain/
│  ├─ entities/
│  ├─ value_objects/
│  ├─ policies/
│  └─ repositories/
├─ application/
│  ├─ use_cases/
│  ├─ commands/
│  └─ queries/
├─ data/
│  ├─ dto/
│  ├─ mappers/
│  ├─ datasources/
│  └─ repositories/
└─ presentation/
   ├─ screens/
   ├─ widgets/
   ├─ controllers/
   └─ providers/
```

공통 `core/`는 dumping ground가 아니다. 둘 이상의 feature가 안정된 의미로 공유할 때만 이동한다.

## 3. 파일과 이름

- Dart standard snake_case file
- class/enum PascalCase
- provider는 역할이 드러나는 이름
- DTO suffix, domain entity에는 DTO suffix 금지
- `Manager`, `Helper`, `Utils` 같은 모호한 이름 제한
- command/query/use case에 행동 동사 사용

## 4. Domain model

- ID는 raw String 남용 대신 value object/typedef wrapper
- money, timezone, local date, recurrence, role을 type으로 표현
- invalid state는 constructor/factory에서 거부
- domain error는 stable sealed type
- equality와 serialization 책임을 분리

예:

```dart
sealed class CompleteChoreFailure {}
final class VersionConflict extends CompleteChoreFailure { ... }
final class PermissionDenied extends CompleteChoreFailure { ... }
```

## 5. Repository 계약

Repository는 사용자 task 관점의 port다. Supabase table 이름을 그대로 노출하지 않는다.

```dart
abstract interface class ChoreRepository {
  Future<Result<TodayChores, ChoreFailure>> loadToday(...);
  Future<Result<ChoreOccurrence, ChoreFailure>> complete(...);
}
```

SDK exception은 data layer에서 domain/application failure로 변환한다.

## 6. Riverpod 코드

- provider definition과 UI를 과도하게 같은 파일에 두지 않는다.
- `ref.watch`는 rendering dependency, `ref.read`는 command에 제한
- async cancellation/dispose 처리
- autoDispose 여부를 데이터 생명주기에 맞춤
- family provider key에 household/user context 포함
- provider override로 test double 주입

## 7. UI component

- design token 사용, 임의 숫자/색상 최소화
- business rule을 component에 넣지 않음
- empty/loading/error/offline/permission-denied 상태를 명시
- destructive action 확인과 undo 정책
- screen reader semantics와 test key

## 8. Serialization

- API/DB DTO는 snake_case 매핑 명시
- unknown enum forward compatibility 정책
- timezone/date/instant 형식을 계약에 고정
- optional과 nullable 의미를 구분
- generated serializer + negative fixture test

## 9. 오류와 Result

expected business failure는 Result/sealed failure로 처리하고 programmer invariant violation은 exception/assert로 구분한다. UI는 stable failure를 localized presentation model로 변환한다.

## 10. Commit/PR 단위

권장 vertical slice:

```text
migration/RLS
→ API/RPC contract
→ Dart DTO/repository
→ use case/provider
→ screen
→ automated tests
→ evidence/docs
```

한 PR에서 여러 Phase를 섞지 않는다.


---

# 23. Flutter UI와 플랫폼 구현 스펙

- 상태: ACCEPTED

## 1. App shell

- MaterialApp.router
- locale/theme/router/provider가 app shell에서 주입
- auth/bootstrap 상태를 route와 분리
- global error boundary와 recovery action
- staging/dev build에만 environment banner/debug panel

## 2. 디자인 시스템

Token:

- spacing, radius, elevation
- semantic color
- typography and text scale
- touch target
- motion duration/easing
- layout breakpoint

Material 3를 기반으로 하되 브랜드 의미를 token으로 정의한다. 색상 하나만으로 완료/지연/오류를 표현하지 않는다.

## 3. 핵심 화면

### Today

- household date와 timezone 표시
- chores와 events section
- assignee/member filter
- stale/offline banner
- optimistic completion은 server confirmation/rollback 명확화
- empty state에서 첫 chore/event 생성 유도

### Chores

- occurrence와 series 편집을 구분
- 완료/취소/승인 state
- 반복 규칙을 사람이 읽는 문장으로 표시
- assignee picker에서 household 경계 유지

### Calendar

- day/week/month 중 MVP 범위는 PRD 따름
- all-day와 timed event 구분
- timezone 표시/편집
- single occurrence vs whole series 선택
- accessible date/time input

### Family

- role/status/managed member 표시
- invite token 원문을 log/analytics에 남기지 않음
- Owner 전용 action 분리
- child mode 전환/종료가 항상 보임

### Subscription

- store에서 가져온 local price
- household 혜택과 자동 갱신 설명
- purchase pending server confirmation
- restore와 support path
- active/expired/billing issue 상태

## 4. Form

- client validation은 UX, server validation이 권위
- unsaved changes 보호
- keyboard action과 focus 이동
- server field/global error 매핑
- double submit 방지와 idempotency
- date/timezone input의 원래 의도 보존

## 5. Permission flow

알림 권한은 첫 실행 즉시 요구하지 않는다.

1. 가치 설명 pre-prompt
2. 사용자가 reminder 설정 또는 관련 action 수행
3. OS permission 요청
4. denied 상태와 settings deep link
5. inbox/email fallback

캘린더/연락처 권한은 MVP에 필요 없으면 요청하지 않는다.

## 6. Deep link

- Universal Links/App Links 우선
- custom scheme은 개발/보조 fallback
- auth callback와 invite link host/path allowlist
- token은 화면/analytics에 노출하지 않음
- cold/warm/background state 모두 테스트
- 로그인 필요 시 목적 route를 안전하게 임시 보존

## 7. Push 처리

- background handler는 top-level entry point 요구사항 준수
- payload parse를 pure function으로 테스트
- notification tap은 resource refetch와 authz 재검증
- foreground에서 중복 system/local notification 방지
- badge/inbox unread count 동기화

## 8. 접근성

- Semantics label/value/hint
- screen reader focus order
- minimum touch target
- text scaling 200%
- contrast와 non-color cue
- reduced motion
- landscape/split screen
- keyboard navigation for tablet/Web

접근성 문제를 Beta 후 polish로 미루지 않는다.

## 9. Localization

- ARB + gen_l10n
- 영어 source와 한국어 번역
- pseudo locale
- plural/gender/number/date formatting
- 문자열 연결 금지
- 긴 독일어/프랑스어와 RTL 구조 사전 테스트
- server error code를 locale key로 매핑

## 10. 성능

- 긴 목록 lazy build
- rebuild scope 최소화
- image/avatar cache 제한
- startup에 불필요한 SDK init 지연
- large household seed로 frame/build profile
- jank 측정은 release/profile build 실제 기기

## 11. 플랫폼 차이

| 기능 | iOS | Android | Web |
|---|---|---|---|
| Back | navigation convention | system back/predictive back | browser history |
| Billing | App Store | Play Billing | 초기 조회만 |
| Push | APNs via FCM | FCM | 후속 |
| Secure store | Keychain | Keystore-backed | browser strategy |
| Update | App Store | Play Store | atomic deploy |

## 12. 화면 테스트 식별자

E2E에 필요한 stable semantic/test keys만 제공한다. 구현 class name/텍스트에 과도하게 의존하지 않는다. test key가 사용자 개인정보를 포함하지 않는다.


---

# 24. 백엔드, 데이터베이스, API 구현 스펙

- 상태: ACCEPTED
- Backend: Supabase Auth/PostgreSQL/RLS/Edge Functions

## 1. Repository layout

```text
supabase/
├─ config.toml
├─ migrations/
├─ functions/
│  ├─ _shared/
│  ├─ accept-invite/
│  ├─ transfer-owner/
│  ├─ billing-webhook/
│  └─ request-account-deletion/
├─ tests/
└─ seed.sql
```

Edge Function은 TypeScript/Deno를 유지한다. Flutter와 동일 언어로 맞추기 위해 서버를 Dart로 바꾸지 않는다.

## 2. Migration

- timestamped immutable file
- one concern per migration
- schema, RLS, function, index가 review 가능
- seed는 deterministic/non-production
- destructive operation은 expand/backfill/contract
- migration hash를 evidence에 기록

## 3. RLS

모든 public/authenticated family table에 RLS. 새 table을 RLS 없이 생성하면 CI 실패. view/function 권한을 명시하고 public execute를 제거한다.

## 4. Direct query vs command

Direct read 예:

- active household list
- Today read model
- household member list
- occurrence detail

RPC/Edge command 예:

- household create/owner setup
- invite accept
- role/owner transition
- recurrence revision
- delete/export
- billing assignment

## 5. Edge Function 공통 middleware

- request ID
- auth token 검증
- CORS exact allowlist (Web)
- body size/content type
- schema validation
- idempotency
- rate limit
- structured redacted log
- stable error envelope
- timeout/cancellation

## 6. Auth context

서버는 access token에서 user를 얻고 active membership을 DB에서 조회한다. body의 userId/role/household ownership을 신뢰하지 않는다. service role로 query할 때도 application authorization을 명시적으로 수행한다.

## 7. Transaction 예: 초대 수락

```text
validate token hash/expiry/revoke/use
lock invite
verify authenticated user
ensure not member/conflicting state
insert membership
increment use count
emit household.member_joined
commit
```

같은 idempotency key는 같은 membership 결과를 반환한다.

## 8. Recurrence materialization

- series/revision/exception을 읽음
- household timezone/local intent 해석
- bounded horizon occurrence upsert
- unique series+scheduled-local/instant key
- completed past occurrence 변경 금지
- revision effective_from 이후만 재생성
- job retry idempotent

## 9. Today read model

입력:

- authenticated user
- active household
- household local date
- optional member filter

출력:

- chores/events ordered sections
- server generated at
- household timezone
- entitlement/limit summary 최소 정보
- cursor/next window 필요 시

UI 전용 과도한 denormalization은 versioned contract로 관리한다.

## 10. Billing webhook

- provider verification
- event unique
- raw payload encrypted/limited retention 또는 필요한 필드만 저장
- customer/transaction upsert
- entitlement recompute
- outbox event
- duplicate success
- unknown/malformed quarantine

## 11. Worker

- claim with `FOR UPDATE SKIP LOCKED` 또는 equivalent lease
- heartbeat/lease expiry
- bounded retries+jitter
- dead letter와 manual replay
- poison message 격리
- worker identity 최소 권한

## 12. Rate limit

고위험:

- auth recovery
- invite create/accept/short-code lookup
- deletion/export
- billing refresh
- support/admin actions

user, IP, household, token fingerprint 중 적절한 key를 조합하며 개인정보를 raw log하지 않는다.

## 13. OpenAPI와 Dart client

`contracts/openapi-edge.yaml`은 Edge command의 권위다. Phase 01/02에서 수동 typed client 또는 승인된 generator를 선택한다. generator 출력이 domain type이 되지 않으며 DTO adapter 뒤에 둔다.

## 14. 성능

- query budget와 index
- explain analyze on representative seed
- N+1 방지
- Realtime publication 최소화
- large JSON payload 제한
- list pagination
- connection/function concurrency 관측

## 15. DB 검증 Gate

- clean reset/migration
- pgTAP/RLS matrix
- cross-household FK attack
- idempotency concurrency
- recurrence deterministic fixture
- webhook replay/out-of-order
- backup restore
- old/new client compatibility


---

# 25. 인증, 세션, Identity, Link 스펙

- 상태: ACCEPTED

## 1. 성인 계정

Store MVP의 auth account는 성인/보호자 사용자를 위한 것이다. 이메일 OTP 또는 magic link를 기본 후보로 하고 OAuth provider는 출시 국가·지원 부담에 따라 선택한다.

## 2. Session state

```text
unknown/bootstrap
unauthenticated
authenticating
authenticated-no-household
authenticated-active-household
refreshing
locked/re-auth-required
deleting
```

UI는 nullable user 하나로 모든 상태를 추론하지 않는다.

## 3. 모바일 저장

- refresh/access token은 secure storage
- app process memory에 필요한 기간만 사용
- logout/invalid grant에서 제거
- debug log/network inspector redaction
- app clone/backup restore behavior 검토

## 4. 로그인 흐름

1. 이메일 형식/locale
2. server auth request
3. generic response로 account enumeration 최소화
4. Universal/App Link callback
5. code/state 검증
6. profile bootstrap
7. active household 선택 또는 onboarding
8. RevenueCat identity login
9. device registration

각 단계 실패 시 재시도/취소/지원 경로를 제공한다.

## 5. OAuth/Deep Link

- own HTTPS domain
- iOS associated domains와 Android assetlinks
- exact redirect allowlist
- state/PKCE 검증
- token/query 로그 금지
- open redirect 방지
- cold start와 이미 열린 앱
- callback replay 방지

## 6. Household 초대

초대 링크를 열었을 때:

- token을 secure ephemeral memory에 보관
- 로그인 전 household 최소 정보 preview는 abuse/rate limit 고려
- 로그인 후 수락 대상 household와 현재 account 재확인
- 이미 가입/만료/회수/가득 참 상태
- 성공 후 active household 전환은 사용자에게 명확히 표시

## 7. Active household

한 계정이 여러 household를 가질 수 있으나 Store MVP UI는 단순화할 수 있다. active household는 client preference일 뿐 서버 권한이 아니다. 전환 시:

- previous household cache/provider dispose
- notification/filter context 갱신
- P1 child acting mode 종료
- entitlement refetch
- Realtime channel 재구성

## 8. Managed Child(P1 계약, Store MVP 비범위)

- auth account 없음
- guardian가 만든 managed member row
- child mode entry에 parental gate/명시적 선택
- allowed action subset
- actor audit 이중 기록
- logout과 별개의 mode exit
- background/timeout에서 자동 종료 정책

## 9. 계정 상태

- active
- suspended (운영/보안 정책 필요)
- deletion requested
- deletion processing
- deleted/tombstoned

삭제 처리 중 새 household 생성이나 purchase를 막고, status/export/support access 정책을 제공한다.

## 10. Device registration

- auth user + installation ID + platform + environment
- FCM token은 rotate 가능
- logout/account switch에서 unlink
- last_seen, app version, permission state
- raw token 접근 최소화
- invalid provider response 시 revoke

## 11. Auth test

- OTP/magic link 성공·만료·재사용
- callback spoof/open redirect
- session refresh offline/expired
- account switch cache purge
- invite before/after login
- removed membership on resume
- P1 child mode route bypass
- reinstall와 restore


---

# 26. 반복, 작업 큐, 알림, 동기화 구현 스펙

- 상태: ACCEPTED

## 1. 시간 type

- Instant: UTC timestamp
- Timezone: IANA ID
- LocalDate: 달력 날짜
- LocalTime: 사용자가 의도한 벽시계 시간
- ZonedIntent: LocalDate/Time + timezone + DST resolution policy
- AllDayRange: date-based exclusive end

Dart `DateTime`만으로 모든 의미를 표현하지 않는다. timezone library 선택은 Phase 04 dependency Gate에서 확정한다.

## 2. 반복 모델

```text
Series: identity/owner/status
Revision: rule, local intent, timezone, effective range
Occurrence: materialized scheduled instance and state
Exception: cancel/override/single edit
```

RRULE을 저장할 수 있지만 RRULE 문자열만 source of truth로 삼지 않고 지원 subset과 validation을 명시한다.

## 3. 수정 범위

MVP:

- 이 회차만 수정
- 전체 시리즈의 향후 회차 수정
- 이 회차 취소
- 시리즈 종료

“이후 모든 회차”가 구현되면 revision effective boundary를 사용한다. 완료된 과거 occurrence는 보존한다.

## 4. Materialization horizon

- Today/알림 요구를 충족하는 과거/미래 window
- worker가 주기적으로 horizon 확장
- 화면 요청 시 bounded on-demand 보완 가능
- 동일 occurrence unique key
- job retry idempotent
- time library/version 변경 시 migration 검토

## 5. DST 정책

사용자에게 예측 가능한 정책을 제품 결정으로 문서화한다.

- 존재하지 않는 local time: 다음 유효 시각으로 이동 또는 생성 차단
- 중복 local time: earlier/later offset 선택
- all-day: timezone instant로 강제 변환하지 않음
- 여행: series timezone 유지, 표시만 device/user timezone 선택

모든 정책은 `TIME_RECURRENCE_TEST_MATRIX.csv` fixture를 갖는다.

## 6. Chore completion

- occurrence state와 expected version
- actor/authenticated user 기록
- optional approval flow
- duplicate tap idempotent
- offline outbox Gate 시 TTL과 membership 재검증
- recurring series 정의와 완료 history 분리

## 7. Job queue

상태:

```text
pending → leased → succeeded
             ├→ pending(retry_at)
             └→ dead_letter
```

필드:

- type, payload/version
- dedupe key
- attempt/max_attempt
- retry_at
- lease_owner/lease_until
- last_error_code
- created/completed timestamps

## 8. Notification rule

- event/occurrence reminder
- chore due/overdue
- assignment/mention-like event
- invite
- subscription lifecycle
- privacy/security event

각 rule은 recipient, schedule instant, quiet hours, dedupe, expiry를 계산한다.

## 9. Delivery

- inbox first
- push provider next
- email은 초대/보안/구독/삭제 등 승인된 유형
- stale notification은 provider 제출 생략 가능
- provider receipt와 invalid token 정리
- 내용 최소화, 잠금 화면 privacy setting

## 10. Client sync

- app resume와 push tap에서 targeted refetch
- optimistic UI는 rollback snapshot 보유
- version conflict는 latest와 user decision
- Realtime은 invalidation 보조
- offline 상태를 명시하고 high-risk mutation 비활성

## 11. Background 제한

iOS/Android background execution을 정확한 스케줄러로 간주하지 않는다. 중요한 due notification은 서버 worker에서 생성한다. client background task는 token refresh, local cache maintenance 같은 opportunistic 작업만 수행한다.

## 12. 검증

- clock-controlled deterministic tests
- DST/month-end/leap-year
- worker crash/lease expiry
- duplicate/out-of-order domain event
- provider outage
- quiet hours boundary
- app states foreground/background/terminated
- notification tap authz
- account/household switch purge


---

# 27. Billing과 Entitlement 구현 스펙

- 상태: ACCEPTED

## 1. Flutter adapter

```dart
abstract interface class BillingService {
  Future<List<StoreOffering>> loadOfferings();
  Future<PurchaseAttempt> purchase(StorePackage package);
  Future<RestoreAttempt> restore();
  Stream<BillingClientSnapshot> get snapshots;
}
```

`purchases_flutter` type은 adapter 밖으로 노출하지 않는다.

## 2. Initialization

- app boot에서 configuration 가능
- purchase action 전 authenticated KinFlow user 필요
- RevenueCat App User ID login/logout을 auth lifecycle과 일치
- 환경별 API key/product 분리
- debug log에 receipt/PII 금지

## 3. UI 상태

```text
catalogLoading
catalogReady
purchasing
storeSuccessServerPending
active
restoreEmpty
restoreConflict
billingIssue
expired
errorRetryable/errorFinal
```

Store success 직후 Plus를 영구 활성화하지 않고 server confirmation pending을 표시한다.

## 4. Server reconciliation

- webhook primary asynchronous signal
- 필요 시 authenticated refresh endpoint
- customer identity mapping
- provider transaction unique
- authoritative entitlement recompute
- client polling/backoff 제한
- mismatch alert

## 5. Household assignment

구매 전 active household를 확인하고 혜택을 명시한다. 한 구매가 여러 household를 자동으로 유료화하지 않는다. billing household 변경/이전은 정책과 audit가 필요한 command다.

## 6. Feature flags와 limits

서버 response:

```json
{
  "entitlement": "plus",
  "status": "active",
  "validUntil": "...",
  "limits": {
    "members": 10,
    "activeSeries": 100
  },
  "verifiedAt": "..."
}
```

client는 UX에 사용하고 server가 mutation에서 다시 강제한다.

## 7. Restore conflict

같은 store purchase가 다른 KinFlow identity/household에 연결된 경우 임의 이전하지 않는다.

- 현재 연결 상태를 민감 정보 없이 설명
- 중복 purchase 유도 금지
- support/ownership verification path
- manual action audit

## 8. Cancellation/Expiry

사용자가 만든 family data를 즉시 삭제하지 않는다. Plus-only creation/advanced feature를 제한하고 read/export/delete는 유지한다. grace와 billing issue 동안 제품 정책에 맞는 유예를 제공한다.

## 9. Testing

- fake adapter unit tests
- RevenueCat sandbox integration
- Apple Sandbox/TestFlight
- Google license tester/internal track
- webhook local fixture/signature
- reinstall/account/household switching
- refund/revoke/expiry
- network loss after store success
- duplicate tap and transaction

## 10. Store copy

- 가격/기간/자동 갱신
- trial 조건
- household benefit
- restore
- terms/privacy
- cancellation path
- 지역별 store price 사용

하드코딩된 통화 환산을 사용하지 않는다.


---

# 28. CI/CD, 환경, Release 구현 스펙

- 상태: ACCEPTED

## 1. Branch와 environment

- pull request: untrusted, production secret 없음
- main: dev artifact와 docs
- release/*: staging/RC
- production environment: 보호 승인과 최소 secret

## 2. CI jobs

### Fast checks

- format
- analyze fatal warnings
- unit/widget tests
- codegen drift
- secret/license/dependency scan
- Markdown/contract validation

### Backend

- Supabase local start/reset
- migration/lint
- pgTAP/RLS matrix
- Edge Function contract test

### Platform

- Android debug/build
- iOS simulator build on macOS
- scheduled Web build/test
- integration smoke

### RC

- signed IPA/AAB
- artifact checksum/SBOM/provenance
- staging deploy
- manual approval
- Fastlane upload

## 3. Reproducibility

- Flutter exact version via FVM 또는 CI action pin
- `pubspec.lock` commit
- Java/Ruby/CocoaPods/CLI version record
- clean checkout build
- build number source of truth
- environment config checksum

## 4. Configuration

공개 client config:

- Supabase URL/publishable key
- RevenueCat public SDK key
- Sentry DSN
- environment name
- public website/API origin

비밀:

- service role
- webhook secrets
- APNs/server credential
- store API key/private key
- signing keystore/password

비밀을 `--dart-define`이나 repository 파일로 전달하지 않는다.

## 5. Flavor

- Dart entrypoint + native scheme/build variant
- unique display suffix/icon for dev/staging
- separate Firebase config
- separate deep link hosts 또는 path
- production에서 debug menu/verbose log 제거

## 6. Fastlane

권장 lane:

```text
ios beta / ios release / ios metadata
android internal / android release / android metadata
```

Fastlane action과 gem version을 lock하고 CI만으로도 재현 가능하게 한다. 초기에는 자동 production rollout보다 upload + human approval을 사용한다.

## 7. DB deployment

- 앱 binary보다 먼저 backward-compatible expand migration
- new feature flag off
- client rollout
- metrics 확인
- contract migration은 old client 비중 감소 후
- migration failure 시 forward recovery

## 8. Remote config

허용:

- feature flag
- safe limits/copy subset
- minimum supported version
- kill switch

금지:

- Store review를 우회하는 실행 코드 다운로드
- 보안/결제 invariant 변경
- 비밀 전달

## 9. Web deploy

- immutable hashed assets
- atomic deploy
- cache headers 분리
- API contract compatibility
- rollback revision
- CSP/security headers test

## 10. Evidence

- workflow run URL
- commit SHA/tag
- toolchain versions
- test/build reports
- artifact checksum
- signer identity
- migration list
- approval and rollout status


---

# 29. NFR, SLO, 성능, 용량 스펙

- 상태: PROVISIONAL, Beta 측정 후 수치 승인

## 1. 대표 데이터 규모

MVP 성능 fixture:

- household당 active member 2~10
- managed member 0~8
- active chore series 0~200
- event series 0~500
- materialized occurrence 1년 window
- 계정당 household 1~5

과도한 enterprise 규모를 선제 최적화하지 않지만 N+1과 무제한 payload를 허용하지 않는다.

## 2. Client 성능 budget

| 지표 | 목표 예시 |
|---|---|
| warm start to usable shell p95 | ≤ 1.5s representative device |
| cold authenticated Today p95 | ≤ 3.0s stable network |
| interaction frame | 60fps target, visible jank 없음 |
| chore complete perceived feedback | ≤ 150ms optimistic/pending 표시 |
| release Android binary size | baseline 대비 변화 Gate |
| memory | low-memory device에서 task 완료, leak 없음 |

## 3. Server budget

| 지표 | 목표 예시 |
|---|---|
| Today API p95 | ≤ 800ms |
| simple mutation p95 | ≤ 700ms |
| invite accept p95 | ≤ 1.5s |
| entitlement materialization | 99% ≤ 10m |
| notification provider submit | 95% scheduled ±5m |

정확한 정의에는 region/network/cache/data volume을 포함한다.

## 4. Availability와 reliability

- core authenticated read 99.9% monthly target
- critical mutation 99.5% excluding user error
- no silent data loss
- outbox/worker at-least-once + idempotent consumer
- notification push는 best effort, inbox가 durable record

## 5. Capacity

- launch household/user forecast
- daily occurrence materialization량
- push job peak (아침/저녁 local time)
- webhook burst
- DB connection/function concurrency
- storage/export size

Beta 전 load test model과 비용 alarm을 설정한다.

## 6. Mobile network

- payload pagination/compression
- app resume targeted refetch
- reconnect thundering herd jitter
- timeout/cancellation
- retry budget
- large avatar/media는 MVP 비범위

## 7. Battery

- persistent polling 금지
- Realtime screen/lifecycle scoped
- background task 최소화
- server scheduled notification
- location 없음

## 8. Accessibility NFR

- screen reader task success
- text scale 200%
- orientation/split view
- minimum target/contrast
- keyboard/focus for Web/tablet
- motion reduction

## 9. Localization NFR

- EN/KO 100% key coverage
- pseudo locale CI/screenshot
- locale-independent API/date storage
- IANA timezone
- first day/calendar formatting locale-aware
- RTL structural check before RTL locale launch

## 10. Privacy/Security NFR

- household isolation test 100%
- secret scan 0 high
- PII logging test
- deletion/export documented SLA
- backup/restore drill
- dependency critical CVE release Gate

## 11. SLO 운영

각 SLO는 numerator/denominator, exclusions, source, owner, alert, review cadence를 갖는다. 사용자 기반이 작을 때 비율만으로 alert하지 않고 절대 건수와 synthetic test를 함께 사용한다.


---

# 30. 엔지니어링 표준과 코딩 에이전트 규칙

- 상태: ACCEPTED

## 1. 구현 원칙

- 작은 vertical slice
- secure by default
- server-authoritative authz/entitlement
- explicit state와 stable error
- codegen/contract/migration 동기화
- 증거 없는 완료 금지

## 2. Dart/Flutter

- sound null safety
- analyzer fatal warnings
- immutable model 선호
- `dynamic`/unchecked cast 최소화
- BuildContext를 async gap 뒤 무검증 사용 금지
- Widget에 business logic 금지
- provider를 service locator처럼 무분별하게 사용 금지
- error를 catch 후 무시하지 않음
- mounted/cancellation/lifecycle 처리

## 3. Async와 concurrency

- duplicate submit guard
- cancellation과 stale response
- idempotency key
- latest request wins가 안전한 경우만 적용
- stream subscription dispose
- background isolate에서 지원되는 API만 사용
- server timestamp 권위

## 4. Security

- secret/token/PII log 금지
- client role/isPlus 신뢰 금지
- RLS 없는 table 금지
- raw SQL string interpolation 금지
- deep link allowlist
- Webhook 검증
- admin/service role 최소화

## 5. 테스트

새 behavior는 정상/실패/권한/동시성/오프라인 또는 lifecycle 상태 중 관련 항목을 포함한다. mock passing만으로 외부 provider 통합 완료를 주장하지 않는다.

## 6. 문서

변경 시 다음을 함께 갱신한다.

- requirement/decision
- contract/type/schema
- migration
- test matrix
- phase plan/evidence
- changelog/ADR

## 7. 에이전트 실행 규칙

1. 작업 전 관련 문서와 contract를 읽는다.
2. 현재 Phase와 Work Package 범위를 명시한다.
3. 모순/누락은 DECISIONS에 OPEN으로 기록한다.
4. 먼저 테스트/contract 영향 분석을 작성한다.
5. 최소 변경으로 구현한다.
6. 실제 명령을 실행한다.
7. 실패를 해결하거나 정직하게 blocker로 남긴다.
8. 수동 설정을 가짜 값으로 성공 처리하지 않는다.
9. 사용하지 않는 scaffold나 TODO를 대량 생성하지 않는다.
10. 다음 Phase 기능을 선행 구현하지 않는다.

## 8. 금지된 완료 보고

- “코드상 문제 없어 보임”
- “테스트는 실행하지 않았지만 통과할 것”
- “스토어 설정은 나중에”를 완료로 표시
- RLS를 UI 테스트로 대체
- sandbox 없이 결제 완료
- 실제 기기 없이 notification/deep link 완료
- Open decision을 추측해 production default 생성

## 9. PR 설명 형식

- 목적/범위/비범위
- 요구사항/Phase ID
- architecture/security/data impact
- migrations/contracts
- screenshots/evidence
- commands/results
- manual setup
- rollback/recovery
- residual risk

## 10. 코드 리뷰 체크

- household/actor authority
- domain boundary
- error/idempotency/concurrency
- local cache purge
- localization/accessibility
- performance/lifecycle
- package/plugin impact
- observability without PII
- test quality and evidence


---

# KinFlow Flutter 앱 구현 계획 v1.0

- 상태: ACCEPTED
- 원칙: 한 Phase 안에서도 한 번에 하나의 vertical Work Package만 구현한다.

## 1. Phase 지도

| Phase | 목표 | 주요 Gate |
|---|---|---|
| 00 | 제품·연령·국가·가격·기술 차단 결정 | Decision Gate |
| 01 | Flutter/Supabase/CI 기반 | Foundation Gate |
| 02 | 인증·가구·초대·성인 역할 | Household Alpha Gate |
| 03 | 집안일·반복·완료·Today | Chores Value Gate |
| 04 | 공유 일정·반복·예외·시간대 | Calendar Value Gate |
| 05 | 알림·작업 큐·신뢰성·제한된 오프라인 | Reliability Gate |
| 06 | RevenueCat·Store·Household Entitlement | Billing Gate |
| 07 | 삭제·내보내기·보안·접근성·글로벌 | Compliance Gate |
| 08 | 실제 가족 Beta·성능·복구·RC 감사 | Beta Exit Gate |
| 09 | Store 제출·점진 출시·30일 운영 | Mobile Launch Gate |
| 10 | Web Companion Beta와 Desktop 수요 검토 | Independent Expansion Gate |

## 2. 선행 의존성

```text
00 → 01 → 02 → 03 → 04
                  ├→ 05
                  ├→ 06
                  └→ 07
05 + 06 + 07 → 08 → 09 → 10
```

Phase 03과 04의 내부 설계는 병렬 검토 가능하지만, 공통 recurrence/time model을 먼저 합의한다. Billing UI는 Phase 06 전 prototype할 수 있으나 production purchase를 열지 않는다.

Managed Child/child mode는 Store MVP Phase 02~09에서 제외한다. H-05와 법률·Store 검토를 통과한 뒤 P1 계획으로 별도 승인한다(D-013).

## 3. Work Package 규칙

각 Work Package는 다음 산출물을 가진다.

- 요구사항/비범위
- data/RLS/API 영향
- Flutter domain/application/presentation 변경
- automated test
- 실제 기기 또는 수동 검증
- evidence
- rollback/recovery
- traceability 업데이트

권장 크기는 하나의 사용자 task 또는 한 개의 보안 경계다.

## 4. 전 Phase 공통 명령

```text
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test --coverage
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
supabase db reset
DB/RLS/contract tests
```

플랫폼 변경은 관련 iOS/Android build와 실제 기기 smoke를 추가한다.

## 5. Gate 원칙

- 자동 테스트 결과만으로 UX/Store/permission 완료를 주장하지 않는다.
- 수동 console 작업은 evidence가 있어야 통과한다.
- blocker/critical defect 0.
- OPEN decision과 production secret 미준비는 관련 기능을 비활성화한다.
- 다음 Phase를 시작하기 전에 completion report를 작성한다.

## 6. 문서

상세 실행은 `phases/PHASE_XX_*.md`를 따른다. 요구사항 변경은 `DECISIONS.md`, 관련 contract, matrix, Phase 문서를 함께 수정한다.


---

# Phase 00 — 발견과 차단 결정

## 목표

코드를 만들기 전에 누구를 위한 어떤 제품인지, Store·아동·가격·데이터 리전·기술 계정의 되돌리기 어려운 결정을 확정한다.

## Entry

- 제품 비전 초안 존재
- 결정권자와 기술/법률/디자인 owner 식별

## Work Packages

### WP00-01 사용자 문제 인터뷰

- 최소 5~10개 가족의 현재 집안일·일정 관리 방식
- 초대/재방문/알림/갈등 상황
- 부모만 쓰는지 자녀도 직접 쓰는지
- PC/Web 수요와 실제 사용 환경
- 결과를 가설/반증 기준과 함께 기록

### WP00-02 MVP와 성공 기준

- 가장 작은 가치 loop
- Must/Should/Not now
- activation, Week 4 retention, household coordination 지표
- Beta go/stop threshold

### WP00-03 출시 시장과 아동 분류

- 최초 국가
- 스토어 대상 연령
- mixed-audience/Families/Kids 적용 검토
- Managed Child가 독립 계정이 아님을 승인
- 데이터 리전/보관/삭제 검토

### WP00-04 가격과 구독 정책

- Free/Plus limits
- monthly/annual/trial
- purchaser/billing household transfer/restore
- Apple Family Sharing
- 환불/지원 owner

### WP00-05 기술·계정 준비

- Flutter baseline 승인
- Bundle ID/package/domain
- Apple/Google/Supabase/Firebase/RevenueCat/GitHub 조직
- CI macOS runner와 signing ownership

### WP00-06 위험 PoC

실제 작은 PoC로 다음을 검증한다.

- Flutter iOS/Android boot
- Supabase auth callback deep link
- Firebase notification 실제 기기 수신
- RevenueCat sandbox catalog load
- RLS local test

PoC 코드는 production architecture로 간주하지 않는다.

## 자동 검증

- decision ID 중복/OPEN blocker 검사
- source link와 확인일 검사
- PoC build 로그

## 수동 검증

- stakeholder decision review
- store/legal/privacy review
- test account/console 접근 확인

## Exit Gate

- D-013, D-039, D-051 ACCEPTED
- 제품 이름/식별자 owner 결정
- Phase 01 toolchain과 계정 준비
- Risk Register owner 지정
- MVP/비범위 승인
- 성인 대상 Store questionnaire와 법률·Privacy 검토 완료

## Stop 조건

- 자녀 독립 계정이 필수인데 법률/스토어 분류가 미확정
- Store 계정 또는 사업 주체가 없음
- 가격/구독 가치 가설이 전혀 검증되지 않음
- 기술 PoC에서 필수 SDK가 지원 플랫폼에서 동작하지 않음

## Evidence

`evidence/phase-00/`: 인터뷰 요약, decision review, console ownership, PoC build/device 결과.


---

# Phase 01 — Flutter 기반 구축

## 목표

기능 개발 전에 재현 가능한 Flutter 프로젝트, 환경 분리, 코드 경계, Supabase local, CI, 테스트, 디자인·i18n 기반을 완성한다.

## Entry

Phase 00 Gate 통과, 식별자와 toolchain 승인.

## Work Packages

### WP01-01 저장소와 Toolchain

- Flutter SDK 3.44.7 exact pin
- app/public_site/supabase/contracts/docs 구조
- `pubspec.lock`, analysis options
- dev/staging/prod flavor
- README bootstrap 명령

### WP01-02 App Shell

- `main_dev/staging/prod.dart`
- bootstrap과 dependency initialization
- MaterialApp.router/go_router shell
- loading/fatal recovery/environment banner
- theme/locale skeleton

### WP01-03 Architecture Boundary

- domain/application/data/presentation sample slice
- Riverpod override/DI
- repository port와 fake adapter
- architecture import test
- generated model/codegen drift test

### WP01-04 Supabase Local

- CLI pin, config, reset
- baseline migrations/RLS default deny
- seed/test users/households
- Edge Function hello/health contract
- Flutter dev client connectivity

### WP01-05 Design/i18n/a11y

- design tokens
- responsive scaffold compact/medium/expanded
- EN/KO ARB + pseudo locale
- semantics/text-scale smoke

### WP01-06 Observability/config

- structured logger와 redaction
- Sentry dev/staging
- public configuration loader/validator
- no-secret scan

### WP01-07 CI

- format/analyze/test/codegen
- DB/RLS/contract
- Android build
- iOS simulator build
- scheduled Web build
- artifact/test reports

## 자동 검증

- clean checkout bootstrap
- analyzer warning 0
- tests/codegen diff 0
- Supabase reset + RLS smoke
- dev Android APK and iOS simulator build
- dependency boundary import 0

## 수동 검증

- iOS/Android shell 실제 실행
- EN/KO/pseudo/dark/large text
- dev/staging visual separation
- Sentry redaction 확인

## Exit Gate

- onboarding 전 shell이 두 모바일 플랫폼에서 실행
- CI green and reproducible
- environment isolation 확인
- domain이 Flutter/SDK에 의존하지 않음
- evidence와 Phase 02 handoff

## Rollback

기능 데이터가 없으므로 깨끗한 scaffold commit으로 되돌린다. toolchain 변경은 ADR 없이 cherry-pick하지 않는다.


---

# Phase 02 — 인증, 가구, 성인 구성원

## 목표

성인 사용자가 로그인하고 가구를 만들거나 안전한 초대로 가입하며, 역할·Owner 경계를 RLS와 서버 transaction으로 보호한다.

## Entry

Foundation Gate 통과, auth provider/redirect/domain 준비.

## Work Packages

### WP02-01 Auth lifecycle

- sign-in/request/callback/logout/session restore
- secure storage
- auth state machine와 router guard
- offline/expired/revoked session
- account switch purge

### WP02-02 Household schema/RLS

- household/membership/profile migration
- Owner/Admin/Member policies
- composite household integrity
- RLS matrix initial automation

### WP02-03 First household onboarding

- transactional household + owner membership
- name/timezone
- active household state
- empty Today route

### WP02-04 Invite

- random token hash, expiry/revoke/use/rate limit
- Universal/App Link
- login 전후 continuation
- concurrent/idempotent accept
- invite abuse tests

### WP02-05 Role/Owner lifecycle

- admin/member changes
- last owner invariant
- owner transfer
- removed member session/cache/device cleanup
- audit events

### WP02-06 Adult activation handoff

- 초대 수락 후 성인 membership과 active household 확정
- 빈 Today와 첫 집안일 생성으로 이어지는 handoff
- 두 번째 성인의 첫 독립 행동 event 계약
- Managed Child table/route/acting context는 만들지 않고 `FR-CHILD-*`를 P1로 유지

### WP02-07 End-to-end authorization

- outsider/different household/removed/service-role tests
- body/path household injection
- direct CRUD RPC bypass

## 자동 검증

- full Phase 02 RLS matrix
- auth repository/use case/widget tests
- invite concurrency/idempotency/rate limit
- route guard와 account/household switch purge
- migration clean reset

## 수동 검증

- two real accounts/two devices create-invite-accept
- cold-start invite link iOS/Android
- owner transfer/removal
- 두 번째 성인의 초대 수락 후 독립 재진입
- account switch data purge

## Exit Gate

- 두 성인이 같은 가구에 참여 가능
- household isolation 공격 test pass
- 마지막 Owner invariant
- auth/invite deep links 실제 기기 pass

## Stop/Rollback

권한 누출, token replay, cache 잔존 시 다음 Phase 금지. feature flag로 invite를 비활성화하고 migration은 forward fix한다. P1 child surface는 Store MVP에서 존재하지 않아야 한다.


---

# Phase 03 — 집안일과 Today

## 목표

가족이 집안일을 만들고 담당자·마감·반복을 지정하고, Today에서 확인·완료하며 다른 기기와 안전하게 동기화한다.

## Entry

Household Alpha Gate 통과.

## Work Packages

### WP03-01 Chore domain/schema

- series/revision/occurrence 기본 모델
- title/assignee/due/local intent/state
- household integrity/RLS
- domain state transition

### WP03-02 One-time chore

- create/edit/cancel/detail/list
- server validation/error mapping
- adaptive form/UI

### WP03-03 Assignment and members

- adult/managed assignee
- removed/suspended member behavior
- cross-household FK attack

### WP03-04 Completion

- expected version/idempotency
- complete/uncomplete/optional approval 범위
- actor/acting child audit
- duplicate tap/conflict

### WP03-05 Repeating chore

- supported recurrence subset
- revision/occurrence materialization
- single occurrence and future series edit
- time matrix fixtures

### WP03-06 Today chores

- household date/timezone
- ordering/filter/empty/error/stale
- Realtime invalidation or resume refetch
- performance budget

### WP03-07 Notification event hooks

실제 push 전에 due/assignment domain event와 inbox contract를 기록한다.

## 자동 검증

- domain transition
- RLS CRUD/assignment
- recurrence fixtures
- idempotency/version conflict
- Today query/order/pagination
- widget/a11y/large text

## 수동 검증

- two-device assignment/complete
- managed child completion
- timezone/date boundary
- reinstall/resume
- iPad/Android tablet layout

## Exit Gate

두 가족 구성원이 반복 집안일을 만들고 담당하고 완료한 상태가 양쪽 Today에 일관되게 보인다. 완료 history와 recurrence definition이 분리되어 있다.

## Rollback

recurrence를 feature flag off하고 one-time chore를 유지할 수 있어야 한다. materialization repair script와 audit가 준비되어야 한다.


---

# Phase 04 — 공유 일정, 반복, 시간대, Today 통합

## 목표

가족이 종일/시간 지정 일정을 공유하고 반복·예외·참석자를 관리하며, 시간대와 DST에서도 정확한 occurrence를 Today에 통합한다.

## Entry

Chores Value Gate 통과, recurrence time library ADR 승인.

## Work Packages

### WP04-01 Time primitives

- Instant/LocalDate/LocalTime/IANA timezone
- all-day exclusive date range
- DST gap/overlap policy
- serialization contract

### WP04-02 One-time event

- create/edit/delete
- timed/all-day
- household participants
- validation/RLS

### WP04-03 Calendar views

- PRD가 정한 day/month/list scope
- compact/tablet adaptive
- locale first day/date formatting
- accessible navigation

### WP04-04 Recurring event

- series/revision/occurrence/exception
- single edit/cancel
- future/whole series edit
- completed/past preservation policy

### WP04-05 Today integration

- chores/events combined sections
- same household local date
- deterministic ordering
- performance/cache invalidation

### WP04-06 Conflict/concurrency

- expected version
- concurrent edits
- deleted/stale deep link
- Realtime reconnect

## 자동 검증

- TIME_RECURRENCE_TEST_MATRIX 전부
- participant household integrity/RLS
- all-day round trip
- materialization idempotency
- Today cross-context order
- serialization locale independence

## 수동 검증

- DST 대표 timezone device tests
- device timezone travel change
- iOS/Android date picker
- iPad split view
- two-device concurrent edit

## Exit Gate

one-time/recurring/all-day event가 시간대 정책에 따라 안정적으로 표시되고 single occurrence와 series 수정 의미가 분리된다.

## Stop/Rollback

DST fixture 또는 과거 occurrence 보존 실패 시 반복 일정 출시 금지. one-time event만 feature flag로 유지 가능해야 한다.


---

# Phase 05 — 알림, 작업 큐, 신뢰성, 제한된 동기화

## 목표

집안일·일정 알림을 서버에서 신뢰성 있게 생성하고, 모바일 앱의 foreground/background/terminated 상태에서 안전하게 전달하며 네트워크 단절과 중복을 처리한다.

## Entry

Chores/Calendar domain event와 occurrence 안정화.

## Work Packages

### WP05-01 Outbox/job worker

- event/outbox schema
- lease/retry/dead letter
- idempotent handler
- monitoring/replay

### WP05-02 Notification preferences/inbox

- per-type settings
- quiet hours/timezone
- in-app durable inbox
- read/unread/badge

### WP05-03 Device registration

- installation identity
- FCM token lifecycle
- logout/account switch/removal purge
- invalid token cleanup

### WP05-04 Mobile push

- Firebase/APNs config
- permission pre-prompt
- foreground/local presentation
- background/terminated handler
- deep link tap authz

### WP05-05 Reliability

- provider outage/backoff
- duplicate/out-of-order
- stale suppression
- queue alert/SLO

### WP05-06 Offline/read cache

- stale read cache namespace
- logout/household purge
- one safe chore-completion outbox PoC
- membership/session/version/TTL revalidation

Offline mutation이 위험하거나 가치가 낮으면 read-only cache로 남긴다.

## 자동 검증

- queue lease/crash/retry/dead letter
- notification dedupe/quiet hours
- payload privacy
- token rotation/purge
- deep link parser
- outbox auth binding

## 수동 검증

- iOS/Android actual device permission states
- foreground/background/terminated push
- notification tap after resource delete/membership removal
- provider/network outage
- account switch and cache forensic check

## Exit Gate

inbox는 durable하고 push는 중복 폭주 없이 주요 앱 상태에서 동작한다. 서버 worker가 중요한 알림 시간의 권위다. offline 범위가 명시적으로 승인된다.

## Rollback

push worker kill switch, provider pause, pending job quarantine, local completion outbox feature flag가 존재한다.


---

# Phase 06 — 구독과 Household Entitlement

## 목표

App Store/Google Play 구매·복원·갱신·만료·환불을 RevenueCat과 서버가 처리하고, 최종 Plus 권한을 선택된 household에 일관되게 적용한다.

## Entry

가격/limits/restore policy 승인, Store/RevenueCat sandbox 준비.

## Work Packages

### WP06-01 Billing domain/schema

- customer/transaction/event/household entitlement
- state model와 audit
- server feature limit

### WP06-02 Product catalog/paywall

- store local price
- monthly/annual/trial copy
- household benefit
- terms/privacy/restore
- accessibility/localization

### WP06-03 Flutter RevenueCat adapter

- authenticated App User ID
- offerings/purchase/restore
- pending server confirmation
- error mapping

### WP06-04 Webhook/reconciliation

- signature, idempotency, ordering
- transaction/customer upsert
- entitlement materialize
- dead letter/alert

### WP06-05 Household assignment/conflicts

- billing household 선택
- purchaser leaves/owner change
- restore conflict
- manual remediation audit

### WP06-06 Lifecycle/limits

- active/trial/grace/billing issue/expired/refund
- server/client gates
- downgrade data preservation

## 자동 검증

- BILLING_TEST_MATRIX
- adapter fake tests
- webhook duplicate/out-of-order/signature
- entitlement RLS/server enforcement
- account/household mapping

## 수동 검증

- Apple sandbox/TestFlight
- Google license tester/internal track
- purchase/restore/reinstall
- pending network loss
- expiry/refund/grace
- price/localization/store copy

## Exit Gate

Store success와 server entitlement가 분리되어도 사용자가 안전한 pending/recovery 경로를 갖고, 다른 account/household에 Plus가 누출되지 않는다.

## Stop/Rollback

mismatch 또는 중복 결제 위험 시 purchase entry를 remote kill switch로 닫고 기존 entitlement read와 support를 유지한다.


---

# Phase 07 — 개인정보, 보안, 접근성, 글로벌 준비

## 목표

계정/가구 삭제와 내보내기, 보안 hardening, 성인 대상 Store 선언, EN/KO 및 접근성 품질을 Store 제출 수준으로 완성한다.

## Entry

핵심 제품/결제 기능 안정화, 법률/정책 owner 준비.

## Work Packages

### WP07-01 Account deletion

- in-app request/status/cancel 가능 범위
- shared data anonymize/tombstone
- last Owner resolution
- token/device/cache cleanup
- active subscription 안내

### WP07-02 Household deletion/export

- Owner authorization
- async job/status
- short-lived download
- retention/audit
- public deletion request site

### WP07-03 Security hardening

- threat model review
- secret/dependency/SAST
- deep link/webhook/rate limit
- PII log scrub
- local cache forensic

### WP07-04 Deferred child surface audit

- Managed Child/child mode route·schema·marketing surface가 production에 없음
- feature flag와 analytics taxonomy에 child 행동 수집 없음
- 성인 대상 Store questionnaire와 실제 기능·SDK inventory 일치
- P1 child 계약은 G7 blocker가 아니며 별도 Gate 없이는 활성화 금지

### WP07-05 Accessibility

- screen reader core journey
- 200% text
- contrast/focus/touch
- iPad/tablet orientation
- reduced motion

### WP07-06 Globalization

- EN/KO completion
- pseudo locale
- timezone/locale date
- long text/RTL structural
- store metadata draft

### WP07-07 Public site

- Astro static pages
- privacy/terms/support/deletion
- accessible/SEO/readable without JS

## 자동 검증

- deletion/export state tests
- security scans
- PII log fixtures
- localization key coverage
- widget semantics/golden selective
- public site link/form tests

## 수동 검증

- full deletion on two accounts/last Owner
- export content/access expiry
- VoiceOver/TalkBack journey
- deferred child route/flag 노출 점검
- legal/privacy/store questionnaire review

## Exit Gate

계정 삭제와 공개 요청 경로, data purge/anonymization, accessibility core journey, EN/KO, security review가 승인된다.

## Rollback

삭제 pipeline은 기능 flag로 신규 요청을 일시 중단할 수 있으나 이미 접수된 법적 요청을 잃지 않는다. export URL은 즉시 revoke 가능해야 한다.


---

# Phase 08 — 실제 가족 Beta, Hardening, 복구

## 목표

실제 가족 사용으로 제품 가치와 운영 안정성을 검증하고, 성능·업그레이드·백업·장애 대응을 Release Candidate 수준으로 만든다.

## Entry

Compliance Gate 통과, TestFlight/Play closed testing 준비.

## Work Packages

### WP08-01 Beta cohort

- 다양한 가족 형태/기기/timezone
- consent/support channel
- activation/retention/task success
- qualitative interview

### WP08-02 Defect/UX hardening

- support/analytics/crash top issues
- onboarding/invite/reminder friction
- no uncontrolled scope expansion

### WP08-03 Performance/capacity

- representative/large seed
- Today/query/index/profile
- low-memory/startup/binary size
- queue/webhook burst

### WP08-04 Upgrade/migration

- previous build → RC update
- local cache schema
- old/new client with migrated DB
- mandatory update/kill switch

### WP08-05 Backup/recovery

- isolated restore
- RPO/RTO measurement
- recurrence/entitlement/RLS integrity
- worker replay

### WP08-06 Security/incident audit

- threat review
- incident tabletop
- notification/billing/RLS drills
- support access audit

### WP08-07 RC audit

- traceability/evidence
- known issue/risk acceptance
- Store metadata/privacy screenshots
- signed staging candidate

## 자동 검증

full regression matrices, load/performance scripts, upgrade tests, restore verification, dependency/security scan.

## 수동 검증

real family end-to-end, actual devices/tablets, sandbox billing, push, accessibility, recovery/tabletop.

## Exit Gate

- Beta success threshold 충족
- blocker/critical 0
- SLO/alert/runbook 준비
- signed RC candidate
- backup/restore and rollback drill
- launch decision review 승인

## Stop

retention/value 기준 미달, privacy/security risk, entitlement mismatch, unrecoverable migration이면 출시하지 않고 제품/기술 decision으로 돌아간다.


---

# Phase 09 — Store 출시와 출시 후 운영

## 목표

iOS/Android 앱을 정책에 맞게 제출하고 점진 배포하며, 초기 30일 동안 제품·신뢰성·구독 지표를 안정화한다.

## Entry

Beta Exit Gate와 release decision 승인.

## Work Packages

### WP09-01 Production readiness

- production secrets/projects/products
- DB migration/backup
- dashboards/alerts/on-call
- feature flags/kill switch

### WP09-02 Signed build/submission

- clean reproducible IPA/AAB
- checksum/SBOM/provenance
- metadata/screenshots/review account
- Apple/Google policy current check
- Fastlane upload + human review

### WP09-03 Review handling

- reviewer notes
- auth/purchase/delete test path
- rejection evidence and narrow fix
- no unreviewed production behavior

### WP09-04 Staged rollout

- internal/1-5%/10-25%/50%/100%
- crash/auth/Today/mutation/push/billing/support check
- pause/rollback criteria

### WP09-05 72-hour review

- severe incident/security/privacy
- Store reviews/support
- entitlement/notification mismatch
- emergency fix decision

### WP09-06 2-week/30-day review

- activation/retention/paid conversion/refund
- top friction and defect
- SLO/cost/capacity
- roadmap and Web Companion decision

## 자동 검증

production smoke/synthetic, rollout dashboards, store receipt/webhook, migration compatibility.

## 수동 검증

production purchase/restore controlled account, deep link/invite, push, delete/export, support flow, Store listing.

## Exit Gate

30-day review에서 모바일 제품과 운영이 안정화되고, 후속 제품 투자와 Web Companion Gate를 데이터로 결정한다.

## Rollback

rollout pause, server feature flags, previous compatible binary, worker/webhook controls, customer communication과 remediation.


---

# Phase 10 — Web Companion Beta와 Native Desktop 수요 Gate

## 목표

모바일 출시 데이터를 바탕으로 PC 사용 가치가 확인되면 Flutter Web Companion을 제한 공개하고, 네이티브 Desktop은 별도 투자 판단만 수행한다.

## Entry

Mobile 30-day review 완료. Web task/사용자/보안 요구와 owner 승인.

## Work Packages

### WP10-01 Web scope

- login/Today/chores/calendar/family/settings 중 Beta scope
- mobile-only capability와 fallback
- browser/support matrix
- Web paid purchase 여부는 별도 결정

### WP10-02 Web session/security

- HTTPS auth redirect/PKCE
- account/household switch purge
- browser storage/CSP/BFCache
- public site와 app origin/path 분리

### WP10-03 Responsive/keyboard/a11y

- medium/expanded layout
- keyboard/focus/200% zoom/screen reader
- browser history/deep link/refresh

### WP10-04 Deploy/ops

- immutable atomic build
- API contract compatibility
- rollback
- Web SLO/alert/support

### WP10-05 Desktop demand review

- Web desktop active share
- system tray/native notification/offline/kiosk 요구
- plugin support and signing/update cost
- Flutter Windows/macOS/Linux PoC 여부
- explicit build/no-build ADR

## 자동 검증

Flutter Web release build, Playwright core journeys, security headers, logout/cache purge, API compatibility.

## 수동 검증

Chrome/Edge/Firefox/Safari, keyboard/screen reader, shared PC account switch, slow/offline state.

## Exit Gate

Web Companion Beta는 모바일 기능과 독립적으로 운영 가능하고 보안/접근성 기준을 통과한다. Desktop은 데이터가 없으면 명시적으로 보류한다.

## 비범위

- PWA 설치율 KPI
- 초기 Web Push
- 초기 Web paid purchase
- Web SEO/marketing pages
- 자동 Windows/macOS/Linux Store 출시


---



<!-- SOURCE: contracts/toolchain.json -->

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "name": "KinFlow Flutter implementation baseline",
  "version": "1.0",
  "acceptedAt": "2026-07-21",
  "flutter": {
    "channel": "stable",
    "version": "3.44.7",
    "dart": "3.12.2 bundled with Flutter SDK 3.44.7",
    "pinPolicy": "exact toolchain; pubspec.lock committed and frozen in CI"
  },
  "platforms": {
    "tier1": {
      "ios": {
        "productMinimum": "16.0",
        "buildTool": "Xcode 26",
        "formFactors": [
          "iPhone",
          "iPad"
        ]
      },
      "android": {
        "minApi": 24,
        "targetApi": 36,
        "formFactors": [
          "phone",
          "tablet"
        ]
      }
    },
    "tier2": {
      "web": {
        "purpose": "companion after mobile launch",
        "browsers": [
          "Chrome stable",
          "Edge stable",
          "Firefox stable",
          "Safari stable"
        ],
        "pwaIsPrimaryStrategy": false
      }
    },
    "deferred": [
      "Windows native",
      "macOS native",
      "Linux native"
    ]
  },
  "client": {
    "state": [
      "flutter_riverpod",
      "riverpod_annotation"
    ],
    "routing": "go_router",
    "models": [
      "freezed",
      "json_serializable"
    ],
    "backend": "supabase_flutter",
    "billing": "purchases_flutter",
    "push": [
      "firebase_core",
      "firebase_messaging",
      "flutter_local_notifications"
    ],
    "secureStorage": "flutter_secure_storage",
    "observability": "sentry_flutter",
    "localization": "Flutter gen_l10n + ARB"
  },
  "backend": {
    "database": "Supabase PostgreSQL",
    "authorization": "PostgreSQL RLS plus transactional RPC/Edge authorization",
    "auth": "Supabase Auth",
    "edgeFunctions": "TypeScript/Deno",
    "migrations": "Supabase CLI migrations only"
  },
  "testing": {
    "unitWidget": [
      "flutter_test",
      "mocktail"
    ],
    "integration": "integration_test",
    "mobileE2e": "Maestro",
    "webE2e": "Playwright",
    "database": [
      "pgTAP",
      "RLS authorization matrix"
    ]
  },
  "delivery": {
    "ci": "GitHub Actions",
    "storeAutomation": "Fastlane with human production approval",
    "iosArtifact": "IPA",
    "androidArtifact": "AAB",
    "web": "immutable atomic deployment",
    "runtimeCodePush": "not in MVP baseline"
  },
  "policies": {
    "domainMustNotImportFlutterOrSdk": true,
    "generatedCodeCommitted": true,
    "codegenDiffMustBeClean": true,
    "serverAuthoritativeAuthorization": true,
    "serverAuthoritativeEntitlement": true,
    "serverAuthoritativeOccurrenceMaterialization": true,
    "noSecretInDartDefine": true,
    "desktopRequiresDemandGate": true
  }
}
```


---



<!-- SOURCE: contracts/architecture-rules.yaml -->

```yaml
version: 1
layers:
  presentation:
    may_import: [application, domain, design_system]
    forbidden_direct_imports: [supabase_flutter, purchases_flutter, firebase_messaging]
  application:
    may_import: [domain]
    forbidden_imports: [flutter_widgets, supabase_flutter, purchases_flutter, firebase_messaging]
  domain:
    may_import: [dart_core]
    forbidden_imports: [flutter, riverpod, supabase_flutter, purchases_flutter, firebase_core, dart_html]
  data:
    may_import: [application, domain, approved_sdk_adapters]
policies:
  dto_must_not_escape_data_layer: true
  widget_must_not_call_sdk_directly: true
  server_authoritative_household_and_entitlement: true
  generated_files_committed: true
```


---



<!-- SOURCE: contracts/analysis_options.yaml -->

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    always_declare_return_types: true
    always_use_package_imports: true
    avoid_dynamic_calls: true
    avoid_print: true
    cancel_subscriptions: true
    close_sinks: true
    discarded_futures: true
    only_throw_errors: true
    prefer_final_locals: true
    sort_constructors_first: true
    unawaited_futures: true
    use_build_context_synchronously: true
```


---



<!-- SOURCE: contracts/pubspec.yaml.example -->

```text
name: kinflow_app
publish_to: none
version: 0.0.0+1

environment:
  sdk: ">=3.12.0 <4.0.0"

# Scaffold example only. In Phase 01 use `flutter pub add` to resolve packages
# compatible with Flutter SDK 3.44.7, then commit exact pubspec.lock.
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: any
  riverpod_annotation: any
  go_router: any
  freezed_annotation: any
  json_annotation: any
  supabase_flutter: any
  purchases_flutter: any
  firebase_core: any
  firebase_messaging: any
  flutter_local_notifications: any
  flutter_secure_storage: any
  sentry_flutter: any
  intl: any

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: any
  build_runner: any
  freezed: any
  json_serializable: any
  riverpod_generator: any
  mocktail: any

flutter:
  uses-material-design: true
  generate: true
```


---



<!-- SOURCE: contracts/types.dart -->

```dart
// Normative examples. Generate concrete DTOs from the accepted API contract.

typedef UserId = String;
typedef HouseholdId = String;
typedef MembershipId = String;
typedef ManagedMemberId = String;
typedef OccurrenceId = String;
typedef RequestId = String;

enum HouseholdRole { owner, admin, member }
enum MembershipStatus { active, invited, removed, suspended }
enum EntitlementStatus {
  inactive,
  trialing,
  active,
  gracePeriod,
  billingIssue,
  expired,
  revoked,
}

sealed class KinFlowFailure {
  const KinFlowFailure({required this.code, this.requestId});
  final String code;
  final RequestId? requestId;
}

final class ValidationFailure extends KinFlowFailure {
  const ValidationFailure({required super.code, super.requestId, this.fields = const {}});
  final Map<String, String> fields;
}

final class AuthorizationFailure extends KinFlowFailure {
  const AuthorizationFailure({required super.code, super.requestId});
}

final class VersionConflictFailure extends KinFlowFailure {
  const VersionConflictFailure({required super.code, super.requestId, required this.latestVersion});
  final int latestVersion;
}

sealed class Result<T, F> {
  const Result();
}

final class Success<T, F> extends Result<T, F> {
  const Success(this.value);
  final T value;
}

final class Failure<T, F> extends Result<T, F> {
  const Failure(this.error);
  final F error;
}

final class HouseholdEntitlementSnapshot {
  const HouseholdEntitlementSnapshot({
    required this.householdId,
    required this.key,
    required this.status,
    required this.verifiedAt,
    this.validUntil,
  });
  final HouseholdId householdId;
  final String key;
  final EntitlementStatus status;
  final DateTime verifiedAt;
  final DateTime? validUntil;
}
```


---



<!-- SOURCE: contracts/error-catalog.yaml -->

```yaml
version: "2026-07-21"
envelope:
  code: stable machine code
  messageKey: client localization key
  retryable: boolean
  requestId: correlation UUID
  details: allowlisted structured data only
errors:
  - code: VALIDATION_FAILED
    httpStatus: 400
    retryable: false
    messageKey: errors.validationFailed
  - code: CONTRACT_MISMATCH
    httpStatus: 502
    retryable: false
    messageKey: errors.contractMismatch
  - code: AUTH_REQUIRED
    httpStatus: 401
    retryable: false
    messageKey: errors.authRequired
  - code: SESSION_EXPIRED
    httpStatus: 401
    retryable: true
    messageKey: errors.sessionExpired
  - code: RECENT_AUTH_REQUIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.recentAuthRequired
  - code: PERMISSION_DENIED
    httpStatus: 403
    retryable: false
    messageKey: errors.permissionDenied
  - code: NOT_FOUND_OR_FORBIDDEN
    httpStatus: 404
    retryable: false
    messageKey: errors.notFound
  - code: HOUSEHOLD_NOT_FOUND
    httpStatus: 404
    retryable: false
    messageKey: errors.householdNotFound
  - code: NOT_HOUSEHOLD_MEMBER
    httpStatus: 403
    retryable: false
    messageKey: errors.notHouseholdMember
  - code: ROLE_NOT_ALLOWED
    httpStatus: 403
    retryable: false
    messageKey: errors.roleNotAllowed
  - code: LAST_OWNER_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.lastOwnerRequired
  - code: OWNER_TRANSFER_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.ownerTransferRequired
  - code: INVITE_INVALID
    httpStatus: 404
    retryable: false
    messageKey: errors.inviteInvalid
  - code: INVITE_EXPIRED
    httpStatus: 410
    retryable: false
    messageKey: errors.inviteExpired
  - code: INVITE_REVOKED
    httpStatus: 410
    retryable: false
    messageKey: errors.inviteRevoked
  - code: INVITE_ALREADY_USED
    httpStatus: 409
    retryable: false
    messageKey: errors.inviteAlreadyUsed
  - code: INVITE_EMAIL_MISMATCH
    httpStatus: 403
    retryable: false
    messageKey: errors.inviteEmailMismatch
  - code: INVITE_LIMIT_REACHED
    httpStatus: 409
    retryable: false
    messageKey: errors.inviteLimitReached
  - code: ACTING_CONTEXT_INVALID
    httpStatus: 403
    retryable: false
    messageKey: errors.actingContextInvalid
  - code: ACTING_CONTEXT_EXPIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.actingContextExpired
  - code: PARENTAL_GATE_REQUIRED
    httpStatus: 403
    retryable: false
    messageKey: errors.parentalGateRequired
  - code: VERSION_CONFLICT
    httpStatus: 409
    retryable: false
    messageKey: errors.versionConflict
  - code: IDEMPOTENCY_KEY_REQUIRED
    httpStatus: 400
    retryable: false
    messageKey: errors.idempotencyKeyRequired
  - code: IDEMPOTENCY_KEY_REUSED
    httpStatus: 409
    retryable: false
    messageKey: errors.idempotencyKeyReused
  - code: OPERATION_IN_PROGRESS
    httpStatus: 409
    retryable: true
    messageKey: errors.operationInProgress
  - code: INVALID_STATE_TRANSITION
    httpStatus: 409
    retryable: false
    messageKey: errors.invalidStateTransition
  - code: RECURRENCE_RULE_INVALID
    httpStatus: 400
    retryable: false
    messageKey: errors.recurrenceRuleInvalid
  - code: RECURRENCE_LIMIT_EXCEEDED
    httpStatus: 422
    retryable: false
    messageKey: errors.recurrenceLimitExceeded
  - code: RESOURCE_LIMIT_EXCEEDED
    httpStatus: 422
    retryable: false
    messageKey: errors.resourceLimitExceeded
  - code: FEATURE_DISABLED
    httpStatus: 403
    retryable: false
    messageKey: errors.featureDisabled
  - code: PLAN_LIMIT_REACHED
    httpStatus: 402
    retryable: false
    messageKey: errors.planLimitReached
  - code: ENTITLEMENT_REQUIRED
    httpStatus: 402
    retryable: false
    messageKey: errors.entitlementRequired
  - code: ENTITLEMENT_PENDING
    httpStatus: 409
    retryable: true
    messageKey: errors.entitlementPending
  - code: BILLING_ASSIGNMENT_CONFLICT
    httpStatus: 409
    retryable: false
    messageKey: errors.billingAssignmentConflict
  - code: PURCHASE_CANCELLED
    httpStatus: 409
    retryable: false
    messageKey: errors.purchaseCancelled
  - code: PROVIDER_UNAVAILABLE
    httpStatus: 503
    retryable: true
    messageKey: errors.providerUnavailable
  - code: NOTIFICATION_PERMISSION_REQUIRED
    httpStatus: 409
    retryable: false
    messageKey: errors.notificationPermissionRequired
  - code: CAPABILITY_UNSUPPORTED
    httpStatus: 501
    retryable: false
    messageKey: errors.capabilityUnsupported
  - code: PRIVACY_REQUEST_ALREADY_PENDING
    httpStatus: 409
    retryable: false
    messageKey: errors.privacyRequestAlreadyPending
  - code: RATE_LIMITED
    httpStatus: 429
    retryable: true
    messageKey: errors.rateLimited
  - code: TEMPORARILY_UNAVAILABLE
    httpStatus: 503
    retryable: true
    messageKey: errors.temporarilyUnavailable
  - code: INTERNAL_ERROR
    httpStatus: 500
    retryable: true
    messageKey: errors.internal
```


---



<!-- SOURCE: contracts/domain-events.yaml -->

```yaml
version: "2026-07-21"
delivery: at-least-once
envelope:
  eventId: uuid
  eventType: string
  eventVersion: positive integer
  occurredAt: ISO-8601 UTC timestamp
  householdId: uuid or null
  actorUserId: uuid or null
  actorMemberId: uuid or null
  actingMemberId: uuid or null
  aggregateType: string
  aggregateId: uuid
  aggregateVersion: integer or null
  correlationId: uuid
  causationId: uuid or null
  payload: event-specific object
rules:
  - Consumers MUST deduplicate by eventId.
  - Events are immutable and may arrive late or out of order.
  - Payloads MUST NOT contain secrets, raw invite tokens, push tokens, receipts, or free-form user content unless explicitly approved.
  - Breaking payload changes require a new eventVersion and migration strategy.
events:
  household.created: {version: 1, aggregate: household}
  household.updated: {version: 1, aggregate: household}
  household.deletion_requested: {version: 1, aggregate: household}
  household.deleted: {version: 1, aggregate: household}
  household.owner_transferred: {version: 1, aggregate: household}
  member.joined: {version: 1, aggregate: household_member}
  member.role_changed: {version: 1, aggregate: household_member}
  member.removed: {version: 1, aggregate: household_member}
  managed_child.created: {version: 1, aggregate: household_member}
  managed_child.updated: {version: 1, aggregate: household_member}
  managed_child.deleted: {version: 1, aggregate: household_member}
  invite.created: {version: 1, aggregate: household_invite}
  invite.accepted: {version: 1, aggregate: household_invite}
  invite.revoked: {version: 1, aggregate: household_invite}
  chore.series_created: {version: 1, aggregate: chore_series}
  chore.series_revised: {version: 1, aggregate: chore_series}
  chore.series_deleted: {version: 1, aggregate: chore_series}
  chore.occurrence_completed: {version: 1, aggregate: chore_occurrence}
  chore.occurrence_reopened: {version: 1, aggregate: chore_occurrence}
  chore.occurrence_skipped: {version: 1, aggregate: chore_occurrence}
  calendar.series_created: {version: 1, aggregate: event_series}
  calendar.series_revised: {version: 1, aggregate: event_series}
  calendar.occurrence_overridden: {version: 1, aggregate: event_occurrence}
  calendar.occurrence_cancelled: {version: 1, aggregate: event_occurrence}
  notification.intent_created: {version: 1, aggregate: notification_intent}
  notification.delivery_succeeded: {version: 1, aggregate: notification_delivery}
  notification.delivery_failed: {version: 1, aggregate: notification_delivery}
  billing.purchase_synced: {version: 1, aggregate: billing_customer}
  billing.household_assigned: {version: 1, aggregate: billing_household_assignment}
  billing.household_unassigned: {version: 1, aggregate: billing_household_assignment}
  billing.entitlement_changed: {version: 1, aggregate: household_entitlement}
  privacy.export_requested: {version: 1, aggregate: privacy_request}
  privacy.deletion_requested: {version: 1, aggregate: privacy_request}
  privacy.request_completed: {version: 1, aggregate: privacy_request}
  security.kill_switch_changed: {version: 1, aggregate: kill_switch}
```


---



<!-- SOURCE: contracts/openapi-edge.yaml -->

```yaml
openapi: 3.1.0
info:
  title: KinFlow Edge API
  version: "2026-07-21"
  description: >-
    Normative contract for transactional and provider-backed operations.
    Simple RLS-protected reads/writes may use Supabase Data API and are not duplicated here.
servers:
  - url: https://{projectRef}.supabase.co/functions/v1/api
    variables:
      projectRef:
        default: example
security:
  - bearerAuth: []
tags:
  - name: Household
  - name: Invite
  - name: Member
  - name: Chore
  - name: Calendar
  - name: Today
  - name: Notification
  - name: Billing
  - name: Privacy
paths:
  /households:
    post:
      tags: [Household]
      operationId: createHousehold
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateHouseholdRequest'
      responses:
        '201':
          $ref: '#/components/responses/HouseholdResponse'
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '401': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/invites:
    post:
      tags: [Invite]
      operationId: createInvite
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateInviteRequest'
      responses:
        '201': {$ref: '#/components/responses/InviteResponse'}
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /invites/preview:
    post:
      tags: [Invite]
      security: []
      operationId: previewInvite
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/InviteTokenRequest'
      responses:
        '200': {$ref: '#/components/responses/InvitePreviewResponse'}
        '404': {$ref: '#/components/responses/ErrorResponse'}
        '410': {$ref: '#/components/responses/ErrorResponse'}
        '429': {$ref: '#/components/responses/ErrorResponse'}
  /invites/accept:
    post:
      tags: [Invite]
      operationId: acceptInvite
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/AcceptInviteRequest'
      responses:
        '200': {$ref: '#/components/responses/MemberResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '410': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/owner-transfer:
    post:
      tags: [Household, Member]
      operationId: transferHouseholdOwner
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [newOwnerMemberId, expectedVersion]
              properties:
                newOwnerMemberId: {$ref: '#/components/schemas/Uuid'}
                expectedVersion: {type: integer, minimum: 1}
      responses:
        '200': {$ref: '#/components/responses/HouseholdResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/members/{memberId}/role:
    put:
      tags: [Member]
      operationId: changeMemberRole
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/MemberId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [role, expectedVersion]
              properties:
                role:
                  $ref: '#/components/schemas/AdultRole'
                expectedVersion: {type: integer, minimum: 1}
      responses:
        '200': {$ref: '#/components/responses/MemberResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/acting-contexts:
    post:
      tags: [Member]
      operationId: createActingContext
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [managedChildMemberId]
              properties:
                managedChildMemberId: {$ref: '#/components/schemas/Uuid'}
                deviceBinding: {type: string, minLength: 16, maxLength: 256}
      responses:
        '201':
          description: Acting context created
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/ActingContext'
        '403': {$ref: '#/components/responses/ErrorResponse'}
  /chores/occurrences/{occurrenceId}/complete:
    post:
      tags: [Chore]
      operationId: completeChoreOccurrence
      parameters:
        - $ref: '#/components/parameters/OccurrenceId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [expectedVersion]
              properties:
                expectedVersion: {type: integer, minimum: 1}
                completedAtClient: {type: string, format: date-time}
      responses:
        '200': {$ref: '#/components/responses/ChoreOccurrenceResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /chores/series/{seriesId}:
    put:
      tags: [Chore]
      operationId: reviseChoreSeries
      parameters:
        - $ref: '#/components/parameters/SeriesId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviseSeriesRequest'
      responses:
        '200': {$ref: '#/components/responses/SeriesResponse'}
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /calendar/series/{seriesId}:
    put:
      tags: [Calendar]
      operationId: reviseCalendarSeries
      parameters:
        - $ref: '#/components/parameters/SeriesId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviseSeriesRequest'
      responses:
        '200': {$ref: '#/components/responses/SeriesResponse'}
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /today:
    get:
      tags: [Today]
      operationId: getToday
      parameters:
        - $ref: '#/components/parameters/HouseholdIdQuery'
        - name: localDate
          in: query
          required: true
          schema: {type: string, format: date}
        - name: limit
          in: query
          schema: {type: integer, minimum: 1, maximum: 500, default: 200}
      responses:
        '200':
          description: Today aggregate
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/TodayPayload'
        '403': {$ref: '#/components/responses/ErrorResponse'}
  /notification-endpoints:
    post:
      tags: [Notification]
      operationId: registerNotificationEndpoint
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/NotificationEndpointRequest'
      responses:
        '200':
          description: Endpoint registered or rotated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessEnvelope'
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /billing/sync:
    post:
      tags: [Billing]
      operationId: syncBillingCustomer
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [provider, householdId]
              properties:
                provider: {type: string, enum: [appStore, playStore, web]}
                householdId: {$ref: '#/components/schemas/Uuid'}
      responses:
        '200': {$ref: '#/components/responses/EntitlementResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
  /billing/assign-household:
    post:
      tags: [Billing]
      operationId: assignBillingHousehold
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [householdId, expectedEntitlementVersion]
              properties:
                householdId: {$ref: '#/components/schemas/Uuid'}
                expectedEntitlementVersion: {type: integer, minimum: 0}
      responses:
        '200': {$ref: '#/components/responses/EntitlementResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /webhooks/revenuecat:
    post:
      tags: [Billing]
      security:
        - webhookAuth: []
      operationId: receiveRevenueCatWebhook
      requestBody:
        required: true
        content:
          application/json:
            schema: {type: object, additionalProperties: true}
      responses:
        '202': {description: Receipt accepted for idempotent processing}
        '401': {$ref: '#/components/responses/ErrorResponse'}
        '409': {description: Duplicate receipt already accepted}
  /privacy/requests:
    post:
      tags: [Privacy]
      operationId: createPrivacyRequest
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [type]
              properties:
                type: {type: string, enum: [export, deleteAccount, deleteHousehold]}
                householdId: {$ref: '#/components/schemas/Uuid'}
      responses:
        '202':
          description: Request accepted
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/PrivacyRequest'
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /privacy/requests/{requestId}:
    get:
      tags: [Privacy]
      operationId: getPrivacyRequest
      parameters:
        - name: requestId
          in: path
          required: true
          schema: {$ref: '#/components/schemas/Uuid'}
      responses:
        '200':
          description: Privacy request status
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/PrivacyRequest'
        '404': {$ref: '#/components/responses/ErrorResponse'}
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    webhookAuth:
      type: apiKey
      in: header
      name: Authorization
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: true
      schema: {type: string, minLength: 16, maxLength: 200}
    RecentAuth:
      name: X-KinFlow-Recent-Auth
      in: header
      required: true
      schema: {type: string, minLength: 16, maxLength: 2048}
    ActingContext:
      name: X-KinFlow-Acting-Context
      in: header
      required: false
      schema: {type: string, minLength: 16, maxLength: 2048}
    HouseholdId:
      name: householdId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    HouseholdIdQuery:
      name: householdId
      in: query
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    MemberId:
      name: memberId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    OccurrenceId:
      name: occurrenceId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    SeriesId:
      name: seriesId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
  schemas:
    Uuid: {type: string, format: uuid}
    AdultRole: {type: string, enum: [owner, admin, member]}
    ErrorEnvelope:
      type: object
      additionalProperties: false
      required: [error]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, messageKey, retryable, requestId]
          properties:
            code: {type: string}
            messageKey: {type: string}
            details: {type: object, additionalProperties: true}
            retryable: {type: boolean}
            requestId: {$ref: '#/components/schemas/Uuid'}
    SuccessEnvelope:
      type: object
      required: [data, meta]
      properties:
        data: {}
        meta:
          type: object
          required: [requestId, contractVersion]
          properties:
            requestId: {$ref: '#/components/schemas/Uuid'}
            contractVersion: {type: string, const: '2026-07-21'}
    CreateHouseholdRequest:
      type: object
      additionalProperties: false
      required: [name, timezone]
      properties:
        name: {type: string, minLength: 1, maxLength: 80}
        timezone: {type: string, minLength: 1, maxLength: 100}
    Household:
      type: object
      required: [id, name, timezone, ownerMemberId, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        name: {type: string}
        timezone: {type: string}
        ownerMemberId: {$ref: '#/components/schemas/Uuid'}
        version: {type: integer, minimum: 1}
    CreateInviteRequest:
      type: object
      additionalProperties: false
      required: [role]
      properties:
        role: {type: string, enum: [admin, member]}
        targetEmail: {type: string, format: email}
        expiresInHours: {type: integer, minimum: 1, maximum: 720, default: 168}
    InviteTokenRequest:
      type: object
      additionalProperties: false
      properties:
        token: {type: string, minLength: 20, maxLength: 512}
        shortCode: {type: string, minLength: 6, maxLength: 16}
      anyOf:
        - required: [token]
        - required: [shortCode]
    AcceptInviteRequest:
      allOf:
        - $ref: '#/components/schemas/InviteTokenRequest'
        - type: object
          properties:
            setActiveHousehold: {type: boolean, default: true}
    Invite:
      type: object
      required: [id, householdId, role, expiresAt, status]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        role: {type: string, enum: [admin, member]}
        expiresAt: {type: string, format: date-time}
        status: {type: string, enum: [active, accepted, revoked, expired]}
        rawToken:
          type: string
          description: Returned only once at creation and never stored in plaintext.
    InvitePreview:
      type: object
      required: [valid, role]
      properties:
        valid: {type: boolean}
        householdDisplayName: {type: string}
        role: {type: string, enum: [admin, member]}
        expiresAt: {type: string, format: date-time}
    Member:
      type: object
      required: [id, householdId, displayName, role, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        authUserId: {$ref: '#/components/schemas/Uuid'}
        displayName: {type: string}
        role: {type: string, enum: [owner, admin, member, managedChild]}
        version: {type: integer, minimum: 1}
    ActingContext:
      type: object
      required: [contextToken, householdId, actingMemberId, expiresAt]
      properties:
        contextToken: {type: string}
        householdId: {$ref: '#/components/schemas/Uuid'}
        actingMemberId: {$ref: '#/components/schemas/Uuid'}
        expiresAt: {type: string, format: date-time}
    RecurrenceEnd:
      oneOf:
        - type: object
          additionalProperties: false
          required: [type]
          properties: {type: {const: never}}
        - type: object
          additionalProperties: false
          required: [type, count]
          properties:
            type: {const: count}
            count: {type: integer, minimum: 1, maximum: 1000}
        - type: object
          additionalProperties: false
          required: [type, localDate]
          properties:
            type: {const: until}
            localDate: {type: string, format: date}
    RecurrenceRule:
      oneOf:
        - type: object
          additionalProperties: false
          required: [frequency, interval, end]
          properties:
            frequency: {const: daily}
            interval: {type: integer, minimum: 1, maximum: 30}
            end: {$ref: '#/components/schemas/RecurrenceEnd'}
        - type: object
          additionalProperties: false
          required: [frequency, interval, weekdays, end]
          properties:
            frequency: {const: weekly}
            interval: {type: integer, minimum: 1, maximum: 30}
            weekdays:
              type: array
              minItems: 1
              uniqueItems: true
              items: {type: string, enum: [MO, TU, WE, TH, FR, SA, SU]}
            end: {$ref: '#/components/schemas/RecurrenceEnd'}
        - type: object
          additionalProperties: false
          required: [frequency, interval, monthDay, end]
          properties:
            frequency: {const: monthly}
            interval: {type: integer, minimum: 1, maximum: 30}
            monthDay: {type: integer, minimum: 1, maximum: 31}
            end: {$ref: '#/components/schemas/RecurrenceEnd'}
    ReviseSeriesRequest:
      type: object
      additionalProperties: false
      required: [scope, expectedVersion, patch]
      properties:
        scope: {type: string, enum: [thisOccurrence, entireSeries]}
        occurrenceId: {$ref: '#/components/schemas/Uuid'}
        expectedVersion: {type: integer, minimum: 1}
        patch: {type: object, additionalProperties: true}
    ChoreOccurrence:
      type: object
      required: [id, householdId, status, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        status: {type: string, enum: [scheduled, completed, skipped, cancelled]}
        dueDate: {type: string, format: date}
        dueAt: {type: string, format: date-time}
        version: {type: integer, minimum: 1}
    SeriesSummary:
      type: object
      required: [id, householdId, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        version: {type: integer, minimum: 1}
    TodayPayload:
      type: object
      required: [householdId, localDate, householdTimezone, chores, events]
      properties:
        householdId: {$ref: '#/components/schemas/Uuid'}
        localDate: {type: string, format: date}
        householdTimezone: {type: string}
        chores: {type: array, maxItems: 500, items: {$ref: '#/components/schemas/ChoreOccurrence'}}
        events: {type: array, maxItems: 500, items: {type: object, additionalProperties: true}}
        generatedAt: {type: string, format: date-time}
    NotificationEndpointRequest:
      type: object
      additionalProperties: false
      required: [channel, platform, installationId, tokenOrEndpoint, permissionState]
      properties:
        channel: {type: string, enum: [nativePush, webPush]}
        platform: {type: string, enum: [ios, android, web]}
        installationId: {type: string, minLength: 16, maxLength: 200}
        tokenOrEndpoint: {type: string, minLength: 16, maxLength: 4096}
        permissionState: {type: string, enum: [granted, denied, prompt, unsupported]}
        locale: {type: string}
        timezone: {type: string}
        appVersion: {type: string}
        runtimeVersion: {type: string}
    Entitlement:
      type: object
      required: [householdId, plan, status, features, verifiedAt, version]
      properties:
        householdId: {$ref: '#/components/schemas/Uuid'}
        plan: {type: string, enum: [free, plus]}
        status: {type: string, enum: [none, trialing, active, grace, billingIssue, expired, revoked]}
        features: {type: object, additionalProperties: {oneOf: [{type: boolean}, {type: number}]}}
        verifiedAt: {type: string, format: date-time}
        version: {type: integer, minimum: 0}
    PrivacyRequest:
      type: object
      required: [id, type, status, createdAt]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        type: {type: string, enum: [export, deleteAccount, deleteHousehold]}
        status: {type: string, enum: [queued, verifying, processing, completed, failed, cancelled]}
        createdAt: {type: string, format: date-time}
        completedAt: {type: string, format: date-time}
  responses:
    ErrorResponse:
      description: Stable error envelope
      content:
        application/json:
          schema: {$ref: '#/components/schemas/ErrorEnvelope'}
    HouseholdResponse:
      description: Household result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Household'}
    InviteResponse:
      description: Invite result; rawToken is returned once on create
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Invite'}
    InvitePreviewResponse:
      description: Minimal public preview
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/InvitePreview'}
    MemberResponse:
      description: Household member result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Member'}
    ChoreOccurrenceResponse:
      description: Chore occurrence result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/ChoreOccurrence'}
    SeriesResponse:
      description: Series result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/SeriesSummary'}
    EntitlementResponse:
      description: Authoritative household entitlement
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Entitlement'}
```


---



<!-- SOURCE: contracts/database-schema.sql -->

```sql
-- KinFlow core PostgreSQL schema contract v1.0
-- This is a normative implementation skeleton, not a substitute for ordered migrations.
-- Production changes MUST be split into forward-only Supabase migrations.
-- D-013: managed_child, member_guardians, and acting_contexts are P1 reference only.
-- Do not include those surfaces in Store MVP migrations without a separate P1 approval.

create extension if not exists pgcrypto;
create schema if not exists app_private;

create type public.household_role as enum ('owner', 'admin', 'member', 'managed_child');
create type public.invite_status as enum ('active', 'accepted', 'revoked', 'expired');
create type public.occurrence_status as enum ('scheduled', 'completed', 'skipped', 'cancelled');
create type public.job_status as enum ('queued', 'claimed', 'running', 'retry_wait', 'succeeded', 'dead_letter', 'cancelled');
create type public.delivery_status as enum ('pending', 'sending', 'succeeded', 'failed', 'dead_letter', 'cancelled');
create type public.entitlement_status as enum ('none', 'trialing', 'active', 'grace', 'billing_issue', 'expired', 'revoked');
create type public.privacy_request_type as enum ('export', 'delete_account', 'delete_household');
create type public.privacy_request_status as enum ('queued', 'verifying', 'processing', 'completed', 'failed', 'cancelled');

create or replace function app_private.set_updated_at_and_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    new.version := old.version + 1;
  end if;
  return new;
end;
$$;

revoke all on function app_private.set_updated_at_and_version() from public;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  locale text not null default 'en' check (char_length(locale) between 2 and 20),
  timezone text not null default 'UTC' check (char_length(timezone) between 1 and 100),
  avatar_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  timezone text not null check (char_length(timezone) between 1 and 100),
  owner_member_id uuid not null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (id, owner_member_id)
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null,
  display_name text not null check (char_length(display_name) between 1 and 80),
  role public.household_role not null,
  avatar_key text,
  joined_at timestamptz not null default now(),
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  removed_at timestamptz,
  unique (household_id, id),
  constraint managed_child_identity_ck check (
    (role = 'managed_child' and auth_user_id is null)
    or (role <> 'managed_child' and auth_user_id is not null)
  )
);

create unique index household_members_active_auth_uq
  on public.household_members(household_id, auth_user_id)
  where auth_user_id is not null and removed_at is null;

create unique index household_members_single_owner_uq
  on public.household_members(household_id)
  where role = 'owner' and removed_at is null;

alter table public.households
  add constraint households_owner_same_household_fk
  foreign key (id, owner_member_id)
  references public.household_members(household_id, id)
  deferrable initially deferred;

create table public.user_active_households (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  member_id uuid not null,
  updated_at timestamptz not null default now(),
  constraint active_household_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id) on delete cascade
);

create table public.member_guardians (
  household_id uuid not null references public.households(id) on delete cascade,
  guardian_member_id uuid not null,
  managed_child_member_id uuid not null,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (household_id, guardian_member_id, managed_child_member_id),
  constraint guardian_member_fk foreign key (household_id, guardian_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint guardian_child_fk foreign key (household_id, managed_child_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint different_guardian_child_ck check (guardian_member_id <> managed_child_member_id)
);

create table public.acting_contexts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  authenticated_user_id uuid not null references auth.users(id) on delete cascade,
  actor_member_id uuid not null,
  acting_member_id uuid not null,
  device_binding_hash bytea,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint acting_actor_member_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint acting_child_member_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id) on delete cascade,
  constraint acting_different_member_ck check (actor_member_id <> acting_member_id)
);

create index acting_contexts_lookup_idx
  on public.acting_contexts(authenticated_user_id, household_id, expires_at)
  where revoked_at is null;

create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  role public.household_role not null check (role in ('admin', 'member')),
  token_hash bytea not null unique,
  short_code_hash bytea unique,
  target_email_hash bytea,
  status public.invite_status not null default 'active',
  expires_at timestamptz not null,
  max_uses integer not null default 1 check (max_uses between 1 and 50),
  used_count integer not null default 0 check (used_count >= 0 and used_count <= max_uses),
  created_by_member_id uuid not null,
  accepted_by_member_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  version bigint not null default 1 check (version > 0),
  constraint invite_creator_fk foreign key (household_id, created_by_member_id)
    references public.household_members(household_id, id),
  constraint invite_acceptor_fk foreign key (household_id, accepted_by_member_id)
    references public.household_members(household_id, id)
);

create index household_invites_active_idx
  on public.household_invites(household_id, expires_at)
  where status = 'active';

create table public.chore_series (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  description text check (char_length(description) <= 4000),
  timezone text not null check (char_length(timezone) between 1 and 100),
  active_revision_id uuid,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (household_id, id)
);

create table public.chore_series_revisions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  effective_local_date date not null,
  due_local_time time,
  recurrence_rule jsonb not null check (jsonb_typeof(recurrence_rule) = 'object'),
  default_assignee_member_id uuid,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  constraint chore_revision_series_fk foreign key (household_id, series_id)
    references public.chore_series(household_id, id) on delete cascade,
  constraint chore_revision_assignee_fk foreign key (household_id, default_assignee_member_id)
    references public.household_members(household_id, id)
);

alter table public.chore_series
  add constraint chore_active_revision_fk
  foreign key (household_id, active_revision_id)
  references public.chore_series_revisions(household_id, id)
  deferrable initially deferred;

create table public.chore_occurrences (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null,
  due_local_date date not null,
  due_at timestamptz,
  timezone text not null,
  status public.occurrence_status not null default 'scheduled',
  assignee_member_id uuid,
  completed_by_member_id uuid,
  completed_by_user_id uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_key),
  constraint chore_occurrence_series_fk foreign key (household_id, series_id)
    references public.chore_series(household_id, id) on delete cascade,
  constraint chore_occurrence_revision_fk foreign key (household_id, revision_id)
    references public.chore_series_revisions(household_id, id),
  constraint chore_occurrence_assignee_fk foreign key (household_id, assignee_member_id)
    references public.household_members(household_id, id),
  constraint chore_occurrence_completer_fk foreign key (household_id, completed_by_member_id)
    references public.household_members(household_id, id),
  constraint chore_completion_fields_ck check (
    (status = 'completed' and completed_at is not null and completed_by_member_id is not null)
    or (status <> 'completed')
  )
);

create index chore_occurrences_today_idx
  on public.chore_occurrences(household_id, due_local_date, status);
create index chore_occurrences_assignee_idx
  on public.chore_occurrences(household_id, assignee_member_id, due_local_date);

create table public.chore_completion_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  event_type text not null check (event_type in ('completed', 'reopened', 'skipped')),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid not null,
  acting_member_id uuid,
  occurred_at timestamptz not null default now(),
  occurrence_version bigint not null,
  correlation_id uuid not null,
  constraint completion_occurrence_fk foreign key (household_id, occurrence_id)
    references public.chore_occurrences(household_id, id) on delete cascade,
  constraint completion_actor_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint completion_acting_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create table public.event_series (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  description text check (char_length(description) <= 8000),
  timezone text not null check (char_length(timezone) between 1 and 100),
  is_all_day boolean not null default false,
  active_revision_id uuid,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  deleted_at timestamptz,
  unique (household_id, id)
);

create table public.event_series_revisions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  local_start_date date not null,
  local_start_time time,
  duration_minutes integer check (duration_minutes is null or duration_minutes between 1 and 10080),
  all_day_end_date_exclusive date,
  recurrence_rule jsonb check (recurrence_rule is null or jsonb_typeof(recurrence_rule) = 'object'),
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (household_id, id),
  unique (series_id, revision_number),
  constraint event_revision_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_revision_time_ck check (
    (local_start_time is null and all_day_end_date_exclusive is not null and all_day_end_date_exclusive > local_start_date)
    or (local_start_time is not null and duration_minutes is not null and all_day_end_date_exclusive is null)
  )
);

alter table public.event_series
  add constraint event_active_revision_fk
  foreign key (household_id, active_revision_id)
  references public.event_series_revisions(household_id, id)
  deferrable initially deferred;

create table public.event_participants (
  household_id uuid not null,
  series_id uuid not null,
  member_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (household_id, series_id, member_id),
  constraint event_participant_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_participant_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id) on delete cascade
);

create table public.event_occurrences (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  series_id uuid not null,
  revision_id uuid not null,
  occurrence_key text not null,
  local_start_date date not null,
  starts_at timestamptz,
  ends_at timestamptz,
  all_day_end_date_exclusive date,
  timezone text not null,
  status public.occurrence_status not null default 'scheduled',
  dst_adjustment jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check (version > 0),
  unique (household_id, id),
  unique (household_id, occurrence_key),
  constraint event_occurrence_series_fk foreign key (household_id, series_id)
    references public.event_series(household_id, id) on delete cascade,
  constraint event_occurrence_revision_fk foreign key (household_id, revision_id)
    references public.event_series_revisions(household_id, id),
  constraint event_occurrence_time_ck check (
    (starts_at is null and ends_at is null and all_day_end_date_exclusive > local_start_date)
    or (starts_at is not null and ends_at is not null and ends_at > starts_at and all_day_end_date_exclusive is null)
  )
);

create index event_occurrences_range_idx
  on public.event_occurrences(household_id, local_start_date, status);
create index event_occurrences_instant_idx
  on public.event_occurrences(household_id, starts_at)
  where starts_at is not null;

create table public.event_occurrence_exceptions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  occurrence_id uuid not null,
  override_payload jsonb not null default '{}'::jsonb,
  cancelled boolean not null default false,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (household_id, occurrence_id),
  constraint event_exception_occurrence_fk foreign key (household_id, occurrence_id)
    references public.event_occurrences(household_id, id) on delete cascade
);

create table public.notification_endpoints (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid references public.households(id) on delete cascade,
  member_id uuid,
  installation_id text not null,
  channel text not null check (channel in ('native_push', 'web_push')),
  platform text not null check (platform in ('ios', 'android', 'web')),
  token_ciphertext bytea not null,
  token_fingerprint bytea not null,
  permission_state text not null check (permission_state in ('granted', 'denied', 'prompt', 'unsupported')),
  locale text,
  timezone text,
  app_version text,
  runtime_version text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (auth_user_id, installation_id, channel),
  constraint endpoint_member_fk foreign key (household_id, member_id)
    references public.household_members(household_id, id)
);

create table public.notification_preferences (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  category text not null,
  native_push boolean not null default true,
  web_push boolean not null default false,
  email boolean not null default false,
  in_app boolean not null default true,
  quiet_start time,
  quiet_end time,
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  primary key (auth_user_id, household_id, category)
);

create table public.notification_intents (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  subject_type text not null,
  subject_id uuid not null,
  scheduled_at timestamptz not null,
  dedupe_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  unique (recipient_user_id, dedupe_key)
);

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  intent_id uuid not null references public.notification_intents(id) on delete cascade,
  endpoint_id uuid references public.notification_endpoints(id) on delete set null,
  channel text not null,
  status public.delivery_status not null default 'pending',
  attempts integer not null default 0,
  provider_message_ref text,
  last_error_code text,
  next_attempt_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (intent_id, endpoint_id, channel)
);

create table public.background_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  payload jsonb not null,
  payload_version integer not null default 1,
  status public.job_status not null default 'queued',
  scheduled_at timestamptz not null default now(),
  attempts integer not null default 0,
  max_attempts integer not null default 8,
  lease_owner text,
  lease_expires_at timestamptz,
  dedupe_key text,
  correlation_id uuid not null default gen_random_uuid(),
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index background_jobs_dedupe_uq
  on public.background_jobs(job_type, dedupe_key)
  where dedupe_key is not null and status not in ('succeeded', 'cancelled');
create index background_jobs_claim_idx
  on public.background_jobs(status, scheduled_at, lease_expires_at);

create table public.outbox_events (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null,
  event_version integer not null default 1,
  household_id uuid references public.households(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid,
  acting_member_id uuid,
  aggregate_type text not null,
  aggregate_id uuid not null,
  aggregate_version bigint,
  correlation_id uuid not null,
  causation_id uuid,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  dispatched_at timestamptz,
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  last_error_code text,
  constraint outbox_actor_member_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint outbox_acting_member_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create index outbox_undispatched_idx
  on public.outbox_events(next_attempt_at, occurred_at)
  where dispatched_at is null;

create table public.idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null,
  idempotency_key text not null,
  request_hash bytea not null,
  status text not null check (status in ('processing', 'succeeded', 'failed')),
  response_status integer,
  response_body jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (auth_user_id, operation, idempotency_key)
);

create table public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  provider text not null check (provider in ('revenuecat', 'web')),
  provider_customer_ref text not null,
  provider_customer_ref_hash bytea not null,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1,
  unique (provider, provider_customer_ref_hash)
);

create table public.billing_webhook_receipts (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  payload_version text,
  payload_ciphertext bytea,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received',
  last_error_code text,
  unique (provider, provider_event_id)
);

create table public.billing_transactions (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null references public.billing_customers(id) on delete cascade,
  provider text not null,
  product_id text not null,
  transaction_ref_hash bytea not null,
  original_transaction_ref_hash bytea,
  status text not null,
  purchased_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean,
  provider_updated_at timestamptz,
  verified_at timestamptz not null default now(),
  raw_snapshot_ciphertext bytea,
  unique (provider, transaction_ref_hash)
);

create table public.billing_household_assignments (
  id uuid primary key default gen_random_uuid(),
  billing_customer_id uuid not null references public.billing_customers(id) on delete cascade,
  billing_owner_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  status text not null check (status in ('active', 'ended', 'revoked')),
  assigned_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1
);

create unique index billing_assignment_customer_active_uq
  on public.billing_household_assignments(billing_customer_id)
  where status = 'active';
create unique index billing_assignment_household_active_uq
  on public.billing_household_assignments(household_id)
  where status = 'active';

create table public.plan_catalog (
  plan_code text primary key,
  version integer not null,
  feature_limits jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_entitlements (
  household_id uuid primary key references public.households(id) on delete cascade,
  assignment_id uuid references public.billing_household_assignments(id) on delete set null,
  billing_owner_user_id uuid references auth.users(id) on delete set null,
  plan_code text not null references public.plan_catalog(plan_code),
  status public.entitlement_status not null default 'none',
  source text not null check (source in ('app_store', 'play_store', 'web', 'manual_support', 'none')),
  product_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  will_renew boolean,
  features jsonb not null default '{}'::jsonb,
  provider_updated_at timestamptz,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1
);

create table public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  household_id uuid references public.households(id) on delete set null,
  request_type public.privacy_request_type not null,
  status public.privacy_request_status not null default 'queued',
  requested_at timestamptz not null default now(),
  verified_at timestamptz,
  processing_started_at timestamptz,
  completed_at timestamptz,
  failure_code text,
  correlation_id uuid not null default gen_random_uuid(),
  version bigint not null default 1
);

create unique index privacy_pending_request_uq
  on public.privacy_requests(auth_user_id, request_type)
  where status in ('queued', 'verifying', 'processing');

create table public.data_exports (
  id uuid primary key default gen_random_uuid(),
  privacy_request_id uuid not null unique references public.privacy_requests(id) on delete cascade,
  storage_object_key text,
  checksum_sha256 text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  downloaded_at timestamptz
);

create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete set null,
  household_id uuid references public.households(id) on delete set null,
  consent_type text not null,
  policy_version text not null,
  status text not null check (status in ('granted', 'withdrawn', 'not_required')),
  recorded_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id) on delete set null,
  authenticated_user_id uuid references auth.users(id) on delete set null,
  actor_member_id uuid,
  acting_member_id uuid,
  action text not null,
  target_type text not null,
  target_id uuid,
  result text not null check (result in ('succeeded', 'denied', 'failed')),
  error_code text,
  correlation_id uuid not null,
  safe_metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  constraint audit_actor_member_fk foreign key (household_id, actor_member_id)
    references public.household_members(household_id, id),
  constraint audit_acting_member_fk foreign key (household_id, acting_member_id)
    references public.household_members(household_id, id)
);

create index audit_events_household_time_idx
  on public.audit_events(household_id, occurred_at desc);

create table public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  rules jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid references auth.users(id) on delete set null
);

create table public.kill_switches (
  key text primary key,
  enabled boolean not null default false,
  reason text,
  updated_at timestamptz not null default now(),
  updated_by_user_id uuid references auth.users(id) on delete set null
);

-- Version/update triggers for mutable user-facing aggregates.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'households', 'household_members', 'household_invites',
    'chore_series', 'chore_occurrences', 'event_series',
    'event_occurrences', 'event_occurrence_exceptions',
    'notification_endpoints', 'notification_deliveries', 'background_jobs',
    'billing_customers', 'billing_household_assignments', 'household_entitlements'
  ]
  loop
    execute format(
      'create trigger %I_set_updated before update on public.%I for each row execute function app_private.set_updated_at_and_version()',
      table_name, table_name
    );
  end loop;
end $$;

-- Baseline plan rows are additive. Product limits remain provisional until D-023 is accepted.
insert into public.plan_catalog(plan_code, version, feature_limits)
values
  ('free', 1, '{"provisional": true}'::jsonb),
  ('plus', 1, '{"provisional": true}'::jsonb)
on conflict (plan_code) do nothing;
```


---



<!-- SOURCE: contracts/rls-contract.sql -->

```sql
-- KinFlow RLS contract v1.0
-- Apply after the core schema. This file defines minimum authorization semantics.
-- D-013: child/guardian/acting-context policies are P1 reference only.

create or replace function app_private.current_user_member_id(p_household_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select hm.id
  from public.household_members hm
  where hm.household_id = p_household_id
    and hm.auth_user_id = auth.uid()
    and hm.removed_at is null
  limit 1
$$;

create or replace function app_private.is_active_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
  )
$$;

create or replace function app_private.has_household_role(
  p_household_id uuid,
  p_roles public.household_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = p_household_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
      and hm.role = any(p_roles)
  )
$$;

create or replace function app_private.can_act_as_member(
  p_household_id uuid,
  p_acting_member_id uuid,
  p_context_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.acting_contexts ac
    join public.household_members child
      on child.household_id = ac.household_id
     and child.id = ac.acting_member_id
     and child.role = 'managed_child'
     and child.removed_at is null
    where ac.id = p_context_id
      and ac.household_id = p_household_id
      and ac.authenticated_user_id = auth.uid()
      and ac.acting_member_id = p_acting_member_id
      and ac.revoked_at is null
      and ac.expires_at > now()
  )
$$;

revoke all on function app_private.current_user_member_id(uuid) from public;
revoke all on function app_private.is_active_household_member(uuid) from public;
revoke all on function app_private.has_household_role(uuid, public.household_role[]) from public;
revoke all on function app_private.can_act_as_member(uuid, uuid, uuid) from public;

grant execute on function app_private.current_user_member_id(uuid) to authenticated;
grant execute on function app_private.is_active_household_member(uuid) to authenticated;
grant execute on function app_private.has_household_role(uuid, public.household_role[]) to authenticated;
grant execute on function app_private.can_act_as_member(uuid, uuid, uuid) to authenticated;

-- Enable and force RLS on all user/provider-facing tables.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'households', 'household_members', 'user_active_households',
    'member_guardians', 'acting_contexts', 'household_invites',
    'chore_series', 'chore_series_revisions', 'chore_occurrences', 'chore_completion_events',
    'event_series', 'event_series_revisions', 'event_participants',
    'event_occurrences', 'event_occurrence_exceptions',
    'notification_endpoints', 'notification_preferences', 'notification_intents',
    'notification_deliveries', 'background_jobs', 'outbox_events', 'idempotency_keys',
    'billing_customers', 'billing_webhook_receipts', 'billing_transactions',
    'billing_household_assignments', 'plan_catalog', 'household_entitlements',
    'privacy_requests', 'data_exports', 'consent_records', 'audit_events',
    'feature_flags', 'kill_switches'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
  end loop;
end $$;

-- Profiles: users can read/update only their own profile. Insert is performed by trusted bootstrap/RPC.
create policy profiles_select_self on public.profiles
for select to authenticated
using (auth_user_id = auth.uid());

create policy profiles_update_self on public.profiles
for update to authenticated
using (auth_user_id = auth.uid())
with check (auth_user_id = auth.uid());

-- Households and members: active same-household read only.
create policy households_select_member on public.households
for select to authenticated
using (app_private.is_active_household_member(id));

create policy household_members_select_member on public.household_members
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Direct role/member writes are intentionally absent. Use transactional RPC/Edge functions.

create policy active_household_select_self on public.user_active_households
for select to authenticated
using (auth_user_id = auth.uid());

-- Update is allowed only to a membership belonging to the same authenticated user.
create policy active_household_update_self on public.user_active_households
for update to authenticated
using (auth_user_id = auth.uid())
with check (
  auth_user_id = auth.uid()
  and exists (
    select 1 from public.household_members hm
    where hm.household_id = user_active_households.household_id
      and hm.id = user_active_households.member_id
      and hm.auth_user_id = auth.uid()
      and hm.removed_at is null
  )
);

create policy member_guardians_select_household on public.member_guardians
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy acting_contexts_select_owner on public.acting_contexts
for select to authenticated
using (authenticated_user_id = auth.uid());

-- Invite metadata is visible only to household admins; public preview uses an Edge function with minimal fields.
create policy household_invites_select_admin on public.household_invites
for select to authenticated
using (app_private.has_household_role(household_id, array['owner','admin']::public.household_role[]));

-- Chore read access.
create policy chore_series_select_member on public.chore_series
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_revisions_select_member on public.chore_series_revisions
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_occurrences_select_member on public.chore_occurrences
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy chore_completion_events_select_member on public.chore_completion_events
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Chore series create/update and occurrence completion are RPC/Edge-only in baseline.

-- Calendar read access.
create policy event_series_select_member on public.event_series
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_revisions_select_member on public.event_series_revisions
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_participants_select_member on public.event_participants
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_occurrences_select_member on public.event_occurrences
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy event_exceptions_select_member on public.event_occurrence_exceptions
for select to authenticated
using (app_private.is_active_household_member(household_id));

-- Notification endpoints and preferences are user-owned. Server workers use service role in a restricted environment.
create policy notification_endpoints_select_self on public.notification_endpoints
for select to authenticated
using (auth_user_id = auth.uid());

create policy notification_preferences_select_self on public.notification_preferences
for select to authenticated
using (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id));

create policy notification_preferences_update_self on public.notification_preferences
for update to authenticated
using (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id))
with check (auth_user_id = auth.uid() and app_private.is_active_household_member(household_id));

create policy notification_intents_select_recipient on public.notification_intents
for select to authenticated
using (recipient_user_id = auth.uid());

create policy notification_deliveries_select_recipient on public.notification_deliveries
for select to authenticated
using (
  exists (
    select 1
    from public.notification_intents ni
    where ni.id = notification_deliveries.intent_id
      and ni.recipient_user_id = auth.uid()
  )
);

-- Internal queue/outbox/idempotency tables intentionally have no client policies.

-- Billing users can read their customer and active household entitlement; all mutations are server-only.
create policy billing_customers_select_self on public.billing_customers
for select to authenticated
using (auth_user_id = auth.uid());

create policy billing_assignments_select_member on public.billing_household_assignments
for select to authenticated
using (
  billing_owner_user_id = auth.uid()
  or app_private.is_active_household_member(household_id)
);

create policy household_entitlements_select_member on public.household_entitlements
for select to authenticated
using (app_private.is_active_household_member(household_id));

create policy plan_catalog_select_authenticated on public.plan_catalog
for select to authenticated
using (active = true);

-- Privacy records are visible only to the requesting user; export object download uses signed server URL.
create policy privacy_requests_select_self on public.privacy_requests
for select to authenticated
using (auth_user_id = auth.uid());

create policy data_exports_select_self on public.data_exports
for select to authenticated
using (
  exists (
    select 1 from public.privacy_requests pr
    where pr.id = data_exports.privacy_request_id
      and pr.auth_user_id = auth.uid()
  )
);

create policy consent_records_select_self on public.consent_records
for select to authenticated
using (auth_user_id = auth.uid());

-- Audit is not exposed directly to general clients in MVP. Feature flags and kill switches are served via a sanitized view/API.

create or replace view public.current_household_entitlement
with (security_invoker = true)
as
select
  he.household_id,
  he.plan_code,
  he.status,
  he.features,
  he.current_period_end,
  he.will_renew,
  he.verified_at,
  he.version
from public.household_entitlements he;

grant select on public.current_household_entitlement to authenticated;

-- Explicit table grants must remain minimal. RLS does not replace GRANT discipline.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, update on public.profiles to authenticated;
grant select on public.households, public.household_members, public.member_guardians,
  public.acting_contexts, public.household_invites to authenticated;
grant select, update on public.user_active_households to authenticated;
grant select on public.chore_series, public.chore_series_revisions,
  public.chore_occurrences, public.chore_completion_events to authenticated;
grant select on public.event_series, public.event_series_revisions,
  public.event_participants, public.event_occurrences, public.event_occurrence_exceptions to authenticated;
grant select on public.notification_endpoints, public.notification_intents,
  public.notification_deliveries to authenticated;
grant select, update on public.notification_preferences to authenticated;
grant select on public.billing_customers, public.billing_household_assignments,
  public.household_entitlements, public.plan_catalog to authenticated;
grant select on public.privacy_requests, public.data_exports, public.consent_records to authenticated;

-- No anon table grants. Public invite preview and privacy request entry use rate-limited Edge endpoints.

comment on view public.current_household_entitlement is
  'RLS-aware entitlement projection for authenticated household members.';
```


---



<!-- SOURCE: contracts/env.example -->

```text
# PUBLIC CLIENT CONFIGURATION ONLY
# Actual secret values must never be committed.

APP_ENV=dev
APP_VERSION=0.0.0-dev
CONTRACT_VERSION=2026-07-21

SUPABASE_URL=https://example.supabase.co
SUPABASE_PUBLISHABLE_KEY=replace-with-environment-key

REVENUECAT_IOS_PUBLIC_SDK_KEY=
REVENUECAT_ANDROID_PUBLIC_SDK_KEY=

SENTRY_DSN=
PUBLIC_SITE_URL=https://example.invalid
AUTH_REDIRECT_HOST=auth.example.invalid
SUPPORT_URL=https://example.invalid/support
PRIVACY_REQUEST_URL=https://example.invalid/privacy-request
FEATURE_CONFIG_URL=

# SERVER/CI ONLY — NEVER EMBED IN FLUTTER OR WEB BUNDLE
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_DB_URL=
REVENUECAT_WEBHOOK_SECRET=
REVENUECAT_SECRET_API_KEY=
FCM_SERVER_CREDENTIAL=
APPLE_APP_STORE_API_PRIVATE_KEY=
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=
INVITE_TOKEN_HMAC_KEY=
DATA_EXPORT_SIGNING_KEY=
INTERNAL_JOB_AUTH_SECRET=
SENTRY_AUTH_TOKEN=
```


---



<!-- SOURCE: matrices/SPEC_TRACEABILITY.csv -->

```csv
ID,Specification,Decisions,Artifacts,Phase,Verification
SPEC-001,Flutter/Dart/toolchain/dependency policy,"D-001,D-006,D-007,D-029,D-037,D-038",docs/21_*; contracts/toolchain.json; pubspec example,01,version/build/codegen/lockfile
SPEC-002,Repository and layer boundary,D-047,docs/22_*; architecture-rules.yaml,01,architecture import tests
SPEC-003,Native-first adaptive client and Web/Desktop Gate,"D-002,D-003,D-004,D-005",docs/20_*; docs/23_*,01-10,device/browser/desktop demand review
SPEC-004,Database/RLS/API authority,"D-008,D-015,D-042,D-048",docs/09_*; docs/24_*; SQL/OpenAPI,02-08,pgTAP/RLS/contract/concurrency
SPEC-005,Auth/session/invite; Managed Child P1,"D-010-D-016,D-040,D-049",docs/11_*; docs/25_*,02/07; P1,auth/link/security E2E; child E2E at P1 gate
SPEC-006,Chores/calendar recurrence and time,"D-019,D-020,D-046",docs/07_*; docs/26_*,03-05,time matrix/materialization/property tests
SPEC-007,Jobs/notifications/cache/offline,"D-017,D-018,D-021-D-023",docs/10_*; docs/26_*,05,job/push/cache actual device
SPEC-008,Billing and household entitlement,D-024-D-028,docs/12_*; docs/27_*,06,sandbox/webhook/reconcile matrix
SPEC-009,Privacy/delete/export; child safety P1,"D-011-D-014,D-035,D-040,D-041",docs/11_*; docs/17_*,07; P1,deletion/export/security/a11y; child safety at P1 gate
SPEC-010,CI/CD/store release,"D-029-D-033,D-037,D-038,D-042",docs/15_*; docs/28_*,01/08/09,signed builds/provenance/rollout
SPEC-011,NFR/SLO/operations,"D-034,D-036",docs/13_*; docs/16_*; docs/29_*,08/09,dashboards/load/restore/runbooks
SPEC-012,Remaining open business decisions stay gated,D-027,DECISIONS.md; Phase 00/06,00/06,decision audit and billing disabled
```


---



<!-- SOURCE: matrices/TEST_MATRIX.csv -->

```csv
Test_ID,Type,Scenario,Platform,Cadence_or_Gate,Pass_Criteria,Phase,Automation,Evidence_Path,Owner,Status
T-STATIC-01,Static,Dart format,All,PR,No diff,01-10,Automated,evidence/test/T-STATIC-01/,,NOT_RUN
T-STATIC-02,Static,Flutter analyze fatal warnings,All,PR,Green,01-10,Automated,evidence/test/T-STATIC-02/,,NOT_RUN
T-STATIC-03,Static,Codegen drift,All,PR,Regenerate then git diff 0,01-10,Automated,evidence/test/T-STATIC-03/,,NOT_RUN
T-STATIC-04,Security,Secret/dependency/license scan,All,PR/RC,No exposed secret; critical issue resolved,01-10,Automated,evidence/test/T-STATIC-04/,,NOT_RUN
T-ARCH-01,Architecture,Domain forbidden imports,Flutter,PR,0 violations,01-10,Automated,evidence/test/T-ARCH-01/,,NOT_RUN
T-BUILD-01,Build,Android dev build,Android,PR,APK build,01-10,Automated,evidence/test/T-BUILD-01/,,NOT_RUN
T-BUILD-02,Build,iOS simulator build,iOS,Main/nightly,Build success,01-10,Automated,evidence/test/T-BUILD-02/,,NOT_RUN
T-BUILD-03,Build,Signed AAB/IPA,Mobile,RC,Installable/provenance,08-09,Mixed,evidence/test/T-BUILD-03/,,NOT_RUN
T-DB-01,DB/RLS,Clean migration/reset,Server,DB change,Success,01-10,Automated,evidence/test/T-DB-01/,,NOT_RUN
T-DB-02,DB/RLS,Full authorization matrix,Server,DB change/RC,All allow/deny pass,02-09,Automated,evidence/test/T-DB-02/,,NOT_RUN
T-DB-03,DB,Cross-household FK injection,Server,DB change,Rejected,02-09,Automated,evidence/test/T-DB-03/,,NOT_RUN
T-DB-04,DB,Removed member old token,Server,Phase02+,Denied,02-09,Automated,evidence/test/T-DB-04/,,NOT_RUN
T-CONTRACT-01,Contract,OpenAPI positive/negative,Server,API change,Schema/error pass,02-10,Automated,evidence/test/T-CONTRACT-01/,,NOT_RUN
T-CONTRACT-02,Contract,Stable error catalog coverage,All,API change,All returned codes declared,02-10,Automated,evidence/test/T-CONTRACT-02/,,NOT_RUN
T-AUTH-01,Integration,Sign-in/session/logout,iOS/Android,G2,Core lifecycle pass,02,Mixed,evidence/test/T-AUTH-01/,,NOT_RUN
T-AUTH-02,Security,Session expiry/account switch purge,Mobile,G2/G7,No stale access/data,02/07,Mixed,evidence/test/T-AUTH-02/,,NOT_RUN
T-LINK-01,E2E,Auth cold-start link,iOS/Android,G2,Callback and safe continuation,02,Manual,evidence/test/T-LINK-01/,,NOT_RUN
T-LINK-02,E2E,Invite cold/warm link,iOS/Android,G2,Token safe; accept/reject states,02,Mixed,evidence/test/T-LINK-02/,,NOT_RUN
T-LINK-03,Security,Open redirect/token log,All,G2,Blocked/no raw token,02,Automated,evidence/test/T-LINK-03/,,NOT_RUN
T-CHILD-01,Security,Child restricted routes/actions,Mobile/Server,P1 child gate,All blocked server-side,P1,Mixed,evidence/p1-child/T-CHILD-01/,,DEFERRED
T-CHILD-02,Security,PIN brute force/recovery,Mobile,P1 child gate,Backoff/recovery policy,P1,Mixed,evidence/p1-child/T-CHILD-02/,,DEFERRED
T-CHORE-01,E2E,Create/assign/complete two devices,Mobile,G3,Consistent Today,03,Mixed,evidence/test/T-CHORE-01/,,NOT_RUN
T-CHORE-02,Concurrency,Duplicate complete/version conflict,All,G3,Idempotent/conflict UI,03,Automated,evidence/test/T-CHORE-02/,,NOT_RUN
T-TIME-01,Domain,DST/month-end/leap/all-day matrix,All,G4,All fixtures pass,04,Automated,evidence/test/T-TIME-01/,,NOT_RUN
T-CAL-01,E2E,One-time/recurring/single exception,Mobile,G4,Correct views/Today,04,Mixed,evidence/test/T-CAL-01/,,NOT_RUN
T-JOB-01,Reliability,Worker lease/crash/retry/dead letter,Server,G5,No loss/duplicate side effect,05,Automated,evidence/test/T-JOB-01/,,NOT_RUN
T-NOTIF-01,Integration,Inbox/dedupe/quiet hours,Server/Mobile,G5,Correct durable state,05,Automated,evidence/test/T-NOTIF-01/,,NOT_RUN
T-PUSH-01,Device,Permission authorized/denied,iOS/Android,G5,Correct UX/fallback,05,Manual,evidence/test/T-PUSH-01/,,NOT_RUN
T-PUSH-02,Device,Foreground push/local display,iOS/Android,G5,No duplicate; tap route,05,Manual,evidence/test/T-PUSH-02/,,NOT_RUN
T-PUSH-03,Device,Background push,iOS/Android,G5,Delivery/tap/refetch,05,Manual,evidence/test/T-PUSH-03/,,NOT_RUN
T-PUSH-04,Device,Terminated push,iOS/Android,G5,Bootstrap then safe route,05,Manual,evidence/test/T-PUSH-04/,,NOT_RUN
T-PUSH-05,Integration,Token rotation/invalid cleanup,All,G5,Binding updated/revoked,05,Mixed,evidence/test/T-PUSH-05/,,NOT_RUN
T-PUSH-06,Security,Payload privacy/stale resource,All,G5,Minimal content/authz recheck,05,Mixed,evidence/test/T-PUSH-06/,,NOT_RUN
T-CACHE-01,Security,Logout purge,Mobile/Web,G2/G7/G10,No previous family data,02/07/10,Mixed,evidence/test/T-CACHE-01/,,NOT_RUN
T-CACHE-02,Security,Account switch purge,Mobile/Web,G2/G7/G10,No cross-account residue,02/07/10,Mixed,evidence/test/T-CACHE-02/,,NOT_RUN
T-CACHE-03,Security,Household switch/removed member,Mobile/Web,G2/G7/G10,No stale access,02/07/10,Mixed,evidence/test/T-CACHE-03/,,NOT_RUN
T-CACHE-04,Reliability,Offline stale read,Mobile/Web,G5/G10,Clear stale state; no unsafe action,05/10,Mixed,evidence/test/T-CACHE-04/,,NOT_RUN
T-SYNC-01,Reliability,Outbox TTL/auth binding,Mobile,G5 optional,Unsafe replay blocked,05,Automated,evidence/test/T-SYNC-01/,,NOT_RUN
T-SYNC-02,Reliability,Realtime reconnect/full refetch,All,G3-G5,Consistent state,03-05,Automated,evidence/test/T-SYNC-02/,,NOT_RUN
T-BILL-01,Sandbox,App Store purchase/restore,iOS,G6,Server entitlement matches,06,Manual,evidence/test/T-BILL-01/,,NOT_RUN
T-BILL-02,Sandbox,Play purchase/restore,Android,G6,Server entitlement matches,06,Manual,evidence/test/T-BILL-02/,,NOT_RUN
T-BILL-03,Billing,Webhook duplicate/out-of-order,Server,G6,Idempotent final state,06,Automated,evidence/test/T-BILL-03/,,NOT_RUN
T-BILL-04,Billing,Reinstall/account/household conflict,Mobile/Server,G6,No entitlement leakage/duplicate purchase,06,Mixed,evidence/test/T-BILL-04/,,NOT_RUN
T-BILL-05,Billing,Expiry/refund/grace/billing issue,All,G6,Policy state correct,06,Mixed,evidence/test/T-BILL-05/,,NOT_RUN
T-PRIV-01,E2E,Account deletion,All,G7,Shared data policy/purge/status,07,Mixed,evidence/test/T-PRIV-01/,,NOT_RUN
T-PRIV-02,E2E,Household delete/last owner,All,G7,Invariant and purge,07,Mixed,evidence/test/T-PRIV-02/,,NOT_RUN
T-PRIV-03,Privacy,PII/log/child analytics,All,G7,Forbidden fields absent,07,Automated,evidence/test/T-PRIV-03/,,NOT_RUN
T-PRIV-04,E2E,Data export/link expiry,All,G7,Authorized/short-lived,07,Mixed,evidence/test/T-PRIV-04/,,NOT_RUN
T-A11Y-01,Accessibility,VoiceOver core journey,iOS,G7,Task success,07,Manual,evidence/test/T-A11Y-01/,,NOT_RUN
T-A11Y-02,Accessibility,TalkBack core journey,Android,G7,Task success,07,Manual,evidence/test/T-A11Y-02/,,NOT_RUN
T-A11Y-03,Accessibility,200% text/tablet/split,Mobile,G7,No blocker clipping,07,Mixed,evidence/test/T-A11Y-03/,,NOT_RUN
T-I18N-01,Localization,EN/KO/pseudo key/layout,All,G7,100% coverage/no overflow blocker,07,Mixed,evidence/test/T-I18N-01/,,NOT_RUN
T-PERF-01,Performance,Startup/Today profile,Mobile,G8,Budget pass or accepted risk,08,Mixed,evidence/test/T-PERF-01/,,NOT_RUN
T-RECOV-01,Recovery,Backup restore/data integrity,Server,G8,RPO/RTO and checks pass,08,Manual,evidence/test/T-RECOV-01/,,NOT_RUN
T-REL-01,Release,Previous build to RC upgrade,Mobile,G8,No auth/cache/data loss,08,Manual,evidence/test/T-REL-01/,,NOT_RUN
T-REL-02,Release,Feature kill switch,All,G8,Risk feature disabled safely,08,Manual,evidence/test/T-REL-02/,,NOT_RUN
T-REL-03,Release,Staged rollout pause,Stores,G9,Procedure demonstrated,09,Manual,evidence/test/T-REL-03/,,NOT_RUN
T-WEB-01,Web,Core Playwright journey,Web,G10,Browser matrix pass,10,Automated,evidence/test/T-WEB-01/,,NOT_RUN
T-WEB-02,Web Security,CSP/session/BFCache/account switch,Web,G10,No unsafe persistence,10,Mixed,evidence/test/T-WEB-02/,,NOT_RUN
T-WEB-03,Accessibility,Keyboard/zoom/screen reader,Web,G10,Core task success,10,Mixed,evidence/test/T-WEB-03/,,NOT_RUN
T-DESK-01,Decision,Desktop plugin/demand PoC,Desktop,G11,"Explicit ADR, no implied support",10,Manual,evidence/test/T-DESK-01/,,NOT_RUN
```


---



<!-- SOURCE: matrices/PLATFORM_CAPABILITY_MATRIX.csv -->

```csv
Capability_ID,Capability,Domain_Interface,iOS_Provider,Android_Provider,Web_Provider,Fallback,Required_Gate,Primary_Test_IDs,Security_Privacy_Notes,Status,Evidence
CAP-001,Authentication session,AuthSessionRepository,Supabase Auth + secure storage,Supabase Auth + secure storage,Supabase browser session,re-auth/read-only public path,G2/G10,T-AUTH-01;T-SEC-04,token redaction; identity switch purge,NOT_STARTED,
CAP-002,Deep links,DeepLinkSource,Universal Links,Android App Links,HTTPS routes,copy safe link,G2/G10,T-LINK-01;T-LINK-02,exact allowlist; invite token scrub,NOT_STARTED,
CAP-003,Push notifications,NotificationService,FCM/APNs,FCM,Deferred Web Push,in-app inbox/email,G5,T-PUSH-01..06,payload minimization; token cleanup,NOT_STARTED,
CAP-004,Local notification display,LocalNotificationService,flutter_local_notifications,flutter_local_notifications,Browser notification deferred,in-app banner,G5,T-PUSH-02;T-PUSH-03,foreground duplicate prevention,NOT_STARTED,
CAP-005,In-app inbox,NotificationInboxRepository,Shared server API,Shared server API,Shared server API,none,G5/G10,T-NOTIF-01,RLS and content minimization,NOT_STARTED,
CAP-006,Billing purchase,BillingService,RevenueCat App Store,RevenueCat Play,Unavailable in initial Beta,mobile purchase route,G6,T-BILL-01..12,server household entitlement,NOT_STARTED,
CAP-007,Entitlement read,EntitlementRepository,Server snapshot,Server snapshot,Server snapshot,Free limits,G6/G10,T-BILL-08,never trust local SDK state,NOT_STARTED,
CAP-008,Secure storage,SecureStorage,Keychain-backed,Keystore-backed,Browser strategy,memory + re-auth,G1,T-SEC-03,no secret in preferences,NOT_STARTED,
CAP-009,Parental gate,ParentalGate,Deferred,Deferred,Deferred,adult-only Store MVP,P1 child gate,T-CHILD-01..04,server allowlist remains authority,DEFERRED,
CAP-010,Background execution,BackgroundScheduler,Best-effort,Best-effort,Foreground only baseline,server worker,G5,T-JOB-01,not source of notification truth,NOT_STARTED,
CAP-011,Offline read cache,OfflineCache,Scoped cache,Scoped cache,Memory/minimal browser storage,stale + retry,G3/G4/G10,T-CACHE-01..04,user+household namespace/purge,NOT_STARTED,
CAP-012,Safe offline mutation,MutationOutbox,Chore completion candidate,Chore completion candidate,Disabled initially,online-only,G5 optional,T-SYNC-01..05,auth/version/TTL/idempotency binding,PROVISIONAL,
CAP-013,Realtime,RealtimeSubscription,Supabase Realtime,Supabase Realtime,Supabase Realtime,resume refetch,G3/G4,T-SYNC-06,RLS; reconnect full validation,NOT_STARTED,
CAP-014,Analytics,AnalyticsSink,Approved mobile sink,Approved mobile sink,Approved web sink,first-party aggregate,G1/G7,T-PRIV-03,child mode disabled; no content,NOT_STARTED,
CAP-015,Crash reporting,ErrorReporter,Sentry Flutter,Sentry Flutter,Sentry Flutter,redacted local logs,G1/G8,T-OBS-01,before-send PII scrub,NOT_STARTED,
CAP-016,Share,ShareService,Native share,Native share,Web Share/clipboard,copy button,G2,T-LINK-03,safe URL; raw token lifecycle,NOT_STARTED,
CAP-017,Export delivery,ExportDelivery,secure download/share,secure download/share,short-lived HTTPS download,support path,G7,T-PRIV-06,expiry; browser residue check,NOT_STARTED,
CAP-018,Update,AppUpdatePolicy,App Store,Play Store,atomic web deploy,feature kill switch,G8/G9/G10,T-REL-01..04,minimum version and compatibility,NOT_STARTED,
CAP-019,Native calendar integration,CalendarIntegration,Deferred,Deferred,Unsupported,ICS/share future,Post-MVP,T-DEFER-01,no broad calendar permission,DEFERRED,
CAP-020,Desktop native shell,DesktopCapability,N/A,N/A,N/A,Web Companion,Phase 10 demand review,T-DESK-01,no support promise before Gate,DEFERRED,
```


---



<!-- SOURCE: matrices/PLATFORM_DEFINITION_OF_DONE.csv -->

```csv
ID,Platform,Tier,Area,Acceptance_Criteria,Automation,Manual_Evidence,Status
PDOD-001,iPhone,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-002,iPhone,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-003,iPhone,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-004,iPhone,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-005,iPhone,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-006,iPhone,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-007,iPhone,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-008,iPhone,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-009,iPhone,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-010,iPhone,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-011,iPhone,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-012,iPad,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-013,iPad,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-014,iPad,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-015,iPad,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-016,iPad,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-017,iPad,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-018,iPad,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-019,iPad,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-020,iPad,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-021,iPad,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-022,iPad,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-023,Android Phone,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-024,Android Phone,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-025,Android Phone,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-026,Android Phone,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-027,Android Phone,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-028,Android Phone,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-029,Android Phone,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-030,Android Phone,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-031,Android Phone,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-032,Android Phone,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-033,Android Phone,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-034,Android Tablet,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-035,Android Tablet,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-036,Android Tablet,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-037,Android Tablet,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-038,Android Tablet,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-039,Android Tablet,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-040,Android Tablet,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-041,Android Tablet,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-042,Android Tablet,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-043,Android Tablet,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-044,Android Tablet,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-045,Web Companion,Tier2,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-046,Web Companion,Tier2,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-047,Web Companion,Tier2,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-048,Web Companion,Tier2,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-049,Web Companion,Tier2,Notifications,inbox and email/mobile fallback; Web Push not initial blocker,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-050,Web Companion,Tier2,Billing,server entitlement read; paid web purchase separately gated,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-051,Web Companion,Tier2,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-052,Web Companion,Tier2,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-053,Web Companion,Tier2,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-054,Web Companion,Tier2,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-055,Web Companion,Tier2,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
```


---



<!-- SOURCE: matrices/RELEASE_GATE_CHECKLIST.csv -->

```csv
Gate_ID,Gate,Condition,Phase,Evidence,Policy,Owner,Status,Notes
G0,Decision Gate,"Launch-blocking product, age, market, price/toolchain decisions accepted",00,decision review; PoC; console ownership,BLOCK,,NOT_STARTED,
G1,Foundation Gate,Flutter/Supabase/CI/flavor/architecture baseline green,01,"CI, build, device shell, RLS smoke",BLOCK,,NOT_STARTED,
G2,Household Alpha,Two adults auth/invite/roles/managed child boundary,02,RLS matrix; iOS/Android link E2E,BLOCK,,NOT_STARTED,
G3,Chores Value,Two-device recurring chore and Today loop,03,domain/RLS/E2E/device evidence,BLOCK,,NOT_STARTED,
G4,Calendar Value,All-day/timed/recurrence/DST and Today integration,04,time matrix; device timezone evidence,BLOCK,,NOT_STARTED,
G5,Reliability Gate,"Inbox, mobile push, worker, cache/offline scope",05,queue/push actual device/forensic purge,BLOCK,,NOT_STARTED,
G6,Billing Gate,Store sandbox lifecycle and household entitlement,06,billing matrix; webhook; iOS/Android sandbox,BLOCK,,NOT_STARTED,
G7,Compliance Gate,Deletion/export/security/child/a11y/EN-KO/public pages,07,privacy/security/a11y/legal evidence,BLOCK,,NOT_STARTED,
G8,Beta Exit/RC,"Real-family value, full regression, restore/rollback, signed RC",08,RC audit; SLO; restore; risk review,BLOCK,,NOT_STARTED,
G9,Mobile Store Launch,Apple/Google submission and staged rollout,09,store records; rollout dashboard,DECISION,,NOT_STARTED,
G10,Web Companion Beta,Independent browser security/a11y/ops Gate,10,Playwright/browser/manual evidence,DECISION,,NOT_STARTED,
G11,Native Desktop Review,"Demand, plugin, ROI, signing/update ADR",10,usage data and PoC decision,DECISION,,NOT_STARTED,
```


---



<!-- SOURCE: matrices/NFR_BUDGETS.csv -->

```csv
ID,Metric,Target,Scope,Gate,Evidence
NFR-001,Mobile cold Today,p95 <= 3.0s,representative device/network/data,Phase08/G8,Profile trace
NFR-002,Warm shell,p95 <= 1.5s,representative device,Phase08/G8,Profile trace
NFR-003,Today server,p95 <= 800ms,defined region/data volume,Phase08/G8,APM/query
NFR-004,Core mutation,p95 <= 700ms,excluding validation/authz,Phase08/G8,APM
NFR-005,Crash-free sessions,>= 99.7%,mobile release cohort,G8/G9,Sentry/Store
NFR-006,Core read availability,>= 99.9% monthly,authenticated Today/read,G8/G9,SLO dashboard
NFR-007,Critical mutation success,>= 99.5%,excluding user errors,G8/G9,SLO dashboard
NFR-008,Notification submit,95% within scheduled ±5m,provider accepted,G5/G8,job dashboard
NFR-009,Entitlement materialize,99% <= 10m,verified provider event,G6/G8,billing dashboard
NFR-010,RLS matrix,100% pass,all protected resources,Every DB change,CI
NFR-011,EN/KO coverage,100% keys,no fallback leak,G7,localization report
NFR-012,Text scaling,200% core task,no clipped blocker,G7,device evidence
NFR-013,Screen reader,core task success,VoiceOver/TalkBack,G7,video/checklist
NFR-014,Account switch purge,0 prior-household residue,mobile/web scoped storage,G2/G7/G10,forensic test
NFR-015,Backup restore,RPO/RTO approved,isolated restore,G8,drill report
NFR-016,Critical CVE,0 unresolved,release dependencies,G8/G9,scan/SBOM
NFR-017,Generated drift,0 diff,build_runner output,Every PR,CI
NFR-018,Analyzer,0 warnings/info at fatal settings,all Dart code,Every PR,CI
NFR-019,Build reproducibility,same source/config provenance,clean RC checkout,G8/G9,artifact hashes
NFR-020,Web core task,browser matrix pass,post-mobile Beta,G10,Playwright/manual
```
