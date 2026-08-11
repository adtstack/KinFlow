# Phase 05 WP05-08 Chore Occurrence Target Recovery Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09) / HOSTED·REAL-DEVICE GATE DEFERRED** — WP05/G5 전체 완료는 아님
- 수직 조각: Chore inbox/push subject UUID → active-household 재인가 → 단건 authoritative read → occurrence 상세와 활동 내역
- 요구사항: `FR-NOTIF-005`, `FR-CHORE-009`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- 결정: `D-002`, `D-006`, `D-013`, `D-018`, `D-036`, `D-051`
- 계약: `docs/contracts/chore-occurrence-target-recovery.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_08_EVIDENCE.md`
- 테스트 ID: `T-CHORE-TARGET-01`, `T-NOTIF-02`, `T-PUSH-04`
- 로컬 결과: 영향 pgTAP 157, 전체 pgTAP 54 files/2,718, Flutter 집중 111 및 전체 1,144 pass(+local-connectivity opt-in 1 skip), Node 141, analyzer/lint/format/codegen/config/secret/workflow/docs/whitespace 통과

## Product boundary

1. `chore_due`와 `chore_assignment` inbox item 또는 재인가에 성공한 Android push tap은 `/chores/occurrence/:occurrenceId`로 이동한다.
2. route에는 strict UUID occurrence ID만 넣고 household ID, 제목, 설명, 표시 이름이나 인증 주체를 넣지 않는다.
3. 화면은 현재 auth lifecycle의 active household를 서버에 전달하고 active membership과 occurrence 소유 가구를 다시 검사한 단건 응답만 표시한다.
4. scheduled와 completed occurrence는 표시하되 skipped, 삭제된 scheduled series, missing 및 다른 가구 occurrence는 동일한 unavailable 상태로 처리한다.
5. 성공 화면은 최신 occurrence 상세와 기존 bounded activity-history 읽기를 함께 제공한다. 이번 slice에서 완료·수정 같은 mutation을 새로 추가하지 않는다.
6. Calendar 알림은 기존 occurrence route로 정확히 보낸다. 파싱 실패, stale target 또는 알 수 없는 목적지는 알림 센터로 fail closed한다.

## DB, API and rollback design

- additive migration으로 `public.get_chore_occurrence_target(p_household_id, p_occurrence_id)`를 추가한다.
- 함수는 authenticated user와 active household membership을 먼저 검사하고 household/occurrence exact match를 강제한다.
- 반환 projection은 기존 Chore list occurrence DTO와 동일한 strict key set 및 series-management 계산을 사용한다.
- public/anon/service-role execute를 제거하고 authenticated execute만 부여한다. 기존 table grant, forced RLS, index와 data는 변경하지 않는다.
- direct target read는 cache fallback을 사용하지 않는다. stale cache가 권한이나 삭제 상태를 되살리지 못하게 한다.
- rollback은 client destination을 Notifications로 되돌리고 forward migration으로 RPC execute를 revoke한다. backfill이나 data cleanup은 없다.

## Client design

1. `ChoreRepository.loadOccurrence`와 strict provider mapping을 추가하고 expected household/occurrence가 다르면 invalid payload로 거부한다.
2. target controller는 initial/loading/ready/failed 상태, retry와 resume refetch를 제공한다.
3. detail route는 잘못된 UUID를 Notifications로 redirect하고 subflow 동안 primary navigation을 숨긴다.
4. 상세 본문은 기존 activity-history UI를 재사용해 list card와 direct route가 동일한 정보 구조와 pagination behavior를 갖게 한다.
5. not-found-or-forbidden은 존재 여부를 드러내지 않는 generic unavailable copy를 사용하고 transient failure만 retry를 제공한다.
6. inbox item은 read 상태 갱신을 시도한 뒤 category별 strict destination으로 이동한다. push intent는 authorized target의 category/subject를 보존해 같은 route builder를 사용한다.

## Automated evidence plan

1. RPC schema, execute grant, security-definer/search-path, cross-household isolation, inactive membership denial
2. scheduled/completed success와 skipped/deleted/missing indistinguishable failure
3. strict DTO exact keys, expected household/occurrence mismatch, malformed remote payload
4. target controller load/retry/resume and repository exception normalization
5. valid/invalid go_router route, loading/ready/unavailable/transient/detail-history UI
6. Chore and Calendar inbox category routing plus read-state behavior
7. Chore and Calendar authorized push routing, stale/mismatch fallback and dedupe
8. EN/KO/EN-XA localization, compact 200% text scale and semantic recovery actions
9. focused, impact and full pgTAP/Flutter/Node regressions; analyzer, format, codegen, config, secret, workflow, matrix and whitespace gates

## Stop conditions

- route나 push/inbox payload에 household ID 외의 기존 최소 envelope를 넘어 title, description, display name, email 또는 auth subject가 추가되면 중단한다.
- active membership 또는 exact household/occurrence 검증 없이 상세를 표시하면 중단한다.
- missing과 forbidden을 서로 다른 사용자 메시지로 노출하면 중단한다.
- direct target에 stale read cache를 사용하거나 notification tap이 target 실패 후 Today로 열리면 중단한다.

## Deferred validation

- Firebase 실제 project, 실계정 inbox/push, physical Android foreground/background/terminated/local tap
- 실제 membership removal 및 삭제 race를 두 기기에서 검증하는 항목
- iOS/APNs, Web Push/browser URL history와 Managed Child route policy

위 항목은 사용자 지시에 따라 기능 개발 이후 마지막 통합 Gate에서 수행한다.
