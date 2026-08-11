# Phase 02 WP02-08 Active Household Switching Work Plan

## Status

- 상태: **IMPLEMENTED — LOCAL AUTOMATED PASS / LIVE PENDING (2026-08-09)** — Phase 02/G2 완료는 아님
- 수직 조각: own-membership projection → versioned server switch → household-bound local purge/write → auth state replacement → authoritative Today reload
- 요구사항: `D-016`, `D-017`, `D-048`, `D-049`, `FR-HH-005`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- 계약: `docs/contracts/active-household-switching.yaml.md`
- 증거: `docs/evidence/phase-02/WP02_08_EVIDENCE.md`
- 실제 Google 계정, hosted migration, 다중기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product Boundary

- D-016의 “한 번에 한 active household”를 유지하면서, 동일 성인 계정이 이미 가입한 다른 가구로 명시적으로 전환할 수 있게 한다.
- 사용자가 구성원인 가구의 이름, 본인 member ID/role/version과 현재 선택 여부만 표시한다. 다른 구성원의 roster, profile, billing 또는 invite 정보는 목록에 포함하지 않는다.
- Managed Child, child mode, guest와 보호자 승인 기능은 D-013에 따라 추가하지 않는다.
- 초대 수락 시 active household 선택은 기존대로 유지하고, 이번 기능은 이후 Settings에서 되돌아갈 수 있는 경로를 추가한다.

## Server and Data Design

1. `user_active_households.version`을 additive하게 추가하고 기존 update timestamp trigger를 version increment trigger로 교체한다.
2. `list_my_households()`는 `auth.uid()`의 non-removed adult membership과 non-deleted household만 최소 projection으로 반환한다.
3. `switch_active_household(target, expectedVersion)`은 target member ID를 서버에서 파생하고 현재 selection row를 lock한 뒤 exact version일 때만 변경한다.
4. 같은 target 재요청은 no-op으로 현재 authoritative version을 반환해 response-loss retry가 중복 version 증가를 만들지 않는다.
5. authenticated direct table update 권한을 제거하고 security-definer RPC만 mutation surface로 둔다.
6. private audit에는 auth user, 이전/다음 household와 selection version, 발생 시각만 기록한다. household name이나 member display name은 저장하지 않는다.
7. 기존 global/capability runtime policy trigger는 RPC 내부 update에도 계속 적용한다.

## Client Design

1. strict DTO → mapper → domain entity로 exact 7-key 목록과 exact 4-key switch response를 검증한다.
2. repository/controller는 retained list, loading, switching, version conflict, unavailable와 local-transition failure를 typed state로 표현한다.
3. 서버 성공 후 새 household 화면을 열기 전에 encrypted read cache, submitted guided-setup resume와 pending invite continuation을 정리하고 새 active-household cache envelope를 기록한다.
4. local transition이 실패하면 이전 가구 content 또는 새 가구 content를 표시하지 않고 auth lifecycle을 `localPurgeFailed` lock으로 닫는다.
5. 성공하면 auth lifecycle의 active household를 교체한다. 기존 push coordinator가 이를 관찰해 installation binding을 새 household로 재동기화한다.
6. Settings의 별도 화면에서 현재 가구를 표시하고 다른 가구 선택은 확인 dialog 뒤 실행한다. 성공 시 Today로 이동해 server-authoritative data를 새로 읽는다.

## Automated Evidence Plan

1. anonymous/outsider/removed/deleted target denial and exact self-only list projection
2. direct table update denial, security-definer/empty-search-path/grant boundary and private audit isolation
3. first switch, same-target replay, stale version conflict, switch-back and selection version increments
4. strict Supabase payload parsing and stable SQLSTATE mapping
5. repository mapping, controller single-flight/conflict/retry and local-commit failure
6. auth lifecycle cache transition success/fail-closed behavior
7. Settings route/widget EN/KO/EN-XA, confirmation, loading/error/current-selection and compact 200% layout
8. focused/full pgTAP and Flutter regression, analyzer, format, localization generation, matrix and whitespace gates

## Stop Conditions and Rollback

- 다른 구성원의 이름/ID, owner ID, member count, invite/billing/profile data가 list payload나 logs에 들어가면 배포하지 않는다.
- client가 target member ID 또는 auth user ID를 authority input으로 보낼 수 있으면 배포하지 않는다.
- stale expected version이 다른 target으로 active household를 바꾸거나 같은 요청이 version을 두 번 올리면 배포하지 않는다.
- 이전 household cache 정리를 확인하지 못했는데 새 household content를 표시하면 배포하지 않는다.
- rollback은 Settings entry를 숨기고 switch RPC execute를 revoke하는 forward operation으로 수행한다. 기존 membership과 invite-time selection은 유지한다.

## Non-scope

- household create/delete/leave/ownership behavior 변경
- multi-household combined Today 또는 cross-household search
- default household pinning, recent list와 automatic switching
- Managed Child/guest/acting context
- hosted/real-account/two-device/physical-device evidence
