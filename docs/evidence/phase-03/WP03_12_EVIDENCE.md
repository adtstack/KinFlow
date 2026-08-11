# Phase 03 WP03-12 Process-Death-Safe Guided Setup Resume Evidence

## Status

- 결과: **LOCAL AUTOMATED SLICE PASS (2026-08-09)**
- 범위: `FR-CHORE-002`, `FR-CHORE-005`, `FR-CHORE-010`, `NFR-REL-01`, `NFR-PRIV-01`, `D-048`, `D-051`
- 계약: `docs/contracts/guided-chore-setup-resume.yaml.md`
- 작업계획: `docs/evidence/phase-03/WP03_12_WORKPLAN.md`
- 이 결과는 WP03/G3/출시 완료가 아니다. 실제 account, remote Supabase, 다중기기와 실제 Android Keystore/iOS Keychain process-kill 검증은 사용자 지시에 따라 마지막 Gate다.

## Delivered slice

| Layer | Result |
|---|---|
| Domain | exact household/member, 원래 start date/timezone, catalog-order exact-three input, unique command ID 3개와 `0..3` checkpoint를 하나의 immutable resume plan으로 재검증한다. |
| Secure codec | app environment별 전용 `flutter_secure_storage` namespace/fixed key, Android backup false, UTF-8 8 KiB 상한과 exact JSON key/type/version/canonical order parser를 구현했다. |
| Controller | 최초 server mutation 전에 whole plan save를 요구하고, 각 성공 뒤 증가한 checkpoint가 저장돼야 다음 request를 보낸다. |
| Recovery | 새 controller가 durable completed count부터 stored payload/command ID로 자동 진행한다. response-success/checkpoint-loss는 같은 요청을 replay하고 기존 server idempotency에 맡긴다. |
| Completion | count 3 저장 뒤 secure record clear가 성공해야 success를 낸다. clear failure retry는 server create 0회로 cleanup만 재시도한다. |
| Routing | Today 첫 source load 앞에서 exact active household/member pending record를 확인하고 guided route로 이동한다. absent/corrupt/mismatch/unavailable이면 mutation 없이 Today를 계속 연다. |
| UI | restored title/repeat/selection을 frozen 상태로 표시하고 localized live notice와 confirmed progress를 제공한다. skip/partial exit는 record clear 성공 뒤에만 Today로 이동한다. |
| Privacy | 입력 중 초안은 저장하지 않고 submitted title/IDs는 secure storage에만 둔다. log/telemetry/network shape를 추가하지 않았고 logout/account switch/account deletion composite purge에 참여한다. |

## Mutation and checkpoint evidence

1. 사용자가 submit하면 exact-three draft와 서로 다른 command ID 세 개를 만든다.
2. completed count 0인 전체 frozen plan의 secure write가 실패하거나 throw하면 recurring-create call은 0회다.
3. 항목 성공 뒤 count `n + 1` write가 실패하면 다음 항목을 호출하지 않고 durable count `n`을 유지한다.
4. 이 모호한 구간에서 process recreation은 동일 title, recurrence, start date와 command ID로 같은 항목을 replay한다.
5. durable count가 1이면 새 controller는 첫 항목을 건너뛰고 두 번째부터 호출하며 새 command ID를 생성하지 않는다.
6. durable count가 3이면 새 create request 없이 record clear만 수행한다.
7. user-confirmed exit도 clear가 실패하면 route에 남고 localized safe failure만 표시한다.

## Strict storage and scope evidence

- exact 7-key envelope와 exact 4-key entry만 허용한다.
- unknown version/key, wrong type, invalid UUID/date/title/frequency/count, noncanonical scope/title, out-of-order entry, duplicate template/command ID와 oversized payload를 거부하고 삭제한다.
- active household 또는 member mismatch는 record content를 UI에 반환하기 전에 삭제한다.
- storage initialize/read/write/delete exception은 `null`/`false` 또는 typed `internal` failure로만 변환하며 raw provider text를 표시하거나 기록하지 않는다.
- checkpoint overwrite failure는 이전 durable record를 삭제하지 않아 same-key recovery가 가능하다.
- auth runtime composition의 sensitive-local-state purge가 전용 namespace의 `deleteAll`을 호출하는 것을 자동 검증했다.

## Automated verification

| Command / suite | Result |
|---|---|
| guided resume domain tests | PASS — 5 tests |
| secure guided resume codec/store tests | PASS — 5 tests |
| guided controller tests | PASS — 10 tests |
| guided widget/Today preflight tests | PASS — 9 tests |
| auth dependency and architecture boundary tests | PASS — secure namespace/backup/purge and layer direction |
| full `flutter test --no-pub --reporter=compact` | PASS — 910 tests, optional 1 skipped |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS — issue 0 |
| Dart format check over `lib test tool` | PASS — 541 files, changed 0 |
| public config / secret scan / generated drift | PASS — exact allowlist, high-confidence secret 0, generated drift 0 across 8 files |
| `npm run ci:test` | PASS — 134 tests |
| `npm run ci:workflow` | PASS — 5 jobs, 17 pinned action uses, `contents:read` |
| `scripts/ci/actionlint.sh` | PASS — pinned archive downloaded and workflow lint green |
| `git diff --check` | PASS — whitespace error 0 |

DB migration, RPC, Edge function, RLS policy, package dependency와 native permission을 바꾸지 않았으므로 이 client-only slice에서 새 DB reset/pgTAP 대상은 없다. 기존 recurring-create의 server authorization, entitlement와 idempotency 계약은 그대로 사용한다.

## Contract and traceability updates

- `docs/contracts/guided-chore-setup-resume.yaml.md`
- `docs/contracts/guided-chore-setup.yaml.md`
- `docs/contracts/README.md`
- `docs/matrices/TEST_MATRIX.csv.md` — `T-GUIDED-RESUME`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/RISK_REGISTER.csv.md` — `RISK-027`
- `docs/phases/PHASE_03_CHORES_AND_TODAY.md`
- `docs/MASTER_SPEC.md`
- `docs/CHANGELOG.md`

## Deferred gates and honest boundary

1. 실제 Android process kill/reboot에서 Keystore-backed record가 유지되고 backup/restore로 이동하지 않는지는 physical-device Gate다.
2. iOS 출시는 Android Beta 이후 범위이므로 실제 Keychain accessibility와 process kill은 iOS Gate까지 미실행이다.
3. 실제 성인 account switch, 같은 household의 다른 adult, logout/account deletion과 reinstall forensic은 local fake composition만 통과했고 live 검증은 남아 있다.
4. remote Supabase response loss에서 동일 command ID replay가 실제 persisted server idempotency snapshot을 반환하는지는 remote Gate다. local controller는 exact key/payload reuse를 검증했다.
5. unsubmitted selection/edit recovery, activation completion marker/analytics와 server-managed/household-specific template는 이번 slice 범위가 아니다.

## Rollback

- Today pending preflight와 guided secure resume provider/controller integration을 제거한다.
- 전용 secure storage namespace는 auth purge 또는 forward cleanup에서 삭제하고 WP03-10의 process-memory retry로 돌아간다.
- DB/API rollback이나 이미 생성된 사용자 chore 삭제는 없다.
