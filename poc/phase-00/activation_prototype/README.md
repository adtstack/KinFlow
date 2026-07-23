# KinFlow Adult Activation Prototype

Phase 00의 H-01~H-03을 검증하기 위한 폐기 가능한 Flutter 프로토타입이다. Production 앱 scaffold나 backend 구현이 아니다.

## 검증 흐름

1. 성인 1이 가구 별칭을 만든다.
2. 성인 2의 초대 수락을 시뮬레이션한다.
3. 집안일을 세 개 이상 만들고 두 사람에게 배정한다.
4. 화면의 현재 성인을 전환해 각자 한 개 이상 완료한다.
5. 다음 날 Today 재방문을 시뮬레이션한다.

## 실행

Flutter SDK 3.44.7/Dart 3.12.2를 사용한다.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## 데이터와 비범위

- 상태는 메모리에만 존재하며 재실행하면 사라진다.
- 네트워크, Supabase, 실제 인증, 초대 링크, 알림, 결제, analytics가 없다.
- `dev.kinflow.poc` 식별자는 prototype 전용이며 production identifier로 승격하지 않는다.
- 이 로컬 환경의 기본 NDK 28.2 설치가 손상돼 Android PoC는 설치된 NDK 27.0을 명시한다. Production scaffold에서는 SDK를 복구하고 Flutter 기본 NDK로 되돌린다.
- 인터뷰에는 실명 대신 가구 별칭을 사용한다.
- 성공 화면 도달 자체가 제품 가설 통과를 뜻하지 않는다. 실제 두 번째 성인의 자발적 참여와 인터뷰 근거를 별도로 기록한다.
