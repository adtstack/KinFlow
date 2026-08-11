# Phase 03 WP03-13 One-time Chore Trash and Undo Evidence

## Status

- 결과: **LOCAL AUTOMATED SLICE PASS (2026-08-09)**
- 범위: `FR-CHORE-001`, `FR-CHORE-003`, `NFR-SEC-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`, `D-048`
- 계약: `docs/contracts/one-time-chore-trash.yaml.md`
- 작업계획: `docs/evidence/phase-03/WP03_13_WORKPLAN.md`
- 이 결과는 WP03/G3/출시 완료가 아니다. 실제 계정, hosted Supabase, 두 기기 Realtime과 physical-device 검증은 사용자 지시에 따라 마지막 Gate다.

## Delivered slice

| Layer | Result |
|---|---|
| Server read | `get_deleted_one_time_chores`가 active exact-household member에게 soft-deleted scheduled one-time chore만 삭제 시각·series ID 역순으로 반환하며 limit `1..100`, opaque cursor와 exact 18-key/metadata-only empty shape를 강제한다. |
| Server restore | `restore_one_time_chore`가 deleted/cancelled/once 상태, 원래 active assignee와 series+occurrence expected version을 한 transaction에서 검증하고 content·revision·due·assignee를 보존해 scheduled로 복원한다. |
| Idempotency/audit | 기존 caller+key namespace에서 same-input replay는 `changed=false`, payload·operation 재사용은 `KFC04`이며 restored audit는 immutable/content-free다. |
| Flutter boundary | strict deleted item/page/cursor와 restore request/snapshot, exact Supabase parser, repository response reconciliation 및 stable typed failure mapping을 추가했다. |
| Application | trash initial/retry/refresh/pagination/restore single-flight와 성공·stale 뒤 authoritative reload를 제공한다. Today 삭제 receipt는 post-delete dual version과 원래 occurrence를 process memory에만 보존한다. |
| UX | 삭제 Snackbar의 즉시 Undo, `/chores/trash` 목록·empty/error·refresh·pagination·restore, compact overflow-safe toolbar와 EN/KO/EN-XA 200% UI를 추가했다. |
| Runtime/cache | chores feature mutation guard를 provider·ID·network I/O 전에 적용한다. trash read는 feature-off에서도 허용하고 persistent fallback을 만들지 않으며 restore 성공은 Today/list cache를 무효화한다. |

## Server authority and security evidence

1. anonymous, removed member와 cross-household caller는 trash content를 읽거나 restore하지 못한다.
2. direct series/revision/occurrence/command-table mutation은 허용하지 않고 authenticated client는 security-definer RPC만 실행한다.
3. restore는 deletion audit가 현재 dual version과 일치하는 exact occurrence에만 적용돼 임의 cancelled/repeating/active row를 복원하지 못한다.
4. 원래 assignee가 제거되면 자동 재할당 없이 `KFC06`으로 거부하며 content나 identifier를 오류에 반사하지 않는다.
5. stale series 또는 occurrence version은 `KFC05`; exact replay는 audit 중복 없이 원래 result version을 반환한다.
6. chores runtime feature가 disabled면 trash read는 유지되고 restore mutation은 DB에서도 거부된다.

## Client reconciliation evidence

- 삭제 성공 뒤 server receipt로 Undo request를 만들고 Today authoritative reload 후 Snackbar를 표시한다.
- transient Undo 실패는 같은 idempotency key와 expected versions를 유지해 다시 시도할 수 있다.
- 성공, stale/invalid reconciliation, scope 변경, 다른 mutation 또는 Snackbar dismissal은 matching receipt를 정리한다.
- trash restore 성공은 로컬 row 조립을 authority로 쓰지 않고 첫 페이지를 다시 읽는다.
- strict parser는 cursor casing/hex, UTC timestamp, nullable time pair, sort order, duplicate identity, household scope와 expected+1 version drift를 fail closed 처리한다.
- 320×568, text scale 200%에서는 trash와 refresh를 localized overflow menu로 합쳐 toolbar overflow 없이 48dp action target을 유지한다.

## Automated verification

| Command / suite | Result |
|---|---|
| focused trash pgTAP | PASS — 1 file / 47 tests |
| clean local DB reset | PASS — 46 migrations + seed |
| full `npx --no-install supabase test db` | PASS — 52 files / 2620 tests |
| DB schema lint | PASS — `app_private`, `public`, issue 0 |
| focused Flutter domain/data/repository/controller/cache/runtime/architecture | PASS — 110 tests |
| focused one-time chore widget suite | PASS — 31 tests including Undo, trash route and compact 200% |
| full exact Flutter `flutter test --reporter compact` | PASS — 972 tests, optional 1 skipped |
| exact Flutter 3.44.7 `flutter analyze` | PASS — issue 0 |
| exact Dart 3.12.2 format check | PASS — 572 files / changed 0 |
| generated code drift | PASS — 8 generated files / drift 0 |
| public config and secret scan | PASS — examples allowlisted / high-confidence finding 0 |
| contract and matrix parse | PASS — contract YAML 13 root keys; 13 fenced CSV documents with declared row/column counts exact |
| `npm run ci:test` | PASS — 136 tests |
| all local Edge unit contracts | PASS — 7 suites / 118 tests |
| `git diff --check` | PASS — whitespace error 0 |

## Traceability updates

- `docs/contracts/one-time-chore-trash.yaml.md`
- `docs/contracts/README.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/TEST_MATRIX.csv.md` — `T-CHORE-TRASH`
- `docs/matrices/API_CONTRACT_TEST_MATRIX.csv.md` — `API-038`, `API-039`
- `docs/phases/PHASE_03_CHORES_AND_TODAY.md`
- `docs/MASTER_SPEC.md`
- `docs/CHANGELOG.md`

## Deferred gates and honest boundary

1. 실제 성인 계정 두 개에서 삭제·Undo·trash restore 권한과 content propagation은 아직 실행하지 않았다.
2. hosted Supabase migration/RLS/runtime-policy 배포와 production-size query plan/latency는 마지막 remote Gate다.
3. 두 기기에서 삭제·복원 Realtime invalidation, reconnect/resume refetch와 stale conflict UX는 local authoritative reload까지만 자동 검증했다.
4. TalkBack/VoiceOver, Android/iOS system Snackbar timing, physical-device 200% font와 process restart 후 receipt가 의도대로 사라지는 경험 검증은 남아 있다.
5. permanent purge, retention, archive, bulk restore, repeating cancellation restore, completed-item delete/restore와 removed-assignee reassignment editor는 구현하지 않았다.

## Rollback

- client route, Snackbar action, trash controller/repository integration을 제거해도 WP03-09 soft-delete data는 유지된다.
- emergency server rollback은 authenticated restore execute를 revoke하고 read-only trash projection을 유지한다.
- schema 제거가 필요하면 client retirement 뒤 forward migration으로 functions와 restored constraints를 제거하며 적용 migration은 수정하지 않는다.
