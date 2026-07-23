# ADR-0001 — Phase 00 검증용 최소 가치 루프

- 상태: ACCEPTED
- 작성일: 2026-07-23
- 결정일: 2026-07-23
- 결정자: Product owner
- 관련 요구사항: PRD-G01, PRD-G02, FR-AUTH-001, FR-AUTH-004, FR-HH-001, FR-HH-003, FR-HH-005, FR-CHORE-001, FR-CHORE-004, FR-CHORE-009, FR-TODAY-003
- 관련 가설: H-01, H-02, H-03
- 관련 위험: RISK-022, RISK-023, RISK-024
- 대체 ADR: 없음

## Context

KinFlow의 가장 큰 제품 위험은 기능 구현 난도가 아니라 한 명의 가족 coordinator가 다른 성인을 실제로 초대하고, 초대받은 성인이 독립적으로 다시 방문해 행동하는지 여부다. 이 행동이 검증되기 전에 캘린더, Managed Child, 알림, 구독, Web Companion을 함께 구현하면 RISK-022와 RISK-024의 노출만 커진다.

제품 문서의 Activation 정의는 가입 후 7일 안에 성인 2명이 참여하고, 집안일 3개 이상을 만들고, 서로 다른 2명이 완료하고, 다음 날 Today를 다시 방문하는 것이다. Phase 00에서는 이 루프를 가장 작은 검증 단위로 사용한다.

## Decision Drivers

- 두 번째 성인의 자발적 참여가 가족 제품 성립의 선행조건이다.
- 실제 사용자 증거 없이 아동·반복·결제 복잡도를 구현하지 않는다.
- 검증 결과가 실패해도 버릴 수 있는 prototype/concierge 운영이어야 한다.
- Production 구현에 진입할 때는 household RLS 경계를 처음부터 유지해야 한다.

## Options Considered

### Option A — 전체 Store MVP 순차 구현

- 장점: 기존 Phase 문서를 그대로 따라간다.
- 단점: 핵심 참여 가설을 확인하기 전에 장기간 구현한다.
- privacy/security: Managed Child와 billing surface를 일찍 연다.
- migration/compatibility: 전체 schema와 운영 계약을 일찍 고정한다.
- 운영/비용: 기기·스토어·결제 테스트 비용이 가장 크다.

### Option B — 성인 2인 Activation slice 우선

- 장점: H-01, H-02, H-03을 가장 빠르게 검증할 수 있다.
- 단점: 캘린더 결합과 자녀 가치가 초기 결과에 포함되지 않는다.
- privacy/security: 성인 테스트 계정과 최소 household/chore 데이터만 사용한다.
- migration/compatibility: Production 구현에서는 승인된 계약을 유지하되, Phase 00 prototype 데이터는 이관하지 않는다.
- 운영/비용: 수동 운영이 필요하지만 실패 비용이 작다.

## Decision

Option B를 선택한다(D-051).

Phase 00 prototype과 concierge pilot의 기본 루프는 다음으로 제한한다.

1. 성인 coordinator가 가구를 만든다.
2. 두 번째 실제 성인을 초대한다.
3. 집안일을 3개 이상 만들고 담당자를 정한다.
4. 서로 다른 두 성인이 한 개 이상씩 완료한다.
5. 다음 날 한 명 이상이 Today에 다시 방문한다.

다음 항목은 별도 가설 통과 전 production 범위로 승인하지 않는다.

- Calendar 통합: H-04 통과 후
- Managed Child: H-05와 Store/privacy 검토 통과 후
- Production billing: H-06과 H-07 통과 후
- Web Companion/Desktop: Mobile Gate 이후

단, recurrence의 series/occurrence 분리와 서버 권위 RLS 같은 이미 ACCEPTED된 도메인 불변조건은 이후 production 구현에서 유지한다.

## Consequences

### Positive

- 가족 네트워크 효과를 가장 먼저 검증한다.
- 실패 시 coordinator-first, chores-only, adult-only 방향으로 좁힐 수 있다.
- Phase 01 이후 첫 기능 목표가 명확해진다.

### Negative / Debt

- prototype은 최종 Store MVP 범위를 보여주지 않는다.
- 수동 초대·reminder 운영이 측정에 영향을 줄 수 있으므로 개입을 기록해야 한다.
- H-04~H-07은 별도 실험이 필요하다.

## Implementation

- schema/API/module: Phase 00 prototype은 비영구 데이터 또는 폐기 가능한 저장소만 사용한다.
- feature flag: child, calendar, billing, web은 기본 OFF.
- migration: prototype 데이터를 production으로 자동 이관하지 않는다.
- observability: 초대 전송/수락, 두 번째 성인의 첫 행동, 생성/완료, 다음 날 Today 방문만 allowlist한다.
- manual setup: 실제 성인 2명 이상인 8가구 모집과 동의 기록이 필요하다.

## Validation

- automated tests: prototype event schema와 집계 규칙 검토.
- manual/device tests: 8가구 14일 concierge pilot.
- evidence: `docs/evidence/discovery/` 아래 scorecard와 pilot 결과.

## Rollback / Revisit Trigger

- rollback: prototype과 테스트 데이터를 폐기하고 production 계정으로 이관하지 않는다.
- 재검토 시점/지표: H-01, H-02, H-03 중 하나라도 실패하거나 심각한 신뢰·권한 문제가 발생할 때.

## Platform Impact (v1.0)

- target platforms: Phase 00 prototype은 mobile task 중심, production target은 iOS/Android 유지.
- capability interface/provider: 없음. prototype provider를 production adapter로 승격하지 않는다.
- unsupported fallback: calendar/child/billing은 테스트 화면 또는 설명만 제공하며 실제 mutation을 열지 않는다.
- mobile release impact: 승인 후 Phase 01과 첫 activation slice의 범위를 제한한다.
- Web Beta/GA impact: 없음.
- native/Web rollback differences: Phase 00 데이터는 모두 폐기 가능해야 한다.
