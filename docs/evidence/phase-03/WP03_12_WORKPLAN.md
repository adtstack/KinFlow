# Phase 03 WP03-12 Process-Death-Safe Guided Setup Resume Work Plan

## Status

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 수직 조각: 제출된 guided chore 3개 묶음 보안 저장 → 항목별 체크포인트 → 앱 재실행 시 자동 발견·동일 멱등 키 재개 → 성공/명시적 이탈 시 삭제
- 요구사항: `FR-CHORE-002`, `FR-CHORE-005`, `FR-CHORE-010`, `NFR-REL-01`, `NFR-PRIV-01`, `D-048`, `D-051`
- 계약: `docs/contracts/guided-chore-setup-resume.yaml.md`
- 완료 증거: `docs/evidence/phase-03/WP03_12_EVIDENCE.md`
- 실제 계정, remote Supabase, 두 기기 Realtime과 실제 Android/iOS 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- 사용자가 정확히 세 집안일을 검토하고 만들기를 누른 시점의 frozen batch만 process death 이후 이어서 처리한다. 아직 제출하지 않은 선택·입력은 저장하지 않는다.
- 앱이 종료됐다 다시 열리면 active household의 Today 진입 전에 matching pending batch를 찾아 guided route로 돌리고, server-authoritative Today를 확인한 뒤 남은 항목을 자동 실행한다.
- 이미 성공한 항목은 다시 보내지 않는다. 성공 응답 뒤 로컬 체크포인트가 유실된 모호한 경우에만 같은 payload와 command ID를 다시 보내 기존 server idempotency로 결과를 복구한다.
- 사용자가 확인 후 설정을 중단하면 pending batch를 먼저 삭제하고 Today로 이동한다. 이미 서버에 생성된 집안일은 정상 사용자 데이터로 보존한다.

## Domain and application contract

- resume plan은 exact household/member, 원래 authoritative start date/timezone, catalog 순서의 exact-three input, 서로 다른 exact-three command ID와 `0..3` completed count를 보존한다.
- strict domain rebuild가 title, cadence, template uniqueness/order, recurrence draft, identifier와 count invariant를 다시 검증한다.
- 최초 제출은 three command ID 생성과 전체 plan 저장이 성공한 뒤에만 첫 create RPC를 보낸다.
- 각 create 성공은 다음 RPC 전에 증가한 completed count를 저장한다. 저장 실패 시 다음 항목을 호출하지 않아 현재 로컬 checkpoint보다 서버가 최대 한 항목만 앞설 수 있다.
- 세 번째 성공도 count 3을 저장한 뒤 record 삭제가 성공해야 UI success를 낸다. 삭제 실패 retry는 create 없이 삭제만 다시 시도한다.
- resume loader는 server-authoritative `loadToday`만 허용한다. 원래 start date와 payload는 멱등 replay를 위해 바꾸지 않으며 cache-only 결과에서는 mutation을 재개하지 않는다.

## Secure persistence and composition

- app environment와 contract version별 dedicated Flutter secure storage namespace/fixed key를 사용하며 Android backup은 끈다.
- JSON envelope는 exact key/type, UTF-8 8 KiB 상한, schema version, household/member scope를 검사한다. unknown version, oversized, malformed, domain-invalid, scope-mismatched record는 삭제하고 pending 없음으로 취급한다.
- storage/provider exception은 raw text 없이 typed safe failure로 변환한다. 최초 save failure는 server call 0회, checkpoint/clear failure는 frozen retry state 유지가 원칙이다.
- secure resume store는 logout, account switch, account deletion의 composite sensitive-local-state purge에 참가한다.
- DB migration, RPC, RLS, Edge function, native permission 또는 dependency는 추가하지 않는다.

## Routing and UI

- active household Today 화면의 첫 load 앞에서 pending lookup을 수행한다. matching valid record면 `/onboarding/chores`로 이동하고 Today source load는 하지 않는다.
- guided screen은 restored frozen inputs를 표시하고 control을 잠그며 resume 상태와 exact completed count를 localized live region으로 알린다.
- network/cache failure는 record를 보존한 채 기존 retry surface를 사용한다. explicit exit는 controller discard 성공 후에만 route를 바꾼다.
- EN/KO/EN-XA ARB만 사용하며 기존 compact 200% text, scroll, 48dp target과 screen-reader semantics를 유지한다.

## Automated evidence plan

1. resume plan exact-three/order/identifier/count invariant와 immutable collection
2. strict JSON round trip, exact keys/types/version/size/scope/corrupt purge
3. first secure-store save failure에서 server call 0회
4. partial success checkpoint와 process recreation 후 successful-entry non-resend
5. response-success/checkpoint-loss 후 same-key replay
6. completedCount 3 cold-start에서 create 0회 및 clear-only completion
7. corrupt/account/household/member mismatch가 title을 UI에 노출하지 않고 purge
8. logout/account switch/account deletion composite purge 참여
9. Today preflight matching redirect와 absent/unavailable continue
10. restored frozen UI, localized resume progress, discard clear-before-navigation
11. full Flutter tests, analyzer warning 0, formatter/codegen/config/secret/contract/matrix/whitespace gates

## Stop conditions and rollback

- 최초 persisted plan 없이 RPC가 시작되거나 checkpoint write 실패 뒤 다음 RPC를 호출하면 배포하지 않는다.
- resume가 command ID/payload/start date를 새로 만들거나 completed entry를 정상 경로에서 재호출하면 배포하지 않는다.
- 다른 household/member record가 UI에 노출되거나 logout/account switch purge에서 남거나 secure payload가 log/telemetry에 들어가면 배포하지 않는다.
- rollback은 Today preflight, secure resume adapter/provider/controller integration을 제거하고 WP03-10의 in-memory retry로 되돌린다. DB/API rollback과 이미 생성된 chore 삭제는 없다.

## Completion boundary

이 slice가 green이어도 activation 완료 marker/analytics, server/household template, invite 결합, 실제 두 성인·remote·두 기기·실기기 경험은 완료가 아니다. 제출된 guided setup의 단일 기기 process-death 복구만 local automated 수준에서 닫는다.
