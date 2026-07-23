# Phase 00 Manual Setup Status

- 점검일: 2026-07-23
- 점검 범위: 저장소와 로컬 개발 환경
- 주의: 외부 console을 열거나 계정 존재를 가정하지 않았다. 저장소에서 증명되지 않은 항목은 `UNVERIFIED`다.

## Organization and ownership

| 항목 | 상태 | 필요한 증거 |
|---|---|---|
| 법적 운영 주체 | UNVERIFIED | 법인/개인사업자/개인 중 owner 결정 기록 |
| Apple Developer/App Store Connect | UNVERIFIED | organization ID, account holder, 역할 export |
| Google Play Console | UNVERIFIED | developer account owner와 역할 export |
| Supabase organization | UNVERIFIED | organization owner와 billing owner |
| Firebase/Google Cloud | UNVERIFIED | organization/project owner와 billing |
| RevenueCat | UNVERIFIED | project owner와 admin 역할 |
| GitHub organization | UNVERIFIED | owner, protected branch, environments |
| domain/DNS/support email | UNVERIFIED | registrar owner, domain, support mailbox |

## App identity

| 항목 | 상태 | 차단 영향 |
|---|---|---|
| 최종 제품명/상표 검색 | OPEN | Store metadata와 domain |
| dev/staging/prod Bundle ID | OPEN | iOS signing, Firebase, deep link |
| dev/staging/prod applicationId | OPEN | Android signing, Firebase, Play |
| Universal/App Links domain | OPEN | auth/invite cold-start PoC |

## Local technical readiness

| 항목 | 상태 | 확인 결과 |
|---|---|---|
| Flutter 3.44.7 | PARTIAL | `/private/tmp` 격리 SDK로 버전 확인; project pin 없음 |
| Xcode 26+ | PASS | Xcode 26.6 |
| iOS Simulator | BLOCKED | 설치 runtime 0 |
| CocoaPods | BLOCKED | 미설치 |
| Android SDK 36 | PASS | platform/build-tools 36.0.0 |
| Android NDK | PARTIAL | 28.2 install 손상; PoC는 정상 NDK 27.0으로 build PASS |
| Android AVD/device | BLOCKED | AVD 0, 연결 기기 0 |
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

- [ ] 각 organization/console에 이름이 있는 accountable owner 기록
- [ ] 제품명·도메인·환경별 identifier 승인
- [x] 최초 시장·리전 제품 승인
- [x] 성인 대상 Store MVP와 Managed Child P1 제품 승인
- [ ] 성인 대상 Store questionnaire와 Legal/Privacy 검토
- [ ] 보관·삭제 정책 legal review
- [ ] Free/Plus 가설과 H-07 실험 승인
- [ ] iOS/Android 실제 기기 PoC 환경 준비
- [ ] auth/push/billing sandbox evidence 확보
