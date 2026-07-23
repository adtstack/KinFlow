# Decision Gate Review: G0

- 날짜: 2026-07-23
- 결정자: Product owner(제품 범위 2026-07-23 승인) / Legal·Privacy owner / Engineering owner 지정 필요
- 관련 ADR/요구사항: ADR-0001, PRD-G01~G07, H-01~H-08
- 결과: **Conditional — DG00-01~03 승인, G0 외부 증거와 나머지 결정 필요**

## 현재 판정

Product owner는 대한민국 단일 시장·Seoul 리전, 성인 대상 Store MVP·Managed Child P1, 성인 2인 Activation slice를 승인했다. 다만 법률·Store 검토, 실제 가족 연구, 앱 식별자와 조직 계정 owner, 가격·보관 정책이 남아 있어 Phase 01 진입은 아직 승인하지 않는다. 아래 표의 미승인 항목은 구현자가 추측하지 않는다.

## 승인 요청 항목

| ID | 항목 | 권고안 | 현재 상태 | 승인 전 영향 |
|---|---|---|---|---|
| DG00-01 | 최초 시장·리전 | 대한민국 단일 시장 + Supabase Seoul `ap-northeast-2` | ACCEPTED 2026-07-23 | D-039 ACCEPTED; 조직 owner 전 production project 생성 금지 |
| DG00-02 | 대상 연령·아동 분류 | 계정 사용자는 성인으로 한정하고 Kids Category는 선택하지 않음. Managed Child/child mode는 P1이며 H-05와 법률/Store 검토 전 production OFF | PRODUCT ACCEPTED / LEGAL·STORE PENDING | D-013 ACCEPTED; Store questionnaire 검증 전 제출 금지 |
| DG00-03 | MVP 가치 루프 | ADR-0001의 성인 2인 Activation slice | ACCEPTED 2026-07-23 | ADR-0001 ACCEPTED, D-051 ACCEPTED |
| DG00-04 | 앱 이름·식별자·도메인 | `KinFlow`는 working name으로 유지. 법적 소유 주체와 도메인 확정 후 dev/staging/prod identifier 예약 | NEEDS OWNER | Bundle ID, applicationId, deep link PoC 차단 |
| DG00-05 | 가격·Free/Plus | 정확한 가격은 H-07 전 확정하지 않음. 한국 smoke-test 가설은 월 ₩3,900/연 ₩29,000과 월 ₩5,900/연 ₩49,000 두 셀로 검증 | EXPERIMENT | D-027 OPEN, production SKU 생성 금지 |
| DG00-06 | 데이터 보관·삭제 | 원문 연구 데이터·자녀 실명은 저장소에 저장하지 않음. 계정/운영 데이터 보관 기간은 법률 검토 후 별도 결정 | NEEDS LEGAL | production 개인정보 처리방침 차단 |
| DG00-07 | 보호자 PIN 복구 | 최근 인증을 마친 성인만 재설정 가능, 보안 질문·아동 단독 복구 금지, 실패 rate limit과 audit 필수 | PROPOSED | child mode production OFF |
| DG00-08 | 계정 소유권 | Apple/Google/Supabase/Firebase/RevenueCat/GitHub는 법적 운영 주체 소유. 개인 계정 단독 소유 금지 | NEEDS OWNER | Store·production console 생성 차단 |
| DG00-09 | 연구 Proceed 기준 | H-01, H-02, H-03 모두 통과하고 심각한 신뢰/권한 이슈 0건일 때만 Proceed | PROPOSED | Phase 01 Gate 승인 차단 |

## Evidence

### 제품·가격 참고

- FamilyWall 한국 App Store 표시 가격은 월 ₩6,000, 연 ₩44,000이며 가족 일정·목록을 Free에 제공하고 고급 기능을 Premium으로 제공한다. 확인일 2026-07-23: <https://apps.apple.com/kr/app/familywall-family-organizer/id496889629>
- Sweepy 한국 App Store 표시 가격은 월 ₩3,500, 연 ₩22,000이며 가구원 공유와 자동 일정이 핵심 비교 대상이다. 확인일 2026-07-23: <https://apps.apple.com/kr/app/sweepy-home-cleaning-schedule/id1498897320>
- 위 가격은 시장의 범위를 보기 위한 참고값이지 KinFlow의 지불 의향 증거가 아니다.

### 기술·Store 정책 참고

- Flutter 공식 문서는 3.44.7 기준이고 공식 GitHub에 3.44.7 verified tag가 존재한다. 확인일 2026-07-23: <https://docs.flutter.dev/release>, <https://github.com/flutter/flutter/releases/tag/3.44.7>
- 2026-08-31부터 Google Play 신규 앱/업데이트는 Android 16, API 36 이상을 대상으로 해야 한다. 문서의 target API 36은 현재 공식 요구와 일치한다. 확인일 2026-07-23: <https://support.google.com/googleplay/android-developer/answer/11926878>
- 2026-04-28부터 App Store Connect 업로드는 Xcode 26 이상과 iOS/iPadOS 26 SDK 이상이 필요하다. 확인일 2026-07-23: <https://developer.apple.com/news/upcoming-requirements/>
- Apple Kids Category는 아동용 앱에 별도 age band, parental gate, 개인정보 제한을 요구한다. 확인일 2026-07-23: <https://developer.apple.com/kids/>
- Supabase는 Seoul `ap-northeast-2`와 Tokyo `ap-northeast-1`을 제공한다. 확인일 2026-07-23: <https://supabase.com/docs/guides/platform/regions>

## Options and Tradeoffs

### 아동 기능을 Store MVP에 유지

- 장점: 문서의 가족 제품 차별화를 그대로 검증한다.
- 비용: 법률·Store 분류, third-party SDK, parental gate, shared-device cache 검증이 Phase 02부터 필수다.
- 진입 조건: H-05 통과, legal/privacy reviewer 지정, target audience 답변 초안 승인.

### 아동 기능을 P1로 연기

- 장점: 성인 2인 참여 가설을 더 적은 개인정보와 권한 surface로 검증한다.
- 비용: 자녀 있는 가족의 차별화가 약해질 수 있다.
- 결정: 이 옵션을 선택했다. H-05와 법률·Store 검토를 통과한 뒤 P1 범위를 별도 승인한다.

## 적용 범위와 금지 범위

- 허용: 인터뷰, clickable prototype, concierge pilot, 격리된 기술 PoC, sandbox catalog 조회.
- 금지: production 사용자 모집, 실제 결제, 자녀 실명 저장, accountable owner 없는 production console 생성, 미승인 결정을 코드 기본값으로 확정.

## 필요한 문서/코드/콘솔 변경

1. Product owner가 남은 DG00-04~09에 승인/수정/거절을 기록한다.
2. DG00-01~03은 `DECISIONS.md`, ADR, PRD, Phase와 traceability에 반영한다.
3. 법적 운영 주체를 각 console owner로 지정한다.
4. 연구 결과로 scorecard와 pilot evidence를 채운다.
5. Flutter 3.44.7을 프로젝트 단위로 고정하고 iOS/Android 테스트 기기를 준비한다.

## 재검토 조건

- 초기 고객의 주 시장이 한국이 아닐 때
- H-02가 실패해 coordinator-first 방향을 검토할 때
- H-05와 법률·Store 검토가 통과해 Managed Child의 P1 구현을 승인할 때
- H-07이 실패해 subscription work를 중단할 때
