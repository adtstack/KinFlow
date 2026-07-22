# Expo 기반 스펙 v0.4 → KinFlow Flutter 앱 스펙 v1.0 전환 가이드

## 유지되는 것

제품 비전, 역할, household 모델, Managed Child, 집안일, 일정, 반복 occurrence, Supabase schema/RLS, Edge API, RevenueCat entitlement, 삭제·내보내기, 분석 이벤트·위험·테스트 시나리오는 유지한다.

## 폐기되는 것

- Expo/React Native client scaffold
- Expo Router route convention
- EAS Build/Submit/Update
- React Query/Zod/React Hook Form 기반 클라이언트 계약
- Expo Notifications/Secure Store/Updates adapter
- PWA 설치·service worker를 초기 제품 KPI로 보는 전략

## 치환표

| Expo 기반 스펙 v0.4 | KinFlow Flutter 앱 스펙 v1.0 |
|---|---|
| TypeScript UI/domain | Dart UI/domain |
| Expo Router | go_router |
| TanStack Query | Riverpod repository/notifier |
| Zod DTO | Freezed/json_serializable DTO |
| React Hook Form | Flutter Form + domain validator |
| Expo Notifications | firebase_messaging + local notifications |
| Expo Secure Store | flutter_secure_storage |
| EAS | GitHub Actions + Fastlane |
| Expo Updates | Store release + server feature flag |

## 전환 원칙

실제 Expo 코드가 아직 없다면 Flutter scaffold를 새로 만든다. 이미 코드가 있다면 화면을 기계적으로 번역하지 않고 feature별 요구사항·상태 전이·API 계약을 기준으로 Flutter vertical slice를 새로 구현한다. DB migration은 되돌리거나 재작성하지 않는다.
