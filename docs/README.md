# KinFlow Flutter Markdown Document Pack v1.2

> **버전 주의:** 이 문서의 `v1.0`은 KinFlow 앱 스펙 버전이다. Flutter 프레임워크 기준선은 `Flutter SDK 3.44.7 stable`, 포함 Dart는 `Dart SDK 3.12.2`다. 자세한 규칙은 `VERSIONING_CONVENTIONS.md`를 따른다.


KinFlow는 가족이 집안일과 일정을 함께 관리하는 글로벌 구독형 앱이다. 이 문서팩은 Flutter 기반 모바일 앱을 바이브코딩으로 구현할 때 제품 의도, 데이터 권한, 기술 선택, Phase Gate와 검증 증거가 분리되지 않도록 만든 실행 기준이다. KinFlow 앱 스펙 기준선은 v1.0, Markdown 문서팩은 v1.2, Flutter SDK 기준선은 3.44.7 stable이다.


## Markdown 전용 패키지

- 압축 파일 안에는 `.md` 파일만 있습니다.
- 기존 DOCX는 포함하지 않습니다.
- JSON·YAML·SQL·CSV·Dart·TypeScript 등은 `<원본명>.md`의 코드 블록으로 보존합니다.
- 실제 구현 파일 추출 방법은 `MD_ONLY_FORMAT_GUIDE.md`를 따릅니다.

## 공식 제품 플랫폼

| 등급 | 플랫폼 | 약속 |
|---|---|---|
| Tier 1 | Android phone/tablet | Store MVP 전체 기능과 구독·푸시·딥링크 |
| Tier 2 | Flutter Web Companion | 로그인 후 일정·집안일 관리. 모바일 출시 후 독립 Beta |
| Deferred | iPhone, iPad, Windows, macOS, Linux native | Android Beta 또는 수요 Gate 통과 후 |
| Separate | Public website | Astro 기반 정적 사이트. 제품 소개·약관·삭제·지원 |

## 확정 스택

- Flutter SDK 3.44.7 stable, Dart SDK 3.12.2 bundled
- Material 3 기반 adaptive UI
- Riverpod, go_router, Freezed/json_serializable
- Supabase Auth/PostgreSQL/RLS/Edge Functions
- RevenueCat `purchases_flutter`
- Firebase Cloud Messaging + local notifications
- Sentry 오류 추적
- GitHub Actions + Fastlane
- flutter_test, integration_test, Maestro, Playwright, pgTAP

## 문서 우선순위

1. `VERSIONING_CONVENTIONS.md`
2. `DECISIONS.md`
3. `SPEC_BASELINE.md`
4. `MD_ONLY_FORMAT_GUIDE.md`
5. `contracts/`의 계약 원문 Markdown 래퍼
6. 구현 스펙 문서
7. 제품 문서
8. Phase 문서
9. 예시·템플릿

## 개발 시작

```bash
flutter --version
flutter doctor -v
supabase --version
```

ADR-0002의 조건부 허용에 따라 Phase 01 WP01-01 Android foundation이 생성됐다. G0 전체 통과나 provider 연결을 의미하지 않는다. `prompts/MASTER_AGENT_PROMPT.md`를 사용하고 한 번에 한 Phase, 한 Work Package만 구현한다.
