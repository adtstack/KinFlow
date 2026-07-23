# Phase 00 Manual Setup Status

- 점검일: 2026-07-23
- 점검 범위: 저장소와 로컬 개발 환경
- 주의: 외부 console을 열거나 계정 존재를 가정하지 않았다. 저장소에서 증명되지 않은 항목은 `UNVERIFIED`다.

## Organization and ownership

| 항목 | 상태 | 필요한 증거 |
|---|---|---|
| 법적 운영 주체 | ACCEPTED — 개인 운영자 | Product owner 결정 2026-07-23 |
| Apple Developer/App Store Connect | DEFERRED | iOS 재도입 ADR 전 생성 불필요 |
| Google Play Console | OWNER DECIDED / ACCESS UNVERIFIED | 개인 account owner, 생성일, production access, 2FA/recovery 증거 |
| Supabase organization | OWNER DECIDED / ACCESS UNVERIFIED | 개인 owner와 billing/recovery 증거 |
| Firebase/Google Cloud | OWNER DECIDED / ACCESS UNVERIFIED | 개인 project owner, OAuth consent/client, billing/2FA 증거 |
| RevenueCat | DEFERRED | Phase 06 Android billing 승인 시 project owner 확인 |
| GitHub organization | OWNER DECIDED / ACCESS UNVERIFIED | 개인 owner, 2FA/recovery, protected branch/environments |
| domain/DNS/support email | UNVERIFIED | registrar owner, domain, support mailbox |

## App identity

| 항목 | 상태 | 차단 영향 |
|---|---|---|
| 최종 제품명/상표 검색 | OPEN | Store metadata와 domain |
| iOS Bundle ID | DEFERRED | iOS 재도입 ADR 전 불필요 |
| Android applicationId | ACCEPTED | prod `me.newlines.kinflow`; dev `me.newlines.kinflow.dev` |
| Universal/App Links domain | OPEN | auth/invite cold-start PoC |

## Local technical readiness

| 항목 | 상태 | 확인 결과 |
|---|---|---|
| Flutter 3.44.7 | PASS | `.fvmrc`, `contracts/toolchain.json`, app `pubspec.lock`; 격리 SDK로 3.44.7/Dart 3.12.2 build PASS |
| Xcode 26+ | PASS | Xcode 26.6 |
| iOS Simulator | BLOCKED | 설치 runtime 0 |
| CocoaPods | BLOCKED | 미설치 |
| Android SDK 36 | PASS | platform/build-tools 36.0.0 |
| Android NDK | PASS | 손상된 28.2를 보존 이동 후 공식 sdkmanager로 재설치; production dev/prod build PASS |
| Android AVD/device | PARTIAL | Product owner가 Android 실기기 보유 확인; ADB 연결·boot 증거는 아직 없음 |
| Docker | PASS | Engine 28.3.2 |
| Supabase CLI | PARTIAL | 임시 npm cache로 2.109.1 확인; project pin 없음 |
| Deno | BLOCKED | 미설치 |

## Product/legal inputs

| 항목 | 상태 | Owner |
|---|---|---|
| 최초 출시 국가 | ACCEPTED — 대한민국 단일 시장 | Product/Business |
| Supabase production region | ACCEPTED — Seoul `ap-northeast-2` | Product + Privacy + Backend |
| 대상 연령/mixed audience | PRODUCT ACCEPTED — 성인 계정·Kids Category 미선택; Legal/Store 검토 PENDING | Product + Legal/Privacy |
| 보관/삭제 기간 | OPEN | Legal/Privacy |
| Free/Plus limits와 가격 | EXPERIMENT | Product/Growth |
| purchaser/household restore policy | OPEN | Billing/Product |
| Apple Family Sharing | PROVISIONAL OFF | Billing/Product |
| 환불/지원 owner | UNASSIGNED | Operations |

## G0 closure checklist

- [x] 각 대상 console의 accountable owner를 개인 운영자로 결정
- [x] Android 제품명·dev/prod applicationId 승인
- [x] 최초 시장·리전 제품 승인
- [x] 성인 대상 Store MVP와 Managed Child P1 제품 승인
- [ ] 성인 대상 Store questionnaire와 Legal/Privacy 검토
- [ ] 보관·삭제 정책 legal review
- [ ] Free/Plus 가설과 H-07 실험 승인
- [ ] Android 실제 기기 ADB 연결과 dev install/boot
- [ ] auth/push/billing sandbox evidence 확보
- [ ] 개인 Google Play 계정 생성일·production access·실기기 인증 상태 확인
- [ ] 개인 운영 계정 2단계 인증·복구 수단 증거
