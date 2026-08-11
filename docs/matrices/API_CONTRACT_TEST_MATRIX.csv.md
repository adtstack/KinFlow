# 원본 파일 문서화: `matrices/API_CONTRACT_TEST_MATRIX.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/API_CONTRACT_TEST_MATRIX.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `56`

```csv
﻿ID,Operation,Scenario,Expected result,Automation,Phase
API-001,POST /households,valid user + idempotency,201 household + owner member,"unit, integration, DB transaction",P01/P02
API-002,POST /households,same key/same payload,"same response, no duplicate",integration,P02
API-003,POST /households,same key/different payload,409 IDEMPOTENCY_KEY_REUSED,integration,P02
API-004,POST /invites/preview,valid raw token,minimal preview only,"contract, integration",P02
API-005,POST /invites/preview,expired/revoked token,410 stable error,"contract, integration",P02
API-006,POST /invites/preview,brute-force rate,429 RATE_LIMITED,security test,P02
API-007,POST /invites/accept,concurrent double accept,"one membership, idempotent result","integration, concurrency",P02
API-008,POST /invites/accept,wrong target email,403 INVITE_EMAIL_MISMATCH,integration,P02
API-009,POST owner-transfer,last owner/new invalid member,"409/403, invariant preserved","DB, RLS, integration",P02
API-010,PUT member role,outsider UUID injection,"404/403, no leak","RLS, integration",P02
API-011,POST acting-context,non-guardian child,403 ACTING_CONTEXT_INVALID,"DB, security",P1 child gate
API-012,POST chore complete,valid expected version,200 completed + audit/outbox,"unit, DB, integration",P03
API-013,POST chore complete,stale expected version,409 VERSION_CONFLICT,integration,P03
API-014,POST chore complete,different household occurrence,"404/403, no mutation","RLS, integration",P03
API-015,PUT chore series,invalid recurrence interval/count,400 RECURRENCE_RULE_INVALID,"contract, unit",P03
API-016,PUT event series,DST gap local time,deterministic adjusted occurrence,"unit, integration",P04
API-017,PUT event series,thisOccurrence scope,"exception only, series unchanged","DB, integration",P04
API-018,PUT event series,entireSeries scope,"new revision, past completion/history preserved","DB, integration",P04
API-019,GET /today,household timezone date,bounded stable aggregate,"contract, performance",P03/P04
API-020,GET /today,limit > 500,400 validation,contract,P03
API-021,POST notification endpoint,token rotation same installation,upsert one active endpoint,integration,P05
API-022,POST notification endpoint,logout/account switch,old binding revoked/removed,"E2E, integration",P05
API-023,POST billing sync,verified purchase + eligible household,server entitlement active,"sandbox, integration",P06
API-024,POST billing sync,provider timeout,"503 retryable, no premature unlock",integration,P06
API-025,POST billing assignment,customer already assigned elsewhere,409 BILLING_ASSIGNMENT_CONFLICT,integration,P06
API-026,POST RevenueCat webhook,duplicate provider event,single receipt/effect,integration,P06
API-027,POST RevenueCat webhook,out-of-order event,authoritative reconcile prevents rollback,integration,P06
API-028,POST privacy request,duplicate pending request,409 PRIVACY_REQUEST_ALREADY_PENDING,integration,P07
API-029,GET privacy request,other user request ID,"404/403, no metadata leak","RLS, integration",P07
API-030,all endpoints,invalid/unknown body fields,400 stable envelope,contract fuzz,all
API-031,all endpoints,expired JWT,401 SESSION_EXPIRED,"contract, integration",all
API-032,all endpoints,provider/SQL exception,"safe INTERNAL_ERROR, no raw details","security, contract",all
API-033,mutation endpoints,missing idempotency key,400 IDEMPOTENCY_KEY_REQUIRED,contract,all
API-034,all responses,contract version/request ID,present and schema-valid,contract,all
API-035,RPC update_one_time_chore,active adult scheduled one-time exact dual version,new immutable revision plus stable updated occurrence; replay exact and conflicts safe,"contract, unit, DB, RLS, concurrency",P03
API-036,RPC delete_one_time_chore,active adult scheduled one-time exact dual version,series soft-deleted and occurrence cancelled with revision/audit preserved; replay exact,"contract, unit, DB, RLS, concurrency",P03
API-037,RPC get_household_activation_progress,active member requests exact household historical activation aggregate,one exact capped content-free row; unauthorized generic denial and DB local-date authority,"contract, unit, DB, RLS",P03
API-038,RPC get_deleted_one_time_chores,active exact-household member requests bounded soft-deleted scheduled one-time page,exact 18-key rows or metadata-only empty row in deterministic opaque-cursor order; unauthorized generic denial,"contract, unit, DB, RLS",P03
API-039,RPC restore_one_time_chore,active exact-household member supplies deleted one-time identity dual expected versions and idempotency key,preserved revision content due and assignee restored to scheduled with dual version increment; exact replay and conflicts safe,"contract, unit, DB, RLS, concurrency",P03
API-040,RPC enqueue_calendar_event_reminder_events,service role runs bounded notification horizon sweep,content-free exact-audience Calendar sources created idempotently while non-service callers are denied,"contract, DB, RLS, integration",P05
API-041,RPC list_my_households,authenticated active adult lists own current memberships,exact privacy-minimized 7-key rows with zero-or-one active selection and unrelated removed deleted memberships absent,"contract, unit, DB, RLS",P02
API-042,RPC switch_active_household,authenticated adult submits target household and expected selection version,server-derived target member with same-target no-op exact version increment private audit and generic unavailable/conflict failures,"contract, unit, DB, RLS, concurrency",P02
API-043,POST manage-household-members leaveHousehold,authenticated non-Owner leaves with expected member version and idempotency key,atomic tombstone invite revoke and exact nullable fallback pair consumed by fail-closed local auth handoff,"contract, unit, DB, RLS, integration",P02
API-044,RPC get_chore_occurrence_target,authenticated active-household member requests an exact occurrence UUID,one strict latest scheduled/completed projection; skipped deleted-scheduled missing and forbidden share generic denial while completed history survives series deletion,"contract, unit, DB, RLS, integration",P05
API-045,RPC get_chore_occurrence_action_target,authenticated active-household adult requests an exact actionable occurrence UUID,WP05-08 strict projection plus exact server-derived can_set_completion; Owner/Admin or current assignee may act on active series while deleted history and unassigned regular members remain read-only and the old RPC shape is preserved,"contract, unit, DB, RLS, integration",P05
API-046,RPC get_household_weekly_report,authenticated active adult requests one server-derived closed household-local week at offset 0 through 11,one exact content-free aggregate with bounded active-member contribution rows and count-only removed deleted overflow contributors; caller date control and unauthorized scope denied,"contract, unit, DB, RLS, privacy",P03
API-047,RPC update_repeating_chore_series_from_occurrence,Owner/Admin submits active scheduled occurrence identity plus exact series version and normalized full rule,server derives immutable recurrence-slot boundary; earlier and completed history is preserved; later incomplete rows rebuild; same-key replay is exact and stale forbidden one-time old-revision or completed targets fail closed,"contract, unit, DB, RLS, concurrency, privacy",P03/P1
API-048,RPC cancel_repeating_chore_series_from_occurrence,Owner/Admin submits active scheduled occurrence identity plus exact series version,server derives immutable recurrence-slot boundary; later incomplete rows cancel; completed history remains; earlier scheduled prefix receives a bounded terminal revision or the series soft-deletes when no prefix remains; same-key replay and unavailable targets fail closed,"contract, unit, DB, RLS, concurrency, privacy",P03/P1
API-049,RPC update_recurring_calendar_series_from_occurrence,active household member submits active scheduled non-exception occurrence identity plus exact series version and normalized full rule,server derives immutable recurrence-slot boundary; earlier rows and all explicit exceptions remain exact; matching later source identities rebuild and obsolete slots cancel; same-key replay and legacy whole-series signature/hash remain safe,"contract, unit, DB, RLS, concurrency, privacy",P04/P1
API-050,RPC cancel_recurring_calendar_series_from_occurrence,active household member submits active scheduled non-exception occurrence identity plus exact series version,server derives immutable recurrence-slot boundary; every later row including moved explicit exceptions cancels; earlier rows remain; an actionable prefix receives a bounded terminal revision or the series ends at the boundary; same-key replay and legacy whole-series signature/hash/result remain safe,"contract, unit, DB, RLS, concurrency, privacy",P04/P1
API-051,RPC get_notification_preferences_v2 / update_notification_preference_v2,authenticated active household member reads or version-updates one self-scoped preference with a strict Calendar lead,"exact 13-key v2 rows; fixed 0/5/10/15/30/60 Calendar-only lead; v1 exact 12-key and lead-preserving writes remain compatible; unevaluated future personal resolutions and pending push time update atomically","contract, unit, DB, RLS, integration, compatibility",P05/P1
API-052,RPC resume_repeating_chore_series_cancellation,original selected-boundary cancellation actor submits a new resume key plus exact household series original cancellation key and cancellation-result version,"current Owner/Admin and exact cancellation terminal shape restore ledger-bound scheduled or skipped rows through a new immutable resumed revision; completed or later-edited prefix is preserved; same-key replay is exact and the legacy cancellation signature/result remain compatible","contract, unit, DB, RLS, concurrency, privacy, compatibility",P03/P1
API-053,RPC resume_recurring_calendar_series_cancellation,original selected-boundary Calendar cancellation actor submits a new resume key plus exact household series original cancellation key and cancellation-result version,active membership and exact cancellation terminal or ended shape restore ledger-bound scheduled completed or skipped rows and moved exception semantics through a new immutable revision; same-key response-loss replay is exact and the legacy cancellation signature/result remain compatible,"contract, unit, DB, RLS, concurrency, privacy, compatibility",P04/P1
API-054,RPC list_notification_inbox_items_v2 / snooze_calendar_notification,"authenticated active household member reads caller-owned inbox Snooze metadata or submits one Calendar item, fixed minutes, UUID command, and expected item version","v1 inbox remains exact; v2 returns exact 16-key bounded metadata; command atomically supersedes original inbox and pending push, emits one content-free source, returns exact 9-key receipt and replays the same command without duplication","contract, unit, DB, RLS, concurrency, privacy, compatibility, integration",P05/P1
API-055,RPC get_notification_preferences_v3 / update_notification_preference_v3,authenticated active household member reads or version-updates one self-scoped primary plus zero-to-two additional Calendar reminder set,"exact 14-key v3 rows; fixed sorted distinct total one-to-three leads; v1 exact 12-key preserves all and v2 exact 13-key replaces only primary while preserving extras; future-only source add and unevaluated schedule reconciliation","contract, unit, DB, RLS, concurrency, privacy, compatibility, integration",P05/P1
API-056,POST /notification-email-worker plus service email delivery RPCs,dedicated scheduler bearer submits an exact empty POST and service role mediates claim marker completion and pause,"aggregate-only worker response; recipient email exists only in one exact 15-key claim; durable marker precedes fixed generic provider I/O; accepted retryable permanent and ambiguous completion are bounded","contract, unit, DB, RLS, security, privacy, reliability, integration",P05/P1
```
