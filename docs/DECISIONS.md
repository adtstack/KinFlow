# KinFlow 제품·아키텍처 결정 v1.0

상태: `ACCEPTED`, `PROVISIONAL`, `OPEN`, `DEFERRED`.

| ID | 상태 | 결정 | 이유·영향 | 재검토 Gate |
|---|---|---|---|---|
| D-001 | ACCEPTED | 클라이언트는 Flutter SDK 3.44.7 stable + Dart SDK 3.12.2 Native-first 구조다. | Android 우선 품질과 후속 플랫폼 확장을 같은 도메인 계약으로 준비한다. | Flutter가 핵심 요구를 차단할 때 |
| D-002 | ACCEPTED | 첫 Store MVP 공식 플랫폼은 Android다. iOS/iPadOS는 Android Beta 증거 이후 별도 ADR까지 연기한다. | 보유한 실기기와 1인 운영 역량에 release surface를 맞춘다. | Android Beta review |
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
| D-021 | ACCEPTED | Android Store MVP push는 FCM, 로컬 표시는 flutter_local_notifications를 사용한다. APNs는 iOS 승인 시 추가한다. | 현재 출시 플랫폼의 서버 발송 경로에 집중한다. | iOS 재도입 또는 공급자 장애 |
| D-022 | ACCEPTED | 서버 scheduled job과 notification_outbox가 알림의 권위자다. | 앱 종료·절전 상태에서도 일관된 발송. | 지속 |
| D-023 | ACCEPTED | 백그라운드 앱 작업은 opportunistic refresh만 수행하며 알림 정확성에 의존하지 않는다. | OS 제한 회피. | 지속 |
| D-024 | ACCEPTED | RevenueCat App User ID는 auth user ID이며 household ID가 아니다. | 구매 복원·계정 수명주기 분리. | 지속 |
| D-025 | ACCEPTED | Plus 권한은 서버 household entitlement가 최종 결정한다. | 구매자와 가족 혜택을 분리한다. | 지속 |
| D-026 | DEFERRED | Apple Family Sharing은 iOS 재도입 전까지 범위 밖이다. | Android 단일 출시에는 적용되지 않는다. | iOS/Billing ADR |
| D-027 | OPEN | 가격, Free 한도, 체험, 연간 할인율을 확정한다. | Phase 06 차단. | Phase 06 시작 전 |
| D-028 | ACCEPTED | 구독 만료 시 공동 데이터는 보존하고 프리미엄 신규 생성만 제한한다. | 데이터 인질화 방지. | 가격 정책 확정 후 |
| D-029 | ACCEPTED | GitHub Actions가 CI, Fastlane이 store delivery 기준이다. | 투명하고 vendor-neutral한 pipeline. | 운영 부담이 임계값 초과 시 |
| D-030 | ACCEPTED | MVP는 런타임 코드 패치/OTA 도구를 사용하지 않는다. | Store 정책·native 호환·rollback 위험 감소. | 안정화 후 별도 ADR |
| D-031 | ACCEPTED | 긴급 차단은 서버 feature flag/kill switch로 수행한다. | 앱 심사 없이 위험 기능을 끈다. | 지속 |
| D-032 | ACCEPTED | environment는 dev/prod 두 flavor와 별도 application ID를 사용한다. 별도 staging 대신 Play internal/closed track에서 prod 후보를 검증한다. | 1인 운영 surface를 줄이면서 개발·운영 데이터 혼선을 막는다. | RC 격리가 부족할 때 |
| D-033 | ACCEPTED | 공개 설정만 `--dart-define-from-file`에 넣고 서버 비밀은 Supabase/GitHub secret에 둔다. | 앱 bundle 비밀 노출 방지. | 지속 |
| D-034 | ACCEPTED | Sentry를 오류 추적에 사용하되 PII allowlist/redaction을 강제한다. | 운영 가시성과 개인정보 균형. | SDK privacy review |
| D-035 | PROVISIONAL | Managed Child mode에서는 외부 analytics를 비활성화한다. | 아동 행동의 제3자 전송 최소화. | 법률 검토 |
| D-036 | ACCEPTED | 영어·한국어 동시 출시, pseudo locale와 RTL 구조 검증을 수행한다. | 글로벌 확장 기반. | 추가 언어 전 |
| D-037 | ACCEPTED | Android 최소 API 24, target API 36을 Store MVP 기준으로 한다. | 2026 Google Play 요건과 유지보수 범위를 맞춘다. | 각 Android RC |
| D-038 | DEFERRED | iOS 제출 도구·SDK 기준은 iOS 재도입 ADR에서 다시 검증한다. | 현재 Android 단일 출시와 무관하다. | iOS 재도입 |
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
| D-052 | ACCEPTED | Android application ID는 prod `me.newlines.kinflow`, dev `me.newlines.kinflow.dev`다. | Play 등록과 환경 격리의 변경 비용이 큰 식별자를 명시한다. | package migration 필요 시 |
| D-053 | ACCEPTED | 초기 법적·기술 운영 주체와 Google Play/provider account의 accountable owner는 개인 운영자다. 2단계 인증과 복구 증거를 출시 Gate로 둔다. | 현재 실제 운영 형태를 반영하고 단일 계정 복구 위험을 통제한다. | 사업체 전환/계정 이전 |
| D-054 | ACCEPTED | 초기 성인 계정 로그인 UI는 Google만 제공하며 Supabase Auth가 session authority다. | Android 단일 출시에서 가입 마찰과 provider surface를 줄인다. | 로그인 실패율/지원 수요 review |
| D-055 | ACCEPTED | WP02-02~04 local/backend 구현은 synthetic auth fixture로 진행하고 Google provider·Android 실기기 검증은 Phase 02 마지막 통합 단계로 연기한다. | provider 준비를 기다리는 동안 schema/RLS/transaction 보안 경계를 검증하되 WP02-01 또는 Phase 02 완료로 오인하지 않는다. | WP02-04 완료 / Phase 02 Exit Gate |
| D-056 | ACCEPTED | Store MVP physical DB 명칭은 `public.household_members`와 `households.owner_member_id`를 사용하고 membership은 도메인 개념명으로 유지한다. | 상위 SQL 계약과 이미 적용된 forward migration을 정렬하고 의미 없는 파괴적 rename을 피한다. | breaking schema revision |
