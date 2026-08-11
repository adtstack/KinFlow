# Phase 03 WP03-09 One-time Chore Lifecycle Evidence

## 결과

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 범위: `FR-CHORE-001`, `FR-CHORE-003`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`, `D-048`
- 구현 수직 조각: scheduled one-time chore row → localized edit/delete UI → dual expected-version idempotent RPC → immutable revision 또는 soft-delete/cancel → authoritative current-query reload
- 실제 계정, remote Supabase, Realtime two-device, 실제 Android/iOS 기기 사용: 없음

## 수용 기준

| 기준 | 결과 |
|---|---|
| 수정 필드 | PASS — title, optional description, active assignee, household-local due date와 optional time을 한 요청으로 수정 |
| 불변 revision | PASS — 기존 revision을 바꾸지 않고 다음 revision을 생성하며 stable occurrence가 새 revision을 참조 |
| 삭제 의미 | PASS — series `deleted_at`, occurrence `cancelled`; series/revision/occurrence/audit 물리 삭제 없음 |
| 상태·유형 경계 | PASS — scheduled one-time만 허용하고 completed, cancelled, repeating target과 no-op을 거부 |
| 권한·scope | PASS — active household adult, exact household/series/occurrence, active exact-household assignee를 서버에서 재검증 |
| 동시성 | PASS — series와 occurrence expected version을 모두 잠그고 stale 어느 쪽도 `KFC05`로 거부 |
| 멱등성 | PASS — caller+key+exact request replay는 동일 metadata와 `changed=false`; payload/operation 교차 재사용은 `KFC04` |
| 개인정보 최소화 | PASS — public audit와 private command metadata에 title, description, display name, token, provider error 없음 |
| Flutter 경계 | PASS — strict DTO key/type parser와 request-correlated mapper가 malformed, extra, missing, ID/date/UTC/version drift를 fail closed |
| 상태 조정 | PASS — duplicate action coalescing, 성공 및 stale/invalid-transition 뒤 현재 query authoritative reload |
| offline | PASS — encrypted cached page는 read-only이며 update/delete RPC를 dispatch하지 않음 |
| UI | PASS — scheduled one-time에만 edit/delete, prefilled scrollable edit form, destructive delete cancel/confirm, success feedback |
| 접근성·국제화 | PASS — EN/KO/EN-XA exact key coverage, pseudo 30% expansion, compact 320×568 200% scroll과 48dp confirm action |

## 서버 계약과 데이터 보존

additive migration은 `supabase/migrations/20260808160000_one_time_chore_lifecycle.sql`이다.

- `public.update_one_time_chore(uuid, uuid, uuid, uuid, bigint, bigint, text, text, uuid, date, time)`
- `public.delete_one_time_chore(uuid, uuid, uuid, uuid, bigint, bigint)`
- `public.one_time_chore_change_events`: forced-RLS, active-member select, immutable trigger, content-free lifecycle metadata
- `app_private.one_time_chore_change_command_requests`: request hash와 exact replay metadata; `anon`, `authenticated`, `service_role` 직접 접근 없음
- 두 RPC만 `authenticated` execute를 가지며 series/revision/occurrence direct mutation privilege는 추가하지 않는다.
- update는 series와 occurrence를 같은 transaction에서 lock하고 revision number, series version, occurrence version을 각각 정확히 1 증가시킨다.
- delete는 기존 content와 revision을 보존하면서 active list projection에서만 제거한다.
- due/assignee/status 변화는 기존 notification hooks를 재사용하며 중복 request에서 side effect를 다시 만들지 않는다.

상세 wire contract와 고정 오류는 `docs/contracts/one-time-chore-lifecycle.yaml.md`에 있다.

## Flutter 동작

1. domain draft는 사용자 text를 trim하고 empty description을 null로 정규화하며 두 expected version과 모든 intent field를 operation-specific fingerprint에 포함한다.
2. repository는 request의 household, series, occurrence, due intent, assignee와 정확히 `expected + 1`인 두 version을 응답과 대조한다. timed due는 UTC instant를 요구한다.
3. controller는 같은 in-flight action을 coalesce하고 같은 retry fingerprint에 command UUID를 재사용한다. 성공 snapshot만으로 로컬 content를 추측하지 않고 현재 Today/list query를 다시 읽는다.
4. stale 또는 invalid transition도 authoritative reload 후 localized stable failure를 표시한다.
5. update 결과가 현재 filter에서 유지되어야 하면 모든 변경 필드와 증가한 두 version을 UI가 확인한다. date/assignee filter 밖으로 이동하면 row 부재를 성공 조건으로 사용한다.
6. delete는 확인 전에는 요청하지 않으며 성공 후 exact occurrence 부재를 확인한다.
7. 성공 mutation은 Today와 chore-list encrypted cache slot을 모두 무효화한다. cached fallback 상태에서는 controller와 UI가 mutation을 차단한다.

## 주요 구현 파일

- 서버:
  - `supabase/migrations/20260808160000_one_time_chore_lifecycle.sql`
  - `supabase/tests/database/one_time_chore_lifecycle.test.sql`
- domain/data/application:
  - `apps/kinflow_app/lib/features/chores/domain/entities/one_time_chore_change.dart`
  - `apps/kinflow_app/lib/features/chores/domain/entities/chore_occurrence.dart`
  - `apps/kinflow_app/lib/features/chores/domain/repositories/chore_repository.dart`
  - `apps/kinflow_app/lib/features/chores/data/datasources/chore_data_source.dart`
  - `apps/kinflow_app/lib/features/chores/data/repositories/provider_chore_repository.dart`
  - `apps/kinflow_app/lib/features/chores/application/today_chores_controller.dart`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_chore_data_source.dart`
  - `apps/kinflow_app/lib/infrastructure/cache/cached_chore_data_source.dart`
- presentation/localization:
  - `apps/kinflow_app/lib/features/chores/presentation/providers/chore_providers.dart`
  - `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart`
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
- 계약·추적성:
  - `docs/contracts/one-time-chore-lifecycle.yaml.md`
  - `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
  - `docs/matrices/API_CONTRACT_TEST_MATRIX.csv.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Clean DB | `npx supabase db reset` | PASS, synthetic seed와 41 migrations clean apply |
| Target pgTAP | `npx supabase test db supabase/tests/database/one_time_chore_lifecycle.test.sql` | PASS, 61 assertions |
| Full DB | `npx supabase test db` | PASS, 48 files / 2,483 tests / 352 wallclock seconds |
| DB lint | `npx supabase db lint --local --level warning` | PASS, schema error 0 |
| Focused Flutter | domain, provider mapper, Supabase parser, controller, cache, widget, localization | PASS, 136 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 864 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 523 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 8 generated files / drift 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Contract parse | fenced WP03-09 YAML exact version/RPC/audit/offline assertions | PASS |
| Matrix parse | fenced CSV declared row and column checks | PASS, requirements 116×18 / tests 65×11 / API 36×6 |
| Whitespace | `git diff --check` | PASS |

focused Flutter 합계는 domain 34, provider mapper 27, Supabase payload 24, controller 9, cache 12, chore widget 26, localization 4다. full Flutter의 opt-in skip은 실제 환경 credential을 요구하는 기존 live test이며 이번 기능을 자동 통과로 대체하지 않는다.

## 보안·개인정보 검토

- authorization, recurrence type, scheduled status, assignee membership, both versions와 idempotency는 UI가 아니라 PostgreSQL security-definer RPC가 최종 결정한다.
- outsider, removed member, cross-household ID injection, inactive assignee, repeating/completed target과 direct table mutation은 pgTAP에서 거부된다.
- public audit는 식별자, operation, 이전/새 due intent, version과 correlation만 가진다. 사용자 chore content와 provider detail을 복제하지 않는다.
- command replay table은 private schema에 있고 client/service direct grant가 없다. 같은 UUID를 update와 delete 사이에 공유해도 operation-bound hash가 충돌을 거부한다.
- Flutter는 raw SQL/provider/exception text를 사용자에게 표시하지 않고 stable localized failure만 사용한다.
- 새 dependency, native permission, public config key, analytics/log event는 추가하지 않았다.

## 수동·실환경 검증

다음은 사용자 지시에 따라 **NOT RUN**이다.

- remote Supabase 배포와 실제 성인 2계정의 상호 update/delete 권한
- 두 기기에서 동일 occurrence 동시 수정, stale reconciliation과 Realtime 반영
- Android/iOS 실제 기기의 keyboard, date/time picker, TalkBack/VoiceOver, system font 200%
- remote notification worker가 update/delete hook을 실제 push/inbox로 전달하는 과정
- managed-child acting context와 approval 상태

로컬 synthetic JWT, fake repository와 widget automation을 실제 사용자·네트워크·기기 완료로 해석하지 않는다.

## 남은 위험과 완료 경계

1. `FR-CHORE-001`에는 approval이 포함되므로 create/read/update/delete가 local complete여도 요구사항 상태는 `PARTIAL`이다. managed-child와 approval은 명시된 P1 Gate다.
2. 삭제 trash/undo/restore와 content-change history presentation은 없다. 데이터는 보존되지만 일반 사용자가 앱에서 복구하거나 변경 내용을 열람할 수는 없다.
3. remote multi-client latency와 Realtime invalidation은 synthetic expected-version tests로 대체할 수 없다.
4. 실제 보조기술과 date/time picker locale 동작은 physical-device Gate가 남는다.
5. 이 증거는 WP03-09의 local automated 완료만 의미하며 Phase 03, G3, RC 또는 Store readiness를 완료로 바꾸지 않는다.

## Rollback

- UI/controller/repository method와 신규 ARB를 제거하면 이전 create/read/complete/repeating 흐름은 유지된다.
- 긴급 비활성화는 두 RPC의 `authenticated` execute grant를 revoke한다.
- migration은 additive이므로 old client와 병행 가능하다.
- soft-deleted series를 복구할 때는 명시적 repair migration으로 series/occurrence version과 audit를 함께 전진시킨다. revision, occurrence 또는 audit를 물리 삭제하지 않는다.

## 다음 기능 후보

- 실계정 Gate를 계속 마지막에 두고 다음 local 사용자 기능은 `FR-CHORE-001` approval을 P1 child 범위보다 앞당기지 않는 조건에서, onboarding의 template 3개 guided setup 또는 Calendar/Today의 비차단 overlap hint 후속 UX를 비교한다.
- 우선순위는 기존 server contract와 테스트 인프라를 재사용하면서 독립적으로 local 검증 가능한 vertical slice를 선택한다.
