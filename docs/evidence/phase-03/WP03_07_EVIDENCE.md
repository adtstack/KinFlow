# Phase 03 WP03-07 Chore Notification Event Hooks Evidence

- Work Package: WP03-07 — content-free due/assignment producer, latest-state resolver, future inbox contract
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/B/C/D/E/F/G/H/WP03-06 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / INTENT·DURABLE INBOX·PUSH·REMOTE·REAL-ACCOUNT LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-07 | PASS FOR LOCAL AUTOMATED SLICE | occurrence insert와 due/status/assignee update가 같은 transaction에서 versioned event를 기록하며 latest state로 stale·recipient·schedule suppression을 재판정한다. |
| FR-NOTIF-003 (FOUNDATION) | PARTIAL | due/assignment event producer와 latest-state resolver로 intent evaluation과 delivery를 분리할 경계를 만들었다. 실제 intent/job/send는 Phase 05다. |
| FR-NOTIF-006 (EVENT DEDUPE) | PARTIAL | event UUID와 `(household, type, occurrence, aggregate version)` unique key 및 command replay duplicate 0을 자동 검증했다. provider receipt, retry cap과 dead letter는 Phase 05다. |
| FR-NOTIF-007 (CONTRACT) | PARTIAL | `chore_due`, `chore_assignment` category와 future inbox item v1을 고정했다. preference UI와 opt-in은 구현하지 않았다. |
| NFR-SEC-01 | PASS FOR NEW PRIVATE BOUNDARY | outbox와 resolver는 `app_private`에 있고 public/anon/authenticated/service-role에 table/function 권한을 부여하지 않는다. future worker는 별도 mediated API가 필요하다. |
| NFR-PRIV-01 | PASS FOR EVENT PAYLOAD | exact payload constraint가 UUID/date/instant/timezone/status 외 key를 거부하며 title, description, display name, email, token과 raw error를 저장하지 않는다. |
| NFR-REL-01 | PASS FOR PRODUCER/RESOLVER FOUNDATION | row trigger는 business mutation과 원자적이고 replay는 event를 중복 생성하지 않는다. late/out-of-order event는 latest-state resolver가 suppress한다. delivery retry는 남아 있다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | 새 private table/trigger/function/contract만 추가했으며 기존 RPC signature와 Flutter client를 변경하지 않았다. fresh migration과 전체 회귀를 통과했다. |

## Database and Event Contract

- `20260807090000_chore_notification_hooks.sql`은 `app_private.chore_notification_outbox`를 추가한다. event envelope은 UUID/type/version, household, optional actor, occurrence aggregate/version, correlation, exact payload, occurred-at과 future dispatcher state를 가진다.
- event vocabulary는 `chore.occurrence_due_changed` v1과 `chore.occurrence_assigned` v1이며 aggregate는 `chore_occurrence`다.
- due payload exact keys는 `dueLocalDate`, `dueAt`, `timezone`, `status`다. assignment payload exact keys는 `assigneeMemberId`, `status`다. DB check는 key set, JSON type, UUID/status/IANA timezone을 fail closed로 검증한다.
- occurrence `AFTER INSERT OR UPDATE` trigger는 insert에서 두 event를 기록한다. due local date/instant/timezone/status 변화는 due event를, assignee 변화는 assignment event를 기록하며 occurrence version trigger가 계산한 최신 version을 aggregate version으로 사용한다.
- authenticated command에서는 동일 household의 active member만 optional actor로 기록한다. JWT가 없는 trusted materializer insert는 actor fields를 null로 유지한다.
- unique key와 기존 command idempotency가 create/reassign/cancel replay의 duplicate event를 막는다. envelope/payload와 occurred-at은 dispatcher state 외 update가 금지되고 attempts 감소와 dispatched 상태 되돌리기도 거부한다.
- API role에는 outbox read/write/delete 권한이나 resolver execute를 부여하지 않았다. privileged worker grant와 retention/delete policy는 Phase 05 migration에서 별도로 고정해야 한다.

## Latest-State and Future Inbox Contract

- `app_private.resolve_chore_notification_event(event_id)`는 event와 현재 occurrence, series, recipient를 다시 읽는다. invoker-rights internal function이며 API role에서 직접 호출할 수 없다.
- due/assignment event는 같은 occurrence/type 중 최신 event이고 stored category fields가 현재 값과 같을 때만 current다. 관련 없는 다른 category의 occurrence version 증가는 event를 자동 stale 처리하지 않지만 완료→재개나 skip→restore가 과거 due event를 되살리지는 않는다.
- due recipient는 현재 assignee이고 assignment recipient는 event assignee다. 두 경우 모두 active adult member와 auth user가 존재해야 한다.
- suppression reason은 `stale_event`, `inactive_series`, `occurrence_not_scheduled`, `inactive_recipient`, `schedule_unresolved` allowlist다. completed/skipped/cancelled occurrence와 soft-deleted series는 새 intent 대상이 아니다.
- all-day due는 승인된 reminder instant가 없으므로 device-local 시간을 만들어내지 않고 unresolved로 남긴다. all-day assignment는 schedule과 무관하게 current recipient에게 평가 가능하다.
- `domain-events.yaml.md`는 두 event와 exact payload schema를 추가했고 consolidated implementation/master snapshot도 같은 2026-08-07 vocabulary로 동기화했다.
- `notification-inbox.yaml.md`는 Phase 05용 inbox item v1, source-event/category/recipient dedupe, minimal household/occurrence payload, read/cancel state와 deep-link reauthorization/refetch 규칙을 고정한다. durable table 자체는 이번 slice에 없다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 17개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused notification-hook pgTAP | PASS, 79/79 |
| full pgTAP/RLS regression | PASS, 19 files, 1,045 tests; predecessor 966 + 신규 79 |
| full Flutter regression | PASS, 336 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 226 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow/actionlint | PASS, 47/47; 5 jobs, pinned action 17개, workflow lint pass |
| unchanged Edge unit regression | PASS, invite 22/22, member lifecycle 18/18 |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated drift 0/8 files |
| coverage | PASS, 6,431 / 8,185 lines = 78.57% |
| whitespace and contract snapshot | PASS, `git diff --check` output 0 and domain-event snapshots synchronized |

Focused fixture는 exact columns/checks/FK/unique/partial index, trigger/function/search-path/grant, one-time/all-day/repeating/trusted insert, create/reassign/cancel replay, reschedule/reassign/complete/reopen/skip/restore/series cancel, actor-null materialization, dispatcher-state protection, additional payload key rejection과 API-role denial을 포함한다.

Resolver fixture는 current due/assignment, unrelated-category version tolerance, stale reschedule/reassignment, completion/reopen과 skip/restore 후 과거-event 비부활, latest assignee routing, non-scheduled state, deleted series, all-day unresolved schedule와 removed recipient suppression을 포함한다.

## Data, Security, and Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/content만 사용했다. production migration, 실제 계정, 실제 household 또는 고객 content는 사용하지 않았다.
- event payload는 household content와 사람의 표시 정보를 담지 않는다. title/description/display name/email/auth subject/token/receipt/raw error key를 정규식 및 exact-key fixture로 거부한다.
- actor user/member는 private envelope의 감사 routing metadata일 뿐 payload나 client contract에 노출되지 않는다. future worker가 inbox item을 만들 때도 client payload는 household/occurrence ID만 허용한다.
- raw provider failure 대신 allowlisted `last_error_code`만 저장할 수 있다. 실제 provider receipt와 token은 이 table 범위가 아니다.
- outbox와 resolver는 RLS 공개 table이 아니라 private schema + revoked grants 경계다. service role도 직접 우회하지 못하며 Phase 05가 최소권한 mediated worker entry를 명시적으로 추가해야 한다.
- 새 mobile SDK, native permission, device token, analytics event, persistent client cache 또는 external network dependency를 추가하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 create/reassign/complete/series change가 다른 기기의 알림으로 이어지는 검증은 **NOT RUN**이다.
- production Supabase deploy, remote trigger/outbox/worker role, scheduled wakeup, production cardinality/latency와 forward rollback rehearsal은 **NOT RUN**이다.
- notification intent evaluator, preference/quiet hours/timezone travel 재평가, durable inbox/read state, device registration, APNs/FCM delivery와 permission education은 **NOT IMPLEMENTED / NOT RUN**이다.
- provider outage/retry/dead-letter/receipt dedupe, push denied fallback, app-killed delivery, deep link와 account switch authorization은 **NOT RUN**이다.
- 실제 notification UI와 OS permission prompt가 없으므로 이번 slice에는 simulator/device UI smoke 대상이 없다.

## Remaining Risks and Completion Boundary

1. outbox는 authoritative input과 dispatcher 상태 자리만 제공한다. claim/lease, bounded retry, dead letter, retention, monitoring과 alert가 없어 아직 운영 queue가 아니다.
2. future worker grant는 의도적으로 없다. Phase 05가 private resolver를 감싼 최소권한 mediated function 없이 service-role broad grant를 추가하면 현재 보안 경계가 약화된다.
3. event payload는 content-free지만 private envelope의 actor/household routing metadata와 household cascade retention은 privacy deletion/retention 정책과 함께 검토해야 한다.
4. all-day due reminder instant 정책이 결정되지 않아 due intent가 suppressed된다. 기기 local default를 임의로 사용하면 timezone/DST 계약이 깨진다.
5. local automation은 trigger source independence를 증명하지만 production volume의 outbox 증가율, index selectivity, lock/trigger latency와 cleanup 비용은 측정하지 않았다.
6. 실제 계정·두 기기, remote deploy와 end-to-end delivery evidence가 없으므로 FR-NOTIF, WP03 전체 release gate 또는 제품 목표를 완료로 표시하지 않는다.

WP03-07 자체는 local automated producer/contract slice로 완료했다. 알림 기능은 Phase 05 intent/inbox/delivery와 마지막 real-account gate까지 `PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 WP03-07 migration/contracts/tests/evidence를 함께 revert하고 clean reset으로 이전 16개 migration과 966-test baseline을 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. forward migration에서 occurrence producer trigger를 먼저 disable해 새 event 생성을 멈춘다.
- 기존 outbox row는 즉시 삭제하지 않고 forensic/replay 판단을 위해 보존한다. corrective migration과 approved retention policy 후에만 privileged cleanup한다.
- 기존 occurrence/series/revision/audit data와 RPC signature는 변경하지 않는다. client rollback은 필요하지 않다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 04 WP04-01 Calendar event domain/schema와 household-timezone 기반 one-time event creation/read vertical slice다.
- 이후 Today에서 chore와 calendar source를 partial-failure-safe하게 합쳐 FR-TODAY-001/005를 완성한다. notification intent/inbox/push는 Phase 05에서 이 event 경계를 소비한다.
- 실제 계정·두 기기·remote Supabase gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
