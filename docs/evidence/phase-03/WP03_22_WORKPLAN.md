# Phase 03 WP03-22 Repeating Chore Cancellation Immediate Undo Workplan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — hosted/real-account/two-device/physical-device Gate는 마지막 검증 단계로 유지한다.
- 수직 조각: 선택 회차 이후 취소의 exact pre-state ledger → version-bound resume RPC → process-memory Snackbar Undo → authoritative reload
- 요구사항: `WP03-22`, `FR-CHORE-005`, `FR-CHORE-008`, `FR-CHORE-013`, `FR-CHORE-014`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`, `D-019`, `D-020`, `D-048`, `D-061`, `D-065`
- 계약: `docs/contracts/chore-series-cancellation-undo.yaml.md`
- 증거: `docs/evidence/phase-03/WP03_22_EVIDENCE.md`

## Product boundary

- Owner/Admin이 `이 회차부터 취소`에 성공하면 현재 앱 세션의 Snackbar에서 즉시 Undo할 수 있다.
- Undo는 원래 cancellation command, exact cancellation-result series version과 private occurrence pre-state ledger에 결합한다.
- 취소로 `cancelled`가 된 future scheduled/skipped occurrence를 원래 상태·revision으로 복원하고, 원래 active revision의 정상 occurrence는 새 immutable resumed revision으로 연결한다.
- cancellation이 만든 terminal prefix revision 또는 series soft-delete를 해제하되, 취소 이후 완료되거나 별도로 변경된 earlier prefix occurrence는 덮어쓰지 않는다.
- 성공과 terminal conflict 뒤에는 authoritative current query를 다시 읽는다. offline cache와 completion outbox에는 resume command를 저장하지 않는다.
- process death 뒤 recent-cancellation history, arbitrary historical resume와 실계정/실기기 검증은 이번 조각 범위가 아니다. Calendar immediate parity는 후속 WP04-16에서 구현한다.

## Server and compatibility contract

1. 기존 `cancel_repeating_chore_series_from_occurrence(...)` 이름, 인자와 exact 9-key 결과를 유지한다.
2. 기존 cancellation engine은 private로 이동하고 동일 public wrapper가 첫 실행 전에 mutation 후보의 metadata-only pre-state를 캡처한다. replay는 새 ledger를 만들지 않는다.
3. private ledger는 cancellation actor+command, occurrence, previous/post status·revision·version과 mutation kind만 저장한다. title, description, assignee, due, auth token과 display identity는 저장하지 않는다.
4. 새 `resume_repeating_chore_series_cancellation(...)`은 resume idempotency key, household, series, original cancellation idempotency key와 exact cancellation-result series version을 받는다.
5. authenticated original cancellation actor가 현재 active Owner/Admin이고 series가 아직 exact cancellation result version/terminal shape일 때만 resume한다.
6. source pre-cancellation revision을 새 immutable revision number로 복제하고 series를 active/non-deleted로 전환한다.
7. cancellation이 status를 바꾼 row는 post-state가 그대로일 때만 전부 복원한다. terminal prefix revision만 바뀐 row는 post-cancellation user action이 없을 때 복원하고, 이후 completed/edited prefix는 보존한다.
8. materialization coverage를 지워 canonical worker가 resumed recurrence를 계속 확장하게 한다.
9. immutable aggregate `resumed` event와 same-key response-loss replay를 기록한다. 다른 입력으로 같은 key를 쓰면 기존 idempotency conflict다.

## Client design

- domain은 cancellation command ID, household/series, effective boundary와 cancellation result version으로 process-memory undo receipt를 만든다.
- data source와 repository는 resume RPC exact result map을 strict parse하고 household/series/version/revision/count invariant를 재검증한다.
- controller는 successful selected-boundary cancellation 뒤 receipt를 유지하고 authoritative reload 후 state에 노출한다.
- Snackbar는 localized Undo action을 제공한다. single-flight와 runtime-policy chores guard를 network/command ID 전에 적용한다.
- resume success는 receipt를 지우고 authoritative query를 다시 읽는다. transient failure는 같은 resume key로 retry 가능하게 유지하고 stale/forbidden/invalid transition은 receipt를 폐기한 뒤 authoritative state를 표시한다.
- 새로운 persistent cache, native dependency, permission, analytics event와 log field는 없다.

## Automated evidence plan

1. legacy cancellation exact signature/result/grant and replay compatibility
2. ledger privacy, exact affected-row capture, skipped preservation and terminal-prefix revision capture
3. unauthenticated/member/other-user/cross-household denial and original Owner/Admin actor scope
4. terminal-prefix and soft-deleted-series resume, new immutable revision and worker continuation
5. post-cancellation completed prefix preservation, cancelled-row drift rejection and series-version conflict
6. resume same-key replay/different-input collision and immutable aggregate event
7. strict Flutter domain/DTO/repository/controller/UI parsing, single-flight, retry and localization
8. clean reset, focused/full pgTAP, focused/full Flutter, analyzer, formatter, localization/codegen/config/secret/Node/docs/whitespace and Android dev APK

## DB/API impact

- forward migration: `supabase/migrations/20260810150000_chore_series_cancellation_undo.sql`
- private metadata-only ledger table, compatible operation constraint widening, private legacy engine and one additive authenticated resume RPC.
- no public content table/column, RLS policy, Edge Function, notification payload, provider, dependency or native permission change.

## Security and privacy

- cancellation actor binding is not authorization by itself; resume rechecks current authenticated Owner/Admin membership and exact household/series/version.
- another Owner cannot guess an original actor's command ID to resume it; missing/foreign cancellation returns the same not-found-or-forbidden error.
- ledger is private from public, anon, authenticated and service role and contains no user content or assignee identity.
- client stores the undo receipt in controller memory only. It is cleared by competing mutations, terminal failure, household/session transition or controller disposal.

## Rollback

- hide the Snackbar action and return the controller to cancellation-only behavior.
- revoke authenticated execute on the additive resume RPC in a forward migration.
- keep the private ledger and widened `resumed` audit/request constraints while immutable resume records exist; do not delete or rewrite audit history.
- legacy cancellation wrapper can continue through the private engine even when resume is disabled.

## Completion boundary

- local pgTAP and Flutter automation must prove exact pre-state restoration, skipped/completed preservation, concurrency/idempotency, strict UI and N-1 cancellation compatibility.
- persistent recent-cancellation history remains a separate follow-on slice; Calendar immediate cancellation Undo is implemented by WP04-16.
- hosted scheduler, real accounts, two-device races, timezone boundary and Android physical-device accessibility remain deferred by user direction until feature development is substantially complete.
