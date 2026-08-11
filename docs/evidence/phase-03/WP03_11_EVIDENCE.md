# Phase 03 WP03-11 Adult Household Activation Progress Evidence

## Status

- 결과: **LOCAL AUTOMATED SLICE PASS (2026-08-09)**
- 범위: `PRD-G01`, `FR-HH-003`, `FR-HH-005`, `FR-CHORE-001`, `FR-CHORE-004`, `FR-CHORE-009`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-051`
- 계약: `docs/contracts/household-activation-progress.yaml.md`
- 작업계획: `docs/evidence/phase-03/WP03_11_WORKPLAN.md`
- 이 결과는 WP03/G3/출시 완료가 아니다. remote Supabase, 실제 성인 2계정, 두 기기와 실제 Android/iOS 검증은 사용자 지시에 따라 마지막 Gate다.

## Delivered slice

| Layer | Result |
|---|---|
| PostgreSQL | `get_household_activation_progress(uuid)`가 current active caller를 재인가하고 역사적 distinct adult 2명, distinct series 3개, distinct adult completer 2명과 household-local day-two를 capped aggregate로 반환한다. |
| Privacy | 새 table/event/visit/analytics row가 없고 반환은 household ID와 capped count 3개, boolean 1개뿐이다. 이름, 계정·구성원·chore·occurrence ID, content와 timestamp는 반환하지 않는다. |
| Historical semantics | later-removed membership, soft-deleted chore series와 reopened completion도 한 번 달성한 milestone을 회귀시키지 않는다. |
| Flutter contract | exact five-key DTO, request household correlation, type/range 검증과 pure domain aggregate를 구현했다. |
| Application | duplicate same-household load coalescing, latest-household-wins, visible content를 보존하는 retry와 raw provider error 비노출을 구현했다. |
| Cache boundary | activation projection은 `CachedChoreDataSource`가 그대로 delegate하며 persistent read cache를 읽거나 쓰지 않는다. cached Today에서는 invite/create mutation action을 비활성화한다. |
| Today | 기존 핵심 content/action 뒤에 4개 ordered step, 기존 invite/create route CTA, local retry, manual/resume refresh와 successful completion 뒤 projection refresh를 제공한다. |
| Localization/a11y | EN/KO/EN-XA ARB와 generated localization을 추가하고 320×568, 200% text, scroll, semantics와 최소 48dp action target을 검증했다. |

## Server authorization and aggregate evidence

- RPC는 `security definer`, empty `search_path`, `authenticated` execute-only다.
- unauthenticated는 `KFC01`, null input은 `KFC02`, outsider/removed/deleted household는 동일한 generic `KFC03`으로 닫힌다.
- membership과 completion actor는 `auth_user_id` distinct 기준이므로 같은 계정의 재가입·복수 완료가 목표를 부풀리지 않는다.
- series 생성은 content-free `chore.series_created` domain event의 distinct aggregate만 집계한다.
- completed audit만 completer에 포함하며 reopen row 자체는 completer 수를 늘리지 않는다.
- DB `clock_timestamp()`를 invocation마다 한 번 잡고 household IANA timezone에서 creation local date와 비교한다. client clock은 authority가 아니다.
- partial completed-event index는 household와 actor 기준 조회를 지원하며 completed row에만 한정된다.

## Client behavior evidence

- projection load는 Today Chore/overdue/Calendar load와 병렬이며 실패해도 기존 content가 남는다.
- failure card의 retry는 projection만 다시 읽는다.
- Today의 기존 create/edit/delete/reschedule/reassign/skip/history/quick-complete 위치를 보존하기 위해 진행 카드를 핵심 content/action 뒤에 배치했다.
- normal chore creation CTA는 기존 due-local-date route를 재사용하며 invite CTA는 기존 household invite creation route를 재사용한다.
- successful quick completion만 projection refresh를 유발하고 실패한 mutation은 milestone을 새로 읽어 성공처럼 보이지 않는다.
- 동일 household 중복 요청은 하나의 repository call을 공유하고, household 전환 중 늦게 끝난 이전 응답은 publish되지 않는다.
- DTO의 extra/missing/wrong-type/out-of-range/mismatched-household payload는 모두 `invalidPayload`로 fail closed 한다.

## Automated verification

| Command / suite | Result |
|---|---|
| `npx supabase db reset` | PASS — WP03-11 migration을 포함한 clean local rebuild |
| `npx supabase test db supabase/tests/database/household_activation_progress.test.sql` | PASS — 32/32 |
| `npx supabase test db` | PASS — 49 files, 2,515 tests |
| `npx supabase db lint --local --schema app_private,public --level warning --fail-on error` | PASS — schema error 0 |
| activation domain/controller/DTO/repository focused Flutter suite | PASS — 60 tests |
| `household_activation_progress_widget_test.dart` | PASS — 4 tests |
| `one_time_chore_widget_test.dart` | PASS — 29 tests; 기존 Today 회귀 포함 |
| `cached_read_data_source_test.dart` | PASS — 13 tests; activation cache read/write 0 |
| full `flutter test` | PASS — 895 tests, optional 1 skipped |
| `flutter analyze` | PASS — issue 0 |
| Dart format check over `lib test tool` | PASS — changed file 0 after formatting |
| public config / secret scan / codegen drift | PASS — valid allowlist, high-confidence secret 0, generated drift 0 across 8 files |
| `npm run ci:test` | PASS — 134 tests |
| `npm run ci:workflow` | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| `scripts/ci/actionlint.sh` | PASS — pinned 1.7.12 archive/binary checksum verified |

## Contract and traceability updates

- `docs/contracts/README.md`
- `docs/contracts/database-schema.sql.md`
- `docs/contracts/rls-contract.sql.md`
- `docs/matrices/API_CONTRACT_TEST_MATRIX.csv.md` — `API-037`
- `docs/matrices/TEST_MATRIX.csv.md` — `T-ACT-01`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/RISK_REGISTER.csv.md` — `RISK-024`
- `docs/matrices/RELEASE_CHECKLIST.csv.md`
- `docs/phases/PHASE_03_CHORES_AND_TODAY.md`
- `docs/MASTER_SPEC.md`
- `docs/CHANGELOG.md`

## Deferred gates and honest boundary

1. 현재 RPC 호출은 “가구 생성 로컬 날짜 이후에 현재 평가했다”만 증명한다. 과거의 정확한 day-two Today route 방문 ledger나 funnel analytics는 만들지 않았다.
2. historical milestone과 current active-member readiness는 다른 개념이다. removed adult가 있어도 과거 milestone은 유지된다.
3. 실제 성인 두 계정의 invite/accept/각 1회 완료와 multi-client propagation은 remote two-device Gate까지 완료로 표시하지 않는다.
4. physical Android/iOS의 screen reader, large text, network transition과 performance는 마지막 device Gate다.
5. production-size aggregate query plan/latency와 hosted monitoring은 아직 측정하지 않았다.
6. process-death guided setup resume와 product analytics는 별도 후속 slice다.

## Rollback

- Flutter card/controller/provider/domain/ARB와 관련 tests를 제거한다.
- `public.get_household_activation_progress(uuid)`와 partial completion index를 forward migration으로 제거한다.
- 새 persisted activation data가 없으므로 user-data cleanup이나 analytics purge는 필요하지 않다.
