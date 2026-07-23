# 17. 수동 설정 체크리스트

코딩 에이전트가 외부 콘솔 설정을 완료했다고 가정하면 안 된다. 각 항목은 담당자, 환경, 완료일, 증거 링크를 갖는다.

## 1. 조직과 계정

- [ ] 개인 Google Play account owner, 생성일, production access
- [ ] 개인 Google Cloud/Firebase owner와 billing
- [ ] 개인 Supabase owner와 production region
- [ ] 개인 GitHub owner, protected branch, environments
- [ ] 각 계정 2단계 인증과 복구 수단
- [ ] RevenueCat project owner(Phase 06 진입 시)
- [ ] 도메인·DNS·support email

## 2. 앱 식별자

- [x] Android prod `me.newlines.kinflow`
- [x] Android dev `me.newlines.kinflow.dev`
- [ ] 앱 표시 이름과 상표 검색
- [ ] Universal Links/App Links 도메인
- [ ] URL scheme collision 검토

## 3. Supabase

- [ ] local/dev/production project
- [ ] Auth provider와 redirect allowlist
- [ ] Google provider, consent screen, Android/Web OAuth client
- [ ] migration deployment identity
- [ ] backup/PITR 정책
- [ ] Edge Function secrets
- [ ] RLS default deny 검증
- [ ] log retention/access 정책

## 4. Firebase/Push

- [ ] dev/prod Firebase project
- [ ] Android `google-services.json`
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
- [ ] Android Play billing 범위 승인
- [ ] price/trial/localization 승인

## 6. CI/CD와 서명

- [ ] Flutter SDK 3.44.7 lock
- [ ] Android keystore/Play App Signing
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
- [ ] Android phone/tablet screenshot
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
