# Documentation Changelog

## v1.2 — 2026-07-22 — Version terminology and SDK patch correction

- `Flutter v1.0`이라는 모호한 표현을 제거하고 `KinFlow 앱 스펙 v1.0`으로 통일
- Flutter SDK 기준선을 `3.44.0`에서 최신 stable hotfix인 `3.44.7`로 갱신
- 포함 Dart SDK를 `3.12.2`로 명시하고 Phase 01에서 `flutter --version` 증거 저장 요구
- `VERSIONING_CONVENTIONS.md` 추가
- 마이그레이션 문서명을 `FROM_EXPO_V0.4_TO_KINFLOW_FLUTTER_SPEC_V1.0.md`로 변경
- 문서팩 버전을 `v1.2`로 갱신

## v1.1 — 2026-07-22 — Markdown-only packaging

- 사람 검토용 DOCX와 전용 review 파일 제거
- 압축 파일 내부 확장자를 `.md`로 통일
- JSON·YAML·SQL·CSV·Dart·TypeScript·Python·환경 변수 예시를 Markdown code fence로 보존
- `MD_ONLY_FORMAT_GUIDE.md`와 원본 경로 매핑 추가
- 계약·검증표 README를 Markdown 래퍼 구조에 맞게 개정
- 제품·기술·Phase의 의미론적 기준선은 KinFlow 앱 스펙 v1.0에서 변경하지 않음

## v1.0 — 2026-07-21

- 클라이언트 기준을 Flutter SDK 3.44.7 stable + Dart SDK 3.12.2로 전환
- 모바일 Store MVP를 iOS/iPadOS/Android로 제한
- Web Companion을 후속 독립 Gate로 이동
- Flutter Desktop 수요 Gate 추가
- Riverpod/go_router/Freezed 기반 계층 구조 확정
- FCM/APNs와 server notification outbox 확정
- GitHub Actions + Fastlane 배포 기준 확정
- 런타임 코드 패치/OTA를 MVP에서 제외
- Astro 공개 사이트 분리
- Flutter 패키지, flavor, code generation, analyzer, 실제 기기 검증 계약 추가
- Expo v0.4 전환 가이드 추가
