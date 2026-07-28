# Phase 02 WP02-02 Work Plan

- 작성일: 2026-07-28
- 기준 commit: `e27b4a8`
- Work Package: WP02-02 Household schema/RLS
- 상태: LOCAL COMPLETE / REMOTE CI PENDING
- 선행 결과: WP02-01 local + remote automated secure-storage slice PASS; Google/provider/device validation DEFERRED

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-02 | adult `profile`/`household`/`household_members`/active-household schema를 정식 authorization boundary로 강화한다. |
| NFR-SEC-01 | UUID나 client-supplied household ID만으로 다른 가구 row를 읽거나 연결할 수 없게 RLS와 composite FK를 검증한다. |
| FR-HH-001 partial | 가구가 정확히 한 명의 active Owner를 가리키는 schema invariant를 제공한다. 실제 생성 RPC/UI는 WP02-03이다. |
| FR-HH-002 partial | profile/household timezone에 PostgreSQL이 아는 IANA zone만 저장되게 한다. 변경 UX는 WP02-03이다. |
| D-010 / D-013 | Store MVP DB 역할은 성인 `owner`, `admin`, `member`만 활성화하며 Managed Child surface를 만들지 않는다. |
| D-016 | DB는 membership 확장을 막지 않되 `user_active_households`는 한 사용자당 한 active selection만 허용한다. |
| D-042 / D-048 | 기존 foundation migration을 수정하지 않고 forward migration을 추가하며 version trigger와 future transactional command 경계를 보존한다. |
| D-049 | removed member는 stale active-household row가 남아도 household/member/active-selection을 읽지 못한다. |

## Sequencing Decision

- 사용자의 2026-07-28 지시에 따라 Google 로그인과 Android 실기기 검증은 마지막 단계로 연기한다.
- synthetic local `auth.users`와 JWT claim을 사용한 backend Work Package WP02-02~04는 순차 진행할 수 있다.
- 이 순서 변경은 WP02-01 provider/device 완료나 Phase 02 Exit Gate 통과를 의미하지 않는다.
- `DECISIONS.md`와 master decision mirror에 sequencing 결정을 기록한다.

## Contract Alignment

- 상위 `docs/contracts/database-schema.sql.md`와 `docs/contracts/rls-contract.sql.md`, 이미 적용된 migration은 physical table을 `public.household_members`, pointer를 `owner_member_id`로 정의한다.
- 하위 `docs/docs/09_DATA_MODEL_AND_RLS.md`의 `household_memberships`/`owner_membership_id` 표기는 physical contract와 불일치하므로 상위 계약에 맞춘다.
- full contract wrapper에는 후속 Phase와 P1 Managed Child reference가 포함돼 있으므로 이번 Store MVP migration으로 전체 추출·활성화하지 않는다.

## Scope

1. forward-only `household_authorization` migration을 추가한다.
2. timezone validator를 private schema에 두고 profile/household timezone constraint를 검증한다.
3. `current_user_member_id`, `is_active_household_member`, `has_household_role` helper를 stable security-definer + empty search path로 확정한다.
4. 정확히 한 명의 active Owner와 `households.owner_member_id` 일치를 deferred constraint trigger로 강제한다.
5. removed member가 stale `user_active_households` row를 읽지 못하도록 select policy를 강화한다.
6. anon/owner/admin/member/removed/other-household actor와 direct write/cross-household 공격을 pgTAP으로 검증한다.
7. schema/RLS naming과 requirement traceability를 실제 구현에 맞춘다.

## Explicit Non-scope

- Google OAuth, 실제 Supabase provider/session, Android device
- household 생성 RPC, onboarding UI, empty Today route — WP02-03
- invite token/link/acceptance — WP02-04
- role 변경, 제거/나가기, Owner 이전 command — WP02-05
- Managed Child, guardian, acting context — P1
- production Supabase link/push 또는 실제 사용자 데이터

## Schema / RLS Design

- 기존 partial unique index는 household당 active Owner를 최대 한 명으로 제한한다.
- 새 deferred constraint trigger는 transaction 종료 시 household가 정확히 한 active Owner를 가지며 pointer가 그 row인지 확인한다.
- household 삭제 cascade는 household row가 이미 없으면 owner check를 생략한다.
- timezone은 `UTC` 또는 `pg_timezone_names`에 존재하는 non-`posix/`, non-`right/` slash-form IANA name만 허용한다.
- household/member direct mutation grant와 policy는 계속 없다. 생성·역할·삭제는 후속 transactional RPC/Edge command만 사용한다.
- active member는 같은 household와 구성원을 읽고, profile은 자기 row만 읽고 허용된 column만 수정한다.

## Automated Validation

- clean Supabase reset과 ordered migration hash/count
- schema lint warning gate에서 application error 0
- exact adult role enum과 P1 table absence
- timezone valid/invalid insert/update
- same-household Owner pointer, exactly-one active Owner, cross-household Owner pointer 공격
- helper 결과: owner/admin/member/removed/outsider
- owner/admin/member same-household read allow
- other-household/removed/anon read deny
- household/member direct insert/update/delete deny
- active household exact auth-user/member composite binding과 removed-member stale row deny
- Node workflow tests, full Flutter quality, dependency audit, backend contract, dev/prod APK CI

## Data / API / Privacy Impact

- 새 production data나 remote schema 변경 없음. local migration/seed/test만 변경한다.
- Edge/OpenAPI/Flutter UI 변경 없음.
- synthetic `.invalid` identity와 deterministic UUID만 사용하고 token/JWT/email을 log/evidence에 넣지 않는다.
- 새 runtime dependency, Android permission, telemetry 변경 없음.

## Manual / Deferred Validation

- 실제 Supabase project migration rehearsal, backup/restore, production query plan은 NOT RUN이다.
- Google 계정, Android device, real two-adult authorization은 마지막 Phase 02 Gate까지 PENDING이다.

## Stop / Rollback

- outsider/removed actor가 household ID, member row 또는 active selection을 읽으면 즉시 중단한다.
- invalid Owner transaction이나 invalid timezone이 commit되면 다음 Work Package로 진행하지 않는다.
- remote migration은 적용하지 않는다. local rollback은 새 migration/test/decision alignment를 revert하고 clean `db reset`으로 확인한다.
- 출시 후 migration은 수정/삭제하지 않고 forward fix하지만 현재 remote project에는 적용하지 않는다.

## Next Entry Condition

- local/remote CI의 DB reset, lint, full pgTAP/RLS matrix와 final gate가 모두 green이어야 WP02-03에 진입한다.
- Android device/Google provider는 여전히 deferred이며 Phase 02 Exit Gate는 blocked 상태를 유지한다.
