# Phase 02 WP02-05 Work Plan

- 작성일: 2026-07-29
- 기준 commit: `2b68351`
- Work Package: WP02-05 Role/Owner lifecycle
- 상태: IN PROGRESS / VALIDATION DEFERRED BY USER
- 선행 결과: WP02-01~04 automated implementation은 완료했으며 실제 Google 로그인·Android 2기기 검증은 별도 live gate로 남아 있다.

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-05 | Admin/Member 역할 변경, 마지막 Owner 불변조건, Owner 이전, 제거·나가기 후 접근 정리와 감사 기록을 구현한다. |
| FR-AUTH-006 | 역할 변경과 Owner 이전 전에 실제 OAuth 인증 시각을 확인한다. access-token refresh 시각만으로 최근 인증을 인정하지 않는다. |
| FR-HH-006 | Owner/Admin만 허용된 역할 변경을 수행하고, Owner 역할은 전용 이전 command로만 바꾸며 변경을 audit한다. |
| FR-HH-007 | 제거·나가기를 transaction으로 처리하고 membership RLS, active-household 선택과 미사용 invite 접근을 즉시 차단한다. |
| FR-HH-008 | 현재 Owner가 유효한 새 성인 member를 명시적으로 확인한 뒤 정확히 한 Owner를 유지하며 atomic transfer한다. |
| API-009/010 | 잘못된 새 Owner, outsider UUID injection, stale version과 권한 상승을 stable error로 거부한다. |
| D-013/D-017 | Store MVP 성인 역할만 제공하며 모든 role/owner/member mutation은 online-only다. |
| D-048/D-049 | expected version과 idempotency key를 사용하고 제거·나가기 시 사용자/가구 범위 상태를 재조정한다. |

## Authorization Decisions

| Actor | 허용 동작 |
|---|---|
| Owner | 다른 active Admin/Member의 역할 변경·제거, 다른 성인에게 Owner 이전 |
| Admin | active Member를 Admin으로 승격, active Member 제거 |
| Member | 자기 가구 나가기 |
| 모든 비-Owner | 자기 가구 나가기 |

- Admin은 Owner, 다른 Admin 또는 자기 자신의 역할을 바꾸거나 제거할 수 없다.
- Owner 자신은 role endpoint로 강등되거나 remove/leave할 수 없고 Owner 이전을 먼저 완료해야 한다.
- `owner`는 일반 역할 변경 입력으로 허용하지 않는다. Owner 이전 command만 기존 Owner→Admin, 대상→Owner, `households.owner_member_id`를 함께 변경한다.
- 역할 변경과 Owner 이전은 최근 10분 안의 실제 Supabase JWT `amr` OAuth 항목을 요구한다. `iat` 또는 `token_refresh` 항목은 최근 인증 증거가 아니다.

## Server Contract

1. forward-only migration에 private idempotency record와 immutable household audit event를 추가한다.
2. authenticated roster query는 active same-household member에게 household name/version과 active adult member의 최소 필드만 반환한다. 다른 household의 존재와 auth user ID는 노출하지 않는다.
3. mutation RPC는 service-role Edge adapter만 실행할 수 있고 authenticated user ID, role과 membership을 DB에서 다시 확인한다.
4. 모든 mutation은 actor+idempotency key advisory lock, normalized request hash와 expected row version을 사용한다. same-key/same-input replay는 저장된 최소 결과를 반환하고 key reuse와 stale write는 stable conflict다.
5. 제거·나가기는 member tombstone을 남기고 `user_active_households`를 삭제한 뒤 남은 membership이 있으면 결정적으로 하나를 다시 선택한다. 해당 member가 만든 active invite도 같은 transaction에서 revoke한다.
6. 현재 schema에는 persistent household cache와 device registration이 없다. 따라서 이번 slice는 RLS membership 차단, active selector와 invite capability 정리를 권위적 cleanup으로 구현한다. 향후 device table을 도입하는 WP05는 같은 transaction/worker contract에 registration revoke를 연결해야 한다.
7. Store MVP에는 assignment row가 아직 없다. 향후 chore/calendar migration은 removed member FK를 historical tombstone으로 보존하고 새 assignment 대상에서는 active member만 허용해야 한다.
8. audit에는 household, actor user/member, action, target, idempotency correlation ID, aggregate version, 결과와 시각만 저장한다. 이름·이메일·token·JWT·자유문장은 저장하지 않는다.

## Edge / Recent Authentication Contract

- `manage-household-members` Edge Function이 bearer session을 Supabase Auth로 검증한 뒤 service-only RPC를 호출한다.
- 역할 변경과 Owner 이전은 별도 `X-KinFlow-Recent-Auth` Supabase access JWT를 다시 검증하고 bearer와 같은 user인지 확인한다.
- 최근 인증은 공식 JWT `amr` 중 `oauth` 또는 `oauth_provider/authorization_code`의 최신 timestamp가 10분 이내일 때만 성립한다. `token_refresh`, access-token `iat`, client timestamp는 인정하지 않는다.
- Flutter는 민감 action 직전에 Google provider 상태를 비우고 계정 선택/인증을 다시 실행한다. 재인증 결과가 원래 auth user와 다르면 mutation을 보내지 않는다.
- request/response/error/log에 recent-auth JWT를 포함하지 않으며 stable envelope에는 allowlisted ID/version/role/timestamp만 담는다.

## Flutter Vertical Slice

1. household membership domain/application/data 경계를 추가하고 외부 JSON을 DTO에서 fail-closed parse한다.
2. `/family/members`에서 roster, 현재 역할과 허용 action만 표시한다. UI 숨김은 보조 수단이며 최종 권한은 Edge/DB가 결정한다.
3. 역할 변경과 Owner 이전은 확인 dialog 뒤 Google recent-auth를 수행한다. 제거·나가기는 명시적 destructive confirmation을 요구한다.
4. mutation 성공 뒤 server roster를 다시 읽는다. 자기 나가기 성공 뒤 auth lifecycle을 refresh해 fallback household 또는 no-household route를 다시 계산한다.
5. 로컬에 roster persistent cache를 추가하지 않으며 화면 dispose/account switch 시 provider state만 남지 않게 한다.

## Validation — Deferred Batch

사용자 요청에 따라 이번 구현 turn에서는 test, analyze, build, local reset과 CI를 실행하지 않는다. 후속 배치에서 아래를 한 번에 수행한다.

- clean migration reset, schema lint, direct RPC/CRUD grant와 RLS matrix
- role capability matrix, last-owner invariant, atomic transfer와 stale version
- remove/leave selector fallback, invite revoke, removed-member read/write denial
- recent-auth missing/refresh-only/wrong-user/expired/fresh OAuth cases와 JWT redaction
- idempotency replay/reuse/concurrency와 immutable audit shape
- Flutter repository/controller/route/dialog/account-switch/localization/a11y tests
- generated drift, analyze, full Flutter/backend quality, dev/prod Android build와 GitHub final gate
- 실제 성인 2계정/2기기 Owner 이전·제거·재진입 검증

검증 전에는 WP02-05를 COMPLETE 또는 PASS로 표기하지 않는다.

## Explicit Non-scope

- Managed Child, guardian, acting context와 child role — P1
- device registration/push-token table과 remote device wipe — Phase 05
- chore/calendar assignment 재배정 UI — 해당 table을 도입하는 후속 Phase
- household 삭제, 계정 삭제, billing owner 이전 — Phase 06~07
- 실제 Google 계정, Android 2기기와 production Supabase 적용 — deferred live/release gate

## Stop / Rollback

- 최근 인증을 refresh token/클라이언트 시각만으로 우회하거나 outsider가 role/member/owner mutation을 실행할 수 있으면 배포하지 않는다.
- 한 transaction 종료 시 active Owner가 0명 또는 2명 이상이거나 pointer가 불일치하면 배포하지 않는다.
- 제거된 member가 RLS로 가구 데이터를 읽거나 active invite를 계속 사용할 수 있으면 배포하지 않는다.
- remote 적용 전 rollback은 WP02-05 feature commit revert다. remote 적용 후 migration은 수정·삭제하지 않고 forward fix한다.

## Next Entry Condition

- deferred validation batch가 green이고 evidence가 기록되어야 WP02-05 완료로 전환한다.
- 이후 WP02-06 adult activation handoff, WP02-07 end-to-end authorization을 순서대로 진행한다.
