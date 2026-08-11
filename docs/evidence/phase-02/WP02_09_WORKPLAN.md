# Phase 02 WP02-09 Household Departure Handoff Work Plan

## Status

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — Phase 02/G2 완료는 아님
- 수직 조각: existing leave transaction → strict fallback mapping → household-bound local purge → fallback/no-household auth commit → guarded home route
- 요구사항: `D-017`, `D-048`, `D-049`, `FR-HH-007`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`
- 계약: `docs/contracts/household-departure-handoff.yaml.md`
- 증거: `docs/evidence/phase-02/WP02_09_EVIDENCE.md`
- 실제 Google 계정, hosted Edge/RPC, 다중기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Existing Boundary and Gap

- `public.leave_household`는 이미 membership tombstone, actor-created invite revoke와 deterministic fallback selection을 한 transaction에서 수행한다.
- Edge/DTO는 `activeHouseholdId`와 `activeMemberId`를 exact nullable pair로 반환하고 검증한다.
- 현재 repository는 검증한 fallback pair를 버리고 controller는 generic success만 내보낸다.
- UI는 서버 성공 뒤 auth lifecycle `refresh()`를 다시 호출하므로 persistent read cache, guided resume와 pending invite의 household transition을 직접 보장하지 못한다.

## Implementation Boundary

1. leave 성공을 generic member command 성공과 분리하고 optional authoritative `ActiveHousehold` fallback을 domain result로 전달한다.
2. controller는 서버 성공 뒤 departure committer가 완료되기 전 `Left`를 내보내지 않는다.
3. fallback이 있으면 기존 active-household transition participant를 모두 purge한 뒤 fallback snapshot을 쓴다.
4. fallback이 없으면 같은 participant를 purge하고 active-household snapshot을 명시적으로 clear한다.
5. local purge/write/clear 실패는 auth lifecycle `localPurgeFailed` lock과 roster 없는 terminal failure로 닫는다.
6. 성공 시 auth lifecycle이 fallback active 또는 no-household 상태를 직접 emit하고 UI는 별도 server refresh 없이 home으로 이동한다.
7. auth credential, notification installation과 RevenueCat account identity는 household-bound가 아니므로 purge하지 않는다.

## Automated Evidence Plan

1. repository exact fallback pair → domain ActiveHousehold mapping, both-null mapping과 partial/malformed rejection
2. controller leave single-flight, authoritative fallback commit, no-fallback commit와 local failure terminal state
3. local transition purge-before-replace, purge-before-clear와 any-step fail-closed ordering
4. auth lifecycle fallback active, no-household and localPurgeFailed state transitions
5. member screen destructive confirmation and refresh-free fallback route handoff
6. existing Owner transfer-first behavior and runtime household mutation guard preservation
7. focused/full Flutter regression, analyzer, formatter, localization and whitespace gates
8. existing leave/fallback pgTAP and full DB regression remain green; no new schema migration is expected

## Stop Conditions and Rollback

- fallback ID를 client가 선택하거나 leave response와 다른 household를 commit하면 배포하지 않는다.
- server leave 성공 뒤 departed roster 또는 이전 household cache를 다시 표시하면 배포하지 않는다.
- fallback pair가 부분 null인데 no-household로 해석하거나 malformed UUID를 무시하면 배포하지 않는다.
- local purge/clear 실패 뒤 protected route를 열면 배포하지 않는다.
- rollback은 persistent household cache가 비활성인 경우에만 이전 refresh handoff로 되돌릴 수 있다. server schema/RPC는 변경하지 않는다.

## Non-scope

- existing Owner transfer, role change와 remove-member authority 변경
- household 삭제, billing owner transfer와 account deletion
- active selection server concurrency protocol 변경
- Managed Child/guest/acting context
- hosted/real-account/two-device/physical-device evidence
