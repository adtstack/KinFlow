# Phase 01 WP01-11 Core Primary Navigation Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Vertical slice: authenticated core shell → responsive exact-five navigation → dedicated Chores hub → route-selected state
- Requirements: FR-CHORE-009, FR-PLAT-009, NFR-A11Y-01, NFR-I18N-01
- Decisions: D-001, D-002, D-006, D-013, D-036, D-051
- Contract: `docs/contracts/core-primary-navigation.yaml.md`
- Test IDs: T-NAV-01, T-A11Y-03, T-I18N-01

## Product boundary

1. Android Store MVP의 authenticated adult core surface에 Today, Chores, Calendar, Family, Settings의 exact five destinations를 같은 순서로 제공한다.
2. compact는 bottom NavigationBar, medium은 collapsed NavigationRail, expanded는 extended NavigationRail을 사용한다.
3. 현재 route가 selected state의 유일한 authority이며 별도 provider, persistence, analytics나 network side effect를 추가하지 않는다.
4. `/chores`는 기존 authoritative list controller/repository를 재사용하되 upcoming, overdue, completed와 Everyone/Me만 노출하고 Calendar Today composition을 섞지 않는다.
5. `/family`를 primary route로 추가하고 기존 `/family/members`는 동일 화면의 호환 alias로 유지한다.
6. form, confirmation, privacy, notification과 기타 subflow는 primary navigation을 숨겨 accidental destination loss를 줄인다.

## DB, API and dependency impact

- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI, remote DTO: **변경 없음**
- local or secure storage schema: **변경 없음**
- runtime dependency and native permission: **변경 없음**
- 기존 auth redirect, feature/runtime policy와 household authority: **변경 없음**

## Security, privacy and accessibility

- route는 고정된 content-free path만 사용하고 household/member/resource ID를 넣지 않는다.
- navigation은 mutation, repository, command ID, cache write와 telemetry를 호출하지 않는다.
- exact localized label과 selected semantics를 제공하고 rail focus order는 navigation 다음 content다.
- 48dp destination target, EN/KO/EN-XA, compact 320×568 200%와 RTL rail 구조를 검증한다.
- Managed Child는 D-013에 따라 production surface가 없으며 향후 별도 destination allowlist와 guardian gate 전에는 활성화하지 않는다.

## Automated verification

1. exact five destination/order/route mapping과 same-destination no-op
2. compact NavigationBar, medium/expanded NavigationRail selected-state mapping
3. actual go_router traversal through Today, Chores, Calendar, Family and Settings
4. Chores hub upcoming initial query, exact three views, Everyone/Me, no Calendar load
5. existing `/family/members` compatibility and authenticated route guard
6. semantics, 48dp, EN/KO/EN-XA compact 200%, RTL and focus traversal
7. focused, impact and full Flutter regression; analyzer, format, codegen, config, secret, Node and documentation gates

## Manual and deferred verification

- Android TalkBack destination announcements and system back behavior
- representative phone/tablet orientation and split-screen interaction
- process recreation destination restoration
- Web browser direct URL/history/keyboard-only and iOS conventions
- real account and physical-device validation

사용자 지시에 따라 실제 계정과 실기기 검증은 마지막 통합 Gate까지 미룬다.

## Rollback

- 공용 destination configuration, compact NavigationBar와 rail destinations를 제거하고 기존 top-bar route shortcuts로 돌아간다.
- `/chores`와 `/family` alias를 제거해도 기존 `/today`, `/calendar`, `/family/members`, `/settings`는 유지한다.
- 저장 데이터와 DB/API가 바뀌지 않으므로 migration, backfill 또는 remote cleanup은 없다.
