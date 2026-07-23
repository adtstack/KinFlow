# KinFlow Flutter Markdown 문서팩 v1.2 — START HERE

> **버전 주의:** 이 문서의 `v1.0`은 KinFlow 앱 스펙 버전이다. Flutter 프레임워크 기준선은 `Flutter SDK 3.44.7 stable`, 포함 Dart는 `Dart SDK 3.12.2`다. 자세한 규칙은 `VERSIONING_CONVENTIONS.md`를 따른다.


- 상태: `ACCEPTED — KINFLOW APP SPEC v1.0 / FLUTTER SDK 3.44.7 / MARKDOWN-ONLY PACK v1.2`
- 기준일: 2026-07-23
- 제품 전략: 가족용 집안일·공유 일정 구독 앱
- 출시 전략: iOS·Android 네이티브 앱 우선, Web Companion 후속, 네이티브 데스크톱은 수요 Gate 이후
- Phase 00 제품 결정: 대한민국 단일 시장·Seoul 리전, 성인 계정 Store MVP, 성인 2인 Activation 우선; Managed Child는 P1


## 0. 이 압축 파일의 형식

이 문서팩에는 `.md` 파일만 들어 있습니다. 기존 DOCX는 제거했고, SQL·YAML·JSON·CSV·Dart·TypeScript·환경 변수 예시·검증 스크립트는 `<원본 파일명>.md` 안의 코드 블록으로 보존했습니다.

구현 전 `MD_ONLY_FORMAT_GUIDE.md`를 읽고 필요한 원본 파일을 지정된 경로로 추출합니다. 제품·기술 기준선 자체는 KinFlow 앱 스펙 v1.0과 동일합니다.

## 1. 무엇이 바뀌었나

v0.4의 Expo/Web Companion 중심 클라이언트 기준을 폐기하고 Flutter Native-first 기준으로 새로 작성했다. 제품 비전, Household 권한 모델, Managed Child, PostgreSQL/RLS, 반복 일정, 서버 알림, RevenueCat household entitlement, 삭제·내보내기 원칙은 보존한다.

교체된 핵심은 다음과 같다.

| 이전 기준 | v1.0 기준 |
|---|---|
| Expo + React Native + TypeScript | Flutter SDK 3.44.7 stable + Dart SDK 3.12.2 |
| Expo Router | go_router |
| TanStack Query / React state | Riverpod + Repository/Use Case |
| EAS Build/Submit/Update | GitHub Actions + Fastlane + Store release |
| Web Companion를 조기 공식 플랫폼으로 운영 | 모바일 Store MVP 우선, Web Companion은 독립 후속 Gate |
| Windows/macOS/Linux는 Web Companion으로만 검증 | Flutter Desktop 확장 가능 구조, 실제 출시는 수요 Gate 후 |

## 2. 처음 읽는 순서

1. `VERSIONING_CONVENTIONS.md` — KinFlow 스펙·문서팩·Flutter SDK 버전 구분
2. `DECISIONS.md` — 변경하면 안 되는 제품·아키텍처 결정
3. `SPEC_BASELINE.md` — Flutter·Dart·플랫폼·품질 기준
4. `MD_ONLY_FORMAT_GUIDE.md` — 계약·검증표 원본 추출 방법
5. `docs/01_PRODUCT_BRIEF.md`와 `docs/03_PRD.md` — 제품 목표와 MVP
6. `docs/20_PLATFORM_AND_CLIENT_ARCHITECTURE.md` — Flutter 클라이언트 구조
7. `docs/21_TECH_STACK_VERSION_AND_DEPENDENCY_POLICY.md` — 패키지와 업그레이드 정책
8. `docs/24_BACKEND_DATABASE_AND_API_IMPLEMENTATION_SPEC.md` — Supabase·RLS·Edge Function 계약
9. `IMPLEMENTATION_PLAN.md` — Phase 00~10 실행 순서
10. 현재 Phase 문서 한 개
11. `contracts/README.md` — 계약 원문 Markdown 래퍼 인덱스
12. `matrices/README.md` — 검증표 Markdown 래퍼 인덱스
13. `prompts/MASTER_AGENT_PROMPT.md` — 바이브코딩 최초 지시문

## 3. 에이전트에게 제공하는 방법

저장소 전체를 제공할 수 있으면 이 패키지를 저장소 루트에 둔다. 한 파일만 제공할 수 있으면 `IMPLEMENTATION_SPEC.md`를 사용한다. 제품 의도까지 함께 이해해야 하면 `MASTER_SPEC.md`를 사용한다.

최초 지시는 다음 원칙을 포함해야 한다.

```text
문서 전체를 읽되 지금은 Phase 00만 수행한다.
DECISIONS.md의 ACCEPTED 결정을 임의로 바꾸지 않는다.
OPEN 결정은 코드로 추측하지 않고 안전한 비활성 상태로 남긴다.
Phase Gate의 자동·수동 검증 증거가 없으면 완료라고 하지 않는다.
```

## 4. 구현을 시작하기 전 반드시 확정할 항목

- 앱의 최종 이름·Bundle ID·Package name·도메인
- 성인 대상 Store questionnaire의 법률·Privacy 검토(D-013의 제품 범위는 승인됨)
- Free/Plus 한도, 월간·연간 가격, 무료 체험
- 개인정보 보관·삭제 기간
- 보호자 PIN 복구 정책
- Apple/Google 개발자 계정 소유 주체

최초 출시 국가는 대한민국, Supabase production region은 Seoul `ap-northeast-2`로 승인됐다. 이 결정은 법적 운영 주체나 console owner 미지정을 해소하지 않는다.

## 5. 절대 하지 말아야 할 것

- 모든 플랫폼을 첫날부터 동시에 출시하지 않는다.
- Flutter UI에서 Supabase·RevenueCat·FCM SDK를 직접 호출하지 않는다.
- 클라이언트가 보낸 householdId, role, actingMemberId, isPlus를 신뢰하지 않는다.
- Managed Child를 일반 로그인 계정으로 만들지 않는다.
- 반복 일정을 단일 RRULE 문자열과 한 행으로만 구현하지 않는다.
- 모바일 구독 상태만으로 가구 전체 Plus 권한을 열지 않는다.
- `--dart-define`에 서버 비밀을 넣지 않는다.
- Store 심사를 우회하는 런타임 코드 업데이트를 MVP에 도입하지 않는다.
- Web Companion을 SEO·법률·마케팅 사이트로 사용하지 않는다.

## 6. 산출물

- 제품·기술 문서와 Phase 계획
- Flutter toolchain·pubspec·analysis 설정 예시
- OpenAPI·DB·RLS·오류·이벤트 계약
- 요구사항·권한·결제·반복·플랫폼 검증 매트릭스
- 코딩 에이전트 프롬프트와 검토 템플릿
- 모바일 Store 출시와 후속 Web/Desktop Gate
