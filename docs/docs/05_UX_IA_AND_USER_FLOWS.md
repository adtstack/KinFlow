# 05. UX, 정보 구조 및 사용자 흐름

## 1. UX 목표

- 앱을 열고 5초 안에 “오늘 누가 무엇을 해야 하는지” 이해한다.
- 생성 폼에서 책임·시간·반복의 모호함을 없앤다.
- 자녀와 성인 모드의 차이가 명확하되 자녀를 낙인찍지 않는다.
- 실패·오프라인·동기화 상태를 숨기지 않는다.
- 유료 제한과 권한 제한을 같은 메시지로 표현하지 않는다.

## 2. 탭 구조

Store MVP의 기본 탭:

1. **Today** — 집안일·일정 통합, 가장 가까운 행동
2. **Chores** — 목록, 반복 template/series, 완료 내역
3. **Calendar** — 월/주보다 agenda 중심에서 시작, 생성
4. **Family** — 구성원, 초대, 자녀 프로필, 역할
5. **Settings** — 계정, 알림, 언어/시간대, 구독, 개인정보

Managed Child mode에서는 Today와 제한된 Chores만 노출한다. Calendar는 자녀에게 공개된 가족 일정만 Today 카드로 보여줄 수 있으며 Family/Settings는 보호자 gate 뒤에 둔다.

## 3. Global navigation 상태

- household context는 상단 또는 profile switcher에 표시한다.
- 네트워크 끊김은 비차단 banner로 알리고 온라인 전용 action은 이유와 함께 disable한다.
- entitlement 만료는 전체 앱을 막지 않고 제한되는 action 직전에 설명한다.
- active child mode는 지속적으로 식별 가능한 시각/텍스트 표시가 있어야 한다.
- deep link가 권한 없는 화면을 열면 빈 화면이 아니라 안전한 설명과 홈 경로를 제공한다.

## 4. 온보딩 흐름

### 4.1 성인 가입

```text
Welcome → 로그인 방법 → 인증 완료 → 이름/locale/timezone 확인
→ 가구 만들기 또는 초대 수락 → 알림 설명(시스템 prompt 전) → Today
```

- 시스템 알림 prompt는 가치 설명 후, 사용자가 reminder를 켜려는 시점에 요청한다.
- 소셜 로그인 실패 시 이메일 OTP 대체 경로를 제공한다.
- 초대 deep link로 시작한 사용자는 인증 후 원래 초대로 돌아온다.

### 4.2 가구 만들기

- 가구 이름
- 기본 시간대(IANA, 기기 추론 후 확인)
- 선택적 집안일 template
- “가족 초대”를 activation의 핵심 CTA로 제시

### 4.3 초대 수락

- 초대한 가구 이름과 inviter display name
- 참여 시 보이는 정보와 역할
- 이미 다른 활성 가구가 있는 경우 자동 이동 금지
- 만료·회수·이미 사용·정원 초과의 구분된 오류

## 5. Today 화면

### 순서

1. overdue chores
2. 지금/다음 일정
3. 오늘 마감 chores
4. 오늘의 나머지 일정
5. 완료된 항목(collapsed)

### 카드 필드

- 종류 icon+텍스트
- 제목
- 담당자 avatar/이름
- 현지 시간 또는 “All day”
- 반복 표시
- 완료/승인 상태
- 동기화 pending 표시(지원하는 action만)

### 필터

- Everyone / Me
- 필요할 경우 구성원 filter
- filter는 가시성 권한을 넓히지 않는다.

### 상태

- loading skeleton
- 진짜 빈 상태: “첫 집안일 만들기”
- 오늘만 빈 상태: 다음 예정 항목과 생성 CTA
- offline stale 상태: 마지막 동기화 시각
- partial error: 한 영역 실패 시 다른 영역 유지

## 6. 생성·편집 폼

### 공통 패턴

- 빠른 생성에는 제목, 담당, 날짜만 먼저 제공
- 고급 옵션은 progressive disclosure
- 저장 전 timezone/종일/반복 요약 문장 제공
- destructive action은 결과 범위 표시
- 권한 오류와 validation 오류를 구분

### 반복 편집 문구

- “이번 항목만 변경”
- “전체 반복 항목 변경”
- “이번 이후 모두 변경”은 Store MVP에 표시하지 않는다.

전체 반복 변경 시 과거 완료 이력은 수정하지 않는다는 점을 명시한다.

## 7. 관리형 자녀 UX

### 자녀 모드 진입

1. 성인 profile switcher에서 자녀 선택
2. 자녀에게 보이는 범위를 설명
3. 모드 전환
4. device-local short-lived child mode session 발급

### 보호자 gate

다음 action은 PIN 또는 최근 성인 인증을 요구한다.

- 자녀 모드 종료 후 성인 화면 접근
- 구성원/초대/역할
- 구독/구매/복원
- 계정·가구 삭제와 export
- 알림·개인정보·identity 설정
- 자녀 프로필 수정

PIN은 서버 계정 비밀번호를 대체하지 않는다. 결제·소유권·삭제처럼 고위험 action은 실제 최근 인증을 요구한다.

### 자녀 카피

- “실패”, “벌점”, “순위” 중심 표현 금지
- 완료 후 보호자 승인 필요 시 `확인 기다리는 중`처럼 중립적으로 표현
- 공개 가족 비교는 기본 비활성화

## 8. 구독 UX

paywall은 다음을 같은 화면에서 명확히 보여준다.

- 어떤 기능이 늘어나는지
- 어느 가구에 적용되는지
- 월/연 가격과 청구 주기
- trial이 있으면 종료일과 자동 갱신
- 구독 관리·복원 경로
- 만료 후 데이터 처리
- Apple Family Sharing과 앱 내부 Family Plan이 다를 경우 그 차이

구매 실패·pending·이미 다른 가구에 적용된 구매·복원 결과를 구분한다.

## 9. 삭제·탈퇴 UX

- **가구 나가기**: 자기 membership 종료. Owner는 소유권 이전 전 불가.
- **계정 삭제**: 로그인 identity와 개인 프로필 삭제 요청. 다른 가구 영향 설명.
- **가구 삭제**: Owner만 가능, 모든 구성원의 공유 데이터에 영향.
- **Managed Child 삭제**: 보호자 전용, 완료 이력은 익명화 보존 가능성 설명.

confirm 문구는 정확한 객체 이름을 보여주고, 삭제 가능한 cooling-off 정책이 있으면 상태와 취소 경로를 표시한다.

## 10. 접근성

- icon-only action에는 접근성 label과 hint 제공
- status를 색만으로 표현하지 않음
- screen reader traversal이 시각 순서와 일치
- 200% 글자 확대에서 핵심 action 누락 없음
- iOS 44pt, Android 48dp 수준의 touch target 지향
- reduce motion에서 불필요한 animation 제거
- 오류는 focus 이동과 텍스트로 알림
- 캘린더 날짜 선택은 screen reader로 날짜·선택 상태를 읽음

## 11. 국제화

- 영어를 source locale로 사용하되 한국어를 동시 검수
- 문장 조합 대신 완전한 번역 문구 사용
- ICU plural과 변수 명명
- 12/24시간, 주 시작 요일, 월/일 순서, 숫자·통화 locale 반영
- 30% 긴 pseudo locale과 RTL mirror smoke test
- 이름 순서를 고정하지 않음

## 12. 핵심 E2E UX 시나리오

1. 초대 deep link → 신규 가입 → 수락 → Today
2. 두 성인이 집안일을 만들고 상대가 완료
3. 반복 집안일 한 회차만 변경
4. 자녀 모드에서 완료 → 보호자 승인
5. DST 변경 주간에도 08:00 반복 일정이 현지 08:00 유지
6. 오프라인에서 읽고 온라인 전용 action 설명 확인
7. Plus 구매 후 다른 구성원이 entitlement 확인
8. 계정 삭제 요청 후 모든 기기 세션 무효화

## 13. 반응형 Web Companion UX

### 13.1 Navigation

| Viewport | 기본 navigation | 콘텐츠 |
|---|---|---|
| compact | bottom tab 또는 compact header | 단일 열, 화면 전환 |
| medium | tab/rail | 1~2열 |
| expanded | sidebar/rail | master-detail 또는 split view |

탭 순서와 route 의미는 플랫폼 간 일관되게 유지한다. expanded layout은 더 많은 정보를 동시에 보여줄 수 있지만 권한이나 데이터 의미를 바꾸지 않는다.

### 13.2 Browser interaction

- Today·집안일 완료·일정 생성·초대 수락을 keyboard-only로 수행할 수 있다.
- focus는 route 전환 시 page heading으로, dialog 종료 시 trigger로 돌아간다.
- browser back/forward가 앱 상태를 깨뜨리지 않는다.
- direct URL과 새로고침을 지원한다.
- hover-only action을 금지한다.
- destructive action은 Enter 오작동을 막고 명시적 confirmation을 사용한다.

### 13.3 Capability 상태

사용자에게 다음 상태를 구분해 보여준다.

- 사용할 수 있음
- 권한 필요
- 이 브라우저/플랫폼에서 지원하지 않음
- 일시적 장애
- 플랜 또는 역할상 사용할 수 없음

예: Web Push 미지원은 “Plus 필요”가 아니며 인앱 알림·이메일 대체 경로를 제공한다.

### 13.4 Web Companion

- 브라우저 URL 접근을 기본으로 하고 설치를 제품 목표로 삼지 않는다.
- 새 배포와 API 계약이 호환되지 않으면 진행 중인 입력을 보존한 뒤 안전한 reload 또는 재인증을 유도한다.
- offline에서는 오래된 데이터임을 표시하고 민감 mutation을 비활성화한다.
- 로그아웃·계정 전환 후 이전 가족 데이터가 browser storage·memory·back-forward cache에 보이지 않아야 한다.

### 13.5 추가 E2E UX

- E2E-W01: desktop browser에서 가구 생성→초대→집안일 완료
- E2E-W02: invite URL direct load→로그인→가입→mobile에서 확인
- E2E-W03: keyboard-only Today→집안일 생성/완료
- E2E-W04: browser refresh/back/session expiry 복구
- E2E-W05: unsupported notification/billing fallback
- E2E-W06: Web Companion 새 배포 감지→호환성 확인→session 유지 또는 안전한 재인증

## 14. Flutter adaptive UX

- compact: bottom NavigationBar, single-pane task flow
- medium/tablet: NavigationRail 또는 wider bottom navigation, optional supporting pane
- expanded Web/Desktop: persistent rail/sidebar와 master-detail
- 플랫폼별 control adaptation은 허용하되 정보 구조와 상태 의미는 동일하다.
- iOS에서 Android UI를 모방하거나 반대로 강제하지 않는다.
- 키보드, 마우스, touch, screen reader를 입력 capability로 분리한다.
