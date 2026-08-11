# Phase 05 WP05-08 Chore Occurrence Target Recovery Evidence

- Work Package: WP05-08 — Chore inbox/push exact occurrence target recovery and Calendar exact target routing
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-08 LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·REAL-DEVICE TAP DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-NOTIF-005 / T-NOTIF-02 / T-PUSH-04 | PASS FOR LOCAL EXACT ROUTING / OVERALL PARTIAL | Chore inbox와 authorized push는 exact Chore occurrence route로, Calendar pair는 existing Calendar occurrence route로 이동한다. invalid, mismatched, stale 및 authorization failure는 알림 센터로 fail closed한다. 실제 FCM과 physical-device lifecycle tap은 남았다. |
| FR-CHORE-009 / T-CHORE-TARGET-01 / API-044 | PASS FOR LOCAL AUTHORITATIVE DETAIL / OVERALL PARTIAL | strict UUID direct route가 active-household authorized 단건 RPC를 읽고 기존 bounded activity surface를 재사용한다. 실계정 두 기기와 production-size latency는 남았다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW SURFACES | household ID는 auth lifecycle에서만 가져오며 route에는 occurrence UUID만 둔다. missing, forbidden, skipped와 deleted scheduled target을 구분하지 않고 raw provider detail이나 family content를 새 payload/log에 추가하지 않는다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / OVERALL PARTIAL | loading, unavailable, transient retry와 recovery action은 generated EN/KO/EN-XA copy와 semantic heading/live region을 사용하고 compact 200% pseudo-locale widget 회귀를 통과했다. TalkBack과 실제 tablet은 남았다. |

## Server Authority and Projection

- `get_chore_occurrence_target(p_household_id, p_occurrence_id)`은 authenticated session, non-deleted household와 active membership을 먼저 검사한다.
- exact household/occurrence에 속한 `scheduled|completed` row 한 건만 기존 Chore list의 strict 18-key projection으로 반환한다.
- skipped, missing, cross-household와 deleted scheduled series는 `KFC03` 하나로 처리한다. completed historical occurrence는 series soft-delete 뒤에도 immutable revision content와 history 접근을 유지한다.
- `security definer`, empty search path와 authenticated-only execute를 사용한다. `anon`, `public`, `service_role`의 직접 execute grant는 없다.
- 기존 table, RLS policy, index와 data를 변경하지 않았으며 migration은 additive function과 notification target resolver의 destination 값만 바꾼다.

## Client and Routing

- `ChoreDataSource`와 `ChoreRepository`에 단건 target read를 추가하고 exact remote key, expected household와 expected occurrence를 모두 검증한다.
- encrypted read-cache decorator는 target read를 그대로 delegate한다. transient network failure가 이전 가구·삭제 전 상세를 복구하지 않는다.
- controller는 같은 요청을 coalesce하고 retry identity를 유지하며 late response와 active-household switch race를 무시한다.
- `/chores/occurrence/:occurrenceId`는 strict UUID만 받고 invalid path는 Notifications로 redirect한다. 화면은 resume와 active-household 변경 시 authoritative refetch한다.
- 성공 화면은 기존 `ChoreOccurrenceHistorySheet`를 embedded mode로 재사용한다. unavailable은 Notifications와 Chores 복구 action만, transient failure는 retry도 제공한다.
- inbox는 read 상태를 먼저 갱신한 뒤 category/subject pair별 exact route를 사용한다. push lifecycle host는 Router 위의 widget context에 의존하지 않고 shared `appRouterProvider`로 이동한다.

## Notification Compatibility and Privacy

- `resolve_notification_push_target`은 기존 exact recipient, active membership, delivery echo, latest source와 optional uncancelled inbox 검사를 유지한다.
- safe destination은 `chore_occurrence → chore_occurrence`, `calendar_occurrence → calendar_event`의 allowlisted pair다. Flutter는 category가 기대하는 destination과 다르면 거부한다.
- FCM data envelope의 contract version과 필드에는 변화가 없다. 이전 client가 새 destination을 이해하지 못하면 target resolution을 거부하고 durable inbox fallback을 유지할 수 있다.
- route에는 occurrence UUID만 있고 household UUID, title, description, display name, email, auth subject나 provider credential을 추가하지 않았다.
- 저장, mutation outbox, telemetry, native permission, SDK와 provider request 형식은 변경하지 않았다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused affected pgTAP | PASS — 3 files / 157 assertions: `chore_list_filters` 63 assertions plus Calendar and push destination regressions |
| full database regression | PASS — 54 files / 2,718 tests |
| database lint | PASS — `app_private,public`, warning level, fail-on-error, schema error 0 |
| focused Flutter impact | PASS — 111 tests across target RPC mapping/cache/controller/screen and inbox/push routing |
| full Flutter regression | PASS — 1,144 tests; existing local-connectivity opt-in 1 skip; all others passed |
| Flutter analyzer | PASS — issue 0 |
| Dart formatter | PASS — 655 files checked, drift 0 |
| localization and generated code | PASS — EN/KO/EN-XA generated localization current; build runner wrote 0 outputs; 8 generated files current |
| public config and secret scan | PASS — allowlist valid, high-confidence secret finding 0 |
| repository Node contracts | PASS — 141/141 |
| workflow and action lint | PASS — 5 jobs, 17 pinned action uses, `contents:read`; actionlint PASS |
| documentation structure | PASS — 374 Markdown files balanced; 5 relevant YAML contracts parse; 13 matrices rectangular and declared counts match; requirements 116×18, tests 83×11, API 44×6 |
| whitespace | PASS — final `git diff --check` output 0 |

The new migration was applied forward to the existing local migration history without a destructive reset. The full local suite exercised the resulting 54-file state, but clean-from-zero and hosted migration completion are not claimed.

## Files and Migration

- Contract and work package: `docs/contracts/chore-occurrence-target-recovery.yaml.md`, `docs/evidence/phase-05/WP05_08_WORKPLAN.md`
- Migration and DB coverage: `supabase/migrations/20260809150000_chore_occurrence_target_recovery.sql`, `supabase/tests/database/chore_list_filters.test.sql`, `calendar_event_reminders.test.sql`, `notification_push_delivery.test.sql`
- Flutter domain/data/application: Chore data source/repository target contracts, `ChoreOccurrenceTargetController`, strict Supabase mapper and no-cache decorator
- Flutter UI/routing: `ChoreOccurrenceTargetScreen`, embedded activity history, `AppRoutes.choreOccurrence`, inbox routing and `NotificationPushLifecycleHost`
- Flutter notification contract: safe destination pair, subject-preserving navigation intent, coordinator and strict repository mapping
- Tests: target controller/widget/repository/data-source/cache fixtures plus notification model/coordinator/repository/widget regressions
- Localization/governance: EN/KO/EN-XA ARBs/generated files, notification/navigation contracts, Phase 05, API/test/requirements matrices and changelog

## Manual and Deferred Validation

- 실제 Firebase project/service account와 FCM foreground/background/terminated/local notification tap은 **NOT RUN**이다.
- 실제 성인 계정에서 notification inbox, membership removal, 다른 가구 전환과 occurrence/series 삭제 race를 두 기기로 확인하는 항목은 **NOT RUN**이다.
- physical Android TalkBack, 200% font, phone/tablet와 OEM process lifecycle 확인은 **NOT RUN**이다.
- hosted Supabase migration/scheduler, production queue telemetry와 provider outage drill은 **NOT RUN**이다.
- iOS/APNs, Web Push/browser history와 Managed Child allowlist는 이번 범위 밖이다.

## Remaining Risks and Completion Boundary

1. 로컬 latest-state transaction과 widget lifecycle은 실제 FCM tap 직후의 network/membership race 시간을 측정하지 않는다.
2. 단건 RPC의 production-size query plan과 hosted latency는 측정하지 않았다.
3. Calendar exact route는 기존 locator/realtime recovery를 재사용하지만 실제 cancelled/deleted Calendar tap은 기기에서 확인하지 않았다.
4. 알림 envelope contract version은 payload가 바뀌지 않아 유지했다. 이전 client와 새 server의 safe-destination 조합은 durable inbox로 fail closed하지만 hosted N-1 binary로 확인하지 않았다.
5. Phase 05 상위 Exit Gate는 실제 provider, 계정, 다중기기와 physical-device evidence가 없어 계속 `PARTIAL`이다.

WP05-08 자체는 provider-independent local exact-target vertical slice로 완료했다. 실계정·실기기 Gate는 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 수행한다.

## Rollback

- client inbox/push destinations를 `/notifications`로 되돌리면 direct target 노출을 중지하면서 durable inbox를 유지할 수 있다.
- production 적용 후에는 destructive down migration 대신 forward migration으로 `get_chore_occurrence_target` execute를 revoke하고 subject-specific safe destination을 기존 fallback 정책으로 되돌린다.
- table data, index와 cached target을 추가하지 않았으므로 backfill·data cleanup·device local purge는 필요 없다.
