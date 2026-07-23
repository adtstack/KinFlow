# 06. 기능 요구사항 상세

상태는 구현 시 traceability matrix와 함께 갱신한다. 모든 `MUST` 요구사항은 Store MVP 출시 Gate이고 `P1`은 Store MVP 비범위다.

## 1. 인증 (`FR-AUTH`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-AUTH-001 | MUST | 이메일 OTP 가입/로그인 | 만료·재사용·rate limit·잘못된 코드 구분, 로그에 코드 없음 |
| FR-AUTH-002 | MUST | iOS Sign in with Apple | nonce/state 검증, relay email 변경/삭제 이벤트 처리 경로 |
| FR-AUTH-003 | MUST | Android Google 로그인 | token audience/issuer 검증, 취소/실패 fallback |
| FR-AUTH-004 | MUST | 세션 복원·refresh | 만료·revoke 시 안전한 로그아웃, deep link intent 보존 |
| FR-AUTH-005 | MUST | 로그아웃 | device token 연결 해제, local sensitive cache 정리 |
| FR-AUTH-006 | MUST | 최근 인증 | 계정 삭제·소유권·결제 가구 이전에 re-auth |
| FR-AUTH-007 | MUST | identity 중복 방지/연결 정책 | 동일 검증 이메일의 자동 병합 금지, 사용자 확인 및 복구 경로 |
| FR-AUTH-008 | MUST | 계정 삭제 요청 | 앱 내 경로, 상태 추적, 세션 무효화, 웹 요청 경로 |
| FR-AUTH-009 | SHOULD | 로그인 공급자 추가/제거 | 최소 한 개 복구 가능한 identity 유지 |

## 2. 가구와 초대 (`FR-HH`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-HH-001 | MUST | 가구 생성 | Owner membership과 가구가 단일 transaction으로 생성 |
| FR-HH-002 | MUST | 기본 시간대 | 유효 IANA zone만 허용, 변경 영향 설명 |
| FR-HH-003 | MUST | 고엔트로피 초대 링크 | 원문 token DB 저장 금지, hash·expiry·max uses·revoke |
| FR-HH-004 | MUST | 짧은 초대 코드(선택) | rate limit, lockout, generic error, 링크보다 짧은 만료 |
| FR-HH-005 | MUST | 초대 미리보기·수락 | 로그인 전 최소 정보, 수락은 transaction/idempotent |
| FR-HH-006 | MUST | 구성원 역할 변경 | Owner/Admin만, 마지막 Owner 제거 금지, audit |
| FR-HH-007 | MUST | 구성원 제거/나가기 | 향후 assignment 처리 정책, token/device 접근 즉시 차단 |
| FR-HH-008 | MUST | 소유권 이전 | 최근 인증, 새 Owner 확인, atomic transfer |
| FR-HH-009 | MUST | 가구 삭제 | Owner 전용, 영향 확인, background deletion 상태 |
| FR-HH-010 | SHOULD | 정원 제한 | Free/Plus 한도와 안전한 downgrade 동작 |

## 3. 관리형 자녀 (`FR-CHILD`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-CHILD-001 | P1 | Managed Child 생성 | 최소 display name/avatar만, birthdate 기본 수집 안 함 |
| FR-CHILD-002 | P1 | guardian 연결 | 최소 한 명, 다른 가구 member 연결 불가 |
| FR-CHILD-003 | P1 | active member mode | device별 짧은 수명 context, 화면에 지속 표시 |
| FR-CHILD-004 | P1 | 자녀 action allowlist | 자기 항목 보기/완료 외 민감 mutation 서버 거부 |
| FR-CHILD-005 | P1 | 보호자 gate | 설정·결제·초대·삭제 접근 차단, high-risk re-auth |
| FR-CHILD-006 | P1 | approval workflow | 필요 항목은 awaiting approval, guardian 승인/반려 |
| FR-CHILD-007 | P1 | audit actor 구분 | authenticated user와 acting managed member 모두 기록 |
| FR-CHILD-008 | P1 | 자녀 삭제·익명화 | 공유 이력 무결성과 개인정보 최소화 균형 |

## 4. 집안일 (`FR-CHORE`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-CHORE-001 | MUST | 단건 생성/조회/수정/삭제 | 제목, 담당, due, notes, approval; 권한/validation |
| FR-CHORE-002 | MUST | 여러 담당자 또는 단일 담당 정책 | 현재 기본 단일 primary assignee; unassigned 허용 여부 명시 |
| FR-CHORE-003 | MUST | 상태 전이 | open→completed/awaiting_approval→approved/reopened 규칙 |
| FR-CHORE-004 | MUST | 완료·되돌리기 | 멱등 mutation, completed_by/at, 권한과 audit |
| FR-CHORE-005 | MUST | 반복 series | daily/weekly/monthly subset, local time semantics |
| FR-CHORE-006 | MUST | occurrence 생성 | horizon job, unique series+occurrence key, 재실행 안전 |
| FR-CHORE-007 | MUST | 한 회차 예외 | skip/reschedule/reassign가 시리즈 원본을 오염시키지 않음 |
| FR-CHORE-008 | MUST | 전체 시리즈 변경 | 미래 미완료 회차 재생성, 과거 완료 이력 유지 |
| FR-CHORE-009 | MUST | 목록/필터 | Today/upcoming/overdue/completed, assignee filter |
| FR-CHORE-010 | SHOULD | template | 초기 template는 앱 내 정적/서버 seed, 개인정보 없음 |

## 5. 일정 (`FR-CAL`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-CAL-001 | MUST | timed event CRUD | start<end, UTC instant+IANA timezone |
| FR-CAL-002 | MUST | all-day event | local date, exclusive end date, timezone 이동 안정 |
| FR-CAL-003 | MUST | 참석/대상 구성원 | 같은 가구 member만, child visibility 정책 |
| FR-CAL-004 | MUST | 기본 반복 | daily/weekly/monthly, DST 현지 시각 보존 |
| FR-CAL-005 | MUST | occurrence/exception | 이번 회차 수정·취소, unique key |
| FR-CAL-006 | MUST | 전체 series 수정 | 과거 이력 보존, 미래 materialization 갱신 |
| FR-CAL-007 | MUST | agenda/calendar 조회 | locale week start, pagination, loading/empty/error |
| FR-CAL-008 | SHOULD | 충돌 표시 | 같은 구성원의 overlap 힌트, 저장 차단은 아님 |

## 6. Today (`FR-TODAY`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-TODAY-001 | MUST | chores+events 통합 | 사용자 local day 경계로 한 응답/조합, 안정 정렬 |
| FR-TODAY-002 | MUST | Everyone/Me filter | 권한 확장 없음, managed child는 자기 범위 |
| FR-TODAY-003 | MUST | quick complete | 낙관적 UI 후 서버 결과 조정, 중복 탭 안전 |
| FR-TODAY-004 | MUST | stale/offline 표시 | 마지막 성공 sync와 수행 불가 action 설명 |
| FR-TODAY-005 | MUST | partial failure | 일정 실패가 chore 목록 전체를 숨기지 않음 |

## 7. 알림 (`FR-NOTIF`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-NOTIF-001 | MUST | permission education | system prompt 전 설명, 거절 후 settings 경로 |
| FR-NOTIF-002 | MUST | device token lifecycle | 사용자/기기/environment 연결, logout/revoke cleanup |
| FR-NOTIF-003 | MUST | due/event reminder | intent 생성과 send 분리, latest state 확인 |
| FR-NOTIF-004 | MUST | quiet hours/timezone | 사용자 local 규칙, DST·여행 시 재평가 |
| FR-NOTIF-005 | MUST | deep link | 로그인/가구/권한 검증 후 안전한 destination |
| FR-NOTIF-006 | MUST | 중복 방지 | idempotency key, provider receipt, retry cap |
| FR-NOTIF-007 | SHOULD | 알림 category 설정 | assignment/due/event/approval 별 opt-in |

## 8. 구독 (`FR-SUB`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-SUB-001 | MUST | offerings/paywall | store 반환 가격·기간 사용, 하드코딩 금지 |
| FR-SUB-002 | MUST | 구매 | RevenueCat user ID=로그인 사용자 ID, pending/failed 처리 |
| FR-SUB-003 | MUST | restore | restore behavior와 계정 충돌 설명, sandbox 테스트 |
| FR-SUB-004 | MUST | webhook ingest | authorization, environment, event id 멱등, raw event 안전 보관 |
| FR-SUB-005 | MUST | household entitlement | 서버가 purchaser→한 paid household 연결, 만료 계산 |
| FR-SUB-006 | MUST | renewal/cancel/billing issue/expiration | 상태별 grace와 UI, 데이터 미삭제 |
| FR-SUB-007 | MUST | transfer/leave policy | cooldown, Owner/billing owner 관계, support override audit |
| FR-SUB-008 | MUST | manage subscription | 플랫폼별 관리 화면 deep link와 안내 |
| FR-SUB-009 | MUST | server reconciliation | webhook 누락/순서 역전 시 공급자 API 재조회 가능 |
| FR-SUB-010 | OPEN | Apple Family Sharing | SKU 생성 전 결정과 별도 테스트 |

## 9. 설정·개인정보 (`FR-SET`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-SET-001 | MUST | 프로필 | display name/avatar, 최소 정보 |
| FR-SET-002 | MUST | 언어·시간대 | 즉시 반영, 반복 semantics 경고 |
| FR-SET-003 | MUST | 데이터 export | machine-readable+human-readable, 보안 다운로드 만료 |
| FR-SET-004 | MUST | 계정 삭제 | 앱·웹 경로, 상태/보관 예외, 토큰 revoke |
| FR-SET-005 | MUST | 개인정보/약관/지원 | 앱 내 접근, 버전·동의 기록 필요 시 저장 |
| FR-SET-006 | MUST | 구독 상태 | 어느 가구에 적용, 갱신/만료, 복원/관리 |
| FR-SET-007 | SHOULD | 진단 정보 복사 | PII 없이 app/build/device/environment/incident ID |

## 10. 플랫폼 (`FR-PLAT`)

| ID | 우선 | 요구사항 | 핵심 수용 기준 |
|---|:---:|---|---|
| FR-PLAT-001 | MUST | 영어·한국어 | missing key test, pseudo locale, locale date/plural |
| FR-PLAT-002 | MUST | 접근성 | screen reader, dynamic type, touch target, contrast, reduced motion |
| FR-PLAT-003 | MUST | analytics governance | event allowlist, child mode disable, SDK inventory |
| FR-PLAT-004 | MUST | feature flags | remote server-authoritative flags, safe defaults |
| FR-PLAT-005 | MUST | app update compatibility | 최소 지원 version/forced update는 emergency만 |
| FR-PLAT-006 | MUST | legal/store disclosures | 실제 SDK·수집·삭제 흐름과 일치 |

## 11. 공통 오류 계약

모든 사용자 노출 오류는 다음 분류를 가진다.

- `VALIDATION_ERROR`
- `AUTH_REQUIRED` / `RECENT_AUTH_REQUIRED`
- `PERMISSION_DENIED`
- `HOUSEHOLD_MISMATCH`
- `INVITE_EXPIRED` / `INVITE_REVOKED` / `INVITE_LIMIT_REACHED`
- `CONFLICT` / `STALE_VERSION`
- `OFFLINE_REQUIRED`
- `PLAN_LIMIT_REACHED`
- `BILLING_PENDING` / `ENTITLEMENT_CONFLICT`
- `RATE_LIMITED`
- `PROVIDER_UNAVAILABLE`
- `UNKNOWN`

사용자 문구와 내부 코드/incident ID를 분리하고, 민감한 존재 여부를 outsider에게 노출하지 않는다.

## 12. v1.0 Universal App 추가 요구사항

| ID | 우선순위 | 요구사항 | 수용 기준 |
|---|:---:|---|---|
| FR-AUTH-010 | MUST | Web OTP/OAuth PKCE callback | HTTPS, redirect allowlist, state/PKCE 검증, callback 후 민감 URL 제거 |
| FR-AUTH-011 | MUST | Web session·cache 수명주기 | logout/account switch/removed member에서 query·browser·SW 사용자 cache 삭제 |
| FR-NOTIF-008 | MUST | Web 인앱 알림 및 fallback | Web Push 없이도 중요한 intent를 inbox와 설정된 email로 확인 |
| FR-NOTIF-009 | SHOULD | Web Push provider | secure context, permission, subscribe/rotate/unsubscribe, click allowlist, dedupe |
| FR-SUB-011 | MUST | Cross-platform entitlement 표시 | 모바일 구매가 Web에, Web 구매가 모바일에 서버 검증 후 동일하게 반영 |
| FR-SUB-012 | SHOULD | Web purchase provider | D-039 승인 후 가격·세금·환불·계정 연결을 명시하고 server entitlement 생성 |
| FR-SET-008 | MUST | Web Companion 세션·알림 설정 | 알림 capability, 캐시/로그아웃 설명, 공개 privacy 링크 제공 |
| FR-PLAT-007 | MUST | Flutter native mobile build | 동일 저장소에서 iOS IPA·Android AAB production build 성공; Web은 후속 Gate |
| FR-PLAT-008 | MUST | Capability registry | 알림·결제·저장소·링크·background의 지원 상태와 provider 선택을 중앙 관리 |
| FR-PLAT-009 | MUST | Responsive layout | compact·medium·expanded에서 핵심 task가 잘림 없이 완료 |
| FR-PLAT-010 | MUST | Keyboard와 focus | Web 핵심 task keyboard-only, visible focus, dialog focus return |
| FR-PLAT-011 | MUST | Direct URL과 route recovery | direct load, refresh, back/forward, 404/forbidden/session expiry 처리 |
| FR-PLAT-012 | MUST | Web Companion safe deployment | immutable asset, API compatibility, 새 배포 감지, session recovery, rollback evidence |
| FR-PLAT-013 | MUST | Safe cache scope | 초기 Web은 broad API persistent cache 금지, logout/account switch purge |
| FR-PLAT-014 | MUST | Platform fallback | unsupported capability가 조용히 실패하지 않고 이유·대안 표시 |
| FR-PLAT-015 | MUST | Cross-platform contract parity | occurrence, timezone, role, entitlement 결과가 플랫폼 간 동일 |
| FR-PLAT-016 | MUST | Independent release gates | Mobile Store, Web Companion Beta, Desktop Review의 범위·증거·승인을 별도 관리 |

## 13. Flutter 구현 요구사항

| ID | 우선순위 | 요구사항 | 수용 기준 |
|---|:---:|---|---|
| FR-FLT-001 | MUST | Flutter/Dart baseline | Flutter SDK 3.44.7 exact, analyzer warning 0, lockfile 고정 |
| FR-FLT-002 | MUST | Flavor 분리 | dev/staging/prod app ID, Firebase, Supabase, RevenueCat key가 혼합되지 않음 |
| FR-FLT-003 | MUST | Layer boundary | domain에서 Flutter/Riverpod/Supabase import 0 |
| FR-FLT-004 | MUST | Riverpod ownership | 서버·UI 상태 owner가 명시되고 duplicate state 없음 |
| FR-FLT-005 | MUST | Generated code integrity | build_runner 재생성 후 git diff 0 |
| FR-FLT-006 | MUST | Native deep link | iOS Universal Links, Android App Links, auth/invite cold start E2E |
| FR-FLT-007 | MUST | Native notification | denied/authorized/token rotation/foreground/background/terminated E2E |
| FR-FLT-008 | MUST | Native billing | purchase/restore/refund/expiry/account switch sandbox matrix |
| FR-FLT-009 | MUST | Adaptive tablet | landscape, split screen, large text에서 핵심 task 완료 |
| FR-FLT-010 | MUST | Store build | signed staging IPA/AAB를 실제 기기에 설치하고 smoke 검증 |
