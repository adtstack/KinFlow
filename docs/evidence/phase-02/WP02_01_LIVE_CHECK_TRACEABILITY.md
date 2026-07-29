# Phase 02 WP02-01 Two-Adult Live Check Traceability

- 감사일: 2026-07-29
- 기준 commit: `914f19e65f5e4d3cb8d2ed9a47acfdf2cc9fbad4`
- authoritative key set: `scripts/ci/android-two-adult-e2e-evidence.mjs`
- live 상태: **27/27 NOT RUN**

`PASS`는 해당 check의 device-independent contract가 자동 검증됐다는 뜻이다. `PARTIAL`은 SDK/OS/두 account 관찰이 남았다는 뜻이다. 어느 표기도 실제 two-device `pass`를 대신하지 않는다.

| # | exact check key | 자동 커버리지 | authoritative evidence | 실제 2기기 |
|---:|---|---|---|---|
| 1 | `device_a_google_login` | PARTIAL | Google SDK gateway, token shape, provider-neutral launcher tests | NOT RUN |
| 2 | `device_a_supabase_session` | PARTIAL | Supabase ID-token exchange/session repository tests; session event before auth success 금지 | NOT RUN |
| 3 | `pre_session_protected_route_blocked` | PASS | auth route guard, bootstrapping/locked app-shell tests | NOT RUN |
| 4 | `household_created_once` | PASS | first-household transactional pgTAP, controller/widget idempotency tests | NOT RUN |
| 5 | `device_a_empty_today_opened` | PASS | onboarding→active household→empty Today widget flow | NOT RUN |
| 6 | `invite_issued_once` | PASS | invite create controller/widget, hash-only DB/Edge contract | NOT RUN |
| 7 | `device_b_invite_link_dispatched_to_app` | PARTIAL | exact manifest/App Link source, HTTPS probe, API 36 verified-link probe | NOT RUN |
| 8 | `device_b_cold_start_invite_captured` | PARTIAL | `/invite/:token` capture/scrub widget route and Android intent contract | NOT RUN |
| 9 | `device_b_google_login` | PARTIAL | same Google gateway/launcher contract as device A | NOT RUN |
| 10 | `device_b_supabase_session` | PARTIAL | same Supabase exchange/session contract as device A | NOT RUN |
| 11 | `device_b_invite_restored_after_login` | PASS | invitation→sign-in→provider session→`/invite` continuation widget test | NOT RUN |
| 12 | `device_b_invite_previewed` | PASS | minimal public preview Edge/data/controller/widget tests | NOT RUN |
| 13 | `device_b_invite_accepted` | PASS | authenticated accept DB/Edge/data/controller/widget flow | NOT RUN |
| 14 | `same_household_visible_on_both_devices` | PARTIAL | accept transaction returns/sets invited household; private Table Editor observation still required | NOT RUN |
| 15 | `distinct_adult_members_confirmed` | PARTIAL | DB creates one active membership per auth user and exact active-member binding | NOT RUN |
| 16 | `device_b_cold_session_restored` | PARTIAL | encrypted Supabase storage and valid-session restore tests | NOT RUN |
| 17 | `device_b_logout_purged` | PASS | logout widget/controller, secure storage + pending invite + Google composite purge tests | NOT RUN |
| 18 | `device_b_account_chooser_reopened` | PARTIAL | Google `signOut()` purge participant and re-enabled sign-in action tests | NOT RUN |
| 19 | `device_b_account_switch_isolated` | PASS | account-switch locked state plus stale preview/in-flight accept invalidation controller/widget tests | NOT RUN |
| 20 | `google_cancel_stable` | PASS | Google cancellation mapping and retryable sign-in widget test | NOT RUN |
| 21 | `google_offline_stable` | PASS | temporary Google/Supabase failure generic/retryable widget contract | NOT RUN |
| 22 | `wrong_signing_sha_fail_closed` | PASS | assetlinks drift rejection and two-device signer preflight tests | NOT RUN |
| 23 | `expired_session_fail_closed` | PASS | session repository/controller purge and protected-route denial tests | NOT RUN |
| 24 | `revoked_session_fail_closed` | PASS | provider revocation event, purge and app-shell route removal test | NOT RUN |
| 25 | `offline_launch_stable` | PASS | indeterminate restore stays locked; Today/onboarding hidden widget test | NOT RUN |
| 26 | `invite_replay_idempotent` | PASS | DB/Edge same-key replay and consumed-invite denial tests | NOT RUN |
| 27 | `concurrent_invite_accept_idempotent` | PASS | DB advisory/row locks and local Edge concurrent single-winner contract | NOT RUN |

## Coverage Summary

- device-independent automated contract PASS: 17/27
- partial SDK/OS/two-account coverage: 10/27
- actual two-device observations completed: 0/27
- completion template state: 27 `not_run`

Automated PASS 수는 실제 E2E 진행률이 아니다. completion gate는 여전히 두 device preflight와 27개 live result가 모두 `pass`일 때만 성공한다.

## Executable Observation Boundary

### Membership pair

1. A와 B 기기 모두 Today route에 진입했음을 확인한다.
2. 공유되지 않는 operator browser에서 Supabase Dashboard의 Authentication Users와 Table Editor를 연다.
3. test account A/B를 화면에서만 식별하고 `user_active_households`의 두 row가 같은 `household_id`, 서로 다른 `member_id`인지 대조한다.
4. 대응 `household_members` 두 row가 서로 다른 auth user에 속하고 `removed_at`이 비어 있는지 확인한다.
5. browser를 닫고 completion JSON에는 두 stable check의 `pass`/`fail`만 기록한다.

이메일, auth UUID, household/member UUID 또는 그 prefix/suffix를 clipboard, SQL query history, screenshot, shell history, log와 evidence에 복사하지 않는다. Table Editor에서 안전하게 대조할 수 없으면 이 두 check는 `not_run`으로 둔다.

## Authoritative Evidence Families

- auth/runtime: `WP02_01_GOOGLE_ANDROID_INTEGRATION_EVIDENCE.md`, `WP02_01_INVITE_AUTH_CONTINUATION_EVIDENCE.md`, `WP02_01_OFFLINE_AUTH_STABILITY_EVIDENCE.md`
- account isolation: `WP02_01_ACCOUNT_SWITCH_INVITE_ISOLATION_EVIDENCE.md`
- household/invite server: `WP02_03_EVIDENCE.md`, `WP02_04_EVIDENCE.md`
- Android/App Link: `WP02_01_ANDROID_EXTERNAL_READINESS_EVIDENCE.md`, `WP02_01_LIVE_APP_LINK_PROBE_EVIDENCE.md`, `WP02_01_TWO_DEVICE_PREFLIGHT_EVIDENCE.md`
- completion schema/provenance/session: `WP02_01_TWO_ADULT_E2E_EVIDENCE_CONTRACT_EVIDENCE.md`, `WP02_01_LIVE_EVIDENCE_PROVENANCE_EVIDENCE.md`, `WP02_01_LIVE_EVIDENCE_SESSION_EVIDENCE.md`

## Final Boundary

현재 자동 증거는 실제 Google chooser, Supabase remote session, two-device OS dispatch, cold lifecycle과 human observation을 대체하지 않는다. `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`를 실제로 수행해 ignored completion JSON이 APK/commit binding과 함께 validator를 통과하기 전에는 WP02-01 및 Phase 02 Exit Gate가 미완료다.
