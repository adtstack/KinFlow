# 00. 기존 설계의 문제와 Flutter 전환 수정안

## 1. 전환 배경

KinFlow의 핵심은 가족이 매일 빠르게 확인하고 완료하는 행동, 푸시 알림, 앱스토어 구독, 초대 링크, 태블릿 사용이다. Web Companion 설치를 주요 채널로 가정하면 사용자 획득·재방문·알림·결제의 불확실성이 제품 위험으로 전이된다. 따라서 v1.0은 Flutter Native-first로 기준을 재설정한다.

## 2. 수정한 핵심 문제

| ID | 심각도 | 문제 | 위험 | v1.0 해결 |
|---|---:|---|---|---|
| GAP-001 | Critical | 모바일과 웹을 동시에 GA하려는 범위 | QA·심사·기능 격차로 출시 지연 | Store MVP → Web Companion 독립 Gate |
| GAP-002 | High | PWA 설치와 Web Push를 핵심 retention 가설로 둠 | iOS 설치 발견성·권한 전환 불확실 | 앱스토어 네이티브 설치와 push를 Tier 1로 설정 |
| GAP-003 | High | 여러 플랫폼 지원을 동일 UI·동시 출시로 해석 | 최소 공통분모 UX | 공통 domain, adaptive UI, 플랫폼별 capability |
| GAP-004 | High | client state layer에 도메인 규칙이 섞일 가능성 | 테스트·데스크톱 확장 어려움 | domain/application/data/presentation 경계 |
| GAP-005 | High | Widget이 Supabase·RevenueCat·FCM 직접 호출 | 권한·재시도·테스트 분산 | Port/Repository/Use Case 강제 |
| GAP-006 | Critical | 클라이언트 role/household/entitlement 신뢰 | 교차 가구·유료 기능 우회 | 서버 membership·RLS·entitlement 재계산 |
| GAP-007 | Critical | Managed Child를 로그인 계정처럼 구현할 가능성 | 아동 개인정보·복구·푸시 위험 | 보호자 관리형 profile + acting context |
| GAP-008 | High | 초대 짧은 코드를 권한 token으로 사용 | brute force·재사용 | 고엔트로피 token hash + 만료·회수·rate limit |
| GAP-009 | High | 반복 시리즈를 한 행/RRULE로 단순화 | DST·예외·이력 손상 | series/revision/occurrence/exception 분리 |
| GAP-010 | High | 기기 local schedule가 알림의 권위자 | 앱 종료·절전·기기 변경 누락 | 서버 job + outbox + FCM/APNs |
| GAP-011 | Critical | RevenueCat customerInfo만으로 household Plus 결정 | 계정·가구 전환 mismatch | 서버 household entitlement materialization |
| GAP-012 | High | 런타임 코드 패치 도구를 기본 배포로 고려 | native 호환·Store 정책·rollback 위험 | MVP 제외, Store release + kill switch |
| GAP-013 | High | 모든 플랫폼 폴더와 plugin을 첫날 활성화 | build surface와 plugin 호환성 폭증 | ios/android/web만 scaffold, desktop 후속 |
| GAP-014 | High | 공개 법률·마케팅 페이지를 Flutter Web으로 구현 | SEO·초기 로딩·접근성 비용 | Astro 정적 사이트 분리 |
| GAP-015 | Medium | package version을 문서가 장기간 고정 | 보안·호환 drift | Flutter SDK exact, package는 Phase 01 검증 후 lock |
| GAP-016 | High | code generation drift 관리 부재 | DTO·Provider 코드 불일치 | generated files commit + CI regeneration diff |
| GAP-017 | Critical | 앱 bundle에 환경 비밀을 넣을 가능성 | 키 탈취 | 공개 config만 dart-define, 비밀 server-side |
| GAP-018 | High | logout 후 local cache/provider identity 잔존 | 다른 가족 데이터 노출 | scope purge contract와 E2E |
| GAP-019 | High | iOS/Android compile 성공을 실제 기능 검증으로 오인 | 결제·푸시·딥링크 실패 | 실제 기기·sandbox·cold-start Gate |
| GAP-020 | Medium | 데스크톱을 “지원 가능”과 “출시 약속”으로 혼동 | 지원 부담 | 수요 Gate와 별도 release train |

## 3. v1.0 원칙

1. 네이티브 모바일이 제품의 첫 번째 유통 채널이다.
2. Flutter는 플랫폼 수를 늘리는 도구지만 출시 범위를 자동으로 늘리지 않는다.
3. 공통화 대상은 도메인·API·권한·디자인 토큰이며, 모든 UI가 같을 필요는 없다.
4. Web Companion은 설치 없이 브라우저에서 쓰는 보조 앱이다.
5. public website와 authenticated product app을 분리한다.
6. desktop은 코드 구조만 준비하고 실제 수요가 생긴 뒤 활성화한다.
7. 각 Phase는 자동 테스트, 실제 기기 검증, 증거, rollback을 가진다.
