# Phase 02 WP02-01 Dev Provider Setup Work Plan

- 작성일: 2026-07-29
- 기준 commit: `4ef94e7`
- Work Package: WP02-01 — real dev Google Android / Supabase Auth provider
- 상태: PROVIDER CONFIGURED / REAL LOGIN PENDING
- 확인된 dev targets: Google Cloud project `kinflow-503900`; Supabase project ref `ghsniwhntbjofvslfxeq`

## Requirements

| ID | 이번 vertical slice |
|---|---|
| FR-AUTH-003 / D-054 | Google Android native identity token을 dev Supabase Auth에서 검증하고 Supabase session만 app authority로 사용한다. |
| FR-AUTH-004 | real provider configuration, package/signing identity와 redirect/callback을 dev environment에 exact 연결한다. |
| FR-AUTH-005 / D-049 | real logout/account switch 뒤 Google local state와 Supabase/local household state purge를 기기에서 검증할 수 있게 한다. |
| Security | Web client secret은 Supabase server-side에만 저장하고 app/Git/log/evidence에 넣지 않는다. token과 account email을 출력하지 않는다. |

## Scope

1. Google Auth Platform의 existing branding/audience/client 상태를 먼저 읽고 중복 생성을 피한다.
2. dev Web OAuth client를 생성하거나 기존 exact client를 재사용한다.
3. callback URI는 Supabase dev project가 제시하는 exact callback만 등록한다.
4. Android OAuth client는 `me.newlines.kinflow.dev`와 current dev signing SHA-1만 등록한다.
5. Supabase Google provider에 Web-first Web/Android client ID 목록과 Web client secret을 server-side로 저장하고 nonce check를 완화하지 않는다.
6. app에는 Supabase URL/publishable key, Web client ID와 verified dev host 같은 public values만 ignored local config로 주입한다.
7. real Android login 성공 전에는 provider setup을 완료로 선언하지 않는다.

## Explicit Non-scope

- production Google/Supabase project, Play App Signing 또는 prod package client
- broad People API scopes, Firebase/`google-services.json`, service account 또는 service-role key
- actual adult account email/token의 evidence 저장
- two-adult invite acceptance는 provider/App Link verified 뒤 `4-3`에서 실행

## Inputs And Exact Bindings

- Google project: `kinflow-503900`
- Supabase project ref: `ghsniwhntbjofvslfxeq`
- Supabase callback: dashboard의 exact Google provider callback을 읽은 뒤 등록
- Android package: `me.newlines.kinflow.dev`
- dev signing SHA-1: `A2:12:1B:14:AA:68:34:21:B5:C5:81:B7:61:F1:B1:3C:AF:DC:24:8D`
- dev App Link signing SHA-256: `6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5`

## Validation

- Google Web client and Android client exist once with exact dev bindings
- Supabase Google provider enabled with Web-first Web/Android client audiences and secret stored only server-side
- `skip_nonce_check=false`
- ignored `config/dev.local.json` passes exact public config allowlist without printing values
- public `/auth/v1/settings` probe confirms Google enabled without printing the publishable key or response body
- pinned Flutter dev APK builds with real host and no additional Android permissions
- Android Google account chooser → Supabase session → protected route succeeds
- logout/account switch and invalid SHA/provider failure remain fail-closed
- full local quality/secret scan and remote CI for repository/evidence changes

## Stop / Rollback

- duplicate/unknown OAuth clients, unexpected callback, broad scope or wrong project/package/signing SHA가 보이면 mutation을 중단한다.
- secret/token/email이 tool output, Git, app config 또는 evidence에 나타나면 즉시 중단하고 credential을 rotate한다.
- rollback은 Supabase Google provider disable 후 이번 dev OAuth clients를 disable/delete하는 순서다. 외부 삭제는 별도 명시적 승인 없이 실행하지 않는다.
- DB schema/API migration은 없다.

## Completion Boundary

- dashboard 저장 성공만으로 완료하지 않는다. actual dev APK에서 Google identity exchange와 Supabase session을 확인해야 한다.
- owned verified App Link와 two-adult/two-device scenario는 별도 gate로 남는다.

## Current Result

- Google external testing audience, Web/Android OAuth clients와 운영자 테스트 사용자 1명을 구성했다.
- Supabase Google provider와 ignored dev public config를 구성하고 공개 settings probe, 실제-config APK build와 Android verified link를 통과했다.
- Google 로그인 버튼은 누르지 않았으므로 token exchange, Supabase session과 protected route는 다음 `4-2c` gate로 남는다.
- 상세 결과는 `WP02_01_DEV_PROVIDER_SETUP_EVIDENCE.md`에 기록한다.
