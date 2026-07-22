# AGENTS.md — KinFlow Flutter

## 1. Source of truth

`DECISIONS.md` → `SPEC_BASELINE.md` → `contracts/` → 구현 스펙 → 제품 문서 → Phase 문서 순서다. 문서 충돌을 발견하면 임의로 한쪽을 선택하지 말고 `DECISIONS.md` 또는 ADR에 기록한다.

## 2. 작업 단위

- 한 번에 한 Phase, 한 Work Package, 한 vertical slice만 수행한다.
- 구현 전 요구사항 ID, DB/API 영향, 테스트, rollback을 적는다.
- 구현 후 실제 명령을 실행하고 `evidence/phase-XX/`에 증거를 남긴다.
- 빌드되지 않은 scaffold, TODO 기반 mock, fake purchase를 완료로 보고하지 않는다.

## 3. Flutter 규칙

- Flutter SDK 3.44.7 stable을 사용한다.
- Dart analyzer warning 0을 유지한다.
- Widget에서 Supabase, RevenueCat, Firebase SDK를 직접 호출하지 않는다.
- domain은 Flutter/Riverpod import 금지다.
- Riverpod Provider는 의존성 조립과 UI 상태에 사용하고 도메인 invariant를 숨기지 않는다.
- 외부 JSON은 DTO parse → mapper → domain entity 순서다.
- generated code를 수정하지 않는다. build_runner로 재생성한다.
- `BuildContext`를 service/repository에 넘기지 않는다.
- ARB 외 문자열을 사용자에게 표시하지 않는다.
- error UI는 raw exception과 stack trace를 노출하지 않는다.

## 4. 데이터·보안 규칙

- RLS를 UI 숨김으로 대체하지 않는다.
- householdId, role, actingMemberId, entitlement를 클라이언트 값만으로 승인하지 않는다.
- service role key를 앱에 넣지 않는다.
- 초대 원문 token을 DB에 저장하지 않는다.
- 로그에 이메일, 이름, 자녀 이름, 초대 token, 구매 receipt, JWT를 넣지 않는다.
- 로그아웃/사용자 전환 테스트에는 local purge를 포함한다.

## 5. dependency 규칙

새 runtime dependency PR은 목적, 대안, 플랫폼 지원, 유지보수, license, privacy, native permission, rollback을 기록한다. 주요 SDK 버전은 `pubspec.lock`과 CI로 고정한다. Flutter/Dart, Firebase, RevenueCat, Supabase major 업그레이드는 ADR이 필요하다.

## 6. 필수 완료 보고

1. 구현한 요구사항 ID
2. 변경 파일과 migration
3. 자동 테스트와 결과
4. 실제 기기·sandbox 수동 검증
5. 보안·개인정보 영향
6. 남은 위험·OPEN 결정
7. rollback 방법
8. 다음 Work Package 진입 조건

## 버전 표기 규칙

- `v1.0`은 KinFlow 앱 스펙 버전이다.
- Flutter 프레임워크는 `Flutter SDK 3.44.7 stable`로 표기한다.
- `Flutter v1.0`이라는 표현을 사용하지 않는다.
- 자세한 기준은 `VERSIONING_CONVENTIONS.md`를 따른다.
