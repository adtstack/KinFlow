# KinFlow Flutter Markdown Document Pack v1.2

> **버전 주의:** 이 문서의 `v1.0`은 KinFlow 앱 스펙 버전이다. Flutter 프레임워크 기준선은 `Flutter SDK 3.44.7 stable`, 포함 Dart는 `Dart SDK 3.12.2`다. 자세한 규칙은 `VERSIONING_CONVENTIONS.md`를 따른다.


- 문서팩 버전: `1.2`
- 기술·제품 스펙 기준선: `v1.0`
- 형식: `Markdown only`
- 기준일: `2026-07-22`
- 상태: `ACCEPTED — VERSION TERMINOLOGY AND TOOLCHAIN PATCH CORRECTION`

## 플랫폼 전략

| 등급 | 범위 |
|---|---|
| Tier 1 | Android phone, Android tablet |
| Tier 2 | 모바일 출시 후 Flutter Web Companion |
| Deferred | iOS, iPadOS, Windows, macOS, Linux 네이티브 앱 |
| Separate | Astro 기반 공개 제품·약관·삭제·지원 사이트 |

## 이 문서팩의 형식 규칙

1. 압축 파일 안의 모든 파일은 `.md` 확장자입니다.
2. DOCX, PDF, JSON, YAML, SQL, CSV, Dart, TypeScript, Python 파일을 직접 포함하지 않습니다.
3. 원래 비-Markdown이던 계약·스키마·검증표는 `<원본 파일명>.md` 안의 fenced code block으로 보존합니다.
4. 구현 저장소를 만들 때 `MD_ONLY_FORMAT_GUIDE.md`의 매핑에 따라 코드 블록을 실제 원본 경로로 추출합니다.
5. KinFlow 앱 스펙 v1.0의 제품·아키텍처 결정은 유지하되, 모호한 버전 표기를 제거하고 Flutter SDK 기준선을 3.44.7 stable로 갱신했습니다.

## 우선 읽을 문서

1. `START_HERE.md`
2. `VERSIONING_CONVENTIONS.md`
3. `DECISIONS.md`
4. `SPEC_BASELINE.md`
5. `MD_ONLY_FORMAT_GUIDE.md`
6. `IMPLEMENTATION_PLAN.md`
7. 현재 Phase 문서
