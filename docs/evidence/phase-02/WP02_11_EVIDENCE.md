# Phase 02 WP02-11 Privacy-safe Invite Sharing Evidence

## Result

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- 기준 commit: base a85f262, implementation은 현재 workspace
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0
- 사용자 기능: 생성된 일회용 성인 초대를 Android 기본 공유 선택기로 보내고, 공유가 불가능할 때 사용자가 명시적으로 링크 또는 짧은 코드를 복사해 복구할 수 있다.
- 완료 경계: 로컬 기능과 자동 검증은 통과했다. 실제 계정, recipient 전달, verified App Link, 실기기와 iOS 공유는 마지막 통합 Gate까지 보류한다.

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-11 | PASS FOR LOCAL AUTOMATED SLICE | one-time invite 결과에서 Android native chooser와 explicit clipboard recovery까지 연결했다. |
| FR-HH-003 | PARTIAL | exact configured HTTPS invite link 생성, native 재검증, 공유와 revoke 동시 실행 방지 및 raw credential 비저장을 자동 검증했다. 실제 recipient 전달과 verified App Link는 남아 있다. |
| FR-HH-004 | PARTIAL | formatted short code와 링크를 provider-neutral write-only clipboard port로 명시적 복사하며 실패 후 재시도를 자동 검증했다. 실기기 clipboard와 keyboard forensic은 남아 있다. |
| CAP-002 / CAP-016 | PARTIAL | Android ACTION_SEND text/plain chooser와 explicit copy fallback은 구현했다. Android 실기기와 iOS native share는 보류한다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR LOCAL SLICE | arbitrary URL, query, fragment, userinfo, port, provider error 노출, 자동 복사와 persistent credential 보존을 차단했다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL WIDGETS | EN, KO, EN-XA와 320×568, 200% text, 48dp action, live-region 결과를 검증했다. |

## Implemented boundary

### Canonical invite link

- HouseholdInviteLink는 configured DNS 또는 localhost host와 기존 InviteToken만 받아 exact HTTPS /invite/{token} 값을 만든다.
- whitespace, custom scheme, query, fragment, userinfo, explicit port와 malformed host를 거부한다.
- diagnostic string은 redacted이며 raw link와 token은 controller state, log, analytics, DB, cache 또는 route query에 보존하지 않는다.

### Provider-neutral share and copy

- HouseholdInviteShareGateway는 opened, unavailable, failed만 노출한다. opened는 chooser handoff만 뜻하며 전달이나 수락을 성공으로 주장하지 않는다.
- HouseholdInviteClipboard는 link 또는 formatted short code를 쓰기만 하며 기존 clipboard를 읽지 않는다.
- controller는 share, link copy, code copy 전체를 하나의 single-flight 경계로 묶고 provider exception을 stable outcome으로 축약한다.
- share failure 뒤 자동 copy는 수행하지 않는다. 사용자가 별도 action을 눌러야만 clipboard가 변경된다.

### Android native boundary

- MainActivity의 me.newlines.kinflow/invite_sharing MethodChannel은 openInviteShareSheet만 허용한다.
- Android string resource의 configured host와 exact HTTPS two-segment invite path를 다시 검증하고 canonical reconstruction이 원문과 같을 때만 진행한다.
- ACTION_SEND, text/plain, EXTRA_TEXT의 URL 하나만 Intent.createChooser로 넘긴다. subject, stream, email, 설치 앱 목록과 새 permission은 추가하지 않았다.
- startActivity handoff 성공만 true로 반환하며 RuntimeException과 unavailable 상태는 raw detail 없이 false 또는 stable Dart result로 축약한다.

### UI, localization, and recovery

- 초대 생성 화면은 Share link, Copy link, code copy를 provider-neutral controller로 실행한다.
- 실행 중 share, copy, revoke를 함께 잠그고 action별 progress와 localized live-region 결과를 제공한다.
- clipboard retention 안내를 항상 보이며, share가 열려도 delivery 확인이 불가능하다는 점을 명시한다.
- unavailable 또는 failed share는 manual Copy link를 안내하고 copy failure 뒤 같은 action으로 재시도할 수 있다.

## Automated evidence

### Focused and impact Flutter tests

- invite link, controller, infrastructure, composition, Android source contract와 widget focused set: **29 passed**
- 최종 localization plus invite widget smoke: **17 passed**
- household, bootstrap와 architecture impact set: **161 passed**
- 주요 증명:
  - exact URL 생성, invalid host 거부와 diagnostic redaction
  - exact MethodChannel method와 arguments, opened/unavailable/failed mapping
  - explicit write-only clipboard, no automatic copy, failure retry와 shared single-flight
  - chooser-opened 상태에서 delivery claim과 clipboard write 없음
  - KO failure recovery와 EN-XA compact 200% scroll 및 48dp action

### Full local regression

- Flutter full suite: **1,121 passed + 1 explicit live opt-in skipped, 0 failed**
- Flutter analyzer with fatal infos and warnings: **0 issues**
- Dart format gate: **649 files checked, 0 changed**
- generated code drift: **8 files checked, 0 outputs, passed**
- Android Kotlin compile, dev debug with lib/main_dev.dart: **BUILD SUCCESSFUL, 138 tasks**
- root npm run ci:test: **141 passed, 0 failed, 0 skipped**
- CI workflow and supply-chain contract: **5 jobs, 17 pinned action uses, passed**
- public configuration allowlist: **passed**
- high-confidence secret scan: **passed**

### Contract and documentation gates

- embedded invite-sharing YAML: **valid**
- Markdown code fences: **balanced**
- CSV matrices: requirements **116×18**, platform capabilities **20×12**, test matrix **81×11**
- repository diff whitespace/error marker check: **passed**
- traceability updated in Phase 02, contract index, changelog, requirements, platform-capability and test matrices.

## Security and privacy evidence

1. Dart와 Android가 동일한 configured host, HTTPS, exact path와 token 형태를 독립적으로 검증한다.
2. arbitrary URL, query, fragment, userinfo, explicit port와 encoding-based canonical drift는 native share 전에 fail closed한다.
3. raw invite link와 code는 사용자 gesture 뒤 OS share 또는 clipboard에 전달되는 순간 외에는 새 상태나 저장소에 추가되지 않는다.
4. provider exception, installed share target와 clipboard content는 읽거나 UI와 log에 반영하지 않는다.
5. share failure가 clipboard mutation을 유발하지 않아 credential 복사는 항상 사용자에게 명시적이다.
6. 새 SDK, runtime dependency, Android permission, DB, API, RPC, Edge Function와 persistent schema 변경은 없다.

## Manual and deferred evidence

- 실제 Android share sheet의 앱 목록, cancel, back, resume와 OEM 차이
- 실제 recipient 전달 뒤 owned-domain verified App Link의 cold 및 warm open
- 실제 계정, 성인 2인, 다중기기와 revoke 또는 accept 경쟁
- Android clipboard 및 keyboard retention forensic
- iOS native share implementation과 VoiceOver 또는 TalkBack 실기기 점검

사용자 지시에 따라 위 live 검증은 가장 마지막 통합 Gate에서 수행한다. 따라서 CAP-002, CAP-016과 관련 요구사항을 전체 완료로 전환하지 않는다.

## Rollback

- Dart share controller, ports, providers와 Android MethodChannel handler를 제거하면 기존 invite creation, code 표시와 revoke 흐름으로 돌아간다.
- native share만 중단해야 하면 unavailable gateway로 fail closed하고 명시적 clipboard fallback은 독립적으로 유지할 수 있다.
- DB, API, storage, dependency와 permission 변경이 없으므로 migration, backfill, data cleanup 또는 provider rollback은 필요 없다.

## Next entry condition

- 다음 Store-MVP local 기능 slice는 남은 PARTIAL 요구사항 중 실계정이나 Store 검증에 의존하지 않는 항목을 우선 계약화해 진행한다.
- hosted, real-account, Store, multi-device와 physical-device 검증은 마지막 통합 Gate에 유지한다.
