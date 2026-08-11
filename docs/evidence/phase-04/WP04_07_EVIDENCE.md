# Phase 04 WP04-07 Same-member Calendar Overlap Hint Evidence

- Work Package: WP04-07 — 같은 구성원 일정 겹침의 bounded read-only hint
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, local Supabase CLI stack
- 결과: **LOCAL AUTOMATED PASS / CLEAN RESET·HOSTED QUERY PLAN·REAL-ACCOUNT·TWO-DEVICE·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-07 / FR-CAL-008 | PASS FOR LOCAL AUTOMATED SLICE | 생성·one-time 수정·반복 한 회차 수정·전체 시리즈 수정 editor에서 같은 active 구성원이 포함된 기존 scheduled occurrence와의 겹침을 자동 표시하며 checking, 조회 실패와 실제 conflict 어느 상태도 저장을 차단하지 않는다. |
| FR-CAL-001 / FR-CAL-002 | PASS FOR NEW READ CONTRACT | timed/timed은 canonical UTC, all-day/all-day는 date-only, mixed는 household-timezone 자정으로 변환한 half-open 범위를 비교한다. 끝점만 맞닿는 일정은 conflict가 아니다. |
| FR-CAL-004 | PASS FOR BOUNDED LOCAL SUBSET | 기존 daily/weekly/monthly와 never/count/until recurrence를 원본 local anchor에서 전개하고, 요청 window의 inclusive 366개 날짜와 최대 366 candidate로 제한한다. 매 timed candidate는 기존 DST resolver를 사용한다. |
| FR-CAL-005 / FR-CAL-006 | PASS FOR EDIT EXCLUSION | one-time/전체-series 수정은 series UUID, 단일 반복 회차 수정은 occurrence UUID 하나만 제외하고 다른 회차와의 겹침은 유지한다. 두 exclusion을 동시에 보내는 요청은 거부한다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW RPC SURFACE | `auth.uid()`와 active household membership을 server에서 다시 확인한다. candidate title·description·actor identity·command ID는 요청하지 않고, 응답도 description·auth user·audit/provider material을 반환하지 않는다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR NEW LOCAL SURFACE | checking, none, conflict, unavailable와 저장 가능 안내를 EN/KO/EN-XA ARB로 제공하고 pseudo 30% expansion 및 widget 회귀를 통과했다. 실제 TalkBack/VoiceOver는 남았다. |

`FR-CAL-008`은 local automated 구현은 통과했지만 hosted 규모와 실제 사용자 흐름을 검증하지 않았으므로 요구사항 전체 상태는 `IN_PROGRESS`로 유지한다.

## Database and API Contract

- `app_private.calendar_overlap_candidate_dates(date,jsonb,date,date)`는 기존 strict recurrence subset을 persisted occurrence 생성 없이 전개한다. public, anon, authenticated, service role의 직접 execute는 모두 회수했다.
- `public.preview_calendar_event_overlaps(...)`는 authenticated-only, `STABLE SECURITY DEFINER`, empty `search_path` RPC이며 14개 schedule/recurrence/participant/exclusion/limit 인자만 받는다.
- participant는 1~50개 unique active same-household member UUID여야 한다. caller identity와 role은 입력으로 받지 않는다.
- one-time은 `windowStart == localStart`; recurring은 `windowStart ... windowStart+365`의 366-date 범위이며 future anchor가 window 뒤에 있는 whole-series draft도 허용한다.
- timed duration은 1~10,080분, time은 minute precision, IANA timezone과 earlier/later fold policy가 필수다. all-day는 exclusive end date 외 timed 필드를 허용하지 않는다.
- candidate occurrence와 existing occurrence의 half-open 교차 후 실제 participant intersection이 있는 pair만 conflict다. 같은 pair에서 참가자가 여러 명이어도 total count는 한 건이다.
- 상세는 candidate date, 기존 household-local date/time, occurrence UUID 순으로 최대 10건이며 전체 건수와 `truncated`는 보존한다. 0건도 정확히 한 metadata-only row를 반환한다.
- strict adapter는 exact key, 동일 metadata, UTC generated-at, 정렬, null shape, count/truncation을 모두 검증하고 malformed payload를 content-free invalid failure로 닫는다.
- normative 계약은 `docs/contracts/calendar-overlap-preview.yaml.md`에 기록했다.

## Client Behavior

- editor가 처음 열리거나 schedule, recurrence, participant, edit exclusion이 바뀌면 즉시 또는 350ms debounce 후 preview를 요청한다. title·description 변경은 요청을 만들지 않는다.
- 새 입력은 이전 결과를 stale 처리하고 request generation이 다른 늦은 응답은 폐기한다. editor dispose 후 응답도 화면 상태를 바꾸지 않는다.
- conflict detail은 candidate 회차, 기존 title/schedule과 실제 겹친 구성원만 표시한다. 전체 count와 bounded 확인 범위 및 첫 10건 제한을 함께 알린다.
- preview 실패는 안전한 unavailable copy로 표시하며 raw Supabase/SQL/SDK 오류를 노출하지 않는다.
- Save action은 checking, zero, conflict, truncated, unavailable 모든 상태에서 활성화된다. preview는 create/update mutation의 전제조건이나 optimistic version contract가 아니다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| additive local migration | PASS, `20260808150000_calendar_overlap_hints.sql`을 기존 39-migration local stack에 적용해 총 40개 상태 |
| clean local Supabase reset | **NOT RUN**; 기존 로컬 DB를 교체하는 파괴적 reset 승인이 없어 additive migration + full regression으로 대체했으며 clean replay는 마지막 검증 gate에 유지 |
| focused overlap pgTAP | PASS, 36/36 |
| Calendar worker harness regression | PASS, 56/56; 정기 `pg_cron` audit row가 있어도 현재 테스트가 만든 run만 세도록 격리 |
| full database regression | PASS, 47 files / 2,422 pgTAP tests / 350s |
| product database lint | PASS, `app_private,public`, warning level + fail-on-error, result 0 |
| focused Flutter overlap slice | PASS, 62 tests across domain/adapter/repository/controller/widget |
| localization contract | PASS, 4/4 after EN-XA overlap summary를 영문 대비 30% 이상으로 확장 |
| full Flutter regression | PASS, 829 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 |
| exact formatter | PASS, 516 files / changed 0 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| localization/codegen drift | PASS, generated drift 0/8 files; build runner wrote 0 outputs |
| repository CI contracts | PASS, Node CI 134/134; workflow/supply-chain contract 5 jobs and 17 pinned action uses |
| CI shell syntax / whitespace | PASS, backend script `bash -n`; `git diff --check` output 0 |

전체 DB 검증을 처음 병렬로 두 번 시작한 환경에서는 dblink 기반 고정 fixture가 서로 보이는 오염이 발생했다. 두 runner/container를 종료하고 테스트 원문의 UUID-scoped cleanup으로 그 실행이 만든 fixture 2건만 제거했다. 이후 한 세션씩 직렬 실행했다. 별도로 발견한 3개 Calendar audit row는 잔여물이 아니라 매시 29분 `pg_cron`이 정상 생성한 0-count operational row였으므로 삭제하지 않았다. `calendar_horizon_worker.test.sql`을 현재 테스트의 target/as-of 범위로 격리한 뒤 focused 56개와 full 2,422개가 통과했다.

전체-schema DB lint는 KinFlow 코드가 아닌 local `pgtap`의 `extensions.*` 구버전 helper에서 PostgreSQL 호환 오류를 보고했다. 제품 스키마 `app_private,public`에 동일 warning/fail-on-error gate를 적용하면 결과는 0이며, CI도 extension 구현 세부에 종속되지 않도록 같은 제품 스키마 범위로 고정했다.

## Files and Migration

- Migration and pgTAP: `supabase/migrations/20260808150000_calendar_overlap_hints.sql`, `supabase/tests/database/calendar_overlap_hints.test.sql`
- Domain and repository: `apps/kinflow_app/lib/features/calendar/domain/entities/calendar_overlap_preview.dart`, Calendar repository interface and unavailable/provider implementations
- Data and adapter: Calendar data-source overlap records, `apps/kinflow_app/lib/infrastructure/supabase/supabase_calendar_data_source.dart`
- Application and UI: Calendar controller/provider, `apps/kinflow_app/lib/features/calendar/presentation/screens/calendar_events_screen.dart`
- Localization: EN/KO/EN-XA ARB and generated localizations
- Flutter tests: overlap domain/parser, provider repository, controller, Calendar widget and shared fake dependencies
- Contracts and tracking: calendar overlap contract, database schema commentary, Phase 04, requirement/test matrices, changelog and this evidence
- Validation harness hardening: `supabase/tests/database/calendar_horizon_worker.test.sql`, `scripts/ci/supabase-backend.sh`

새 runtime package, native permission, background worker, persistent cache, analytics event, table, index 또는 Calendar mutation signature는 추가하지 않았다.

## Security, Privacy, and Data

- requester authorization, household existence, participant integrity와 removed status를 server가 다시 계산한다. 다른 household UUID나 removed participant를 넣어도 event 존재 또는 content를 반환하지 않는다.
- request fingerprint와 RPC payload에는 title, description, display name, auth-user ID, actor, email, idempotency/correlation ID가 없다.
- response의 title과 intersecting display name은 caller가 이미 읽을 수 있는 active household Calendar/roster 범위이며, description과 전체 participant roster는 반환하지 않는다.
- detail 최대 10건, candidate 최대 366개, participant 최대 50명, duration 최대 7일과 bounded anchor scan으로 요청 비용과 content 노출을 제한한다.
- raw provider exception, SQL statement, schedule content와 UUID payload를 UI 오류나 새 log/analytics에 기록하지 않았다.
- 자동 테스트는 synthetic UUID, title, display name만 사용했으며 production project, 실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Google/Supabase 성인 계정과 실제 household에서 겹침 생성·편집·저장
- 두 계정·두 기기의 concurrent Calendar change와 preview stale timing
- hosted migration replay, production-size cardinality/query plan 및 p75/p95
- 실제 Android/iOS의 keyboard, 200% font, TalkBack/VoiceOver, tablet/split layout
- 실제 DST gap/fold 및 device timezone travel 흐름
- destructive clean local reset과 처음부터의 40-migration replay

## Remaining Risks and Completion Boundary

1. preview는 요청 시점 read-only snapshot이다. 다른 사용자가 직후 일정을 바꾸면 저장 전 결과가 오래될 수 있으며, 이는 mutation 차단 계약이 아니므로 의도적으로 허용한다.
2. existing side는 materialized scheduled occurrence만 검색한다. rolling horizon 밖의 무기한 반복 일정을 전 세계 미래까지 보장하는 availability engine이 아니다.
3. 상세 10건 이후는 total/truncated만 보인다. 사용자는 Calendar 전체 화면에서 나머지 일정을 확인해야 한다.
4. mixed all-day/timed은 household timezone 자정으로 해석한다. 역사적으로 자정 전환이 특이한 timezone의 hosted catalog/query behavior는 실환경 gate에 남아 있다.
5. 대형 household occurrence cardinality의 query plan과 index 효율은 remote 측정 전까지 NFR-PERF 완료 근거가 아니다.
6. clean reset은 실행하지 않았으므로 additive migration과 full regression 성공을 migration-from-zero 증거로 과장하지 않는다.
7. 따라서 WP04-07 local automated slice만 완료하며 Phase 04, FR-CAL-008 전체, release gate와 장기 기능 목표는 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- client rollback은 overlap domain/data/repository/controller/provider/editor surface, ARB/generated output와 관련 tests를 함께 revert한다. 기존 Calendar create/update/cancel/delete 경로는 그대로 남는다.
- DB rollback은 authenticated execute를 먼저 회수한 뒤 `public.preview_calendar_event_overlaps(...)`와 private candidate helper를 제거한다.
- migration은 table/data/mutation signature를 바꾸지 않는 additive read surface다. rollback 시 사용자 Calendar row나 occurrence history를 삭제하지 않는다.
- 운영 중 비용이나 오류가 커지면 client preview invocation만 비활성화해도 저장 가능성과 기존 expected-version mutation semantics는 유지된다.

## Next Entry Condition

- 다음 기능 우선순위는 남아 있는 `FR-TODAY-001`의 overdue → now/next → due-today chores → remaining events → completed-collapsed 상세 feed ordering을 작은 local composition slice로 닫는 것이다.
- 기존 Calendar/Chore source authority, partial failure, optimistic complete와 member filter를 유지하고 새 aggregate persistence나 content logging을 추가하지 않아야 한다.
- 실계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 뒤 마지막 gate에 계속 유지한다.
