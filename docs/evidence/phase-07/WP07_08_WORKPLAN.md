# Phase 07 WP07-08 PII-safe Diagnostic Report Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — WP07 전체와 G7 완료는 아님
- 수직 조각: settings entry → local diagnostic snapshot → exact allowlist preview → explicit clipboard copy → new incident ID
- 요구사항: `FR-SET-007`, `NFR-PRIV-01`, `NFR-OBS-01`, `NFR-SEC-02`, `FR-PLAT-001`, `FR-PLAT-002`
- 완료 증거: `docs/evidence/phase-07/WP07_08_EVIDENCE.md`

## Product boundary

- 인증된 사용자가 지원 요청에 붙일 수 있는 로컬 진단 보고서를 생성하고 명시적으로 복사한다.
- 보고서 본문은 계정이나 서버 상태를 조회하지 않는다. DB migration, Edge/API 호출, analytics mutation과 background upload가 없다. 무작위 incident ID만 기존 PII-filtered observability가 구성된 경우 support correlation을 위해 기록될 수 있음을 UI에 알린다.
- incident ID는 보고서를 서로 구분하는 매 생성 단위 UUID v4이며 사용자·계정·가구 ID가 아니다.
- 화면을 다시 열거나 `새 사고 ID 만들기`를 실행하면 새 보고서를 만든다. 기존 ID를 영구 저장하지 않는다.
- 복사는 OS clipboard에만 쓰며 clipboard를 읽거나 자동으로 지원 링크에 첨부하지 않는다.

## Exact data contract

클립보드 JSON은 다음 9개 key만 이 순서로 포함한다.

1. `schemaVersion`
2. `applicationId`
3. `appVersion`
4. `buildNumber`
5. `environment`
6. `contractVersion`
7. `devicePlatform`
8. `incidentId`
9. `generatedAtUtc`

`appVersion`은 설치 package metadata의 version이고, `buildNumber`는 별도 숫자 문자열이다. configured `APP_VERSION`은 `version+buildNumber`와 정확히 일치해야 한다.

## Privacy and security boundary

- 허용: package/application ID, 앱 version, build number, dev/prod environment, API contract date, 거친 OS platform category, 무작위 incident UUID, UTC 생성 시각.
- 금지: user/account/household/member ID, 이메일·이름·프로필, chore/calendar/notification/billing content, access/refresh token, URL/query, IP/network, locale/timezone, device model/name/serial, advertising ID, signing hash, installer/store, install/update timestamp.
- platform은 `android`, `ios`, `web`, `macos`, `windows`, `linux`, `fuchsia`, `unknown` 중 하나이며 고유 기기 정보가 아니다.
- 외부 package metadata는 domain validator를 통과해야 한다. application ID 또는 configured version이 다르면 payload를 부분 생성하지 않고 `invalid metadata`로 fail closed한다.
- structured logger에는 보고서 본문을 보내지 않고 stable event와 allowlisted `request_id` incident UUID만 기록한다. logger 실패는 보고서 생성을 실패시키지 않는다.
- clipboard 실패/예외는 stable UI 상태로 매핑하고 raw exception이나 기존 clipboard 내용을 노출하지 않는다.

## Architecture and dependencies

- domain: exact report/value validation과 deterministic safe JSON serialization.
- application: single-flight load/refresh/copy controller와 provider-neutral app metadata, platform, incident recorder, clipboard ports.
- data: public config와 runtime metadata를 대조하는 repository, cryptographically secure UUID v4 generator, unavailable fallback.
- infrastructure: `package_info_plus` adapter, Flutter target-platform mapper, write-only system clipboard adapter, `AppLogger` incident recorder.
- composition: app-level diagnostic dependency factory가 concrete adapters를 만들고 bootstrap은 interfaces만 provider override한다.
- `package_info_plus 10.2.1`을 direct runtime dependency로 승격한다. 목적은 설치된 package name/version/build number의 authoritative read다. package는 BSD-3-Clause이고 Android/iOS/Web/desktop을 지원하며 새 runtime permission이나 network를 요구하지 않는다.
- `device_info_plus`는 기기 fingerprint 확대 위험 때문에 추가하지 않는다. 공개 `APP_VERSION`만 사용하는 대안은 실제 설치 build와 drift할 수 있어 채택하지 않는다.

## UI and accessibility

- 설정의 도움말 카드에 진단 정보 항목과 `/settings/diagnostics` route를 추가한다.
- 화면은 포함/제외 범위를 설명하고 schema version을 제외한 8개 진단 값을 표시한다. `schemaVersion`은 프로토콜 내부 값이므로 별도 사용자 행 대신 안내에 포함할 수 있다.
- loading/error/retry, copy in-progress/success/failure, refresh in-progress/failure 상태를 제공한다.
- 모든 mutation은 single-flight이며 busy 동안 duplicate tap을 무시한다. refresh 실패 시 이미 생성된 보고서를 유지한다.
- status는 accessibility live region, incident ID는 selectable text, 주요 action은 최소 48dp를 유지한다.
- EN/KO/EN-XA와 320×568의 200% text scale에서 scroll/overflow 0을 자동 검증한다.

## Automated evidence plan

1. domain exact key/order, UUID v4, UTC, app/build/config validation과 금지 key/value fixture
2. repository success, package read failure, config mismatch, invalid metadata, logger failure isolation
3. secure incident generator uniqueness/version/variant와 platform enum-only mapping
4. clipboard write-only success/false/throw mapping
5. controller initial load, retry, copy, duplicate suppression, refresh success/failure preservation
6. widget exact safe preview/copy payload, no identity/content labels, copy failure recovery, settings tile/route
7. EN/KO/EN-XA, 200% compact layout, live region과 48dp target
8. focused tests, full Flutter regression, analyzer, format, codegen, public config, secret scan, matrix/contract parse와 whitespace gate

## Manual and deferred evidence

- Android/iOS clipboard privacy prompt, TalkBack/VoiceOver announcement, physical-device package metadata와 support handoff는 마지막 실기기 Gate에서 검증한다.
- 실제 Sentry incident correlation, remote retention와 support 운영 절차는 승인된 계정/환경이 준비된 마지막 통합 Gate로 미룬다.
- clipboard lifetime/keyboard history 정책은 OS/키보드별로 다르므로 사용자가 붙여넣은 뒤 필요한 경우 clipboard를 지우도록 안내하며 자동 삭제나 기존 clipboard read는 하지 않는다.

## Rollback

- settings tile/route와 diagnostic feature files, app composition override를 제거하면 기존 설정 기능은 유지된다.
- `package_info_plus` direct dependency를 제거하면 Sentry의 transitive dependency 상태로 되돌아간다.
- DB/API/remote mutation과 persisted local data가 없으므로 data rollback은 없다.
