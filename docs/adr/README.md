# Architecture Decision Records

`templates/ADR_TEMPLATE.md`를 복사해 `ADR-0001-short-title.md` 형식으로 저장한다. 승인된 ADR은 `DECISIONS.md`보다 구체적인 구현 기준이 되며, 대체 시 이전 ADR을 삭제하지 않고 `SUPERSEDED`로 연결한다.

## Accepted

- `ADR-0001-mvp-scope.md`: 성인 2인 최소 가치 루프
- `ADR-0002-android-first-release.md`: Android 단일 출시, dev/prod, 개인 운영, Google 로그인
- `ADR-0003-calendar-time-and-dst.md`: Calendar time primitives, server-authoritative DST gap/fold 정책과 client adapter
- `ADR-0004-push-submission-ambiguity.md`: FCM submission marker, ambiguity terminalization, bounded retry/backoff와 stale/SLO 정책
- `ADR-0005-bounded-encrypted-offline-cache.md`: Android fixed-slot encrypted read cache, user/session/household/TTL scope와 read-only policy
- `ADR-0006-server-authoritative-household-entitlement.md`: purchaser identity와 household assignment를 분리한 서버 권위형 entitlement, event ordering/idempotency와 fail-closed billing policy
