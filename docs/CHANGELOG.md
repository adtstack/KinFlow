# Documentation Changelog

## Unreleased — 2026-07-23 — Phase 00 product-scope decisions

- Android 단일 출시, dev/prod 두 환경, 개인 운영 주체, Google 로그인 승인(D-002, D-032, D-052~D-054, ADR-0002)
- production `me.newlines.kinflow`, dev `me.newlines.kinflow.dev` 식별자 승인
- iOS/iPadOS, APNs와 staging은 Android Beta review 이후로 연기
- G0 전체 통과 전 로컬·가역적인 Phase 01 WP01-01 foundation 작업만 조건부 허용
- 대한민국 단일 공개 출시와 Supabase Seoul `ap-northeast-2` 승인(D-039)
- Store MVP를 성인 계정 사용자로 한정하고 Managed Child/child mode를 P1로 연기(D-013)
- 성인 2인 Activation vertical slice 승인(D-051, ADR-0001)
- PRD, roadmap, requirements, Phase 00/02/07, traceability와 release checklist를 승인 범위에 맞게 정렬
- 사용자 연구, 법률·Store 검토, 가격·보관 정책, 앱 식별자·console owner, 실제 기기/provider PoC는 미완료 상태 유지
- WP02-01 인증 session/PKCE 저장에 Android Keystore-backed `flutter_secure_storage 10.3.1`을 고정하고 Supabase runtime composition과 backup-disabled 계약 추가

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
