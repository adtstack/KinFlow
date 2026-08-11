# Phase 05 WP05-01 Notification Outbox Worker Evidence

- Work Package: WP05-01 — leased Chore notification Outbox, latest-state resolution, retry/dead letter/replay, pause/health, internal Edge worker
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, Node 24.15.0, npm 11.12.1, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-01 LOCAL AUTOMATED PASS / HOSTED SCHEDULER·REMOTE ALERT·INBOX·PROVIDER·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-01 / FR-NOTIF-003 | PASS FOR LOCAL CANDIDATE SLICE | 기존 content-free due/assignment event를 lease로 claim하고 최신 occurrence, series, recipient를 다시 평가해 source event당 actionable candidate 또는 allowlisted suppression을 durable하게 확정한다. candidate는 inbox item이나 send 성공이 아니다. |
| WP05-01 / FR-NOTIF-006 | PASS FOR LOCAL QUEUE SLICE / OVERALL PARTIAL | source event unique resolution, response-loss replay, 최대 5회 server-computed backoff+jitter, final dead letter, expired final lease sweep와 manual replay를 검증했다. provider receipt와 delivery dedupe는 후속 WP다. |
| D-022 / D-023 | PASS FOR NEW AUTHORITY BOUNDARY | 서버 Outbox/worker가 권위이며 client lifecycle이나 background scheduler에 의존하지 않는다. 앱 runtime/dependency/permission은 추가하지 않았다. |
| NFR-REL-01 | PASS FOR NEW LOCAL SLICE | `FOR UPDATE SKIP LOCKED`, opaque token, heartbeat, expired lease reclaim, poison isolation, two-worker contention, retry/dead-letter/replay와 atomic success를 pgTAP으로 검증했다. |
| NFR-SEC-01 / NFR-SEC-02 | PASS FOR NEW WORKER SURFACE | public worker RPC는 service role만 실행한다. service role도 private Outbox/resolution/transition/control/helper/resolver를 직접 읽거나 변경할 수 없다. Edge 진입점은 별도 32자 이상 server secret을 exact Bearer로 검증한다. |
| NFR-PRIV-01 | PASS FOR NEW PAYLOAD | claim, transition, health와 Edge summary에는 content, display name, email, token, provider body와 raw error가 없다. suppression은 recipient와 schedule을 null로 저장한다. |
| NFR-OBS-01 | PASS FOR LOCAL PRIMITIVES / OVERALL PARTIAL | immutable content-free lifecycle transition, pause state, ready/retry/leased/expired/dead-letter counts, oldest ready와 next retry aggregate를 제공한다. hosted dashboard/alert/retention은 남았다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | 기존 WP03 event envelope/producer/resolver와 Chore/Calendar API signature를 유지하고 lifecycle columns/private tables/public mediated APIs만 additive하게 추가했다. |

## Queue and Resolution Contract

- lifecycle은 `pending`, `leased`, `retry_wait`, `succeeded`, `dead_letter` 다섯 상태다. state check와 transition trigger가 envelope, attempt, replay와 terminal-state 불변식을 보호한다.
- claim은 batch 1–100, lease 5–300초만 허용하고 ready timestamp, event occurrence, event UUID 순으로 `FOR UPDATE SKIP LOCKED`한다. attempt를 증가시키고 worker UUID와 opaque lease token을 저장한 뒤에만 반환한다.
- heartbeat는 일치하는 아직 유효한 token만 연장하며 caller `as_of` 기준 최대 5분을 넘지 않는다. 만료된 non-final lease는 다음 attempt로 reclaim하고, 만료된 final lease는 `LEASE_EXPIRED` dead letter로 격리한다.
- process는 lease row lock 안에서 기존 latest-state resolver를 실행한다. candidate는 category/subject/recipient IDs, schedule/timezone만 저장한다. suppression은 `stale_event`, `inactive_series`, `occurrence_not_scheduled`, `inactive_recipient`, `schedule_unresolved` 중 하나다.
- resolution insert, Outbox `succeeded`, succeeded transition은 같은 transaction이다. 응답 유실 후 같은 event process 재호출은 최초 `resolved_at`과 한 resolution을 반환하고 succeeded audit를 중복하지 않는다.
- failure는 uppercase stable code만 받고 attempt 1의 30초부터 exponential backoff와 event/attempt 기반 0–15초 deterministic jitter를 적용한다. attempt 5는 즉시 dead letter다.
- replay는 dead letter만 `pending`, attempts 0으로 되돌리고 replay count/reason을 immutable transition에 남긴다. pause 중 새 claim은 비어 있지만 기존 lease의 heartbeat/process/fail은 마무리할 수 있다.
- health는 aggregate counts/timestamps와 pause reason만 반환한다. event, household, subject, recipient UUID나 payload를 반환하지 않는다.

## Edge Worker Contract

- `notification-outbox-worker`는 body와 query가 없는 `POST`만 받는다. `verify_jwt = false`는 일반 공개 접근을 허용하기 위한 설정이 아니라 전용 `KINFLOW_NOTIFICATION_WORKER_SECRET` exact Bearer 검증을 함수 내부에서 수행하기 위한 것이다.
- scheduler secret과 `SUPABASE_SERVICE_ROLE_KEY`는 server environment에서만 읽고 Flutter/web configuration에 추가하지 않는다. secret 비교는 SHA-256 digest를 이용해 길이와 byte 차이를 누적한다.
- 한 호출은 server clock, server-generated worker UUID, bounded batch/lease 설정으로 claim → process를 순회한다. process 오류는 raw detail 없이 `WORKER_PROCESSING_FAILED`만 failure RPC에 전달한다.
- HTTP success는 candidate/claimed/retry/dead-letter/suppressed/unrecorded-failure 집계와 contract version만 반환한다. 인증·runtime 오류도 stable code/retryable flag만 반환하고 exception/provider body를 읽거나 반사하지 않는다.
- hosted schedule, secret-manager injection과 실제 Edge runtime live invocation은 이번 local slice에서 구성하지 않았다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS, ordered 25 migrations including `20260808010000_notification_outbox_worker.sql` and synthetic seed |
| focused worker lifecycle pgTAP | PASS, 86/86 |
| focused two-worker concurrency pgTAP | PASS, 7/7 |
| predecessor notification producer/resolver pgTAP | PASS, 79/79 |
| full database regression | PASS, 29 files / 1,658 pgTAP tests |
| database lint | PASS, warning level with fail-on-error; schema error 0 |
| pure worker/Edge/PostgREST contract | PASS, 15/15 |
| repository JavaScript contract suite | PASS, 62/62 |
| full Flutter regression | PASS, 464 tests + local-connectivity opt-in 1 skip |
| full Flutter coverage | PASS, 10,078/12,710 lines, 79.29% |
| exact formatter/analyzer | PASS, 275 files changed 0; analyzer issue 0 |
| public config/secret/codegen | PASS, public config allowlist; high-confidence secret 0; generated drift 0/8 files |
| dependency/license/vulnerability | PASS, 150 Pub + 15 npm license audit; offline OSV scan PASS |
| workflow/supply chain | PASS, 5 jobs, 17 pinned action uses, `contents:read` |
| matrix structure | PASS, requirements 116×18, tests 61×11, risks 30×15, release 23×10 |
| whitespace | PASS, implementation-stage `git diff --check` output 0 |

Focused DB fixtures cover exact schema/function output/grants/search path, client and direct-service denial, content-free columns, invalid bounds and raw error rejection, two category candidates, timezone due instant, heartbeat token mismatch, response-loss replay, attempt backoff bounds, early-claim denial, attempt-five poison isolation, expired final lease, manual replay, pause/resume, aggregate health, immutable transition audit, every suppression reason and two competing workers with an externally locked head row.

Pure worker fixtures cover strict response key allowlists, duplicate claim identity rejection, malformed/content-shaped payload rejection, process failure recording, failure-API outage, aggregate-only HTTP response, empty-POST/query/method boundary, exact scheduler secret and PostgREST credential/error mapping.

## Files and Migration

- Migration: `supabase/migrations/20260808010000_notification_outbox_worker.sql`
- Worker core/runtime: `supabase/functions/_shared/notification_worker_contract.mjs`, `notification_worker_runtime.mjs`
- Edge entry/config: `supabase/functions/notification-outbox-worker/index.ts`, `deno.json`, `supabase/config.toml`
- Tests: `supabase/tests/database/notification_outbox_worker.test.sql`, `notification_outbox_worker_concurrency.test.sql`, predecessor `chore_notification_hooks.test.sql`, `scripts/ci/notification-worker-contract.test.mjs`
- Contracts: `docs/contracts/notification-worker.yaml.md`, notification inbox/domain event/database/env contracts
- Governance: Phase 05 document, implementation/master snapshots, requirements/test/risk/release matrices and `WP05_01_WORKPLAN.md`

## Security, Privacy, and Data

- mobile/web bundle에는 service-role key나 worker secret을 넣지 않았다. 전용 Edge runtime만 두 server secret을 읽으며 query/body로 secret이나 worker 설정을 받지 않는다.
- `anon`과 `authenticated`는 worker RPC를 실행할 수 없다. `service_role`도 private schema table/helper/resolver direct privilege가 없고 bounded security-definer API만 사용한다.
- resolution candidate에는 내부 routing을 위해 household/subject/member/user UUID와 schedule/timezone이 저장된다. household title, chore title/description, display name, email, auth token, push token, receipt, provider payload와 raw exception은 저장하지 않는다.
- suppression row는 recipient IDs와 scheduled instant를 제거한다. transition/control/health에는 business payload나 household/recipient ID를 추가하지 않는다.
- Edge handler는 provider failure body를 읽지 않고 stable error로 축약한다. worker summary는 개수만 반환하며 event/household/recipient/worker UUID를 반환하지 않는다.
- 자동 검증은 synthetic UUID/content와 local Supabase만 사용했다. production project, 고객 계정, 실제 token, 실제 notification provider 또는 고객 데이터를 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 계정, 실제 household, remote Supabase deploy와 실제 계정 event 생성은 **NOT RUN**이다.
- hosted cron/scheduler, production secret manager, actual Edge invocation, concurrent remote workers, queue throughput/index plan, dashboard/alert/pager와 runbook drill은 **NOT RUN**이다.
- durable inbox/read state, preference, category opt-in, quiet hours/timezone travel 재평가와 badge는 **NOT IMPLEMENTED / NOT RUN**이다.
- device installation/FCM token, APNs/FCM send/receipt, invalid token cleanup, permission UI, foreground/background/terminated delivery와 notification tap은 **NOT IMPLEMENTED / NOT RUN**이다.
- 실제 iOS/Android 기기와 실계정 검증은 대다수 기능 개발 이후 마지막 gate로 유지한다.

## Remaining Risks and Completion Boundary

1. 로컬 handler 계약은 green이지만 hosted scheduler와 secret-manager wiring이 없어 queue가 production에서 자동으로 깨어나지는 않는다.
2. candidate는 durable routing decision일 뿐 사용자 inbox나 provider send가 아니다. WP05-02/03/04 전까지 사용자가 알림을 받지 않는다.
3. transition과 succeeded/dead-letter row retention/cleanup 정책이 아직 없다. production volume과 index selectivity, vacuum/storage 비용을 측정해야 한다.
4. local dblink는 row-lock 경쟁을 검증하지만 multi-region/network timeout, Edge termination timing과 hosted PostgREST connection behavior는 재현하지 않는다.
5. provider delivery를 추가할 때 source resolution dedupe만으로 send 중복을 막을 수 없다. delivery receipt/dedupe key와 ambiguous provider response reconciliation이 별도로 필요하다.
6. account deletion과 member lifecycle이 candidate routing metadata를 어떻게 purge/cancel하는지는 WP05-02/03과 Phase 07 retention policy에서 함께 검증해야 한다.
7. Phase 05 전체와 FR-NOTIF 전체는 inbox/preferences/device/provider/remote/device gate가 남아 `PARTIAL`이다. 완료로 표시하지 않는다.

WP05-01 자체는 local automated vertical slice로 완료했다. 상위 기능 목표는 계속 active다.

## Rollback

- 운영 기능 중지는 먼저 `set_chore_notification_worker_paused(true, 'ROLLBACK_PAUSE', as_of)`로 새 claim을 막고 hosted scheduler/Edge invocation을 중지한다. 이미 유효한 lease는 만료 또는 mediated process/fail로 정리한다.
- production 적용 전에는 migration, worker function/config, tests와 contracts를 함께 revert하고 이전 24-migration/1,565-test baseline으로 clean reset한다.
- production 적용 후에는 applied migration을 수정하거나 private rows를 즉시 삭제하지 않는다. forward migration으로 public worker execute를 revoke하고 control을 pause한 뒤 corrective API를 배포한다.
- 기존 Chore mutation과 WP03 producer는 worker pause 중에도 business data와 source events를 안전하게 유지한다. Outbox/resolution/transition은 forensic/replay 판단과 승인된 retention 전까지 보존한다.
- mobile client schema/API는 변경하지 않았으므로 WP05-01만의 client rollback은 없다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 05 WP05-02 notification preferences/quiet hours/durable inbox/read-unread-badge vertical slice다.
- WP05-02는 `candidate`만 소비하고 `(recipient_user_id, source_event_id, category)` unique dedupe, active membership/latest state 재검증, recipient-user RLS와 content-minimal deep-link payload를 먼저 고정해야 한다.
- quiet hours는 IANA timezone과 DST gap/fold policy를 사용하고 assignment/due category preference를 server-side에서 재평가해야 한다. suppressed 또는 cancelled candidate가 inbox item으로 부활하면 안 된다.
- WP05-02에서도 provider send와 device token을 결합하지 않는다. inbox가 provider 실패와 독립적으로 durable해진 뒤 WP05-03 endpoint, WP05-04 delivery로 진행한다.
- 실계정·remote·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 후 마지막 gate에 유지한다.
