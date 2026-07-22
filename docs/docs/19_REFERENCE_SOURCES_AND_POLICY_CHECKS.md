# 19. 기준 자료와 출시 직전 정책 점검

- 상태: MAINTAINED
- 기준일: 2026-07-21

## 1. 기술 기준 자료

- Flutter stable release와 Dart release notes
- Flutter supported deployment platforms
- Flutter adaptive/responsive, deep link, build/release 문서
- Supabase Flutter/Auth/Postgres/RLS/Edge Function 문서
- RevenueCat Flutter SDK, restore behavior, webhook 문서
- Firebase Cloud Messaging Flutter 문서
- Apple Developer/App Store Review/Subscription/Privacy 문서
- Google Play target API, Billing, Data Safety, Families 문서
- WCAG 2.2와 플랫폼 접근성 지침

구체 링크는 `docs/99_REFERENCES.md`에서 관리한다.

## 2. 변경 가능성이 높은 항목

RC 시작 직전에 공식 출처로 다시 확인한다.

- Flutter stable와 지원 OS/browser matrix
- Xcode/iOS SDK 제출 요구사항
- Google Play target API deadline
- Store billing SDK 요구사항
- privacy manifest/required reason API
- App Privacy/Data Safety 질문
- account deletion 요구사항
- Families/mixed-audience/아동 법률
- RevenueCat SDK/store compatibility
- Supabase platform deprecation/security advisory

## 3. 정책 확인 절차

1. 담당자가 공식 문서 URL과 확인일을 기록
2. 변경사항과 기존 설계 영향 분석
3. blocker이면 ADR/implementation plan 갱신
4. build/test/store metadata 변경
5. evidence에 screenshot 또는 exported policy summary 저장

블로그·검색 요약만으로 정책을 확정하지 않는다.

## 4. 지역·아동 점검

최초 국가와 대상 연령이 확정되면 다음을 별도 검토한다.

- 미국 COPPA
- EU/EEA GDPR 아동 동의 연령과 데이터 주체 권리
- 영국 Children’s Code
- Apple Kids Category/Google Families 적용 여부
- 데이터 국외 이전, DPA, 보관 기간
- 결제 세금·환불·소비자 고지

## 5. 오픈소스와 라이선스

- dependency license inventory
- Store와 상업 사용 적합성
- copyleft/asset/font license 검토
- 앱 내 acknowledgements 필요 여부
- discontinued/unmaintained plugin 대체 계획

## 6. 출처 변경 기록

정책 또는 toolchain이 변경되면 `CHANGELOG.md`, `DECISIONS.md`, 관련 matrix와 Phase Gate를 함께 갱신한다.
