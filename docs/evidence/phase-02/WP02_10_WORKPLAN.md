# Phase 02 WP02-10 Google Identity Conflict Safe Recovery Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Phase: 02 only
- Vertical slice: Android Google sign-in identity conflict detection → provider-neutral failure → safe retry/support UI

## Requirements and decisions

- Requirements: `FR-AUTH-003`, `FR-AUTH-007`, `FR-SET-005`, `NFR-PRIV-01`
- Decisions: `D-002`, `D-014`, `D-033`, `D-047`, `D-054`, `D-055`
- Contract: `docs/contracts/auth-identity-conflict-recovery.yaml.md`
- Test IDs: `T-AUTH-01`, `T-AUTH-03`, `T-PRIV-03`, `T-I18N-01`, `T-A11Y-03`

## Scope

1. `AuthException.code`의 `email_exists`, `identity_already_exists`, `user_already_exists`만 `IDENTITY_CONFLICT`로 분류한다.
2. provider message/status/substring으로 identity 존재 여부를 추측하지 않는다.
3. conflict 뒤 Google SDK의 선택된 계정 상태만 best-effort로 지워 다음 명시적 로그인에서 다른 계정을 고를 수 있게 한다.
4. 자동 identity link/merge, Supabase session mutation, email OTP·Apple UI는 추가하지 않는다.
5. 로그인 화면에 localized 충돌 설명, 다른 Google 계정 명시적 재시도와 fixed configured support action을 제공한다.
6. support launch는 single-flight이고 결과는 stable localized live region으로만 표시한다.

## DB/API/storage impact

- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI, remote DTO: **변경 없음**
- local persistent storage와 schema: **변경 없음**
- 새 runtime dependency 또는 provider SDK: **변경 없음**
- 공통 error catalog에 additive `IDENTITY_CONFLICT`와 exact provider mapping만 추가한다.

## Security and privacy

- UI/log/semantics/support URL에 email, provider user ID, 상대 identity/provider, token, raw exception을 넣지 않는다.
- 현재 사용자가 Google proof를 제출한 직후의 generic conflict만 알리고 어떤 기존 계정이 있는지는 밝히지 않는다.
- Google selection 초기화 실패는 raw 오류를 노출하지 않고 원래 conflict 결과를 유지한다.
- support launcher는 기존 enum-only trusted HTTPS 경계를 재사용하며 identity query/body를 만들지 않는다.

## Automated verification

- Supabase exact-code mapping과 non-code/message-only negative cases
- data source conflict-only Google sign-out, sign-out failure isolation, other failure no sign-out
- data→domain stable failure mapping과 controller retry single-flight regression
- EN/KO/EN-XA conflict card, retry, support success/failure, raw detail non-exposure
- compact 320×568, 200% text, scroll와 48dp action
- focused auth/infrastructure/widget tests 후 full Flutter regression
- analyzer fatal warnings, format, codegen drift, localization, architecture, root CI, config, secret, YAML/CSV/reference/whitespace gates

## Manual and deferred verification

- hosted Supabase의 automatic linking/provider policy audit
- 실제 충돌 계정·Google chooser·support URL과 Android back/resume
- 실제 계정·다중기기·실기기

사용자 지시에 따라 위 live 검증은 마지막 통합 Gate까지 미룬다. 이 WP는 local 기능을 테스트 가능한 상태로 만들되 `FR-AUTH-007` 전체 완료를 주장하지 않는다.

## Rollback

- client conflict enum/mapping과 로그인 recovery card를 제거하면 기존 generic provider-unavailable 로그인 UX로 돌아간다.
- DB/API/storage 변경이 없으므로 rollback migration, data cleanup 또는 account merge 취소는 필요 없다.
