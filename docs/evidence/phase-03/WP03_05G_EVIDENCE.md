# Phase 03 WP03-05G Repeating Series Change Evidence

- Work Package: WP03-05G — repeating series future edit and termination
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/B/C/D/E/F 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05G | PASS FOR LOCAL AUTOMATED SLICE | Today에서 Owner/Admin이 반복 시리즈의 현재 시점 이후 전체 항목을 변경하거나 종료할 수 있다. |
| FR-CHORE-005 | PARTIAL | immutable revision에 title/description, 기본 담당자, local time과 canonical daily/weekly/monthly rule을 snapshot한다. custom interval/end 편집 UI와 DST 실환경 검증은 남아 있다. |
| FR-CHORE-006 | PASS FOR NEW SURFACE | stable recurrence local slot으로 오늘부터 365일 horizon을 재구성하고 worker coverage를 reset한다. |
| FR-CHORE-008 | PASS FOR LOCAL AUTOMATED SURFACE | household-local today 이후 미래 미완료 occurrence만 rebuild/cancel하며 과거와 모든 completed occurrence를 보존한다. |
| D-019 | PASS FOR NEW SURFACE | series identity, immutable revision, recurrence slot, occurrence state, command record와 audit event를 분리했다. |
| D-020 | PASS FOR STORE MVP SURFACE | client가 effective boundary를 지정하지 못하며 서버가 현재 시각과 series timezone으로 local today를 산출한다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | active Owner/Admin만 mediated RPC를 실행한다. member/removed member/outsider/anonymous와 direct mutation은 거부된다. |
| NFR-REL-01 | PASS FOR SERIES COMMAND | expected version, per-user command UUID, normalized request hash, advisory lock와 series row lock으로 replay와 경쟁 변경을 제어한다. |
| NFR-OBS-01 | PARTIAL | content-free immutable change event에 actor, operation, boundary, version과 aggregate count를 남긴다. remote dashboard/alert/retention은 후속 범위다. |

## Implementation

- `20260807060000_chore_series_change.sql`은 revision content snapshot, stable `recurrence_local_date`, canonical candidate-date helper, future-window rebuild, change command ledger와 immutable aggregate event를 추가한다.
- `update_repeating_chore_series`와 `cancel_repeating_chore_series`는 `statement_timestamp()`를 series IANA timezone으로 변환해 effective local date를 산출한다. client 요청에는 임의 boundary가 없으므로 과거 회차를 소급 변경할 수 없다.
- 변경 명령은 active Owner/Admin membership, active repeating series, active default assignee, expected series version, normalized content/time/rule과 no-op 여부를 mutation 전에 검증한다. one-time/deleted series와 invalid transition은 fail closed다.
- update는 새 revision number를 series row lock 아래 단조 증가시키고 기존 revision을 수정하지 않는다. revision의 title/description snapshot 때문에 과거 occurrence를 최신 series content로 재해석할 필요가 없다.
- `recurrence_local_date`는 reschedule된 due date와 별개인 원래 recurrence slot이다. 경계 이전 occurrence와 status가 `completed`인 occurrence는 revision, due, assignee, status, version과 audit를 그대로 유지한다.
- 새 rule에도 포함되는 미래 미완료 slot은 기존 occurrence ID/key를 재사용하면서 새 revision 기본값과 `scheduled` 상태로 reset한다. 빠진 slot은 삭제하지 않고 `cancelled`로 보존하며 새 slot만 insert한다.
- cancel은 series를 soft-delete하고 경계 이후 미래 미완료 occurrence를 `cancelled`로 전이한다. 과거, completed occurrence, revision, exception/audit row를 삭제하지 않는다.
- update는 effective local date부터 최대 365일까지 즉시 materialize한다. update/cancel 모두 private worker coverage state를 제거해 다음 horizon worker가 active revision 또는 삭제 상태를 기준으로 다시 판정하게 한다.
- command UUID replay는 최초 결과를 `changed=false`로 반환하고 revision/version/event를 중복 증가시키지 않는다. 같은 UUID를 다른 payload나 operation에 재사용하면 거부한다.
- 실제 두 PostgreSQL connection이 같은 expected version으로 경쟁하는 fixture에서 정확히 한 명만 새 revision을 만들고 다른 명령은 stale conflict가 됐다.

## Flutter Surface

- provider-free domain contract에 update/cancel draft, request, snapshot, validation, stable fingerprint와 retry-safe command ID를 추가했다.
- Today strict DTO/parser는 series version, recurrence rule, 기본 담당자/local time과 서버 산출 `can_manage_series`를 요구한다. malformed 또는 불완전한 provider payload는 domain으로 전달하지 않는다.
- Today의 scheduled repeating occurrence는 서버가 허용한 Owner/Admin에게만 “전체 반복 항목 변경”과 “반복 종료” 메뉴를 보인다. 서버 RPC가 동일 권한을 다시 확인하므로 UI 가림은 보안 경계가 아니다.
- 변경 dialog는 title, notes, 기본 담당자, local time과 frequency를 prefill한다. frequency를 유지하면 기존 canonical rule 전체를 보존하고 frequency를 바꾸면 server-local today anchor의 interval-1/never daily, weekly 또는 monthly rule을 만든다.
- update/cancel은 동일 intent의 중복 탭을 coalesce하고 transient retry에 같은 command UUID를 재사용한다. stale/invalid transition과 성공 모두 authoritative Today reload로 series version과 occurrence set을 복구한다.
- 구현 중 자정 경계 test가 서버 명령 성공 후 household local date가 client의 기존 Today보다 하루 앞설 수 있음을 드러냈다. client는 서버의 유효한 authoritative date가 loaded Today date 이상이면 성공으로 수용하며, 새 rule이 오늘 회차를 제거해도 같은-series row 존재를 성공 조건으로 요구하지 않도록 교정했다.
- destructive confirmation과 성공/오류 문구는 en/ko/pseudo ARB에 추가했고 generated localization drift를 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 14개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused series-change pgTAP | PASS, 85/85 |
| focused two-connection concurrency pgTAP | PASS, 10/10; 같은 expected version에서 one-winner/one-stale 확인 |
| full pgTAP/RLS regression | PASS, 16 files, 879 tests; predecessor 784 + 신규 95 |
| focused Flutter regression after midnight fix | PASS, repository/controller/widget 35/35 |
| full Flutter regression | PASS, 304 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 219 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow | PASS, 47/47; 5 jobs, pinned action 17개, `contents:read` |
| Edge/backend regression | PASS, invite 22/22, member lifecycle 18/18, health, invite live와 Flutter local adapter |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated output drift 0/8 files |
| coverage | PASS, 5,483 / 7,012 lines = 78.19% |
| whitespace | PASS, `git diff --check` output 0 |

DB fixture는 exact schema/grant/RLS, revision/slot/event immutability, Owner/Admin success, member/removed member/outsider/anonymous denial, invalid rule/time/assignee, one-time/deleted/no-op/stale denial, update/cancel replay, conflicting key, 과거 및 completed 보존, skip/reschedule/reassign reset, obsolete cancellation, matching occurrence ID reuse, new slot insertion, count/until/month-end/weekly rule, all-day/timed timezone 결과, worker reset/replay compatibility와 direct table mutation denial을 포함한다.

Flutter fixture는 domain validation/fingerprint, strict RPC payload/parser, provider error mapping, duplicate command coalescing, transient retry command-ID reuse, stale reload, local authorization/no-op denial, owner edit/cancel UI, permission-based action hiding, pseudo-locale expansion과 household-local midnight boundary를 포함한다.

## Data / API / Security / Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/텍스트만 사용했다. production migration, 실제 계정, 실제 household와 고객 콘텐츠는 사용하지 않았다.
- public RPC 결과는 household/series/revision IDs, effective local date, version과 aggregate counts만 반환한다. raw database/provider error와 title/description을 결과에 포함하지 않는다.
- `chore_series_change_events`에는 title, description, member display name, email, token 또는 raw error를 저장하지 않는다. active household member만 RLS로 조회할 수 있고 append-only trigger가 update/delete를 거부한다.
- private command ledger는 authenticated user, command UUID, SHA-256 request hash와 aggregate result만 보존하며 anon/authenticated/service-role direct table privilege를 모두 거부한다.
- content snapshot은 기존 household-scoped revision relation에만 저장되고 household authorization 경계 안에서 사용된다.
- 새 모바일 runtime dependency, native platform permission, analytics event, persistent client cache, offline outbox 또는 secret-bearing external service를 추가하지 않았다. 기존 pg_cron worker와만 통합된다.
- local Supabase stack의 실행 상태는 기존 개발 환경을 보존하기 위해 이번 slice 종료 시 변경하지 않았다.

## Manual / Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 edit/cancel propagation, 동시 탭, offline/reconnect와 account switch를 확인하는 검증은 **NOT RUN**이다.
- production Supabase deploy, remote RLS/RPC, remote pg_cron wake, dashboard/alert/retention과 forward rollback rehearsal은 **NOT RUN**이다.
- 실제 기기의 TalkBack/VoiceOver, large text, locale/timezone 변경 중 dialog, DST gap/fold와 OS tzdata 차이 검증은 **NOT RUN**이다.
- production-size occurrence rebuild query plan, lock wait/timeout, long-running transaction과 remote throughput 측정은 **NOT RUN**이다.
- 수동 simulator/device UI smoke는 **NOT RUN**이며 widget/semantics 자동 계약만 수행했다.

## Remaining Risks / Completion Boundary

1. local two-connection contention은 통과했지만 production latency에서의 lock wait, timeout과 재시도 UX는 remote load gate 전까지 미확정이다.
2. server가 effective date를 권위 있게 결정하고 자정 이동을 수용하도록 교정했지만 DST gap/fold의 product policy와 실제 tzdata matrix는 Phase 04 time gate까지 남아 있다.
3. 현재 edit UI는 frequency 변경 시 interval-1/never preset을 만든다. canonical custom interval, weekday/day-of-month와 count/until을 직접 편집하는 고급 UI는 아직 없다.
4. immutable event와 occurrence audit는 존재하지만 사용자가 과거 예외를 상세히 보는 persistent exception history/detail surface는 아직 없다.
5. Today upcoming/overdue/completed filter, resume invalidation, notification hook과 remote scheduler 운영 증적은 후속 work package다.
6. 실제 계정·두 기기 결과와 production deploy evidence가 없으므로 WP03, Chores Value Gate 또는 전체 제품 목표를 완료로 표시하지 않는다.

WP03-05G 자체는 local automated 기능 slice로 완료했다. FR-CHORE-008은 local surface가 통과했지만 release gate는 remote·real-account 검증 전까지 `IN_PROGRESS`를 유지한다.

## Rollback

- production 적용 전에는 WP03-05G migration/client/tests/evidence를 revert하고 clean reset으로 이전 13개 migration과 784-test baseline을 확인한다.
- production 적용 후에는 적용된 migration을 수정하거나 삭제하지 않는다. 두 RPC의 execute grant와 Today edit/cancel action을 먼저 회수하고 forward migration으로 revision/materializer/permission contract를 교정한다.
- 이미 생성된 revision, occurrence, private command record와 public audit event는 이력 보존을 위해 삭제하지 않는다. 잘못된 active revision은 새 corrective revision으로 전진 교정한다.
- cancel 오작동은 soft-deleted series와 cancelled occurrence를 직접 삭제/되감기하지 않고 승인된 복구 RPC 또는 forward migration으로 복원해야 한다.
- worker state reset 문제 시 cron wake를 일시 중단할 수 있지만 기존 occurrence와 완료 이력은 보존한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP03-05H persistent exception history/detail이다. occurrence별 skip/restore/reschedule/reassign/complete와 series-change audit를 한 화면에서 안전하게 설명하는 read contract를 먼저 고정한다.
- 그 다음 WP03-06 Today upcoming/overdue/completed filter와 app resume authoritative invalidation을 진행한다.
- 실제 계정·두 기기 및 remote Supabase gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
