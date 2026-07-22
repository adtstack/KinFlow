# 02. 제품 발견 및 가설 검증 계획

## 1. 목적

코드를 많이 만들기 전에 다음 질문에 증거로 답한다.

- 실제로 누가 가장 아픈 문제를 느끼는가?
- 초대한 가족이 참여하는가?
- 집안일과 일정이 하나의 Today에 있을 때 더 유용한가?
- 관리형 자녀 모드가 정말 구매·유지 이유인가?
- 어떤 기능을 무료로 남겨야 네트워크 가치가 만들어지는가?

## 2. 가설 등록부

| ID | 가설 | 위험 | 검증 방법 | 통과 기준 | 실패 시 행동 |
|---|---|:---:|---|---|---|
| H-01 | coordinator는 주 3회 이상 가족 일을 메신저/메모로 재촉한다 | High | 문제 인터뷰 12~15명 | 60% 이상이 최근 2주 구체 사례 제시 | 타깃 또는 문제 재정의 |
| H-02 | 초대받은 성인도 7일 내 독립적으로 Today를 다시 연다 | Critical | concierge pilot 8가구 | 5가구 이상에서 두 번째 성인이 2일 이상 행동 | 개인 coordinator 도구로 pivot 검토 |
| H-03 | 담당·완료 가시성이 재촉 부담을 줄인다 | High | 2주 pilot 전후 설문·인터뷰 | 50% 이상이 체감 감소, 반대 심각 사례 없음 | 알림·책임 표현 재설계 |
| H-04 | 일정과 집안일의 Today 통합이 유의미하다 | Medium | clickable prototype A/B task | 통합안 task success/선호 우세 | 캘린더 출시 후로 이동 |
| H-05 | Managed Child가 필요한 가구는 공유 기기 방식을 수용한다 | High | 자녀 있는 6가구 prototype | 4가구 이상 사용 의향, 보호자 gate 이해 | 자녀 기능 P1 이동 |
| H-06 | 가구 구독 개념을 사용자가 이해한다 | High | paywall comprehension test | 80%가 “한 결제로 어느 가족이 혜택 받는지” 정확히 설명 | 명칭·정책 변경 |
| H-07 | Plus 후보 중 최소 하나가 반복적 지불 가치를 만든다 | Critical | 가격 인터뷰·smoke test | 후보 하나가 명확한 상위 선호와 구매 의향 | 구독 전면 재검토 |
| H-08 | 영어·한국어로 동일 핵심 흐름을 이해한다 | Medium | 양 언어 usability | 핵심 task success 80% 이상 | 카피·IA 수정 |

## 3. 연구 대상과 모집

### 세그먼트

- 자녀 없는 동거/부부 4가구
- 어린 자녀가 있는 가족 4가구
- 학령기 자녀가 있는 가족 4가구
- 돌봄·다세대 조율이 있는 가족 2~3가구

각 연구에서 coordinator만 인터뷰하지 말고 초대받는 두 번째 성인을 포함한다. 같은 가구의 의견을 독립적으로 수집해 “한 명의 강한 선호”가 가족 전체 요구로 오해되지 않게 한다.

### 제외

- 제품 팀 지인만으로 표본 구성
- 미래 의향만 묻는 설문
- 기능 목록을 먼저 보여주고 필요 여부를 묻는 방식

## 4. 문제 인터뷰 가이드

1. 최근 2주 동안 가족에게 반복해서 부탁하거나 확인한 일을 떠올려 달라.
2. 처음 어떻게 전달했고, 누가 맡았으며, 완료 여부를 어떻게 알았는가?
3. 실패하거나 다퉜던 순간은 무엇이었는가?
4. 현재 사용하는 메신저·캘린더·메모 중 버리지 못하는 이유는 무엇인가?
5. 다른 가족이 새 앱을 설치하지 않는 가장 큰 이유는 무엇인가?
6. 자녀에게 일을 맡길 때 어떤 정보와 권한까지 허용하는가?
7. 가족 운영 도구에 비용을 낸 경험과 해지 이유는 무엇인가?

“이 앱을 쓰겠는가?”보다 과거 행동, 대체재 비용, 실제 초대 가능성을 묻는다.

## 5. Prototype 검증

### 필수 task

- 가구 만들고 배우자 초대
- 이번 주 쓰레기 배출을 상대에게 반복 배정
- 자녀 프로필 추가 후 자녀 모드로 자기 할 일 완료
- 토요일 가족 일정 추가 후 Today에서 충돌 확인
- 잘못 완료한 회차 되돌리기
- 유료 플랜이 어느 가구에 적용되는지 설명
- 계정 삭제와 가구 삭제의 차이 찾기

### 기록

- task success/failure
- 첫 클릭과 잘못된 경로
- 도움 요청 횟수
- 주요 문구 이해
- 보호자 gate 우회 시도
- 신뢰를 잃는 순간

## 6. Concierge pilot

### 운영

- 실제 앱 전에는 단순 prototype 또는 최소 구현으로 8가구를 14일 운영한다.
- 연구자가 초기 집안일 template를 구성해 주되, 가족이 직접 수정하게 한다.
- 모든 가구에는 실제 성인 2명 이상이 참여해야 한다.
- 자녀 데이터는 가명·최소 정보만 사용한다.

### 관찰 지표

- 초대 전송→수락 시간
- 두 번째 성인의 첫 생성/완료 행동
- 재촉 메시지 빈도 변화
- 반복 항목 수정/삭제 패턴
- 알림 mute 비율
- 이탈 시점과 이유
- 일정 기능이 실제로 사용된 날

### 주간 질적 질문

- 이번 주 앱 없이 처리했을 일은 무엇인가?
- 앱 때문에 새롭게 한 행동은 무엇인가?
- 가장 신뢰하지 못한 정보는 무엇인가?
- 가족 갈등을 늘린 표현이 있었는가?

## 7. 가격·패키지 검증

### 순서

1. 기능 목록이 아니라 현재 대안의 비용과 불편을 파악한다.
2. Free/Plus 2개 패키지만 제시한다.
3. 월간·연간의 절대 가격보다 가구 단위 적용 이해를 먼저 검증한다.
4. fake purchase 대신 명확한 “관심 등록” 또는 sandbox에서만 테스트한다.
5. 가격은 국가별 tier와 세금을 고려해 Store 설정 직전 확정한다.

### 후보 가치

- 구성원·활성 반복 수 확대
- 고급 반복과 여러 알림
- 완료 내역·가족 리포트
- 일정/집안일 template
- 추가 가구 또는 고급 자동화(P1)

데이터 내보내기, 삭제, 기본 보안, 접근성은 유료 잠금으로 사용하지 않는다.

## 8. 의사결정 규칙

- **Proceed**: 핵심 가설 H-01, H-02, H-03 통과. 심각한 신뢰·권한 문제 없음.
- **Narrow**: 문제는 강하지만 초대 참여가 낮으면 coordinator-first 제품으로 범위를 줄이고 두 번째 성인 activation을 다시 설계.
- **Defer child**: child mode의 가치가 낮거나 정책 부담이 과도하면 Managed Child를 P1로 옮기고 일반 성인 가족만 출시.
- **Defer calendar**: H-04가 통과하지 않으면 Store MVP를 chores+Today로 제한.
- **Stop subscription work**: H-07이 통과하지 않으면 결제 integration을 시작하지 않고 무료 pilot을 연장.

## 9. 산출물

- `evidence/discovery/interview-notes/`
- `evidence/discovery/hypothesis-scorecard.md`
- `evidence/discovery/prototype-results.md`
- `evidence/discovery/pilot-results.md`
- `adr/ADR-0001-mvp-scope.md`
- 업데이트된 `DECISIONS.md`

개인 식별 정보, 자녀 실명, 원문 녹취는 저장소에 넣지 않는다.

## 10. 플랫폼 수요 검증

| ID | 가설 | 검증 | 통과 기준 | 실패 시 행동 |
|---|---|---|---|---|
| H-09 | coordinator는 주간 계획·일괄 편집을 큰 화면에서 더 빠르게 수행한다 | 동일 task 모바일/Web prototype 비교 | task time 또는 오류율이 의미 있게 개선 | expanded UI를 Web Beta 후순위화 |
| H-10 | 앱 미설치 초대 수신자는 Web에서 가입을 시작하면 수락률이 높다 | invitation funnel 비교 | Web fallback이 수락 완료 또는 설치 연결 개선 | Web public invite를 단순 안내로 축소 |
| H-11 | 한 가구가 모바일과 Web을 섞어 써도 상태·시간·권한을 이해한다 | 5가구 cross-platform pilot | 심각한 불일치/신뢰 손상 0, task success 80% 이상 | Web Beta 중단·contract 수정 |
| H-12 | Web Companion이 coordinator의 주간 계획 시간을 줄인다 | phone/tablet/Web 동일 task 비교 | 시간 또는 오류율이 의미 있게 개선 | Web Companion을 read-mostly로 축소 |
| H-13 | 네이티브 push가 가족 재참여에 유의미하다 | permission funnel·delivery·open 측정 | 주요 reminder의 전달·재방문 개선 | 알림 빈도·가치 제안 재설계 |
| H-14 | 유료 Web 결제 경로가 필요한 사용자 비율이 존재한다 | paywall comprehension/interest | 명확한 구매 의향과 국가별 운영 가능성 | Web은 entitlement read-only 유지 |

### Prototype viewport

- compact mobile
- tablet/medium
- expanded desktop browser
- keyboard-only
- 200% browser zoom
- iOS Safari와 Android Chrome의 invite fallback

플랫폼 가설이 실패해도 공통 API·도메인 설계를 폐기하지 않는다. Web Companion의 release priority만 낮춘다.

## 11. Flutter 플랫폼 검증

- 저가 Android 실제 기기와 최신 iPhone을 모두 사용한다.
- phone과 tablet에서 같은 task를 비교하되 layout 동일성을 성공 기준으로 삼지 않는다.
- desktop/web 수요는 모바일 활성 사용자 인터뷰와 event data 이후 검증한다.
- Flutter package 선택은 prototype 속도보다 실제 기기 안정성·접근성·유지보수로 평가한다.
