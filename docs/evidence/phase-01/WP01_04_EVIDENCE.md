# Phase 01 WP01-04 Evidence

- Work Package: WP01-04 Supabase Local
- 기준 commit: base `ec4229f`; WP01-04 change
- 검증일: 2026-07-24
- 환경: macOS arm64, Node 24.15.0, npm 11.12.1, Docker client/server 28.3.2, Supabase CLI 2.109.1, Flutter 3.44.7, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / DEVICE BOOT PENDING / REMOTE PROJECT UNLINKED**
- 범위 제한: Google 로그인·session, production Supabase project, 실제 사용자 데이터는 포함하지 않음

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP01-04 CLI/config/reset | PASS | project-scoped CLI 2.109.1, local config, clean DB reset |
| WP01-04 migration/RLS/seed | PASS | timestamped migration, deterministic adult fixtures, pgTAP 37/37 |
| WP01-04 Edge health contract | PASS | Deno 2 function, JSON schema, live success/error smoke |
| WP01-04 Flutter connectivity | PASS | infrastructure adapter unit tests와 local SDK live test |
| D-008 Supabase baseline | PASS | local Auth/PostgreSQL/RLS/API/Edge Runtime |
| D-009 TypeScript/Deno | PASS | `supabase/functions/health/index.ts` |
| D-013 adult-only Store MVP | PASS | enum/seed에 `owner`, `admin`, `member`만 존재 |
| D-033 public client config only | PASS | local URL/publishable key만 runtime test에 주입; secret 저장 0 |
| D-042 forward-only migration | PASS | `20260724000000_foundation.sql`, hash 고정 |
| D-047 SDK boundary | PASS | Supabase SDK import는 `infrastructure`와 live test에만 존재 |
| SPEC-004 DB/RLS/API authority | PASS | 권한·동일/타 가구·탈퇴 사용자·API 계약 자동 검증 |

## Implementation

- root npm dev dependency로 Supabase CLI를 exact `2.109.1`에 고정했다.
- local stack은 PostgreSQL 17, Auth, API, Edge Runtime만 사용하고 Studio, SMTP, Realtime, Storage, Analytics는 비활성화했다.
- baseline migration은 `profiles`, `households`, `household_members`, `user_active_households`, optimistic version trigger와 private membership helper를 생성한다. active household의 가구·member·auth user 일치는 복합 FK로 강제한다.
- 네 table 모두 RLS를 enable/force한다. anon direct access와 authenticated household/member direct mutation은 grant 단계에서 차단한다.
- primary household에는 synthetic 성인 2인, 격리 검증용 별도 household에는 synthetic 성인 1인을 deterministic seed로 둔다.
- `health` Edge Function은 DB·Auth·개인정보에 접근하지 않고 exact local contract와 safe method error만 반환한다.
- Flutter SDK 호출은 `lib/infrastructure/supabase` adapter 뒤에 격리했다. malformed/provider failure는 raw detail 없이 stable code로 변환한다.
- Android dev flavor만 `10.0.2.2`, `127.0.0.1`, `localhost` cleartext를 허용한다. prod merged manifest에는 network security override가 없다.

## Migration / Contract Integrity

| File | SHA-256 |
|---|---|
| `supabase/migrations/20260724000000_foundation.sql` | `650cc415a72f87584ffb262d303dfe28341dc6770ef1efe870218281fbea79a0` |
| `contracts/supabase-health.schema.json` | `481b6a40595dec2ad07e413c6a48742cbe4b7db12836c5884fd2b5e3bd316dd0` |
| `package-lock.json` | `2d5dbdcffd50114818251e6f766ba2a160e61aefe0e31062d60a94be96c4ac42` |
| `apps/kinflow_app/pubspec.lock` | `8561ec37fb36a843723232293a3b6e89c5c950d740b3a1e7a3084be3cc7ee6d9` |

## Dependency Review

| Dependency | Locked version | License | Platform / permission / privacy / rollback |
|---|---:|---|---|
| Supabase CLI | 2.109.1 | MIT | dev only; Docker network와 local ports 사용, remote credential 없음; root npm/config/container 제거로 rollback |
| `supabase_flutter` | 2.16.0 | MIT | Android runtime/network; `INTERNET` 추가, dangerous runtime prompt 없음; health는 PII 없음; adapter/dependency/manifest 제거로 rollback |
| Supabase Dart core | 2.14.0 transitive | MIT | Functions HTTP client; adapter 밖 노출 없음 |
| `app_links` / `shared_preferences` / `url_launcher` | 7.2.1 / 2.5.5 / 6.3.2 transitive | package licenses | SDK가 Auth/session/deep-link 지원용으로 포함; 이번 WP에서는 login/session을 초기화하지 않음 |

수기 HTTP client는 향후 Auth/Functions 계약을 중복 구현하므로 채택하지 않았다. merged APK manifest audit 결과 일반 권한은 `INTERNET`뿐이며 plugin이 추가한 별도 dangerous permission은 없다. SDK의 로그인·session 저장 surface는 후속 Google Auth Work Package 전까지 호출하지 않는다.

## Automated Validation

| 명령 | 결과 |
|---|---|
| `npx supabase start` | PASS, migration/seed 적용과 local health checks |
| `npx supabase db reset` | PASS, 빈 DB 재생성 후 migration/seed 재적용 |
| `npx supabase test db` | PASS, pgTAP 37/37 |
| `npx supabase db lint --schema public,app_private --level error --fail-on error` | PASS, schema error 0 |
| `npm run supabase:health` | PASS, schema/success headers/exact payload/safe 405 |
| `npm run supabase:flutter-health` | PASS, Flutter SDK → local Edge 1/1 |
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS, changed 0 |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| `flutter test --coverage` | PASS, 21 passed + opt-in live 1 skipped; 264/293 lines, 90.1% |
| `dart run tool/verify_codegen.dart` | PASS, generated drift 0 |
| dev/prod debug APK build | PASS |
| staged-index clean bootstrap/reset/test/build | PASS |

기본 schema 전체를 lint하면 pgTAP extension의 PostgreSQL 17 비호환 정적 진단도 포함된다. 최종 Gate는 application-owned `public,app_private`만 명시하고 `--fail-on error`로 실행했으며 error 0이다. 상세 명령 요약은 `logs/wp01-04-supabase-local.log`에 있다.

## Android Artifacts

빌드 산출물은 `.gitignore` 대상이며 저장소에 커밋하지 않는다.

| Flavor | package | bytes | SHA-256 |
|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` | 184,881,896 | `74c3432821bf5d6e777c43cb2fc920421f629730fd6040cf7aaa728fba6a25c8` |
| prod | `me.newlines.kinflow` | 184,881,815 | `265682ce0499a0212d266f51aae07c5912ff96e683abce24347b737dc028607c` |

두 APK 모두 min API 24, target/compile API 36이다. debug APK는 release signing이나 Play artifact 검증이 아니다.

## Clean staged-index reproduction

- 스테이징된 index만 새 `/private/tmp` 디렉터리에 export했다.
- `npm ci`는 15 packages를 exact lock으로 설치했고 audit vulnerability 0이었다.
- `flutter pub get --offline`이 성공했고 root/Flutter lockfile과 재생성된 `lib` source는 작업 트리와 byte-identical이었다.
- clean migration/seed로 DB reset 후 pgTAP 37/37, application schema lint error 0을 재확인했다.
- clean Node contract와 Flutter adapter로 Edge health 및 SDK live connectivity를 각각 재검증했다.
- codegen drift 0, analyzer issue 0, Flutter test 21 passed + opt-in live 1 skipped를 재확인했다.
- clean dev APK는 package `me.newlines.kinflow.dev`, min API 24, target/compile API 36, 153,594,389 bytes, SHA-256 `73bbfcbb75c64ff3c94f55a8749fa4bea207d31391e66aca2ca6fb8f959d54a6`다.

## Data / Security / Privacy

- remote Supabase `link`, `push`, production migration/data 변경은 0이다.
- service role key, JWT secret, DB URL, OAuth secret은 source/evidence/config에 저장하지 않았다.
- seed의 `.invalid` identity와 display name은 deterministic synthetic fixture이며 password/token은 없다.
- default-deny grant와 forced RLS를 함께 적용하고 cross-household, removed-member denial을 DB role로 검증했다.
- health API는 개인정보·DB 상태·raw exception을 반환하지 않으며 `no-store`와 제한된 CORS header를 사용한다.
- Supabase local stack은 shared development key로 모든 interface에 bind될 수 있어 신뢰할 수 없는 네트워크에서 실행하지 않는다.

## Manual Validation

- `adb devices -l` 실행 결과 연결 기기 0대였다.
- 실제 Android emulator/device에서 `10.0.2.2` connectivity와 app boot를 확인하는 수동 smoke는 NOT RUN이다.
- APK metadata와 merged manifest로 identifier, API level, dev-only cleartext 범위는 자동 검증했다.

## Remaining Risks / Next Entry

- production Supabase project/region/backup/PITR/network restriction은 아직 선택·검증하지 않았다.
- Google OAuth, redirect/deep link, session persistence와 logout purge는 의도적으로 비범위다.
- household 생성/초대/역할 변경에는 아직 transactional RPC가 없어 direct client mutation도 의도적으로 차단돼 있다.
- WP01-05 Design/i18n/a11y는 local backend contract와 무관하게 진입 가능하다. 실제 로그인 WP 전에는 OAuth provider/redirect와 session purge 계약을 별도 Work Plan으로 확정해야 한다.

## Rollback

- 이 change를 되돌리면 `ec4229f`의 backend 없는 WP01-03 상태로 복귀한다.
- migration/seed/function/config, root npm files, Flutter adapter/dependency/Android network 변경을 함께 제거한다.
- local container와 volume까지 폐기할 때만 `npx supabase stop --no-backup`을 실행한다.
- remote project와 production data를 변경하지 않아 remote rollback은 없다.
