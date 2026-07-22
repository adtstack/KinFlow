# KinFlow 버전 표기 규칙

- 기준일: `2026-07-22`
- 상태: `ACCEPTED`

## 1. 서로 다른 세 가지 버전

| 구분 | 현재 값 | 의미 |
|---|---:|---|
| KinFlow 앱 스펙 버전 | `v1.0` | 제품·아키텍처·구현 계획의 기준선 버전 |
| Markdown 문서팩 버전 | `v1.2` | 압축 문서 구성과 정정 이력 버전 |
| Flutter SDK 버전 | `3.44.7 stable` | 앱을 빌드하는 Flutter 프레임워크·도구 버전 |
| Dart SDK 버전 | `3.12.2` | Flutter SDK 3.44.7에 포함된 Dart 버전 |

`v1.0`은 Flutter SDK 버전이 아니다. 문서에서는 **`Flutter v1.0`이라는 표현을 사용하지 않는다.**

## 2. 올바른 표기 예시

```text
KinFlow 앱 스펙 v1.0
KinFlow Markdown 문서팩 v1.2
Flutter SDK 3.44.7 stable
Dart SDK 3.12.2
```

잘못된 예시:

```text
Flutter v1.0
Flutter 1.0 기준선
Flutter 버전 v1.0
```

## 3. Toolchain 고정 정책

1. Phase 01 시작 시 `flutter --version`과 `flutter doctor -v` 결과를 증거로 저장한다.
2. CI와 로컬 개발 환경은 Flutter SDK `3.44.7`을 정확히 고정한다.
3. `pubspec.lock`을 커밋하고 CI에서 lockfile drift를 검사한다.
4. Flutter patch 업데이트는 별도 의존성 변경 PR로 처리하며 unit·widget·integration·iOS·Android build 검증을 통과해야 한다.
5. Release Candidate 직전에는 공식 Flutter SDK archive와 release notes에서 최신 stable 및 hotfix를 다시 확인한다.
6. 최신 stable이 바뀌었다고 자동 업그레이드하지 않는다. 플러그인 호환성과 회귀 테스트를 통과한 후 ADR로 기준선을 갱신한다.

## 4. 공식 확인 경로

- Flutter SDK archive: <https://docs.flutter.dev/install/archive>
- Flutter release notes: <https://docs.flutter.dev/release/release-notes>
- Flutter repository changelog: <https://github.com/flutter/flutter/blob/master/CHANGELOG.md>
