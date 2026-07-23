# 25. 인증, 세션, Identity, Link 스펙

- 상태: ACCEPTED

## 1. 성인 계정

Store MVP의 auth account는 성인/보호자 사용자를 위한 것이다. 이메일 OTP 또는 magic link를 기본 후보로 하고 OAuth provider는 출시 국가·지원 부담에 따라 선택한다.

## 2. Session state

```text
unknown/bootstrap
unauthenticated
authenticating
authenticated-no-household
authenticated-active-household
refreshing
locked/re-auth-required
deleting
```

UI는 nullable user 하나로 모든 상태를 추론하지 않는다.

## 3. 모바일 저장

- refresh/access token은 secure storage
- app process memory에 필요한 기간만 사용
- logout/invalid grant에서 제거
- debug log/network inspector redaction
- app clone/backup restore behavior 검토

## 4. 로그인 흐름

1. 이메일 형식/locale
2. server auth request
3. generic response로 account enumeration 최소화
4. Universal/App Link callback
5. code/state 검증
6. profile bootstrap
7. active household 선택 또는 onboarding
8. RevenueCat identity login
9. device registration

각 단계 실패 시 재시도/취소/지원 경로를 제공한다.

## 5. OAuth/Deep Link

- own HTTPS domain
- iOS associated domains와 Android assetlinks
- exact redirect allowlist
- state/PKCE 검증
- token/query 로그 금지
- open redirect 방지
- cold start와 이미 열린 앱
- callback replay 방지

## 6. Household 초대

초대 링크를 열었을 때:

- token을 secure ephemeral memory에 보관
- 로그인 전 household 최소 정보 preview는 abuse/rate limit 고려
- 로그인 후 수락 대상 household와 현재 account 재확인
- 이미 가입/만료/회수/가득 참 상태
- 성공 후 active household 전환은 사용자에게 명확히 표시

## 7. Active household

한 계정이 여러 household를 가질 수 있으나 Store MVP UI는 단순화할 수 있다. active household는 client preference일 뿐 서버 권한이 아니다. 전환 시:

- previous household cache/provider dispose
- notification/filter context 갱신
- P1 child acting mode 종료
- entitlement refetch
- Realtime channel 재구성

## 8. Managed Child(P1 계약, Store MVP 비범위)

- auth account 없음
- guardian가 만든 managed member row
- child mode entry에 parental gate/명시적 선택
- allowed action subset
- actor audit 이중 기록
- logout과 별개의 mode exit
- background/timeout에서 자동 종료 정책

## 9. 계정 상태

- active
- suspended (운영/보안 정책 필요)
- deletion requested
- deletion processing
- deleted/tombstoned

삭제 처리 중 새 household 생성이나 purchase를 막고, status/export/support access 정책을 제공한다.

## 10. Device registration

- auth user + installation ID + platform + environment
- FCM token은 rotate 가능
- logout/account switch에서 unlink
- last_seen, app version, permission state
- raw token 접근 최소화
- invalid provider response 시 revoke

## 11. Auth test

- OTP/magic link 성공·만료·재사용
- callback spoof/open redirect
- session refresh offline/expired
- account switch cache purge
- invite before/after login
- removed membership on resume
- P1 child mode route bypass
- reinstall와 restore
