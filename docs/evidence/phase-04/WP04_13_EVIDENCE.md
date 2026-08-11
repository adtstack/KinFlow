# Phase 04 WP04-13 External Calendar File Import Evidence

- Work Package: WP04-13 — Android external iCalendar file import
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / DOCUMENT-PROVIDER·HOSTED·REAL-ACCOUNT·MULTI-DEVICE·PHYSICAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-CAL-009 | PASS FOR LOCAL AUTOMATED SLICE | Android SAF `.ics` 선택, strict bounded parse, 일정별 preview/선택, active-household participant와 기존 Calendar create 경로를 연결했다. |
| FR-CAL-001 / FR-CAL-002 | PASS FOR IMPORTED ONE-TIME SUBSET | one-time timed/all-day candidate는 existing strict draft와 idempotent create contract로만 복사한다. |
| FR-CAL-003 / FR-CAL-004 | PASS FOR IMPORTED RECURRENCE SUBSET | daily/weekly/monthly interval/count와 all-day until을 canonical recurrence object로 만든 뒤 existing recurring create contract를 사용한다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR LOCAL BOUNDARY | file URI는 native 밖으로 나오지 않고 source·display name·UID는 process-memory 전용이며 URL·attachment·alarm을 열거나 실행하지 않는다. |
| NFR-REL-01 | PASS FOR CLIENT COMMAND BOUNDARY | 선택 전체의 command ID를 첫 write 전에 freeze하고 preview 순서로 실행하며 첫 실패 뒤 같은 key로 재시도한다. disposal/auth-context invalidation은 다음 write 전에 중단한다. |
| NFR-A11Y-01 | PASS FOR LOCAL AUTOMATION | 48dp checkbox/button, progress/error live region, scrollable review와 320×568 EN-XA 200% 흐름이 blocker overflow 없이 통과했다. |
| NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | 모든 copy/error/disclosure/progress를 EN/KO/expanded EN-XA ARB로 제공하고 exact coverage와 30% pseudo expansion을 통과했다. |
| D-059 / CAP-019 | PASS FOR ANDROID LOCAL SLICE | provider account·calendar permission·broad storage permission·persistent UID mapping·sync 없이 explicit file copy만 추가했다. |

이 결과는 사용자 지시에 따라 기능을 테스트 가능한 수준으로 만든 local automated
slice에 한정한다. 실제 Android document provider, hosted Supabase, 실제 계정, 두 기기와
physical-device 검증은 마지막 통합 Gate이며 WP04/G4 또는 release 완료 근거가 아니다.

## Product and Import Behavior

- Calendar 화면의 별도 import action이 typed `/calendar/import` context로 현재 active
  household와 timezone을 고정한다. route는 active household가 다르면 Calendar로 닫힌다.
- Android `ACTION_OPEN_DOCUMENT`에서 사용자가 직접 고른 `.ics`만 읽는다. native는
  strict UTF-8, 262,144 bytes와 safe `.ics` display name을 검사하고 Dart에는
  `status`, `displayName`, `content`만 반환한다.
- parser는 exactly one `VCALENDAR`, exactly one `VERSION:2.0`, 최대 50 `VEVENT`를
  요구한다. fatal structure/encoding/size/count 오류는 파일 전체를 거부한다.
- supported candidate는 기본 전체 선택, participant는 현재 adult member만 기본
  선택한다. 사용자는 일정과 공통 active-household participant를 명시적으로 바꾼다.
- 선택한 one-time/recurring candidate는 existing repository/RPC request로 순차 복사한다.
  성공한 일정은 authoritative하게 남고 첫 실패에서 멈추며 live batch retry는 실패한
  command ID부터 재사용한다.
- import는 sync가 아니다. source 변경·삭제가 전파되지 않고 같은 파일을 다시 가져오면
  새 복사본이 생길 수 있음을 선택 전과 preview에서 표시한다.
- active write 중 close/system back을 막는다. route/controller가 dispose되거나 auth/context가
  사라지면 이미 시작한 한 write 이후 다음 command I/O는 수행하지 않는다.

## RFC, Time, and Failure Boundary

- RFC 5545 content-line CRLF/LF, SPACE/HTAB folding과 TEXT `\\`, `\n`, `\,`, `\;`
  unescape를 지원한다.
- all-day `DATE`는 exclusive `DTEND`, absent one-day default 또는 positive whole-day/week
  `DURATION`을 사용하며 supported year `0001..9999` 밖으로 넘지 않는다.
- timed 값은 seconds `00`만 허용한다. UTC `Z`, household-zone floating time과 bundled
  exact IANA `TZID`를 existing `CalendarTimeResolver`로 검증한다.
- `DTEND` duration은 두 resolved instant 차이다. RFC day/week duration은 local calendar
  day를 먼저 더하고 hour/minute를 exact하게 더해 DST 변화에서도 의미를 보존한다.
  gap은 skip, overlap은 existing `earlier` policy와 preview disclosure를 사용한다.
- arbitrary-length duration 숫자는 bounded `tryParse`로 거부하며 9999 year overflow도
  exception이나 값 coercion 없이 일정 단위 unsupported로 처리한다.
- recurrence는 daily/weekly/monthly, interval `1..30`, count `1..1000`, all-day date until,
  unique unnumbered weekly BYDAY와 DTSTART-anchored monthly BYMONTHDAY만 허용한다.
- exception, custom VTIMEZONE, yearly/ordinal/broader RRULE과 mismatched value/zone은
  source를 변경하지 않고 aggregate invalid/unsupported/duplicate 수로만 표시한다.
- within-file UID는 duplicate 확인에만 쓰고 candidate 전에 폐기한다. location, URL,
  organizer, attendee, attachment, alarm과 unknown display-only property는 복사·열기·실행하지 않는다.

Normative exchange-format semantics are based on
`https://www.rfc-editor.org/rfc/rfc5545`; KinFlow deliberately accepts only the
documented bounded subset.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused parser/controller/MethodChannel suite | PASS, 23 tests |
| parser RFC folding/TEXT, DATE/DATE-TIME, UTC/floating/TZID and exact recurrence | PASS |
| DST fall-back instant duration, nominal spring-forward day duration, gap skip and overlap disclosure | PASS |
| oversized numeric duration, date overflow, malformed structure/version, 256 KiB and 50-event bounds | PASS |
| controller selection/participant/order/empty guards, picker/mid-batch policy races, first-failure same-key retry and dispose stop | PASS |
| MethodChannel exact result map, cancellation/unavailable/size/error, `.ics` name and no-URI fail-closed mapping | PASS |
| Calendar widget regression | PASS, 23 tests; import review/success, partial retry and runtime-policy I/O block included |
| compact accessibility | PASS, import review at 320×568 EN-XA 200% with no overflow |
| localization contract | PASS, 4/4 exact key, pseudo expansion, locale and ICU checks |
| architecture/runtime-policy guards | PASS within full Flutter regression |
| full Flutter regression | PASS, 1,303 tests + existing local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 699 Dart files / changed 0 |
| localization/codegen drift | PASS, build runner wrote 0 outputs; 8 generated files current |
| Node contract suite | PASS, 141/141 |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| contract and matrix parse | PASS, contract 12 root keys; 13 matrices; requirements 118×18; tests 88×11; time 38×12 |
| Android dev debug APK | PASS, `assembleDevDebug` 25.3s; `build/app/outputs/flutter-apk/app-dev-debug.apk` |
| merged Android permission surface | PASS, no READ/WRITE_CALENDAR or broad storage permission; only existing network/billing/notification/biometric/FCM permissions |
| whitespace | PASS, `git diff --check` output 0 |
| database/Edge regression | **NOT RUN BY DESIGN**; DB/API/RLS/Edge source와 signature 변경 없음 |

실행한 핵심 명령은 다음과 같다.

```text
flutter gen-l10n
flutter test test/features/calendar/icalendar_import_parser_test.dart test/features/calendar/calendar_import_controller_test.dart test/infrastructure/calendar/method_channel_calendar_import_file_gateway_test.dart
flutter test test/features/calendar/calendar_events_widget_test.dart
flutter test --reporter failures-only
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
npm run ci:test
flutter build apk --debug --no-pub --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.example.json
git diff --check
```

모든 Flutter/Dart 명령은 `/private/tmp/kinflow-flutter-exact-3.44.7` exact SDK로
실행했다. APK compile은 성공했으나 `purchases_flutter`와 `sentry_flutter`의 future
Built-in Kotlin migration warning은 기존 dependency hardening 항목으로 남아 있다.

## Files and Data Impact

- Contract/tracking: D-059, FR-CAL-009, `calendar-file-import.yaml.md`, Phase 04,
  requirement/test/platform/release matrices, work plan과 이 evidence
- Domain/application: `calendar_import.dart`, `icalendar_import_parser.dart`,
  `calendar_import_state.dart`, `calendar_import_controller.dart`, file gateway port
- Infrastructure/native: `method_channel_calendar_import_file_gateway.dart`,
  Android `MainActivity.kt` SAF channel과 bootstrap dependency composition
- Presentation: import route context/screen/provider, Calendar import action와 success refresh
- Localization/tests: EN/KO/EN-XA ARB/generated files, parser/controller/gateway/widget/runtime and
  architecture coverage

새 migration, table, index, RLS, RPC/Edge signature, package dependency, analytics event,
persistent cache, calendar permission 또는 broad storage permission을 추가하지 않았다.
server data rollback이나 migration rollback은 필요하지 않다.

## Security, Privacy, and Authority

- native `content://` URI는 일시적으로 stream을 여는 데만 쓰고 MethodChannel payload에
  넣지 않는다. persistable URI permission도 요청하지 않는다.
- raw file, display name와 UID를 log, analytics, disk/cache, secure storage, database,
  command metadata 또는 error string에 저장하지 않는다.
- source URL, attachment, alarm, organizer나 provider callback은 실행하지 않는다.
- runtime Calendar policy를 picker, parser, command ID와 repository보다 먼저 검사한다.
- client parse와 preview는 UX preflight다. existing server household membership,
  participant, timezone, recurrence와 idempotency validation이 최종 authority다.
- 자동 검증은 synthetic `.ics`, fake household/member와 fake repository만 사용했고
  production project, 실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- physical Android의 Files/Drive 등 실제 document provider에서 CRLF/LF·UTF-8 `.ics` 선택,
  취소, provider read failure와 실제 MIME/display-name 변형
- hosted Supabase + 실제 성인 계정으로 one-time/all-day/recurring create와 server rejection 복구
- import 중 process kill, activity recreation, logout/household switch와 이미 성공한 partial batch 확인
- 같은 파일 재가져오기, 두 기기 동시 import와 duplicate-copy 이해도
- 실제 Asia/Seoul·America/New_York DST 파일과 device timezone travel
- TalkBack focus/announcement, 실제 font 200%, phone/tablet/split layout
- production-like signed release build와 Store Data Safety/permission inspection

## Remaining Risks and Completion Boundary

1. 실제 document provider가 MIME·display name·stream behavior를 다르게 제공하는 호환성은
   physical-device 검증 전까지 완료 근거가 아니다.
2. custom `VTIMEZONE`, timed `UNTIL`, exception, yearly/ordinal/business-day recurrence와
   broader RFC grammar는 의도적으로 skip한다.
3. persistent source UID mapping과 sync가 없으므로 앱 재시작 뒤 partial batch나 재가져오기의
   cross-session duplicate를 자동 제거하지 않는다.
4. process death resume는 external family content를 disk에 보존하지 않기 위해 지원하지 않는다.
5. iOS/Web picker는 deferred이며 Android release가 첫 공식 platform이다.
6. 따라서 WP04-13 local automated slice만 완료하며 Phase 04, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- Calendar import action/route, provider/controller/parser, gateway composition과 Android
  MethodChannel handler를 함께 제거하면 기존 수동 Calendar 생성만 남는다.
- no-op unavailable gateway는 configuration failure의 fail-closed fallback으로 유지할 수 있다.
- DB/API 변경이 없어 migration, data backfill 또는 server deployment rollback은 없다.

## Next Entry Condition

- 다음 기능 우선순위는 canonical requirement/test/platform matrices의 남은 P1 가치를 다시
  점검해 독립적인 다음 수직 조각으로 선택한다.
- 실제 계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발이 충분히 진행된
  뒤 마지막 통합 Gate에 계속 유지한다.
