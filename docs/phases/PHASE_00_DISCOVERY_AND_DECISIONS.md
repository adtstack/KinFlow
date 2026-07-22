# Phase 00 — 발견과 차단 결정

## 목표

코드를 만들기 전에 누구를 위한 어떤 제품인지, Store·아동·가격·데이터 리전·기술 계정의 되돌리기 어려운 결정을 확정한다.

## Entry

- 제품 비전 초안 존재
- 결정권자와 기술/법률/디자인 owner 식별

## Work Packages

### WP00-01 사용자 문제 인터뷰

- 최소 5~10개 가족의 현재 집안일·일정 관리 방식
- 초대/재방문/알림/갈등 상황
- 부모만 쓰는지 자녀도 직접 쓰는지
- PC/Web 수요와 실제 사용 환경
- 결과를 가설/반증 기준과 함께 기록

### WP00-02 MVP와 성공 기준

- 가장 작은 가치 loop
- Must/Should/Not now
- activation, Week 4 retention, household coordination 지표
- Beta go/stop threshold

### WP00-03 출시 시장과 아동 분류

- 최초 국가
- 스토어 대상 연령
- mixed-audience/Families/Kids 적용 검토
- Managed Child가 독립 계정이 아님을 승인
- 데이터 리전/보관/삭제 검토

### WP00-04 가격과 구독 정책

- Free/Plus limits
- monthly/annual/trial
- purchaser/billing household transfer/restore
- Apple Family Sharing
- 환불/지원 owner

### WP00-05 기술·계정 준비

- Flutter baseline 승인
- Bundle ID/package/domain
- Apple/Google/Supabase/Firebase/RevenueCat/GitHub 조직
- CI macOS runner와 signing ownership

### WP00-06 위험 PoC

실제 작은 PoC로 다음을 검증한다.

- Flutter iOS/Android boot
- Supabase auth callback deep link
- Firebase notification 실제 기기 수신
- RevenueCat sandbox catalog load
- RLS local test

PoC 코드는 production architecture로 간주하지 않는다.

## 자동 검증

- decision ID 중복/OPEN blocker 검사
- source link와 확인일 검사
- PoC build 로그

## 수동 검증

- stakeholder decision review
- store/legal/privacy review
- test account/console 접근 확인

## Exit Gate

- D-007, D-019, D-023의 launch-blocking 부분 ACCEPTED
- 제품 이름/식별자 owner 결정
- Phase 01 toolchain과 계정 준비
- Risk Register owner 지정
- MVP/비범위 승인

## Stop 조건

- 자녀 독립 계정이 필수인데 법률/스토어 분류가 미확정
- Store 계정 또는 사업 주체가 없음
- 가격/구독 가치 가설이 전혀 검증되지 않음
- 기술 PoC에서 필수 SDK가 지원 플랫폼에서 동작하지 않음

## Evidence

`evidence/phase-00/`: 인터뷰 요약, decision review, console ownership, PoC build/device 결과.
