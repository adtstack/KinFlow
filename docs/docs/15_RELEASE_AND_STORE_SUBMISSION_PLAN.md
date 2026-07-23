# 15. 출시와 Store 제출 계획

- 상태: ACCEPTED
- 전략: Mobile Store MVP 먼저, Web Companion과 Desktop은 독립 Gate

## 1. Release train

| Train | 범위 | Gate |
|---|---|---|
| Internal Alpha | 핵심 vertical slice, dev/staging | G1-G4 |
| Family Beta | 실제 가족, TestFlight/Play internal | G5-G7 |
| Mobile RC | signed IPA/AAB, privacy/billing/ops | G8 |
| Store Launch | staged Android release | G9 |
| Web Companion Beta | mobile 안정화 후 browser app | G10 |
| Desktop Review | 수요 데이터 기반 ADR | G11 |

## 2. 버전 규칙

- semantic product version + monotonically increasing build number
- Android versionName/versionCode는 release record와 정렬
- DB/API contract version은 앱 version과 독립
- release branch freeze 후 critical fix만 cherry-pick
- feature flag로 incomplete capability를 안전하게 off

## 3. iOS 준비

- Apple Developer/App Store Connect 소유권 확정
- production Bundle ID, capabilities, Associated Domains, Push Notifications
- privacy manifest와 required reason API 검토
- subscription group/product/localization
- account deletion in-app flow
- restore purchases
- review notes와 test account
- iPhone/iPad screenshots, support/privacy URLs
- current Store 제출 SDK/Xcode 요구사항을 RC 전에 재검증

## 4. Android 준비

- Play Console, package name, app signing
- target SDK/current policy 재검증
- App Links, FCM, notification permission
- subscription base plans/offers
- Data Safety, target audience/content declarations
- in-app account deletion과 public deletion URL
- phone/tablet screenshots, internal/closed testing track
- pre-launch report와 device compatibility

## 5. RC build

- clean checkout, locked Flutter SDK, `pubspec.lock`
- production flavor configuration
- signed reproducible build metadata
- SBOM/dependency/license report
- `flutter build ipa --release --flavor prod`
- `flutter build appbundle --release --flavor prod`
- artifact checksum과 provenance 저장
- 실제 기기 설치 후 cold start/auth/invite/Today/push/billing/deletion smoke

## 6. 제출 전 Gate

- 모든 blocker/critical defect 0
- RLS matrix와 billing matrix pass
- backup restore drill pass
- privacy/legal 문서 승인
- support/runbook/on-call owner 확인
- production secrets와 webhook 검증
- analytics/alert dashboard 확인
- feature flags default 상태 확인
- rollback version과 DB compatibility 확인

## 7. 점진 출시

권장:

1. 내부 직원/테스터
2. 제한된 국가 또는 1~5%
3. 10~25%
4. 50%
5. 100%

각 단계에서 crash-free, auth, Today, mutation, notification, entitlement, support ticket를 확인한다. Google Play internal/closed/production rollout을 runbook에 반영한다.

## 8. 중단 기준

- household 데이터 노출/권한 우회
- account deletion 실패 또는 데이터 잔존
- paid user entitlement 광범위 불일치
- crash-free 또는 startup 급락
- notification 폭주/중복
- migration 데이터 손상
- legal/store policy 위반 가능성

## 9. Rollback

- 이전 client binary rollout halt/rollback 가능 범위 확인
- feature flag kill switch
- backward-compatible DB migration
- webhook/worker pause
- notification job drain/quarantine
- 고객 안내와 entitlement manual remediation 절차

Store binary를 즉시 되돌릴 수 없는 상황을 전제로 server compatibility와 kill switch를 준비한다.

## 10. Web Companion 출시

Mobile 안정화 후 별도 수행한다.

- immutable asset + atomic deploy
- CSP/headers/session/cache 검증
- browser matrix와 accessibility
- API 최소 호환 범위
- rollback deployment
- public website와 앱 경로 분리
- PWA 설치율을 출시 KPI로 삼지 않는다.
