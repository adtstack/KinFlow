# ADR-0002 — Android 우선 단일 출시와 개인 운영 기준

- 상태: ACCEPTED
- 작성일: 2026-07-23
- 결정일: 2026-07-23
- 결정자: Product owner / Individual operator
- 관련 결정: D-001, D-002, D-021, D-032, D-037, D-038, D-051, D-052, D-053, D-054
- 대체 ADR: 없음
- 부분 대체 범위: 기존 문서의 iOS 동시 출시, staging 환경, 조직 계정 필수 기준

## Context

초기 운영자는 개인 한 명이고 현재 실제 검증 가능한 기기는 Android뿐이다. 성인 2인의 참여 가설을 검증하기 전에 iOS signing, macOS CI, APNs, Apple 심사와 staging 환경까지 동시에 운영하면 출시 surface가 제품 증거보다 커진다.

앱 식별자는 제품 책임자가 `me.newlines.kinflow`로 승인했다. 초기 로그인 방식은 성인 사용자의 Google 로그인으로 제한한다. 백엔드 권한의 기준은 기존 결정대로 Supabase Auth user와 PostgreSQL RLS이며, Google identity 자체를 household 권한 근거로 사용하지 않는다.

## Decision

1. 첫 Store MVP와 공개 출시는 Android만 대상으로 한다.
2. iOS/iPadOS는 삭제하지 않고 Android Beta와 초기 운영 증거를 검토한 뒤 별도 ADR로 재승인한다.
3. production application ID는 `me.newlines.kinflow`, dev application ID는 `me.newlines.kinflow.dev`로 고정한다.
4. 환경은 dev/prod 두 개만 운영한다. 별도 staging 대신 Google Play internal/closed testing track에서 production application ID의 release candidate를 검증한다.
5. 앱과 외부 콘솔의 accountable owner는 개인 운영자다. 계정 생성 여부와 접근 증거는 별도 수동 검증으로 남긴다.
6. 개인 운영 계정에는 passkey 또는 2단계 인증, 복구 수단, 별도 recovery code 보관을 출시 전 필수로 둔다.
7. 초기 인증 UI는 Google 로그인만 제공한다. 구현은 Supabase Auth Google provider와 native ID token 교환 방식으로 제한하고, 이메일 OTP와 다른 OAuth provider는 후속 결정까지 노출하지 않는다.
8. 제품 범위는 ADR-0001의 성인 2인 Activation slice를 유지한다. Managed Child, calendar, billing, Web은 기존 Gate 전 production OFF다.

## Environment Matrix

| 환경 | applicationId | 표시 이름 | 데이터/인증 | 배포 목적 |
|---|---|---|---|---|
| dev | `me.newlines.kinflow.dev` | KinFlow Dev | dev Supabase/Google project | 로컬·개발 기기 |
| prod | `me.newlines.kinflow` | KinFlow | prod Supabase/Google project | Play internal/closed/production |

dev와 prod는 Google OAuth client, Supabase project, signing 구성과 redirect 설정을 공유하지 않는다. 공개 client identifier는 환경 설정에 둘 수 있지만 client secret, service role key와 signing secret은 앱 bundle과 저장소에 넣지 않는다.

## Consequences

### Positive

- 보유한 Android 실기기로 가장 빠르게 반복 검증할 수 있다.
- iOS/APNs/macOS CI와 staging 운영 비용을 성인 2인 가치 증거 이후로 미룬다.
- production package name과 dev package name이 분리되어 데이터·인증 혼선을 줄인다.

### Negative / Debt

- iOS 수요와 플랫폼 차이는 첫 출시에서 검증하지 못한다.
- 별도 staging 백엔드가 없어 prod 후보 검증은 Play track, feature flag, test account 규율에 더 의존한다.
- 운영자 개인 계정의 복구 불능이 단일 장애점이므로 2단계 인증과 복구 증거가 필수다.
- 2023-11-13 이후 생성한 신규 개인 Play 계정은 production 접근 전 최소 12명이 14일 연속 참여하는 closed test와 실기기 인증이 필요할 수 있다.

## Implementation

- Phase 01 WP01-01은 Android platform만 생성한다.
- Dart entrypoint와 Android product flavor는 dev/prod만 둔다.
- iOS, APNs, Apple login, Apple billing과 staging용 파일을 현재 scaffold에 생성하지 않는다.
- Google 로그인 SDK와 provider 연결은 Phase 02에서 repository/adapter 경계 안에 구현한다.
- G0 전체 통과 전에는 로컬의 가역적인 foundation 작업만 허용한다. production console, 실제 사용자 데이터와 production provider 연결은 만들지 않는다.

## Validation

- dev/prod application ID가 서로 다르고 승인된 값과 일치하는지 Gradle artifact에서 확인한다.
- Flutter SDK 3.44.7/Dart 3.12.2로 analyze/test와 두 flavor Android build를 실행한다.
- Android 실기기에서 dev install/boot를 확인한다.
- Phase 02에서 dev/prod Google OAuth client, SHA-1/SHA-256, Supabase provider와 로그인/로그아웃/session purge를 검증한다.

## Release Gate

- 개인 Play 계정 생성일과 production access 상태 확인
- 신규 개인 계정이면 12명 이상이 14일 연속 참여하는 closed test 완료
- Play Console 모바일 앱을 통한 Android 실기기 접근 인증 완료
- 계정 2단계 인증과 복구 수단 확인
- production signing key의 복구 가능한 백업 확인

공식 정책 확인일 2026-07-23:

- <https://support.google.com/googleplay/android-developer/answer/14151465>
- <https://support.google.com/googleplay/android-developer/answer/14316361>
- <https://support.google.com/googleplay/android-developer/answer/13634885>
- <https://supabase.com/docs/guides/auth/social-login/auth-google?platform=android>

## Rollback / Revisit Trigger

- Android Beta에서 iOS 요청이 유의미하거나 Android 단일 플랫폼이 모집을 막으면 iOS 재도입 ADR을 작성한다.
- dev/prod만으로 release candidate 격리가 부족하면 staging 추가 ADR을 작성한다.
- 앱이 사업체 운영으로 전환되면 Google Play와 provider 계정 이전 계획을 별도 승인한다.
- production application ID를 Play Console에 등록한 뒤에는 이름 변경처럼 취급하지 않고 migration/이전 계획 없이는 교체하지 않는다.
