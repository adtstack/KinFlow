# Phase 05 WP05-07 Calendar Event Reminder Evidence

- Work Package: WP05-07 — Calendar occurrence start reminder source, latest-state inbox and Android push routing
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, local Supabase stack
- 결과: **WP05-07 LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·REAL-DEVICE DELIVERY DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-NOTIF-003 / T-NOTIF-02 | PASS FOR LOCAL CALENDAR PRODUCER AND LATEST STATE / OVERALL PARTIAL | timed, all-day와 recurring occurrence가 exact participant별 source를 만들고 일정 변경·취소·참여자 제거를 provider claim 전까지 다시 평가한다. hosted scheduler와 실제 provider delivery는 남았다. |
| FR-NOTIF-004 | PASS FOR EXISTING QUIET-HOUR PIPELINE | Calendar candidate가 기존 recipient IANA timezone quiet-hours와 future-due gate를 통과한다. 자동 travel timezone 및 실제 provider timing은 남았다. |
| FR-NOTIF-005 | PASS FOR SYNTHETIC AUTHORIZED TAP | strict `calendar_event/calendar_occurrence` envelope가 authenticated latest-state target RPC를 통과한 경우에만 Today로 이동한다. 실제 foreground/background/terminated tap은 남았다. |
| FR-NOTIF-006 / NFR-REL-01 | PASS FOR LOCAL IDEMPOTENCY AND STALE SUPPRESSION / OVERALL PARTIAL | source unique key에 exact occurrence version과 audience가 포함되고 horizon sweep, worker resolution, inbox/push materialization replay가 멱등이다. hosted outage·duplicate telemetry와 incident drill은 남았다. |
| FR-NOTIF-007 | PASS FOR CALENDAR CATEGORY / OVERALL PARTIAL | server preference와 Flutter 설정에 세 번째 `calendar_event` category를 추가했다. approval category/producer는 남았다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW SURFACES | service-role-only horizon mutation, active-member target authorization, strict category/subject checks와 content-free persistence를 검증했다. production provider/log inspection은 남았다. |

## Scheduling and Audience Contract

- timed occurrence는 `starts_at` instant를 reminder schedule로 사용한다.
- all-day occurrence는 `local_start_date`의 date-only 의미를 바꾸지 않고, 현재 authoritative household timezone의 해당 날짜 09:00을 notification instant로만 계산한다.
- occurrence insert capture와 worker horizon sweep은 현재 시각부터 32일 이내로 제한한다. 반복 일정의 장기 materialization이 알림 queue를 즉시 폭증시키지 않는다.
- recurring와 occurrence exception은 occurrence가 가리키는 `event_revision_participants` immutable snapshot을 사용한다. revision snapshot이 없는 one-time legacy occurrence만 `event_participants`를 fallback으로 사용한다.
- source event는 `(household, event type, occurrence, occurrence version, audience member)`로 멱등화한다. 같은 occurrence의 다른 참여자는 독립 source, resolution, inbox와 push 상태를 갖는다.

## Latest-State and Cancellation

- generic resolver가 exact audience별 newest source version, occurrence version/status/schedule, series lifecycle, snapshot membership와 active auth membership을 다시 확인한다.
- 일정 변경, 취소와 참여자 변경은 이전·현재 audience 합집합에 새 source를 기록한다. 제거된 참여자의 이전 inbox/push는 stale 또는 cancelled가 되고 유지된 참여자의 상태는 보존된다.
- future Calendar candidate는 `scheduled_at` 이전에 inbox를 만들지 않는다. provider claim도 기존 quiet-hours와 usefulness window를 적용하며 최신 상태를 다시 확인한다.
- Chore 이름이 남은 outbox table과 public worker RPC는 배포 호환성을 위해 유지했고, 허용 pair만 `chore_due|chore_assignment/chore_occurrence`와 `calendar_event/calendar_occurrence`로 제한했다.
- Chore와 Calendar occurrence hard delete는 polymorphic source event를 명시적 trigger로 정리해 기존 foreign-key cascade 의미를 보존한다.

## Privacy and Authority

- Calendar source payload exact key는 `recipientMemberId`, `localStartDate`, `scheduledAt`, `timezone`, `status`다.
- inbox와 push routing에는 household/occurrence/delivery 식별자만 남긴다. title, description, household/member display name, email, raw provider response와 token material은 저장하지 않는다.
- horizon enqueue와 worker mutation은 service role만 실행할 수 있다. authenticated client는 preference/inbox/target의 기존 mediated API만 사용한다.
- strict timestamp validator는 UTC `Z` 또는 numeric offset이 없는 source timestamp를 거부한다.
- 실제 customer data, production credential, Firebase project와 hosted environment는 사용하지 않았다.

## Client Surface

- Flutter domain은 `calendar_event` category와 canonical `calendar_occurrence` subject pair를 함께 검증한다. mismatched pair는 inbox와 push parser 모두에서 fail closed한다.
- 알림 센터에 Calendar preference row와 category label을 추가했다. visible notification copy는 family content를 포함하지 않는 generic EN/KO/EN-XA 문자열이다.
- foreground/background/terminated envelope는 기존 auth 준비와 active-household wait 뒤 server target 재인가를 거친다. stale, cancelled 또는 mismatched target은 알림 센터로 돌아간다.
- Android notification channel 설명도 Chore 전용 문구에서 generic household reminder 문구로 변경했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Calendar reminder pgTAP | PASS — 46/46: timed/all-day schedule, recurring revision audience, one-time participant change, 32-day horizon, future gating, per-audience cancellation, preference, push claim와 target auth |
| related notification pgTAP | PASS — 467 assertions across Chore hooks 79, source worker 86, preference/inbox 85, push delivery 48, push reliability 48, endpoint 58, inbox concurrency 10, outbox concurrency 7 and Calendar 46 |
| full DB regression baseline | PASS — 53 files / 2,662 tests after migration and cascade change; 이후 추가한 recurring snapshot 4개 assertion은 focused 46/46으로 별도 재검증 |
| database lint | PASS — `app_private,public`, warning level, fail-on-error; schema error 0 |
| notification Node focus | PASS — 41 tests |
| full Node regression | PASS — 140 tests |
| notification Flutter focus | PASS — 49 tests |
| full Flutter regression | PASS — 1,004 tests; local-connectivity opt-in 1 skip; 나머지 전부 통과 |
| Flutter analyzer | PASS — issue 0 |
| formatter | PASS — 570 Dart files checked, drift 0 |
| localization generation | PASS — exact Flutter `gen-l10n`; en/ko/en-XA generated files current and pseudo expansion pass |
| whitespace | PASS — final `git diff --check`, output 0 |

`20260809130000_calendar_event_reminders.sql`은 기존 로컬 migration history 위에 forward apply했다. 장시간 전체 DB 회귀는 통과했지만, 사용자 작업 상태를 파괴할 수 있는 clean reset은 수행하지 않았으므로 clean-from-zero나 hosted migration 완료를 주장하지 않는다.

## Files and Migration

- Contract: `docs/contracts/calendar-event-reminder.yaml.md`
- Migration: `supabase/migrations/20260809130000_calendar_event_reminders.sql`
- DB coverage: `supabase/tests/database/calendar_event_reminders.test.sql` 및 기존 notification hook/worker/inbox/push/reliability/concurrency regressions
- Edge contracts/runtime: `supabase/functions/_shared/notification_worker_contract.mjs`, `notification_push_contract.mjs`, `notification_push_runtime.mjs`
- Node tests: `scripts/ci/notification-worker-contract.test.mjs`, `scripts/ci/notification-push-contract.test.mjs`
- Flutter: notification domain/push models, notification center, test fakes, EN/KO/EN-XA ARB/generated localization와 Android notification resources

## Manual and Deferred Validation

- hosted Supabase scheduler가 Calendar horizon enqueue와 source/inbox/push workers를 실제 cadence로 실행하는 검증은 **NOT RUN**이다.
- 실제 Firebase service account/project, FCM send/receipt, Android foreground/background/terminated 표시와 tap은 **NOT RUN**이다.
- 실계정 participant 추가·제거, 반복 일정 수정/취소, 두 기기 동시 수신과 account switch는 **NOT RUN**이다.
- physical Android permission, OEM battery restriction, timezone travel/DST와 TalkBack 확인은 **NOT RUN**이다.
- iOS/APNs, Web Push, multiple reminders와 approval category는 이 WP 범위 밖이다. 당시 제외했던 user-selected lead time은 후속 `WP05_11_EVIDENCE.md`에서 별도 검증한다.

## Remaining Risks and Completion Boundary

1. hosted scheduler 배치 지연과 실제 queue throughput은 로컬 bounded sweep이 증명하지 않는다.
2. Firebase submission ambiguity와 provider outage 정책은 기존 synthetic reliability suite로만 검증했으며 Calendar 실제 delivery telemetry는 없다.
3. all-day 09:00은 household timezone 변경 후 latest source/sweep 시 재계산되지만 실제 여행·DST 기기 표시를 확인하지 않았다.
4. 기존 Chore 명칭의 outbox table/RPC는 호환성을 위해 의도적으로 남아 있어, 후속 rename은 expand/contract migration과 N-1 검증이 필요하다.
5. Phase 05 상위 Exit Gate는 hosted provider, 실제 계정과 실기기 evidence가 없어 계속 `PARTIAL`이다.

WP05-07 자체는 provider-independent local Calendar reminder vertical slice로 완료했다. 실계정·실기기 Gate는 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 수행한다.

## Rollback

- Calendar horizon enqueue 호출을 중지하면 새 먼 미래 Calendar source 생성을 멈출 수 있다.
- `calendar_event` preference를 disable하거나 기존 notification worker/push pause를 사용하면 새로운 inbox/push delivery를 차단할 수 있다.
- 기존 Chore category와 backward-compatible worker interfaces는 유지된다.
- schema rollback은 destructive down migration 대신 forward corrective migration으로 수행한다.
