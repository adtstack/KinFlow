# Phase 03 WP03-05H Occurrence History and Detail Evidence

- Work Package: WP03-05H — occurrence activity history and Today detail
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03-04/WP03-05A/B/C/D/E/F/G 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT LIVE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP03-05H | PASS FOR LOCAL AUTOMATED SLICE | active household member가 Today 회차의 현재 정보와 complete/reopen/skip/restore/reschedule/reassign 활동을 상세 sheet에서 조회한다. |
| FR-CHORE-004 | PASS FOR NEW READ SURFACE | 완료와 reopen actor, UTC 발생 시각, occurrence version을 기존 immutable audit에서 읽는다. |
| FR-CHORE-007 | PASS FOR NEW READ SURFACE | 한 회차의 skip/restore/reschedule/reassign을 stable occurrence identity 아래 설명하고 series/revision/sibling을 변경하지 않는다. |
| D-019 | PASS FOR NEW READ SURFACE | series/revision/occurrence와 source audit를 유지하고 bounded union projection만 추가했다. |
| NFR-SEC-01 | PASS FOR NEW SURFACE | active household member와 same-household occurrence를 서버가 함께 검증하고 anon/removed/outsider/cross-household probing을 거부한다. |
| NFR-PRIV-01 | PASS FOR NEW SURFACE | 응답 exact allowlist에 auth user ID, correlation/idempotency, title/notes, request hash와 raw error가 없다. 새 이름 snapshot이나 client cache를 만들지 않는다. |
| NFR-REL-01 | PASS FOR READ PAGINATION | 1~100 bounded limit과 `(occurred_at, source:event_id)` keyset cursor가 equal-time tie까지 deterministic하게 진행한다. |
| NFR-A11Y-01 | PASS FOR AUTOMATED SURFACE | scrollable detail, semantic headings/status, 48dp close/retry/load-more와 ko/en-XA 200% text overflow 0을 검증했다. |
| NFR-I18N-01 | PASS FOR NEW SURFACE | en/ko/pseudo exact key coverage와 locale-aware household date/time 및 event instant 표현을 사용한다. |

## Database and API Contract

- `20260807070000_chore_occurrence_history.sql`은 기존 completion/reschedule/assignment audit relation을 변경하지 않고 `get_chore_occurrence_history` stable read RPC를 추가한다.
- RPC는 session의 `auth.uid()`를 사용하고 active, non-deleted household membership과 요청 occurrence의 동일 household 소속을 함께 확인한다. 존재하지 않음과 권한 없음은 같은 `KFC03`으로 처리한다.
- 응답 vocabulary는 `completed`, `reopened`, `skipped`, `restored`, `rescheduled`, `reassigned` 여섯 개다. private restore command의 `result_event_id`와 연결된 legacy `reopened` event만 `restored`로 분류한다.
- 모든 row는 source-qualified immutable entry ID, actor member ID/current display name, optional acting member pair, UTC instant와 positive occurrence version을 가진다.
- reschedule row만 이전/새 household-local date/time을, assignment row만 이전/새 assignee member ID/current display name을 가진다. 다른 variant의 필드는 null이어야 한다.
- `p_limit + 1` bounded read로 `has_more`를 산출하고 최신순 `(occurred_at, history_entry_id)` keyset cursor를 사용한다. 같은 timestamp에서도 source-qualified ID가 total order를 제공한다.
- 유효한 occurrence에 audit가 없으면 row 0개의 성공 응답이다. limit/cursor pair/entry ID가 유효하지 않으면 mutation 없이 `KFC02`로 거부한다.
- 함수는 empty search path의 `SECURITY DEFINER`, `STABLE`이며 execute를 `authenticated`에만 부여한다. underlying audit/private command table privilege는 추가하지 않았다.

## Flutter Surface

- provider-free domain에 history event type, request, cursor, page와 variant별 nullability/source/order/uniqueness invariant를 추가했다.
- Supabase datasource는 RPC의 19개 exact response key, target household/occurrence, allowlisted event vocabulary, acting pair, UTC/version과 variant shape를 검증한다.
- repository mapper는 strict UUID/local date/local time/UTC value object로 변환하고 page size, newest-first order, uniqueness와 cursor보다 엄격히 이전인 continuation을 다시 확인한다.
- application controller는 initial load와 load-more 중복 호출을 coalesce한다. initial 실패는 전체 retry로, continuation 실패는 기존 event를 보존한 동일 cursor retry로 처리한다.
- Today card를 누르면 현재 title/notes/assignee/household-local due/status와 activity를 bottom sheet로 연다. loading, empty, initial failure, list, load-more, continuation failure를 독립 상태로 표시한다.
- UI에는 provider SDK import가 없고 repository interface를 controller에 주입한다. provider/database error text는 렌더링하지 않고 ARB의 안전한 실패 문구만 표시한다.
- 상세 제목과 내용은 scrollable 영역에 두고 close action은 고정했다. 이 구조는 구현 중 en-XA 200% text에서 발견된 fixed-header vertical overflow를 제거했다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx supabase db reset` | PASS, ordered forward migration 15개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused occurrence-history pgTAP | PASS, 41/41 |
| full pgTAP/RLS regression | PASS, 17 files, 920 tests; predecessor 879 + 신규 41 |
| focused domain/repository/controller/parser | PASS, 72/72 |
| focused Today detail/a11y/i18n regression | PASS, 30/30 |
| full Flutter regression | PASS, 322 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 224 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow/actionlint | PASS, 47/47; 5 jobs, pinned action 17개, workflow lint pass |
| Edge/backend regression | PASS, invite 22/22, member lifecycle 18/18, health, invite live와 Flutter local adapter |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated drift 0/8 files |
| localization/adaptive | PASS, en/ko/pseudo exact keys, pseudo expansion, ko/en-XA 200% detail scroll overflow 0 |
| coverage | PASS, 6,004 / 7,607 lines = 78.93% |
| whitespace | PASS, `git diff --check` output 0 |

DB fixture는 exact function/grant/search-path, auth/input/cursor denial, unified ordering와 exact minimal shape, complete/reopen/skip/restore classification, reschedule/reassign fields, actor/acting pair, version, equal-timestamp three-page traversal, no duplicate, member access, outsider/cross-household/unknown/removed denial, empty success와 removed historical actor display를 포함한다.

Flutter fixture는 value-object/source/variant invariant, exact payload parsing, repository fail-closed mapping, initial/load-more coalescing과 retry, cross-page duplicate denial, Today 진입/현재 정보/빈 상태, event 여섯 종류, safe failure, continuation retry, locale formatting, touch target와 200% pseudo layout을 포함한다.

## Data, Security, and Privacy

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/content만 사용했다. production migration, 실제 계정, 실제 household 또는 고객 콘텐츠는 사용하지 않았다.
- public projection은 household/occurrence/history/member IDs, 현재 household display names, activity instant/version과 variant-specific schedule/assignee만 반환한다.
- title과 notes는 RPC 응답에 없고 client가 이미 authorized Today row에서 가진 현재 snapshot만 sheet에 표시한다. history endpoint로 다른 occurrence content를 새로 유출하지 않는다.
- auth user ID, actor user ID, command/correlation/idempotency ID, private request hash, raw database/provider error와 token은 response, UI, evidence에 포함하지 않는다.
- 삭제된 historical member row의 display name은 household relation에 남은 현재 tombstone 값을 사용한다. 별도 event name snapshot을 만들지 않으므로 이름 변경 전의 과거 표기는 복원하지 않는다.
- 새 analytics event, persistent client cache, offline outbox, mobile dependency, native permission 또는 secret-bearing external service를 추가하지 않았다.
- local Supabase stack은 다음 기능 개발에 재사용할 수 있도록 실행 상태를 유지했다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정 2개와 Android 기기 2대에서 상대방 activity propagation, account switch, concurrent mutation 중 sheet refresh와 offline/reconnect를 확인하는 검증은 **NOT RUN**이다.
- production Supabase deploy, remote RLS/RPC, production-size event query plan/latency, observability와 forward rollback rehearsal은 **NOT RUN**이다.
- 실제 기기의 TalkBack/VoiceOver, swipe-dismiss, dynamic type, locale/timezone 전환과 OS tzdata 차이 검증은 **NOT RUN**이다.
- 수동 simulator/device UI smoke는 **NOT RUN**이며 widget/semantics 자동 계약만 수행했다.

## Remaining Risks and Completion Boundary

1. actor/assignee 이름은 immutable event snapshot이 아니라 household member relation의 현재 또는 tombstoned display name이다. rename 전 표기를 법적 audit처럼 복원하는 요구가 생기면 별도 privacy/retention 결정을 먼저 해야 한다.
2. sheet의 현재 상세는 열 때의 authorized Today snapshot이다. 열린 동안 다른 기기에서 변경한 current status/details를 자동 갱신하지 않으며 다음 authoritative Today reload가 필요하다.
3. occurrence history는 complete/skip/restore/reschedule/reassign만 포함한다. series-wide revision change가 이 occurrence에 적용된 설명은 아직 projection하지 않는다.
4. local equal-time pagination은 통과했지만 production-size audit cardinality의 query plan, index pressure와 remote p75는 측정하지 않았다.
5. Today upcoming/overdue/completed/assignee filter, app resume invalidation, notification hook와 remote scheduler 운영 증적이 남아 있다.
6. 실제 계정·두 기기와 production deploy evidence가 없으므로 WP03, Chores Value Gate 또는 전체 제품 목표를 완료로 표시하지 않는다.

WP03-05H 자체는 local automated 기능 slice로 완료했다. 관련 Store MVP requirement와 release gate는 remote·real-account 검증 전까지 `IN_PROGRESS`를 유지한다.

## Rollback

- production 적용 전에는 WP03-05H migration/client/tests/evidence를 revert하고 clean reset으로 이전 14개 migration과 879-test baseline을 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. RPC execute grant와 Today detail entry point를 먼저 회수하고 forward migration으로 projection/authorization/pagination contract를 교정한다.
- 기존 completion/reschedule/assignment audit와 private restore command record는 source evidence이므로 삭제하거나 재작성하지 않는다.
- client rollback은 history domain/data/controller/sheet와 ARB keys를 함께 제거하고 `ChoreRepository`/datasource fake signature를 이전 상태로 되돌린다. 기존 Today mutation은 계속 동작한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP03-06 Today upcoming/overdue/completed 및 assignee filter다. household-local date boundary, bounded query와 filter state를 먼저 고정한다.
- 같은 slice 또는 직후에 app resume authoritative invalidation을 연결해 상세/Today snapshot stale window를 줄인다.
- 실제 계정·두 기기 및 remote Supabase gate는 사용자 지시에 따라 기능 개발이 끝난 마지막 단계까지 유지한다.
