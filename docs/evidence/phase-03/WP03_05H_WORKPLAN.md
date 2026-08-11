# WP03-05H Work Plan — Occurrence history and detail

- 상태: LOCAL AUTOMATED COMPLETE / REMOTE·REAL-ACCOUNT LIVE DEFERRED
- 범위: 기존 immutable chore audit를 가구 구성원이 한 회차의 영구 활동 이력으로 조회하고 Today 상세 화면에서 이해할 수 있게 한다.
- 실제 성인 계정·2기기·remote Supabase 검증은 사용자 지시에 따라 기능 개발 후 마지막 gate로 유지한다.

## 요구사항과 결정

| ID | 이번 slice의 수용 기준 |
|---|---|
| FR-CHORE-004 | complete/reopen actor와 발생 시각을 삭제되지 않는 이력으로 조회한다. |
| FR-CHORE-007 | skip/restore/reschedule/reassign 이력을 한 회차 identity 아래 최신순으로 조회한다. series/revision과 sibling occurrence는 변경하지 않는다. |
| D-019 | 기존 series/revision/occurrence/event 분리를 유지하고 read projection만 추가한다. |
| NFR-SEC-01 | active household member만 해당 household occurrence history를 조회한다. removed member/outsider/anon과 cross-household probing은 거부한다. |
| NFR-PRIV-01 | 새 content snapshot이나 provider log를 만들지 않는다. actor/assignee 이름은 household member relation에서 읽고 response에는 auth user ID, correlation ID, title/notes를 포함하지 않는다. |
| NFR-REL-01 | `(occurred_at, source:event_id)` cursor와 bounded limit으로 중복·누락 없는 deterministic pagination을 제공한다. |
| NFR-A11Y-01 | 상세 sheet의 header, loading/error/empty/activity와 버튼을 semantics 및 large-text-safe scroll 구조로 제공한다. |
| NFR-I18N-01 | event 문구와 local date/time은 en/ko/pseudo ARB와 locale formatter를 사용한다. |

## 기능 계약

1. `get_chore_occurrence_history`는 household/occurrence, 1~100 limit과 optional cursor pair를 받는 stable read RPC다.
2. 인증과 active household membership을 서버에서 확인하고 occurrence가 같은 household에 없으면 동일한 not-found-or-forbidden 오류를 반환한다.
3. completion, skip, restore, reschedule과 assignment event를 하나의 allowlisted projection으로 합친다. restore command가 만든 legacy `reopened` event는 private command link로 `restored`로 분류한다.
4. 반환 event type은 `completed`, `reopened`, `skipped`, `restored`, `rescheduled`, `reassigned`만 허용한다.
5. 모든 row는 actor member ID/name, 발생 UTC instant와 occurrence version을 가진다. reschedule만 이전/새 local date/time을, reassignment만 이전/새 member ID/name을 가진다.
6. auth user ID, idempotency/correlation ID, title, description, raw error와 private request hash는 반환하지 않는다.
7. 최신순 `(occurred_at, history_entry_id)` keyset pagination을 사용하고 page마다 최대 요청 limit만 반환한다. `has_more=true`이면 마지막 row가 다음 cursor다.
8. 이력이 없는 유효한 occurrence는 빈 성공 page다. invalid cursor/limit/payload는 fail closed다.

## Client surface

1. provider-free domain에 history event/page/request/cursor와 variant invariant를 둔다.
2. DTO strict parser와 repository mapper는 exact key set, expected household/occurrence, UUID/date/time/UTC, event별 nullable shape, page order/uniqueness와 cursor 진행성을 검증한다.
3. Today chore card를 누르면 현재 title/notes/assignee/due/status와 영구 활동 이력을 bottom sheet로 연다.
4. loading, empty, initial failure/retry, load-more, load-more failure/retry를 별도 상태로 제공한다. 중복 load/load-more는 coalesce한다.
5. actor와 optional acting member, 이전/새 due 또는 assignee를 locale-aware 문구로 표시하며 raw provider 오류를 노출하지 않는다.

## 자동 검증

- RPC signature, stable/security-definer/search-path/grant와 response column allowlist
- anon/removed member/outsider/cross-household/unknown occurrence denial
- active owner/admin/member read, empty success와 removed historical actor display
- complete/reopen/skip/restore classification, reschedule/assignment detail shape
- deterministic newest-first ordering, equal-timestamp tie break, bounded first/next page와 invalid cursor/limit denial
- direct audit immutability와 private command state 비노출 회귀
- Dart domain invariant, strict parser, repository mapping, controller initial/load-more/retry/coalescing
- Today detail sheet loading/empty/history/error/load-more, semantics, localization, formatter/analyzer와 full regression

## 배포 중단 조건과 rollback

- 다른 household의 occurrence 존재 여부나 event/actor metadata가 노출되면 배포하지 않는다.
- auth user/correlation/title/notes/raw error/private request hash가 response나 log에 포함되면 배포하지 않는다.
- restore가 reopen으로 오분류되거나 pagination에서 event가 중복·누락되면 배포하지 않는다.
- production 적용 후 migration을 수정·삭제하지 않는다. RPC execute grant와 Today detail 진입점을 먼저 회수하고 forward migration으로 projection을 교정한다. 기존 immutable audit row는 삭제하지 않는다.

## 완료 경계

이 slice가 green이어도 Today upcoming/overdue/completed filter, resume invalidation, notification hook, remote scheduler와 실제 계정·2기기 검증이 남으므로 WP03 또는 전체 목표를 완료로 표시하지 않는다.
