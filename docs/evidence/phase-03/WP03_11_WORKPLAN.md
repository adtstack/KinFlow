# Phase 03 WP03-11 Adult Household Activation Progress Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 수직 조각: Today 진입 → 서버 권위 activation 집계 → 4단계 진행 카드 → 초대/집안일 생성 CTA → 완료 성공 후 진행률 갱신
- 요구사항: `PRD-G01`, `FR-HH-003`, `FR-HH-005`, `FR-CHORE-001`, `FR-CHORE-004`, `FR-CHORE-009`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-051`
- 정확 계약: `docs/contracts/household-activation-progress.yaml.md`
- 완료 증거: `docs/evidence/phase-03/WP03_11_EVIDENCE.md`
- 실제 계정, remote Supabase, 두 기기와 실제 Android/iOS 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- D-051의 두 번째 성인 참여, 집안일 3개 생성, 성인 두 명의 각 1회 이상 완료, 첫날 이후 Today 재방문을 하나의 진행 카드로 보여준다.
- 이 카드는 analytics dashboard가 아니라 사용자가 다음 행동을 이해하는 Today 안내다. 완료 후에도 현재 route 동안 compact complete state를 유지하며 dismiss/collapse preference는 저장하지 않는다.
- 성인 참여와 완료는 동일 계정의 재가입으로 부풀지 않도록 distinct authenticated account 기준이며, 목표값 2/3까지만 반환한다.
- 단계는 역사적 milestone이다. 구성원 제거, 집안일 soft-delete, 완료 reopen 뒤에도 이미 한 번 달성한 단계는 되돌리지 않는다.
- current active member readiness, persisted funnel analytics, exact 과거 Today 방문 ledger와 실계정 행동 분석은 이번 slice에 포함하지 않는다.

## Server and privacy contract

- `get_household_activation_progress`는 authenticated active household member에게만 exact household aggregate 한 행을 반환하는 `security definer` RPC다.
- caller identity는 JWT에서 유도하고, deleted household와 다른/removed household 접근은 기존 generic forbidden 오류로 닫는다.
- 성인 참여는 membership의 distinct auth account, 집안일 생성은 content-free `chore.series_created` domain event의 distinct series, 완료는 `completed` audit의 distinct actor account를 집계한다.
- 반환 필드는 household ID, 0..2/0..3/0..2로 capped된 세 count와 boolean 하나뿐이다. 이름, 이메일, member/user/chore/occurrence ID, title과 event timestamp는 반환하지 않는다.
- 별도 visit table/event/analytics를 만들지 않는다. Today에서 현재 RPC가 호출된 시점의 household-local date가 household creation local date보다 늦은지만 DB clock으로 계산한다.
- 따라서 마지막 단계는 “현재 Today 평가가 첫 가구 로컬 날짜 이후다”를 증명하지만, 과거의 정확한 day-two route visit을 복원하지는 않는다.

## Flutter domain and application contract

- strict DTO는 exact five-key row, exact request household ID, capped integer range와 boolean type을 검증한다. extra/missing/wrong-type/out-of-range payload는 `invalidPayload`로 닫는다.
- pure domain entity는 네 milestone과 전체 완료 여부를 파생하며 mutable collection이나 provider 타입에 의존하지 않는다.
- controller는 duplicate load를 coalesce하고 latest household request만 publish한다. load failure는 raw provider 오류 없이 retry 가능한 failure state로 바꾼다.
- projection은 persistent cache에 기록하지 않는다. Today 본문/Calendar/notification/overdue load와 병렬 실행하며 실패해도 기존 Today 콘텐츠를 막지 않는다.
- 완료 mutation 성공 뒤 projection을 다시 읽어 distinct completer 진행률을 반영한다. route에서 돌아오거나 manual refresh할 때도 다시 읽는다.

## UI, accessibility, and localization

- Today view의 기존 핵심 content/action 뒤에 4개 ordered step을 표시해 생성·초대·완료 동선의 화면 위치를 보존한다. 각 step은 완료 상태와 2/2, 3/3, 2/2 또는 날짜 경계 상태를 텍스트로도 전달하고 색/아이콘만 의존하지 않는다.
- 성인 단계는 기존 household invite creation route, 집안일 단계는 기존 normal chore creation route를 사용한다. 완료/재방문 단계는 설명만 제공한다.
- projection failure는 compact retry surface로 국소화하고 Today list·empty/error/cached content는 그대로 사용할 수 있어야 한다.
- cached Today에서는 projection을 새 cache로 오인하지 않으며 mutation CTA를 비활성화하고 기존 offline read-only 설명을 유지한다.
- EN/KO/EN-XA ARB만 사용하고 compact 320×568, 200% text, scroll, 48dp action target과 semantics를 자동 검증한다.

## Automated evidence plan

1. RPC existence, empty search path, authenticated-only execute와 generic cross-household/removed denial
2. distinct account deduplication, 2/3 caps, one-time+recurring series event count와 completed-only actor count
3. soft-delete/reopen/removal 뒤 historical milestone preservation
4. household timezone 양쪽 날짜 경계와 DB clock authority
5. strict DTO exact-key/type/range/household validation 및 repository failure mapping
6. controller duplicate/latest load, non-blocking failure/retry와 household change isolation
7. Today parallel load, invite/create CTA, completion refresh, completed state와 projection-only retry
8. KO localization, EN-XA compact 200% scroll/overflow 0와 48dp action target
9. full Flutter tests, analyzer warning 0, formatter/codegen/config/secret/contract/matrix/whitespace gates

## Stop conditions and rollback

- RPC가 current active caller authorization 없이 private audit를 읽거나 uncapped identifier/content를 반환하면 배포하지 않는다.
- client clock으로 return milestone을 계산하거나 projection 실패가 Today 전체를 막거나 persistent cache로 저장되면 배포하지 않는다.
- 동일 성인 재가입/복수 완료가 distinct-adult 목표를 부풀리거나 deleted/reopened historical milestone이 예기치 않게 회귀하면 배포하지 않는다.
- rollback은 Today card/controller/domain/ARB/tests를 제거하고 RPC를 drop한다. 새 table/event/user data가 없으므로 data cleanup은 없다.

## Completion boundary

이 slice가 green이어도 D-051의 실제 성인 2계정·remote Supabase·두 Android 기기 행동, 정확한 historical day-two visit analytics와 Phase 03 Exit Gate는 완료가 아니다. 개인정보 최소 aggregate로 사용자가 다음 activation 행동을 보고 local automation에서 테스트할 수 있는 상태만 완료로 평가한다.
