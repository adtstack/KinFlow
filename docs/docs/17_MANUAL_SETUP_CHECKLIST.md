# 17. 수동 설정 체크리스트

코딩 에이전트가 외부 콘솔 설정을 완료했다고 가정하면 안 된다. 각 항목은 담당자, 환경, 완료일, 증거 링크를 갖는다.

## 1. 조직과 계정

- [ ] Apple Developer 조직과 권한
- [ ] App Store Connect 사용자/역할
- [ ] Google Play Console 조직과 권한
- [ ] Google Cloud/Firebase 조직과 billing
- [ ] Supabase 조직과 production region
- [ ] RevenueCat 조직과 project
- [ ] GitHub organization, protected branch, environments
- [ ] 도메인·DNS·support email

## 2. 앱 식별자

- [ ] iOS dev/staging/prod Bundle ID
- [ ] Android dev/staging/prod applicationId
- [ ] 앱 표시 이름과 상표 검색
- [ ] Universal Links/App Links 도메인
- [ ] URL scheme collision 검토

## 3. Supabase

- [ ] local/staging/production project
- [ ] Auth provider와 redirect allowlist
- [ ] SMTP와 이메일 template
- [ ] migration deployment identity
- [ ] backup/PITR 정책
- [ ] Edge Function secrets
- [ ] RLS default deny 검증
- [ ] log retention/access 정책

## 4. Firebase/Push

- [ ] dev/staging/prod Firebase project
- [ ] iOS APNs key/certificate 연결
- [ ] Android `google-services.json`
- [ ] iOS `GoogleService-Info.plist`
- [ ] notification permission 문구
- [ ] FCM service credential server secret
- [ ] token rotation/invalid token dashboard

## 5. RevenueCat/Stores

- [ ] Store subscription group/products
- [ ] RevenueCat product/entitlement/offering
- [ ] App User ID policy
- [ ] webhook endpoint와 secret
- [ ] sandbox/license tester 계정
- [ ] restore/transfer policy 승인
- [ ] Apple Family Sharing 결정
- [ ] price/trial/localization 승인

## 6. CI/CD와 서명

- [ ] Flutter SDK 3.44.7 lock
- [ ] macOS runner와 Xcode 26
- [ ] Android keystore/Play App Signing
- [ ] App Store API key/Fastlane auth
- [ ] protected production environment
- [ ] secret rotation/backup owner
- [ ] artifact retention/provenance

## 7. 법률·정책

- [ ] 개인정보 처리방침
- [ ] 이용약관
- [ ] 계정 삭제 공개 URL
- [ ] 데이터 보관·삭제 정책
- [ ] 대상 연령/mixed-audience 검토
- [ ] App Privacy/Data Safety 답변
- [ ] 구독 고지와 환불 안내
- [ ] 지원/문의/침해 신고 경로

## 8. 출시 자산

- [ ] 아이콘/스플래시
- [ ] iPhone/iPad/Android phone/tablet screenshot
- [ ] 영문·한국어 store metadata
- [ ] review test account와 설명
- [ ] support/privacy/terms URL
- [ ] accessibility statement

## 9. 운영

- [ ] Sentry project와 PII scrubber
- [ ] analytics project와 child-mode policy
- [ ] alerts/on-call/runbook
- [ ] status page/incident communication
- [ ] backup restore drill
- [ ] support admin 최소 권한
