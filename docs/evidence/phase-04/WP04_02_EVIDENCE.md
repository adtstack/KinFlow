# Phase 04 WP04-02 One-time Calendar Event Evidence

- Work Package: WP04-02 — timed/all-day one-time event create/list/edit/delete, participants, RLS/RPC, Flutter vertical slice
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03/WP04-01 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / ADVANCED VIEWS·RECURRENCE·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-02 | PASS FOR LOCAL AUTOMATED SLICE | one-time timed/all-day event가 Flutter UI→controller→repository→strict provider adapter→mediated RPC→RLS 경계에서 생성·조회·수정·삭제된다. |
| FR-CAL-001 | IN PROGRESS | timed event는 minute-precision local intent, pinned IANA timezone, explicit fold policy와 positive duration을 받고 server-resolved canonical UTC start/end를 저장한다. 로컬 CRUD는 통과했고 remote/device gate가 남았다. |
| FR-CAL-002 | IN PROGRESS | all-day event는 inclusive UI end를 exclusive persistence end로 변환하며 timezone, local time, duration, UTC instant와 DST metadata를 저장하지 않는다. device travel gate가 남았다. |
| FR-CAL-003 | IN PROGRESS | 최소 1명의 같은 household active Store-MVP adult participant만 허용하며 exact replacement, removed/cross-household denial을 검증했다. Managed Child는 D-013 P1 범위다. |
| D-017 | PASS FOR THIS SLICE | event mutation은 online repository command이며 offline optimistic outbox를 만들지 않는다. 성공한 authoritative response만 visible list에 적용한다. |
| D-019 | PASS FOR ONE-TIME SLICE | series definition, immutable revision과 stable materialized occurrence를 분리했다. edit/delete 뒤에도 series/occurrence identity가 안정적이다. |
| D-047 | PASS FOR THIS SLICE | Calendar domain/application은 Flutter, Riverpod, Supabase SDK를 import하지 않는다. provider SDK는 infrastructure adapter에만 있다. |
| D-048 | PASS FOR THIS SLICE | create/update/delete는 per-user UUID command key를 사용하고 update/delete는 expected series version을 검증한다. same-key replay와 changed-input conflict를 자동 검증했다. |
| NFR-SEC-01 | PASS FOR NEW BOUNDARY | public Calendar tables는 force RLS와 read-only authenticated grant만 갖고 mutation은 empty-search-path authenticated RPC로만 가능하다. caller, household와 participant 권한을 server가 재판정한다. |
| NFR-PRIV-01 | PASS FOR COMMAND/AUDIT PAYLOAD | private command/audit rows에는 title, description, display name, email 또는 token을 복제하지 않고 IDs, hash, action, correlation과 version만 기록한다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | migration/RPC/route/provider가 additive이며 기존 Auth/Household/Chore public contract를 변경하지 않고 clean reset 및 전체 회귀를 통과했다. |

## Database and RPC Contract

- `20260807110000_one_time_calendar_events.sql`은 `event_series`, immutable `event_series_revisions`, `event_participants`와 `event_occurrences`를 추가한다. household를 포함한 composite FK가 series/revision/participant/occurrence 관계를 교차 가구로 조립하지 못하게 한다.
- one-time occurrence key는 `series_id:once`이고 edit는 occurrence ID와 key를 유지한 채 active revision, time fields, participant set과 optimistic version만 전진시킨다.
- timed row는 valid IANA timezone, local date/time, 1–10,080분 duration, canonical `starts_at < ends_at`와 exact five-key DST envelope을 강제한다. overlap resolution과 selected earlier/later policy가 모순되면 DB와 Flutter domain이 모두 거부한다.
- all-day row는 `[local_start_date, all_day_end_date_exclusive)`만 저장한다. timezone, local time, duration, instant와 DST envelope은 모두 null이어야 한다.
- `create_one_time_event`, `update_one_time_event`, `delete_one_time_event`는 authenticated caller의 active household membership을 다시 확인하고 advisory lock 아래 normalized request hash/idempotency를 처리한다. changed input key reuse는 `KFE04`, stale version은 `KFE05`다.
- 생성/수정 command replay가 더 나중의 delete를 따라 도착해도 deleted snapshot을 다시 반환하지 않고 `KFE03`으로 종료한다. 따라서 delayed retry가 client visible list에 삭제된 event를 잠깐 부활시키지 않는다.
- `list_one_time_events`는 household timezone/local-date envelope과 non-deleted event를 deterministic date/time/title/ID 순서로 최대 100개 반환한다. advanced range intersection과 keyset pagination은 WP04-03이다.
- public tables는 authenticated `SELECT`만 허용하고 insert/update/delete grant가 없다. force RLS가 active same-household read만 허용하며 anonymous, outsider와 removed member를 차단한다. private command/audit table은 API role에서 읽거나 변경할 수 없다.
- delete는 series soft-delete와 occurrence cancel/version advance를 같은 transaction에서 수행한다. participant, revisions와 content-free audit는 forensic/history를 위해 보존한다.

## Flutter Vertical Slice

- domain은 strict event/occurrence IDs, local date/time/all-day range/IANA/UTC values, participant, draft/request/result/failure와 repository/command-ID/time-resolver interfaces를 제공한다.
- data repository는 exact provider key set, paired participant arrays, stable household/series/occurrence identity, date/time mode와 versions를 fail closed로 검증한다. PostgreSQL time/timestamp 표현은 infrastructure 경계에서 canonical minute/Z wire form으로 정규화한다.
- application controller는 initial load와 content-preserving refresh, serial create/update/delete, duplicate submit suppression, same-input failure retry key reuse, expected-version mutation과 authoritative local replacement/removal을 담당한다.
- client resolver는 unsupported timezone과 DST gap을 command 생성 전에 안내하지만 server resolver가 저장 authority다. provider의 `KFE01`–`KFE06`/PostgREST 오류는 content-free typed failure로 매핑된다.
- `/calendar` 화면은 loading/error/empty/refresh/list와 create/edit/delete flow를 제공한다. timed/all-day 전환, date/time, duration, household timezone default, explicit earlier/later fold와 최소 1명 participant 선택을 지원한다.
- Today app bar에서 Calendar route로 진입한다. 사용자 문자열은 en/ko/en-XA ARB에 있고 timed zone/participants, all-day inclusive range와 안정된 failure copy를 사용한다.
- editor 전체가 constrained scroll surface이며 dropdown label은 ellipsis, action은 wrap된다. en-XA 200% text에서 overflow 없이 스크롤·저장 action에 접근할 수 있음을 widget test로 검증했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx --no-install supabase db reset` | PASS, ordered forward migration 19개와 synthetic seed 적용 |
| focused Calendar pgTAP | PASS, 120/120 |
| full pgTAP/RLS regression | PASS, 21 files, 1,193 tests; predecessor 1,073 + 신규 120 |
| strict DB lint | PASS, `app_private`, `public` warning/error 0 |
| focused Calendar Flutter tests | PASS, 41/41 |
| full Flutter regression | PASS, 377 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 252 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline`; lockfile drift 0 |
| localization/codegen | PASS, en/ko/en-XA exact coverage·pseudo expansion; generated drift 0/8 files |
| config/secret/dependency license | PASS, public config allowlist, high-confidence secret 0, Pub 150 and npm 15 licenses |
| whitespace | PASS, `git diff --check` output 0 |

Focused DB fixture는 schema/check/FK/index/immutability, RLS/grant, unauthenticated/anonymous/outsider/removed/direct-write denial, Seoul canonical timed create, LA gap/fold, exact all-day date-only row, participant replacement, stable occurrence identity, immutable revision, optimistic conflict, create/update/delete replay, delete-after-replay suppression과 content-free immutable audit를 포함한다.

Focused Flutter fixture는 value/domain invariants, DST gap/fold/half-hour resolver, strict repository/provider payload, Supabase RPC/error mapping, controller serialization/retry/refresh, all-day create/edit/delete widget, timed display와 pseudo 200% editor를 포함한다.

## Data, Security, Privacy, and Platform

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/event content만 사용했다. production migration, 실제 계정, 실제 household, 고객 일정 또는 provider token은 사용하지 않았다.
- event title/description은 사용자에게 필요한 public RLS aggregate에만 있고 private idempotency/audit record에는 복제되지 않는다. command hash는 normalized request의 SHA-256이며 원문을 복원하거나 client에 노출하지 않는다.
- UI/controller/adapter failure는 allowlisted kind/code만 유지하고 raw database/provider message, event content와 participant display name을 로그 payload로 만들지 않는다.
- authenticated API client는 security-definer RPC만 실행할 수 있고 table mutation, private command/audit read, audit update/delete를 할 수 없다. service role에도 private Calendar table의 broad client-facing grant를 추가하지 않았다.
- participant FK와 RPC는 request household의 active row만 허용한다. Store MVP role enum은 owner/admin/member만 포함하며 Managed Child identity/visibility는 별도 D-013 P1 gate 없이는 추가하지 않는다.
- 새 native plugin, OS Calendar/Contacts permission, background worker, analytics event, persistent event cache 또는 external network dependency를 추가하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, Android/iOS 실기기와 성인 2계정·두 기기 동시 CRUD/participant propagation 검증은 **NOT RUN**이다.
- production/remote Supabase migration, deployed PostgreSQL tzdata, remote RPC/RLS, network loss/reconnect와 forward rollback rehearsal은 **NOT RUN**이다.
- device timezone travel, household timezone 변경, OS locale/date picker, VoiceOver/TalkBack와 tablet journey는 **NOT RUN**이다.
- day/month/agenda range projection, locale week-start, keyset pagination과 production-size query plan은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-03 범위다.
- recurring event series, materialization, single-occurrence exception, future-series edit/cancel과 repair job은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-04 범위다.
- Today의 Chore+Calendar partial-failure-safe composition, notification intent/inbox/push는 **NOT IMPLEMENTED / NOT RUN**이며 WP04-05/Phase 05 범위다.

## Remaining Risks and Completion Boundary

1. client embedded tzdata와 deployed PostgreSQL tzdata가 다를 수 있다. client validation은 UX preflight일 뿐이며 remote release 전 supported scheduling window parity와 actual server version을 다시 확인해야 한다.
2. list는 one-time event 최대 100개 전체 snapshot이다. large household의 range query, overlap projection, pagination/index plan은 WP04-03 전까지 release-ready가 아니다.
3. 같은 client controller의 mutation은 직렬화되지만 실제 두 기기 race와 network timeout은 local RPC contract로만 검증했다. remote stale-version/error UX를 마지막 live gate에서 확인해야 한다.
4. soft-deleted event content와 participant/revision/audit history의 retention·export·account/household deletion 정책은 Phase 07에서 승인된 privileged cleanup과 함께 정해야 한다.
5. automated pseudo-large-text는 layout regression을 잡지만 실제 screen reader focus order, native picker와 tablet ergonomics를 증명하지 않는다.
6. recurring/view/Today composition과 real-account/device evidence가 없으므로 FR-CAL 전체, T-CAL-01, REL-014, Phase 04 또는 제품 목표를 완료로 표시하지 않는다.

WP04-02 자체는 local automated one-time CRUD slice로 완료했다. Calendar product/release gate는 이후 WP와 마지막 real-account/device 검증까지 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 WP04-02 migration, Calendar feature/infrastructure/route/l10n/tests/contracts/evidence를 함께 revert하고 이전 18-migration/1,073-test baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. forward migration에서 Calendar RPC execute를 revoke하고 Today→Calendar entry를 disable한 뒤 constraints/function을 보정한다.
- 이미 생성된 event, revision, occurrence, participant, command와 audit row를 임의 삭제하지 않는다. export/retention 판단과 forensic history를 보존한 채 approved privileged migration/job으로만 정리한다.
- client rollback은 additive `/calendar` route/provider override를 제거하되 기존 Auth/Household/Chore navigation과 public RPC를 변경하지 않는다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-03 Calendar agenda/day/month projection이다. household-local Today와 timed range intersection, all-day span, deterministic keyset pagination, locale week-start와 empty/partial-error UI를 추가한다.
- WP04-03은 현재 source intent/occurrence identity를 변경하지 않고 read projection만 확장하며 one-time CRUD RPC signature를 호환 유지해야 한다.
- 실계정·두 기기·remote Supabase와 device timezone travel gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
