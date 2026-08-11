# Phase 04 WP04-16 Calendar Cancellation Immediate Undo Work Plan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — hosted/real-account/two-device/timezone/DST/physical-device Gate는 마지막 검증 단계로 유지한다.
- 수직 조각: 선택 회차 이후 취소의 exact pre-state ledger → actor/version-bound resume RPC → process-memory Snackbar Undo → authoritative Calendar reload
- 요구사항: `WP04-16`, `FR-CAL-004`, `FR-CAL-005`, `FR-CAL-006`, `FR-CAL-011`, `FR-CAL-012`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-066`
- 계약: `docs/contracts/calendar-series-cancellation-undo.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_16_EVIDENCE.md`

## Product boundary

- active household member가 `이 회차부터 취소`에 성공하면 현재 controller lifetime의 persistent Snackbar에서 즉시 Undo할 수 있다.
- Undo는 원래 cancellation actor·command와 exact cancellation-result series version에 결합한다. 다른 active member는 원래 command UUID를 알아도 실행할 수 없다.
- 취소가 바꾼 selected-and-later occurrence의 scheduled/completed/skipped 상태와 explicit exception semantics를 private ledger로 복원한다.
- 취소 전 source snapshot·participants·recurrence를 새 immutable resumed revision으로 복제하고, bounded terminal prefix 또는 no-prefix ended series를 다시 활성화한다.
- 취소 뒤 별도로 바뀐 prefix row는 덮어쓰지 않고, cancelled suffix row나 series version이 달라졌으면 전체 resume를 fail closed한다.
- process death 뒤 recent-cancellation history, arbitrary historical resume와 hosted/실계정/실기기 검증은 이번 조각 범위가 아니다.

## Server and compatibility contract

1. 기존 `cancel_recurring_calendar_series_from_occurrence(...)`의 exact 5개 입력·11개 결과·authenticated grant를 유지한다.
2. 기존 WP04-15 cancellation engine은 private로 이동하고 compatible public wrapper가 첫 성공 실행 전에 mutation 후보의 metadata-only pre-state를 캡처한다. replay는 ledger를 중복 생성하지 않는다.
3. private ledger는 actor+original command+occurrence, mutation kind와 previous/post status·revision·version만 저장한다. Calendar content·time·timezone·participant identity·token은 저장하지 않는다.
4. 새 `resume_recurring_calendar_series_cancellation(...)`은 resume key, household, series, original cancellation key와 exact cancellation-result version을 받는다.
5. original actor가 현재 exact household의 active member이고 series가 cancellation-result version 및 terminal/ended shape를 유지할 때만 resume한다.
6. source revision과 participants를 새 immutable revision으로 복제하고 series의 ended state를 해제하거나 terminal revision을 교체한다. removed participant가 있으면 transition을 거부한다.
7. cancellation-status ledger row는 exact post-state일 때만 모두 원래 status로 복원한다. source revision row는 새 active revision에 연결하고 existing explicit exception payload는 보존한다.
8. unchanged terminal-prefix repoint는 새 revision으로 연결하되 취소 이후 변경된 prefix row는 그대로 둔다.
9. materialization coverage를 지워 canonical worker가 resumed recurrence를 계속 확장하게 한다.
10. immutable aggregate/private audit `resumed` event와 same-key response-loss replay를 기록한다. 다른 입력이나 Calendar operation의 같은 key는 충돌한다.

## Flutter design

- domain receipt와 resume request는 household, series, original cancellation key, cancellation boundary와 exact version으로 stable retry fingerprint를 만든다.
- data source/repository는 exact 9-key result를 strict parse하고 household/series/version/revision/count invariant를 재검증한다.
- controller는 successful selected-boundary cancellation 뒤에만 receipt를 노출한다. competing mutation·household scope transition·terminal failure는 receipt를 지운다.
- transient repository failure와 server success 뒤 authoritative reload failure는 receipt와 exact resume key를 유지한다. retry는 same-key replay로 수렴한다.
- authoritative reload가 성공한 뒤에만 receipt와 retry key를 지운다. stale/forbidden/invalid transition은 receipt를 지우고 authoritative state를 읽는다.
- Snackbar는 EN/KO/EN-XA copy, persistent lifetime, scrollable compact layout과 minimum 48dp Undo target을 제공한다.
- Today Calendar cache는 successful resume repository result 뒤 invalidated되고 offline mutation/outbox나 persistent receipt는 추가하지 않는다.

## Automated evidence plan

1. legacy cancellation signature/result/grant and 48-case behavior compatibility
2. ledger immutability/privacy, exact scheduled/completed/skipped and terminal-prefix capture
3. original actor, active-member, removed/member/cross-household and unauthenticated authorization boundaries
4. terminal-prefix and no-prefix ended-series resume, new immutable revision, participants and worker continuation
5. moved explicit exception status restoration, earlier exception/prefix preservation and row/version drift rejection
6. resume same-key replay, different-input/cross-operation collision and content-free immutable event/audit
7. strict Flutter domain/DTO/repository/cache/controller/UI parsing, transient and success-reload retry identity
8. compact 320×568 EN-XA at 200% with reachable 48dp Undo action
9. clean reset, focused/full pgTAP, focused/full Flutter, analyzer, formatter, localization/codegen/config/secret/Node/docs/whitespace and Android dev APK

## DB/API impact

- forward migration: `supabase/migrations/20260810160000_calendar_series_cancellation_undo.sql`
- one private immutable metadata-only ledger, compatible operation/revision-shape constraint widening, private legacy engine and one additive authenticated resume RPC
- no public content table/column, RLS policy, Edge Function, notification payload, dependency, native permission or public configuration change

## Security and privacy

- cancellation actor binding is not authorization by itself; resume rechecks the current authenticated active household membership and exact household/series/version.
- missing, foreign, removed-actor and cross-household original cancellations share the bounded not-found-or-forbidden result.
- the ledger has no client or service-role grant and contains no event content, time, participant/display identity, email, token or arbitrary payload.
- the client keeps only identifiers, boundary and version in controller memory and never logs or persists the receipt.

## Stop conditions and rollback

- legacy cancellation signature, exact 11-key output or behavior가 바뀌면 배포하지 않는다.
- moved explicit exception이나 scheduled/completed/skipped 상태가 복원되지 않거나 later-edited prefix가 덮어써지면 배포하지 않는다.
- exact version/post-state drift가 last-write-wins로 통과하거나 다른 actor가 resume하면 배포하지 않는다.
- rollback은 Snackbar Undo를 숨기고 additive resume RPC execute를 forward migration으로 revoke한다. immutable ledger·revision·event·audit history는 삭제하거나 rewrite하지 않는다.

## Completion boundary

- local automation은 exact restoration, compatibility, authorization, optimistic concurrency, replay, strict client retry와 accessibility를 증명한다.
- hosted scheduler, actual accounts, two-device races, timezone/DST boundary, process-death product review와 Android physical-device validation은 사용자 지시에 따라 기능 개발이 충분히 진행된 마지막 Gate로 유지한다.
