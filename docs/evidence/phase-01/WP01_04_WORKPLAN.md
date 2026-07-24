# Phase 01 WP01-04 Work Plan

- 작성일: 2026-07-24
- 기준 commit: `ec4229f`
- Work Package: WP01-04 Supabase Local
- 상태: COMPLETE

## Requirements

| ID | 구현 범위 |
|---|---|
| WP01-04 | CLI pin/config/reset, baseline migration, default-deny RLS, deterministic seed, health Edge contract, Flutter dev connectivity |
| D-008 | Supabase Auth/PostgreSQL/RLS/Edge Functions local baseline |
| D-009 | Edge Function은 TypeScript/Deno 유지 |
| D-013 | Store MVP schema와 seed는 성인 계정만 포함하고 Managed Child surface 제외 |
| D-033 | 앱에는 공개 URL/publishable key만 포함하고 service role/DB secret 제외 |
| D-042 | timestamped forward-only migration과 migration hash evidence |
| D-047 | Supabase SDK는 infrastructure/data adapter 뒤에 두고 domain/application import 금지 |
| SPEC-004 | DB/RLS/API 권위와 cross-household isolation 자동 검증 |

## Database Scope

- `profiles`, `households`, `household_members`, `user_active_households`만 baseline으로 생성한다.
- 활성 역할은 `owner`, `admin`, `member`만 허용한다.
- primary seed household에는 독립 성인 사용자 2인을 넣는다.
- RLS isolation 검증용 별도 성인 사용자와 household 하나를 추가한다.
- 모든 table은 RLS를 enable/force하고 anon direct access를 허용하지 않는다.
- authenticated direct write는 profile의 제한된 self-edit와 active household self-selection 외에는 허용하지 않는다.
- household/member 생성·역할 변경은 후속 transactional RPC/Edge Work Package까지 direct policy를 두지 않는다.

## Edge / Client Scope

- `health` function은 DB·인증·개인정보 없이 local service/contract 상태만 반환한다.
- response는 JSON schema와 Node contract smoke로 검증한다.
- Flutter adapter는 Supabase client를 infrastructure 경계에 격리하고 health response만 typed result로 변환한다.
- dev Android emulator의 local cleartext는 `10.0.2.2`/localhost에만 허용한다.
- Google OAuth, session persistence, production project initialization은 비범위다.

## Data / API Impact

- local migration: 신규 1개, 위 네 table과 helper/trigger/RLS policy 생성
- local seed: deterministic synthetic users 3명, households 2개; 실제 이메일·이름·token 없음
- Edge API: unauthenticated local `GET/POST /functions/v1/health`
- remote Supabase project link/push: 없음
- production data/migration: 없음

## Dependency Plan

| Dependency | 구분 | 목적 | 대안/선택 이유 | 플랫폼·권한·개인정보 | Rollback |
|---|---|---|---|---|---|
| `supabase` CLI | root dev, exact `2.109.1` | local stack/reset/test/function serve | global Homebrew는 repo pin 재현성이 낮음 | Docker network/local ports 사용, production credential 없음 | package/config와 local containers 제거 |
| `supabase_flutter` | Flutter runtime, resolver target `2.16.0` | 승인된 Flutter Supabase client/adapter | 수기 HTTP는 Auth/PostgREST/Functions 계약을 중복 구현 | Android INTERNET, network 가능; health smoke에는 PII 없음 | adapter/dependency/permission 제거 |

CLI는 Node 24.15.0과 Docker 28.3.2에서 검증한다. Flutter dependency는 SDK 3.44.7 / Dart 3.12.2 resolver로 확정하고 `pubspec.lock`에 고정한다.

## Planned Tests

1. clean `supabase db reset`과 seed 적용
2. migration hash와 schema table/constraint/trigger 확인
3. 모든 public baseline table의 RLS enable/force와 anon deny
4. self profile/same-household read 허용, outsider/removed/cross-household deny
5. direct household/member insert/update/delete deny
6. active household selection이 자기 membership에만 제한됨
7. primary seed가 성인 2인이고 Managed Child row/type이 없음
8. health response status/content-type/cache/error-safe schema contract
9. Flutter adapter가 valid response를 typed success로 mapping하고 malformed/provider failure를 stable failure로 변환
10. 실제 local stack에 Flutter Supabase client로 health 호출
11. analyzer warning 0, Flutter 전체 test, codegen drift, dev/prod APK build
12. staged-index clean bootstrap과 local DB reset 재현

## Non-scope

- Google 로그인/OAuth client/redirect/deep link
- production Supabase project 생성·link·push·secret 설정
- household 생성/초대/역할 변경 RPC
- chores/calendar/billing/notification/privacy schema
- Managed Child, guardian, acting context
- remote signing, Play upload, 실제 사용자 데이터

## Rollback

- migration/seed/function/config, Flutter adapter/dependency와 Android network 변경을 함께 되돌리면 `ec4229f`의 local-backend 없는 상태로 복귀한다.
- local container/volume은 `npx supabase stop --no-backup`으로 폐기할 수 있다.
- remote project와 production data를 건드리지 않으므로 remote rollback은 없다.
