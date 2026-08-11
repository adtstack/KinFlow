# Phase 05 WP05-09 Actionable Chore Occurrence Target Evidence

- Work Package: WP05-09 — exact Chore target complete/reopen actions and authoritative reconciliation
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-09 LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·REAL-DEVICE GATE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CHORE-004 / T-CHORE-TARGET-02 / API-045 | PASS FOR LOCAL ACTION SLICE / OVERALL PARTIAL | exact target의 server-derived actionability가 기존 versioned/idempotent 완료·다시 열기 mutation에 연결된다. Owner/배정자 허용과 read-only 경계, duplicate/response-loss/stale/post-commit 조정을 자동화로 검증했다. 실계정 role/assignment와 두 기기 race는 남았다. |
| FR-TODAY-003 | PASS FOR LOCAL RECONCILIATION / OVERALL PARTIAL | duplicate tap single-flight, same-fingerprint command ID 재사용, exact next-version 검증과 authoritative target/history refresh를 검증했다. 실제 network response-loss와 다중 client reconciliation은 남았다. |
| FR-NOTIF-005 / T-NOTIF-02 | PASS FOR LOCAL ACTIONABLE DESTINATION / OVERALL PARTIAL | WP05-08 exact Chore destination이 최신 active-household 권한으로 actionability를 다시 읽고 unavailable은 safe recovery, 권한 없음은 readable detail로 fail closed한다. 실제 Firebase lifecycle tap은 남았다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW SURFACE | 새 read RPC는 authenticated active membership을 재검사하고 capability boolean만 추가한다. mutation은 기존 권한·version 검증을 다시 수행하며 family content, raw provider text, 새 storage나 direct table grant를 추가하지 않는다. |
| NFR-REL-01 / NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / OVERALL PARTIAL | late household result suppression, typed failure, runtime-policy pre-I/O block, post-commit refresh warning과 EN-XA compact 200% scroll/action 회귀를 통과했다. physical-device TalkBack은 남았다. |

## Server Authority and Compatibility

- `get_chore_occurrence_action_target(p_household_id, p_occurrence_id)`은 WP05-08의 strict 18-field target projection과 `can_set_completion` 한 필드만 반환한다.
- strict unknown-key parser를 사용하는 N-1 client를 위해 기존 `get_chore_occurrence_target` 함수와 response shape를 변경하지 않았다.
- 새 함수는 authenticated session, non-deleted household와 active membership을 먼저 검사한다. 활성 series에서 Owner/Admin 또는 현재 assignee이면 capability가 true다.
- 삭제된 series의 completed historical occurrence는 계속 읽을 수 있지만 capability는 false다. 일반 성인이 다른 구성원에게 배정된 occurrence를 읽어도 action은 false다.
- capability는 presentation hint이며 기존 `set_chore_occurrence_completion`이 membership, role/assignee, series/occurrence state, expected version과 caller-scoped idempotency를 다시 검증한다.
- 새 table, index, RLS policy, data backfill과 Edge function은 없다. 새 RPC execute는 authenticated에만 부여하고 `public`, `anon`, `service_role`에는 부여하지 않았다.

## Client Action and Reconciliation

- strict DTO는 새 RPC의 exact boolean을 요구하며 missing, wrong type와 unknown key를 invalid payload로 거부한다. repository는 이를 domain occurrence의 read-only presentation capability로 매핑한다.
- scheduled target은 완료, completed target은 다시 열기 action을 표시한다. capability false인 삭제 이력이나 미배정 target은 상세와 활동 내역만 유지한다.
- controller는 같은 action을 in-flight 동안 합치고 household/occurrence/version/requested-status fingerprint가 같으면 response-loss 재시도에 같은 UUID를 재사용한다.
- 성공 응답은 exact household, occurrence, requested status와 `current version + 1`을 검증한다. 그 결과를 먼저 적용한 뒤 action target을 다시 읽어 기존 history sheet를 새 version으로 재생성한다.
- stale version, invalid transition, forbidden 또는 unauthenticated failure는 최신 target을 다시 읽되 새 version으로 mutation을 자동 재전송하지 않는다.
- commit 뒤 target refetch만 실패하면 완료 결과를 되돌리지 않고 reconciled status/version, readable detail과 별도 refresh warning을 유지한다.
- Chores runtime feature policy와 in-flight 상태는 repository I/O 전에 action을 disable한다. direct target/action에는 encrypted cache fallback과 offline mutation outbox를 사용하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused action-target pgTAP | PASS — `chore_list_filters` 78/78; 새 existence/grant/projection/role/assignment/deleted-history/outsider/removed-member assertions 포함 |
| full database regression | PASS — 54 files / 2,733 tests |
| database lint | PASS — `app_private,public`, warning level, fail-on-error, schema error 0 |
| focused Flutter impact | PASS — 85 tests across target controller/screen, strict Supabase mapper and provider repository |
| full Flutter regression | PASS — 1,157 tests; existing local-connectivity opt-in 1 skip; all others passed |
| Flutter analyzer | PASS — issue 0 |
| Dart formatter | PASS — 655 files checked, drift 0 |
| localization and generated code | PASS — build runner wrote 0 outputs; 8 generated files current |
| public config and secret scan | PASS — allowlist valid, high-confidence secret finding 0 |
| repository Node contracts | PASS — 141/141 |
| documentation structure | PASS — 385 Markdown files balanced; 2 relevant YAML contracts parse; 13 matrices rectangular and declared counts match; requirements 116×18, tests 84×11, API 45×6 |
| whitespace | PASS — final `git diff --check` output 0 |

Migration `20260809160000_chore_occurrence_target_actions.sql`은 기존 local migration history에 forward 적용했다. destructive reset, clean-from-zero migration과 hosted migration 완료는 이번 실행에서 주장하지 않는다.

## Files and Migration

- Contract and work package: `docs/contracts/chore-occurrence-target-actions.yaml.md`, `docs/evidence/phase-05/WP05_09_WORKPLAN.md`
- Migration and DB coverage: `supabase/migrations/20260809160000_chore_occurrence_target_actions.sql`, `supabase/tests/database/chore_list_filters.test.sql`
- Flutter domain/data: `ChoreOccurrence.canSetCompletion`, strict action-target DTO/parser and provider repository mapping
- Flutter application/UI: `ChoreOccurrenceTargetController`, `ChoreOccurrenceTargetScreen`, action-enabled `ChoreOccurrenceHistorySheet`
- Tests: target controller and widget, provider repository, Supabase data source and shared fake fixtures
- Governance: Phase 05, API/test/requirements matrices, navigation authority, contract index and changelog

## Manual and Deferred Validation

- 실제 Google 성인 계정의 Owner/Admin/member assignment matrix는 **NOT RUN**이다.
- 실제 두 기기의 simultaneous completion, stale-version race와 network response-loss recovery는 **NOT RUN**이다.
- 실제 Firebase foreground/background/terminated/local notification에서 completion까지의 Android 여정은 **NOT RUN**이다.
- physical Android TalkBack, 200% font, phone/tablet와 OEM process lifecycle은 **NOT RUN**이다.
- hosted Supabase migration, production-size RPC latency와 N-1 signed binary compatibility는 **NOT RUN**이다.
- Managed Child acting-member와 approval workflow는 Store MVP 범위 밖이다.

## Remaining Risks and Completion Boundary

1. 로컬 role fixture는 실제 Supabase Auth token과 household selection 전환 지연을 측정하지 않는다.
2. same-key response-loss recovery는 fake repository와 existing DB idempotency 계약을 조합해 검증했으며 실제 packet loss 뒤 재시도는 기기에서 확인하지 않았다.
3. additive RPC가 기존 response를 보존하지만 hosted N-1 binary와 production PostgREST schema-cache 갱신은 확인하지 않았다.
4. Phase 05 상위 Exit Gate는 실제 provider, 계정, 다중기기와 physical-device evidence가 없어 계속 `PARTIAL`이다.

WP05-09 provider-independent local action vertical slice는 완료했다. 사용자 지시에 따라 실계정·실기기 Gate는 기능 개발 대부분이 끝난 뒤 수행한다.

## Rollback

- client에서 action을 숨기고 WP05-08 `get_chore_occurrence_target` read로 되돌리면 상세·활동 recovery를 유지하면서 mutation 진입을 중지할 수 있다.
- production 적용 후에는 destructive down migration 대신 forward migration으로 `get_chore_occurrence_action_target` execute를 revoke한다.
- table data, index, cached target과 outbox를 추가하지 않았으므로 backfill, data cleanup과 device local purge는 필요 없다.
