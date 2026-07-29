# Phase 02 WP02-01 Two-Device Preflight Work Plan

- 작성일: 2026-07-29
- 기준 commit: `64f95ac`
- Work Package: WP02-01 — real dev Google Android / two-adult manual gate
- 상태: IMPLEMENTED — LOCAL AUTOMATED PASS / LIVE TWO-DEVICE PENDING
- 선행 결과: dev Pages/App Link verified, Google/Supabase provider configured, actual-config dev APK built

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-01 / Phase 02 manual gate | 서로 다른 Android 기기 2대가 실제 dev package, 현재 signing certificate와 verified HTTPS App Link를 갖췄는지 계정 상호작용 전에 검사한다. |
| FR-AUTH-003 / FR-AUTH-004 | Google 로그인 검증에 들어갈 기기마다 Android API와 package 설치 상태가 지원 범위인지 fail-closed 한다. |
| FR-AUTH-005 / D-049 | 이후 logout/account-switch 검증이 서로 다른 두 기기에서 실행된다는 전제를 명시적으로 고정한다. |
| Security / Privacy | ADB serial, Google 이메일, token, invite token과 raw command output을 evidence 또는 실패 메시지에 노출하지 않는다. |

## Scope

1. 호출자가 ADB serial 2개를 명시해야 하며 같은 serial, 빈 값과 안전하지 않은 형식은 실행 전에 거부한다.
2. 각 기기에서 `get-state`, boot completion, Android API, package install, `pm get-app-links`만 읽는다.
3. Android API 24 이상, `me.newlines.kinflow.dev` 설치, 현재 dev signer SHA-256과 `adtstack.github.io: verified`를 exact 검사한다.
4. 출력에는 `Device A` / `Device B`, API와 boolean 결과만 남기고 serial 및 ADB raw output을 출력하지 않는다.
5. parser, command boundary, 같은 기기 거부, offline/unbooted/미설치/wrong signer/unverified host를 repository self-test로 고정한다.
6. 실제 두 기기가 연결되기 전에는 reusable preflight 구현만 PASS로 선언하고 manual E2E를 완료 처리하지 않는다.

## Explicit Non-scope

- 기기 연결, APK 설치, App Link 재검증 또는 앱 데이터 변경
- Google 로그인 버튼 클릭, 계정 선택, Supabase session 발급
- household 생성, 실제 invite 발급/수락, logout/account switch
- production package, Play App Signing과 prod provider 검증
- ADB serial, 실제 이메일, token, invite URL 또는 raw command output의 evidence 저장

## Interface

```bash
node scripts/ci/android-two-device-preflight.mjs \
  <device-a-serial> \
  <device-b-serial> \
  me.newlines.kinflow.dev \
  adtstack.github.io \
  6A:C5:22:6C:F7:1B:20:1C:99:49:E8:1F:75:14:49:AD:94:53:64:A9:46:5C:ED:0C:69:19:00:51:C5:6E:C7:D5
```

`KINFLOW_ADB_BIN`은 Android SDK의 exact `adb` executable을 지정할 때만 사용한다. CLI 결과와 evidence에는 그 경로나 serial을 기록하지 않는다.

## Validation

- `node --test scripts/ci/android-two-device-preflight.test.mjs`
- `npm run ci:test`
- `npm run ci:workflow`
- repository secret scan
- 실제 두 기기 연결 시 위 명령 PASS 후 `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`의 account/session/invite 시나리오 실행

## Stop / Rollback

- 동일 기기, API 24 미만, offline/unbooted, package 미설치, signer 불일치 또는 host가 `verified`가 아니면 로그인 단계로 진행하지 않는다.
- raw output에 민감정보가 포함될 가능성이 있으므로 subprocess stderr/stdout은 성공 판정에만 사용하고 실패 시 재출력하지 않는다.
- 구현 rollback은 preflight script/test와 runbook/evidence 변경을 함께 revert한다. DB/API/remote provider rollback은 없다.

## Completion Boundary

- 자동 테스트와 한 기기/emulator의 기존 verified 결과는 두 성인·두 기기 E2E를 대체하지 않는다.
- 두 개의 서로 다른 실제 ADB target에서 preflight가 통과하고 Google login, Supabase session, invite continuation/accept, cold restore와 account-switch purge까지 확인해야 WP02-01 전체를 완료할 수 있다.

## Current Result

- read-only two-device preflight와 parser/command/privacy contract 테스트를 구현했다.
- repository self-test 31개, workflow contract와 high-confidence secret scan이 통과했다.
- implementation commit `148b02c`의 GitHub Actions run `30414815240`에서 모든 job과 final gate가 통과했다.
- 검증 시점 online ADB target은 0대이므로 live two-device preflight와 계정/session/invite E2E는 실행하지 않았다.
- 상세 결과는 `WP02_01_TWO_DEVICE_PREFLIGHT_EVIDENCE.md`에 기록한다.
