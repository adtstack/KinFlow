# Phase 00 Technical PoC Evidence

- 검증일: 2026-07-23
- 검증 환경: macOS 26.4.1 arm64
- 저장소 commit: `329a1b5`
- 검증자: Codex local audit
- 결과: PARTIAL

## Toolchain inventory

| 항목 | 요구 기준 | 확인 결과 | 판정 |
|---|---|---|---|
| Flutter | 3.44.7 stable | 공용 SDK는 3.32.8/Dart 3.8.1; 격리 SDK tag `84fc5cbb`는 Flutter 3.44.7/Dart 3.12.2 | PARTIAL — project pin 필요 |
| Xcode | 26+ / iOS 26 SDK | Xcode 26.6 build 17F113 | PASS |
| iOS runtime | iOS simulator 또는 실제 기기 | 설치된 Simulator runtime 0, CocoaPods 없음 | BLOCKED |
| Android | SDK 36, API 24+ | SDK 36.0.0, build-tools 36.0.0, license accepted | PASS |
| Android runtime | emulator 또는 실제 기기 | AVD 0, 연결 기기 0 | BLOCKED |
| Java | Android toolchain 호환 | Android Studio JBR 21.0.9 | PASS |
| Node | Edge tooling | Node 22.14.0, npm 11.4.0 | PASS FOR POC |
| Deno | Edge Functions | 미설치 | BLOCKED FOR EDGE POC |
| Supabase CLI | local stack | 전역 미설치; 격리 npm cache로 CLI 2.109.1 실행 확인 | PARTIAL |
| Docker | local Supabase/Postgres | Docker Desktop 4.44.3, Engine 28.3.2 | PASS |

## PoC 결과

| PoC | 절차 | 결과 | Evidence/차단 이유 |
|---|---|---|---|
| Flutter iOS boot | Flutter 3.44.7 + iOS runtime | NOT RUN | Simulator runtime/CocoaPods/실제 기기 없음 |
| Flutter Android scaffold | Flutter 3.44.7 `flutter create` + `flutter test` | PASS | scaffold 생성, 기본 widget test 1/1 통과 |
| Flutter Android build | Flutter 3.44.7 `flutter build apk --debug` | TIMEOUT | 약 10분간 Gradle/Kotlin DSL 초기 구성 후 APK 미생성; 프로세스 정상 종료 |
| Flutter Android boot | Flutter 3.44.7 + Android runtime | NOT RUN | AVD/실제 기기 없음 |
| Supabase auth callback deep link | 실제 auth project + app link | NOT RUN | identifier/domain/auth project 미결정 |
| Firebase notification | dev Firebase + 실제 기기 | NOT RUN | Firebase project/APNs key/실제 기기 없음 |
| RevenueCat catalog | sandbox offering 조회 | NOT RUN | Store/RevenueCat project와 SKU 없음 |
| Household RLS isolation | PostgreSQL 16 일회용 container에서 동일/교차 household 조회와 직접 쓰기 검증 | PASS | `poc/phase-00/rls_household_isolation.sql` |

## RLS test command

```text
docker run --rm --name kinflow-phase00-rls \
  -e POSTGRES_PASSWORD=<ephemeral-test-value> \
  -v <repo>/poc/phase-00/rls_household_isolation.sql:/poc.sql:ro \
  -d postgres:16-alpine

docker exec -e PGPASSWORD=<ephemeral-test-value> kinflow-phase00-rls \
  psql -v ON_ERROR_STOP=1 -U postgres -f /poc.sql
```

결과:

```text
PASS: household RLS isolation and direct-write denial
ROLLBACK
```

검증한 최소 불변조건:

- User A는 Household A 하나와 같은 가구 구성원 2명만 조회한다.
- User A에게 Household B가 노출되지 않는다.
- removed member는 가구를 조회하지 못한다.
- authenticated role은 direct insert 권한이 없다.

이 PoC는 전체 Supabase/JWT/RLS matrix를 대신하지 않는다. Phase 01에서 실제 schema extraction, Supabase local reset, pgTAP/RLS authorization matrix를 실행해야 한다.

## 공식 기준 확인

- Flutter 3.44.7 verified tag: <https://github.com/flutter/flutter/releases/tag/3.44.7>
- Flutter docs 3.44.7 baseline: <https://docs.flutter.dev/release>
- Apple Xcode 26/iOS 26 SDK 제출 기준: <https://developer.apple.com/news/upcoming-requirements/>
- Google Play API 36 제출 기준: <https://support.google.com/googleplay/android-developer/answer/11926878>

## Safe next actions

1. 사용자의 공용 Flutter SDK를 직접 업그레이드하지 말고 Phase 01에서 프로젝트 단위 exact pin을 구성한다.
2. iOS 26 Simulator runtime과 CocoaPods를 설치하고 대표 iOS 기기 1대를 준비한다.
3. Android API 24 또는 저사양 대표 AVD와 실제 기기 1대를 준비한다.
4. legal entity/domain/identifier 승인 후 dev Supabase/Firebase/RevenueCat project를 만든다.
5. 각 provider PoC는 production secret 없이 dev/sandbox에서 실행한다.
6. Android build는 Phase 01의 고정 Gradle/JDK/네트워크 조건에서 상세 로그와 함께 재실행한다. 이번 timeout만으로 Flutter 3.44.7 호환 실패라고 판정하지 않는다.

## Rollback

- RLS 컨테이너는 `--rm`으로 중지 후 자동 제거했다.
- 격리 Flutter SDK, scaffold, npm cache 약 1.4GB는 evidence 작성 후 `/private/tmp`에서 삭제했다.
- 사용자의 공용 Flutter SDK는 변경하지 않았다. Android 시도 과정에서 공유 Gradle dependency cache에는 다운로드 항목이 추가됐을 수 있다.
- 실제 provider project, token, SKU, 사용자 데이터는 생성하지 않았다.
