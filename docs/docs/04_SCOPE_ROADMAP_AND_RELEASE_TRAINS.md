# 04. 범위, 로드맵 및 Release Train

## 1. 범위 관리 원칙

- 릴리스의 목표는 기능 개수가 아니라 **가족 단위 가치가 끝까지 작동하는 것**이다.
- 보안·삭제·결제 무결성·접근성은 “나중에 다듬기” 항목이 아니다.
- 각 train은 feature flag 뒤에서 배포할 수 있어야 한다.
- 문서에 없는 기능은 backlog이지 암묵적 MVP가 아니다.

## 2. Release Train

| Train | 대상 | 제품 결과 | 배포 채널 |
|---|---|---|---|
| R0 Prototype | 연구 참여자 | 초대·Today·집안일 이해 검증 | Figma/로컬 prototype |
| R1 Internal Alpha | 개발자·내부 테스터 | auth, 가구, 단건 chore end-to-end | dev client/internal |
| R2 Household Alpha | 5~8 실제 가구 | 반복 chore와 두 번째 성인 retention | closed internal |
| R3 Closed Beta | 20~50 가구 | calendar, push, 성인 가구 안정성 | TestFlight/Play closed |
| R4 Paid Beta | 제한 국가·초대 | sandbox에서 검증된 subscription을 소수 production 사용자에게 노출 | phased feature flag |
| R5 Store MVP | 선정 국가 | 영어·한국어 공개 출시 | App Store/Google Play |
| R6 P1 | 유지율·H-05·정책 Gate 후 | Managed Child, Guest, multi-household, 고급 반복/자동화 | 점진 업데이트 |

## 3. Train별 범위

### R1 Internal Alpha

- 이메일 OTP 또는 dev 인증
- 가구 생성
- 직접 구성원 seed 또는 안전한 초대 최소 흐름
- 단건 집안일 CRUD·완료
- Today 기본 목록
- RLS smoke test

**제외:** 자녀, 반복, 일정, 푸시, 결제.

### R2 Household Alpha

- 실제 초대 링크와 수락
- 역할·구성원 제거
- 반복 집안일·occurrence
- 두 번째 성인의 독립적 사용
- 기본 감사 이력
- 읽기 캐시·네트워크 오류 상태

### R3 Closed Beta

- timed/all-day 일정과 기본 반복
- Today 통합
- 관리형 자녀·guardian·parental gate
- 푸시·quiet hours·deep link
- 영어·한국어와 accessibility
- export/delete staging rehearsal

### R4 Paid Beta

- Store sandbox에서 검증된 paywall
- production SKU를 feature flag로 제한 노출
- purchase/restore/renewal/cancel/billing issue/expiration/transfer 대응
- support runbook과 manual reconciliation
- 기존 데이터 만료 정책 검증

### R5 Store MVP

R3와 R4의 검증 범위, 스토어 정책·법률·운영 준비를 포함한다. 계정 사용자는 성인으로 한정하고 Managed Child/child mode는 포함하지 않는다(D-013). 스토어 상세 범위는 `15_RELEASE_AND_STORE_SUBMISSION_PLAN.md`를 따른다.

## 4. P1 후보

우선순위는 출시 데이터로 다시 계산한다.

- Guest와 기간 제한 초대
- 다중 가구 전환과 추가 가구 유료 옵션
- “이번 이후” 반복 수정
- template marketplace가 아닌 내부 template 확장
- 가족 주간 리포트
- 위젯/워치/웹 read-only
- 제한적 chore offline outbox
- 외부 캘린더 단방향 import
- Managed Child, guardian 관계, child mode, parental gate(H-05·법률·Store 검토 후 별도 Gate)

## 5. Scope Cut 규칙

출시 목표를 줄여야 할 때 아래 순서로 cut한다.

1. Realtime 즉시 반영 → 수동/foreground refresh
2. 여러 reminder → 한 개의 안정적 reminder
3. 복잡한 반복 패턴 → daily/weekly/monthly subset
4. calendar 반복 → 단건/all-day만 유지
5. calendar 전체를 P1로 이동하고 chores+Today 출시

Managed Child와 child mode는 이미 P1로 이동했으므로 Store MVP scope cut 후보가 아니라 비범위다(D-013).

다음은 cut할 수 없다.

- 가구 격리 RLS와 무결성
- 초대 토큰 안전성
- 계정 삭제·구독 고지
- 결제 entitlement 검증
- 핵심 접근성
- 오류·빈 상태
- rollback/kill switch

## 6. 변경 통제

새 기능 제안은 다음을 포함해야 한다.

- 해결할 사용자 문제와 증거
- 관련 요구사항·데이터·권한 변경
- 자녀/개인정보/스토어 영향
- 구독 및 기존 사용자 영향
- migration과 rollback
- 기존 train에서 cut할 항목

승인된 변경은 `DECISIONS.md`, 관련 PRD/Phase, traceability matrix를 함께 갱신한다.

## 7. v1.0 Flutter Release Train

기존 R1~R4는 공통 기능 검증에 유지한다. R5부터 모바일과 Web을 분리한다.

| Train | 대상 | 필수 범위 | Gate |
|---|---|---|---|
| R5M Mobile Store MVP | iOS·Android | 성인용 Store MVP, push, native billing, privacy/store | G2 |
| R6W Web Companion Beta | Web | HTTPS auth, core household/chores/calendar, responsive/keyboard, session/cache purge | G9 |
| R7D Native Desktop Review | Windows/macOS/Linux | 수요·ROI·plugin·보안·배포 ADR만 | G10 |

### Train 분리 규칙

- Web Companion 미완료는 R5M Mobile Store MVP를 자동 차단하지 않는다.
- 공통 DB/API contract 결함은 두 Train 모두 차단할 수 있다.
- cross-platform data/authorization mismatch는 관련 모든 Train의 blocker다.
- Web Push와 Web paid purchase는 Web Companion Beta 필수 범위가 아니다.
- Web Companion Beta 전 browser accessibility, session recovery, cross-account purge를 완료한다.
