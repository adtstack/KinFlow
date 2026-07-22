# 11. 보안, 개인정보, 자녀 보호

- 상태: ACCEPTED
- 주의: 법률 자문이 아니며 출시 국가와 대상 연령 확정 후 전문가 검토가 필요하다.

## 1. Threat model

보호 대상:

- 가족 관계, 이름, 집안일, 일정, 시간대
- auth token과 deep link token
- 결제·구독 연계 정보
- managed child 표시명과 활동 기록
- 삭제·내보내기 산출물

주요 위협:

- household UUID 주입과 RLS 우회
- 초대 token 추측·재사용
- 공유 기기의 계정 전환 후 데이터 잔존
- 보호자 gate 우회
- 알림 payload를 통한 잠금 화면 노출
- webhook 위조·replay
- 로그/analytics에 PII 저장
- 손상된 dependency 또는 signing credential

## 2. 인증과 세션

- Supabase Auth를 identity authority로 사용한다.
- 모바일 token은 OS secure storage에 보관한다.
- refresh token을 log/crash event에 포함하지 않는다.
- logout, account deletion, membership removal 시 local cache와 device token을 정리한다.
- 세션 refresh 실패 시 민감 화면을 잠그고 stale 데이터를 가리지 않는다.
- biometric은 편의 unlock일 뿐 server auth를 대체하지 않는다.

## 3. 초대 보안

- 최소 128-bit random token
- DB에는 hash만 저장
- 짧은 코드는 보조 입력 수단이며 rate limit 적용
- expiry, revoke, max use, target email 선택 옵션
- 수락 전 로그인 identity와 household 이름을 재확인
- 중복·동시 수락은 transaction/idempotency로 방지
- 초대 URL에는 PII를 넣지 않는다.

## 4. Managed Child 원칙

Store MVP의 Managed Child는 독립 로그인 계정이 아니다.

- 보호자가 household 안에서 만든 프로필
- 이메일, OAuth identity, 개인 push token 없음
- 공유 기기에서 guardian가 member mode로 전환
- settings, invite, billing, deletion, export는 parental gate
- 외부 analytics는 child mode에서 기본 차단 또는 최소 집계
- location, chat, medical, school record 수집 금지

대상 연령과 mixed-audience 분류가 확정되기 전에는 자녀용 독립 계정이나 광고 SDK를 도입하지 않는다.

## 5. Parental gate

- PIN 또는 OS-level authentication을 사용할 수 있다.
- PIN hash/secret은 안전하게 저장하며 plaintext log 금지
- brute-force backoff와 recovery policy 필요
- 앱 재설치/기기 변경 후 recovery를 보호자가 통제
- acting context 시작·종료를 UI에 지속적으로 표시
- 일정 시간 비활성 또는 앱 background 후 자동 종료 가능

## 6. 데이터 최소화

MVP에서 수집하지 않는 정보:

- 정확한 위치
- 연락처 주소록 전체
- 사진/비디오
- 건강·의료 정보
- 학교 성적
- 광고 ID
- 불필요한 생년월일

프로필에는 표시명과 선택적 avatar 정도만 필요하다. 진짜 법적 이름을 요구하지 않는다.

## 7. 암호화와 secret

- transit: TLS
- at rest: provider-managed encryption + 최소 접근
- 앱에 포함 가능한 Supabase anon/publishable key는 RLS를 전제로 한다.
- service role, RevenueCat webhook secret, APNs key, store credentials는 client에 포함 금지
- CI secret 접근은 protected environment와 최소 인원
- secret rotation 및 incident procedure 문서화

## 8. Logging과 analytics

금지:

- access/refresh token
- invite raw token
- full household/event/chore title
- child display name
- email 원문
- payment receipt 원문

허용:

- pseudonymous user/household identifier
- stable error code
- screen/feature name
- timing, retry count, provider status
- request ID

Sentry before-send hook에서 PII scrubber를 적용한다.

## 9. 모바일 보안

- Universal Links/App Links 도메인 검증
- exported Android component 최소화
- iOS Keychain/Android Keystore 기반 secure storage
- 화면 캡처 차단은 민감 화면에 한해 UX·접근성을 고려해 선택
- rooted/jailbroken 기기를 무조건 차단하지 않되 위험 telemetry와 고위험 action 재인증 검토
- production build에서 debug menu와 verbose network log 제거

## 10. Web Companion 보안

- HTTPS, secure cookie/session strategy, PKCE
- broad family API persistent cache 금지
- logout/account/household switch purge
- CSP, frame-ancestors, referrer policy
- BFCache/tab restore에서 session 재검증
- 공용 PC 로그인 유지 선택을 명확히 표시

## 11. 삭제와 내보내기

- 앱 안에서 계정 삭제 시작 가능
- 공개 웹 삭제 요청 경로 제공
- 공동 household 데이터와 개인 identity를 분리
- 마지막 Owner resolution
- active subscription 안내
- export 다운로드 URL은 short-lived, one-time 또는 auth 재검증
- 삭제 처리 상태와 예상 범위를 사용자에게 보여준다.

## 12. Security Gate

출시 전 최소 검증:

- RLS matrix 100% 자동화
- 다른 household ID injection E2E
- invite brute force/rate limit/replay
- webhook signature/replay/out-of-order
- local storage/cache forensic check
- child mode parental gate bypass test
- SAST, dependency/license scan, secret scan
- backup restore와 breach response tabletop
