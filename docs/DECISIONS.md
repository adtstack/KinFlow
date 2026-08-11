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
| D-057 | PROVISIONAL | P1 가족 주간 리포트는 가구 시간대로 서버가 계산한 최근 완료 ISO 주차의 읽기 전용 집계로 시작한다. 최대 12주, active member 이름별 기여와 이름 없는 former/overflow 합계만 제공하며 content·occurrence ID·persistent cache·analytics를 포함하지 않는다. | 핵심 기능을 방해하지 않는 테스트 가능한 가족 가치 surface를 확보하면서 leaderboard·감시·잔존 데이터 위험을 제한한다. | Beta의 주간 재방문·가족 만족도 review |
| D-058 | PROVISIONAL | P1 내부 집안일 template 확장은 앱에 포함된 PII-free exact catalog와 localized title 검색·고정 category filter로 한정한다. 검색·선택 상태와 template key/version은 저장·network·analytics로 보내지 않으며 remote catalog·추천·개인화는 별도 결정 전 금지한다. | 외부 provider와 새 권한 없이 빠른 시작의 발견성과 범위를 확장하면서 content·행동 추적·동기화 surface를 만들지 않는다. | Beta의 template 사용성·catalog 품질 review |
| D-059 | PROVISIONAL | P1 외부 캘린더 가져오기는 Android Storage Access Framework에서 사용자가 명시적으로 고른 UTF-8 `.ics` 파일을 최대 256 KiB·50 VEVENT로 제한해 미리보기 후 기존 Calendar 일정으로 복사하는 단방향 흐름으로 시작한다. Google/provider 계정, broad calendar/storage permission, 외부 UID 저장, 지속 원본 cache, 자동 동기화·갱신·삭제 전파는 금지하며 재가져오기는 중복 복사될 수 있음을 표시한다. | provider 계정과 실계정 준비 없이도 실제 교환 형식으로 일정을 옮기는 P1 가치를 테스트하면서 RFC 시간 의미·가족 content·권한 surface를 bounded하게 유지한다. | Beta의 import 성공률·unsupported rule 분포·중복 혼란 review |
| D-060 | PROVISIONAL | P1 반복 집안일의 `이번 회차부터 수정`은 Owner/Admin이 선택한 active scheduled occurrence의 immutable recurrence slot을 서버 경계로 삼아 그 회차와 이후 미완료 회차만 새 immutable revision으로 재구성한다. 이전 회차와 완료 이력은 보존하고, 기존 `오늘부터 시리즈 수정`과 한 회차 예외는 유지하며 Calendar·취소의 같은 범위는 별도 수직 조각으로 둔다. | 미래 항목을 미리 조정하려는 사용자가 오늘부터 전체 기본값을 바꾸거나 회차를 하나씩 고치는 양자택일을 피하면서도 client date 신뢰와 series 분할 schema를 새로 만들지 않는다. | Beta의 미래 시리즈 수정 빈도·예외 초기화 혼란 review |
| D-061 | PROVISIONAL | P1 반복 집안일의 `이번 회차부터 취소`는 Owner/Admin이 선택한 active scheduled occurrence의 immutable recurrence slot부터 이후 미완료 회차를 취소한다. 이전 예정 회차가 남으면 그 prefix의 content·anchor를 보존하는 bounded terminal revision을 활성화하고, 남지 않을 때만 시리즈를 즉시 soft-delete한다. 이전·완료 이력과 기존 전체 취소·편집 계약은 유지하며 Calendar 동일 범위는 별도 수직 조각으로 둔다. | 미래 종료를 예약하면서 그 전에 남은 집안일까지 즉시 숨기는 전체 취소의 부작용을 피하고, 새 cutoff column이나 split-series table 없이 기존 immutable revision·worker 모델로 종료 경계를 표현한다. | Beta의 미래 취소 빈도·종료 예약 이해도·재개 요구 review |
| D-062 | PROVISIONAL | P1 반복 일정의 `이 회차부터 수정`은 active household member가 선택한 active scheduled non-exception occurrence의 immutable recurrence slot을 서버 경계로 삼아 이후 source occurrence만 새 immutable revision으로 재구성한다. 이전 occurrence와 경계 이후 기존 한 회차 예외는 그대로 보존하고 기존 `오늘부터 전체 수정`·한 회차 수정/취소·전체 종료 계약을 유지한다. | 미래 일정 기본값을 바꾸면서 이미 조정한 개별 회차를 잃지 않고, client date나 새 split-series table을 authority로 만들지 않는다. | Beta의 미래 시리즈 수정 빈도·기존 예외 보존 이해도·취소 parity review |
| D-063 | PROVISIONAL | P1 반복 일정의 `이 회차부터 취소`는 active household member가 선택한 active scheduled non-exception occurrence의 immutable recurrence slot부터 이후 모든 회차를 취소한다. 이전 actionable source prefix가 남으면 source content·participant·anchor를 보존하고 `until = boundary - 1`인 immutable terminal revision을 활성화하며, 없을 때만 시리즈를 경계에서 종료한다. 이전 occurrence와 그 예외는 표시 날짜와 무관하게 보존하고, 경계 이후 예외는 이동 여부와 무관하게 함께 취소한다. | 미래 일정 종료를 예약하면서 earlier prefix를 즉시 숨기지 않고, 예외의 표시 날짜 대신 immutable recurrence identity를 일관된 authority로 사용하며 새 cutoff column이나 split-series table 없이 worker 재생성을 차단한다. | Beta의 미래 취소 빈도·예외 포함 범위 이해도·재개 요구 review |
| D-064 | PROVISIONAL | P1 Calendar reminder는 사용자·가구별로 정시·5·10·15·30·60분 전 중 하나를 선택한다. timed start 또는 all-day household-local 09:00 base instant에서 개인 lead를 먼저 뺀 뒤 quiet hours와 기존 1시간 usefulness window를 적용한다. source payload는 base instant를 유지하고 아직 inbox/push가 terminal 평가되지 않은 candidate만 원자적으로 재스케줄하며, v1 preference RPC의 signature와 exact 12-key 결과는 보존한다. | 같은 일정 참여자에게 개인별 준비 시간을 제공하면서 source 멱등성·content-free payload·N-1 호환과 이미 전달된 알림 이력을 지킨다. | Beta의 lead option 사용률·late/early 알림 불만·복수 reminder 수요 review |
| D-065 | PROVISIONAL | P1 반복 집안일의 `이 회차부터 취소` 성공 직후에는 현재 controller lifetime의 process-memory Snackbar에서만 Undo를 제공한다. 복구는 original cancellation actor의 현재 Owner/Admin 권한, 원래 cancellation command, exact cancellation-result series version과 private metadata-only pre-state ledger를 모두 검증하고 새 immutable resumed revision을 만든다. transient 실패는 동일 resume key로 재시도하고 terminal conflict는 receipt를 폐기한다. | 짧은 실수 복구 창을 제공하면서 임의 과거 되돌리기·오프라인 write·content 복제·last-write-wins를 피하고 기존 cancellation RPC의 N-1 signature/result를 보존한다. | Beta의 취소 후 Undo 사용률·process-death 복구 수요·Calendar와의 정책 차이 review |
| D-066 | PROVISIONAL | P1 반복 일정의 `이 회차부터 취소` 성공 직후에는 현재 controller lifetime의 process-memory Snackbar에서만 Undo를 제공한다. 복구는 original cancellation actor의 현재 active household membership, 원래 cancellation command, exact cancellation-result series version과 private metadata-only pre-state ledger를 검증하고 source snapshot·participants를 새 immutable resumed revision으로 복제한다. transient 또는 성공 뒤 reload 실패는 동일 resume key로 재시도하고 terminal conflict는 receipt를 폐기한다. | Chore와 같은 짧은 실수 복구 창을 Calendar의 active-member authority와 moved exception semantics에 맞추면서 임의 과거 되돌리기·오프라인 write·content-bearing ledger·last-write-wins를 피하고 기존 5-input/11-output cancellation 계약을 보존한다. | Beta의 취소 후 Undo 사용률·exception 복원 이해도·process-death history 수요 review |
| D-067 | PROVISIONAL | P1 Calendar 알림 Snooze는 현재 caller 소유의 active inbox item에서 5·10·30분 중 하나를 선택하고 연속 최대 3회, occurrence base start 이후 1시간 이내로 제한한다. optimistic item version과 caller UUID command를 private immutable metadata-only ledger로 직렬화하고, 원본 inbox/pending push를 원자적으로 supersede한 뒤 content-free source event를 기존 inbox·quiet-hours·Android push worker에 다시 넣는다. v1 inbox API는 보존하고 v2가 bounded Snooze metadata를 제공한다. | 사용자가 방금 받은 일정 알림을 잠시 미루는 가치를 기존 신뢰성 파이프라인으로 제공하면서 임의 시각·무한 반복·중복 발송·content-bearing local alarm·N-1 break를 피한다. | Beta의 Snooze 선택/반복률·late reminder 불만·복수 reminder 수요 review |
| D-068 | PROVISIONAL | P1 Calendar 알림은 기존 `reminder_lead_minutes` 기본 1개와 distinct fixed 추가 시간 최대 2개를 갖는다. v1은 전체 집합을 보존하고 v2는 기본만 바꾸며 추가를 보존하고, strict 14-key v3만 전체 집합을 편집한다. 같은 content-free source event에 private lead identity를 추가해 각 시간을 기존 latest-state·quiet-hours·inbox·Snooze·Android push 경로로 독립 처리하고, 새 설정의 과거 시각은 소급 발송하지 않으며 평가 완료 이력은 동결한다. | 준비 알림을 여러 번 원하는 사용 가치를 제공하면서 N-1 설정 유실, payload content 증가, 별도 client alarm, 무제한 fan-out과 이미 전달된 이력 재발송을 막는다. | Beta의 reminder 개수·시간 조합 사용률, quiet-hours 동시 도착과 notification fatigue review |
| D-069 | PROVISIONAL | 알림 `email` 채널은 기본 OFF인 개인·가구·category preference로 활성화하며, 기존 content-free source와 latest-state·quiet-hours·1시간 usefulness window를 재사용하는 독립 durable delivery다. 확인된 Auth 이메일은 private queue에 저장하지 않고 service-only claim에서 전송 직전에만 가져온다. provider는 SDK 없이 고정 SendGrid Web API v3 endpoint를 사용하고 EN/KO generic copy만 보내며, provider 제출 직전 marker 이후 불명확한 결과는 자동 재시도하지 않는다. | Web Push 없이도 inbox와 별도의 중요한 intent fallback을 제공하면서 가족 content·이메일의 영속/로그 노출, client-side SMTP, provider lock-in SDK와 응답 유실 중복 메일을 피한다. | Beta의 opt-in·delivery·complaint 비율, sender reputation/cost와 provider portability review |
| D-070 | PROVISIONAL | 초기 Web Companion은 같은 Flutter codebase의 독립 dev/prod release build와 path URL을 사용하고 email OTP를 첫 인증 surface로 둔다. runtime identity는 package `kinflow_app`·platform `web`이며 global/exact-six server policy를 독립 적용한다. PWA 설치·Web Push·Web 구매·영속 API cache·client background는 활성화하지 않고 각각 inbox+configured email, server entitlement read, re-auth와 server notification fallback을 제공한다. | Android 출시 흐름을 넓히지 않으면서 브라우저에서 핵심 서버 계약과 로그인 진입을 테스트 가능한 수준으로 만들고 공유 PC 잔존 데이터·provider·배포 surface를 제한한다. hosted HTTPS/CSP/SPA rewrite·OAuth callback과 실계정/browser matrix 전에는 Web Beta 완료로 보지 않는다. | Web Beta hosting·auth·browser evidence review |
