# 원본 파일 문서화: `contracts/edge-types.ts`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/edge-types.ts`
- 원본 형식: `typescript`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```typescript
/* KinFlow shared semantic types. Generated DB types remain separate. */

export type Brand<T, B extends string> = T & { readonly __brand: B };

export type UserId = Brand<string, 'UserId'>;
export type ProfileId = Brand<string, 'ProfileId'>;
export type HouseholdId = Brand<string, 'HouseholdId'>;
export type MemberId = Brand<string, 'MemberId'>;
export type InviteId = Brand<string, 'InviteId'>;
export type ChoreSeriesId = Brand<string, 'ChoreSeriesId'>;
export type ChoreOccurrenceId = Brand<string, 'ChoreOccurrenceId'>;
export type EventSeriesId = Brand<string, 'EventSeriesId'>;
export type EventOccurrenceId = Brand<string, 'EventOccurrenceId'>;
export type RequestId = Brand<string, 'RequestId'>;
export type EventId = Brand<string, 'EventId'>;
export type IdempotencyKey = Brand<string, 'IdempotencyKey'>;
export type IsoInstant = Brand<string, 'IsoInstant'>;
export type LocalDate = Brand<string, 'LocalDate'>;
export type LocalTime = Brand<string, 'LocalTime'>;
export type IanaTimeZone = Brand<string, 'IanaTimeZone'>;

export type HouseholdRole = 'owner' | 'admin' | 'member' | 'managedChild';
export type Weekday = 'MO' | 'TU' | 'WE' | 'TH' | 'FR' | 'SA' | 'SU';

export type RecurrenceEnd =
  | { readonly type: 'never' }
  | { readonly type: 'count'; readonly count: number }
  | { readonly type: 'until'; readonly localDate: LocalDate };

export type RecurrenceRule =
  | {
      readonly frequency: 'daily';
      readonly interval: number;
      readonly end: RecurrenceEnd;
    }
  | {
      readonly frequency: 'weekly';
      readonly interval: number;
      readonly weekdays: readonly Weekday[];
      readonly end: RecurrenceEnd;
    }
  | {
      readonly frequency: 'monthly';
      readonly interval: number;
      readonly monthDay: number;
      readonly end: RecurrenceEnd;
    };

export type CapabilityStatus =
  | { readonly state: 'available' }
  | { readonly state: 'permissionRequired'; readonly permission: string }
  | { readonly state: 'denied'; readonly canOpenSettings: boolean }
  | {
      readonly state: 'unsupported';
      readonly reasonKey: string;
      readonly fallback?: 'inApp' | 'email' | 'mobileApp' | 'support';
    }
  | { readonly state: 'temporarilyUnavailable'; readonly retryAfterMs?: number };

export type ErrorCode =
  | 'VALIDATION_FAILED'
  | 'CONTRACT_MISMATCH'
  | 'AUTH_REQUIRED'
  | 'SESSION_EXPIRED'
  | 'RECENT_AUTH_REQUIRED'
  | 'PERMISSION_DENIED'
  | 'NOT_FOUND_OR_FORBIDDEN'
  | 'HOUSEHOLD_NOT_FOUND'
  | 'NOT_HOUSEHOLD_MEMBER'
  | 'ROLE_NOT_ALLOWED'
  | 'LAST_OWNER_REQUIRED'
  | 'OWNER_TRANSFER_REQUIRED'
  | 'INVITE_INVALID'
  | 'INVITE_EXPIRED'
  | 'INVITE_REVOKED'
  | 'INVITE_ALREADY_USED'
  | 'INVITE_EMAIL_MISMATCH'
  | 'INVITE_LIMIT_REACHED'
  | 'ACTING_CONTEXT_INVALID'
  | 'ACTING_CONTEXT_EXPIRED'
  | 'PARENTAL_GATE_REQUIRED'
  | 'VERSION_CONFLICT'
  | 'IDEMPOTENCY_KEY_REQUIRED'
  | 'IDEMPOTENCY_KEY_REUSED'
  | 'OPERATION_IN_PROGRESS'
  | 'INVALID_STATE_TRANSITION'
  | 'RECURRENCE_RULE_INVALID'
  | 'RECURRENCE_LIMIT_EXCEEDED'
  | 'RESOURCE_LIMIT_EXCEEDED'
  | 'FEATURE_DISABLED'
  | 'PLAN_LIMIT_REACHED'
  | 'ENTITLEMENT_REQUIRED'
  | 'ENTITLEMENT_PENDING'
  | 'BILLING_ASSIGNMENT_CONFLICT'
  | 'PURCHASE_CANCELLED'
  | 'PROVIDER_UNAVAILABLE'
  | 'NOTIFICATION_PERMISSION_REQUIRED'
  | 'CAPABILITY_UNSUPPORTED'
  | 'PRIVACY_REQUEST_ALREADY_PENDING'
  | 'RATE_LIMITED'
  | 'TEMPORARILY_UNAVAILABLE'
  | 'INTERNAL_ERROR';

export interface ApiMeta {
  readonly requestId: RequestId;
  readonly contractVersion: '2026-07-21';
  readonly nextCursor?: string;
}

export type ApiSuccess<T> = {
  readonly data: T;
  readonly meta: ApiMeta;
};

export type ApiFailure = {
  readonly error: {
    readonly code: ErrorCode;
    readonly messageKey: string;
    readonly details?: Readonly<Record<string, unknown>>;
    readonly retryable: boolean;
    readonly requestId: RequestId;
  };
};

export type ApiResponse<T> = ApiSuccess<T> | ApiFailure;

export type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

export interface ActingContext {
  readonly householdId: HouseholdId;
  readonly authenticatedUserId: UserId;
  readonly actorMemberId: MemberId;
  readonly actingMemberId?: MemberId;
  readonly expiresAt?: IsoInstant;
}

export type EntitlementStatus =
  | 'none'
  | 'trialing'
  | 'active'
  | 'grace'
  | 'billingIssue'
  | 'expired'
  | 'revoked';

export interface EntitlementSnapshot {
  readonly householdId: HouseholdId;
  readonly plan: 'free' | 'plus';
  readonly status: EntitlementStatus;
  readonly features: Readonly<Record<string, boolean | number>>;
  readonly verifiedAt: IsoInstant;
  readonly version: number;
}

export interface DomainEvent<TPayload extends Readonly<Record<string, unknown>>> {
  readonly eventId: EventId;
  readonly eventType: string;
  readonly eventVersion: number;
  readonly occurredAt: IsoInstant;
  readonly householdId: HouseholdId | null;
  readonly actorUserId: UserId | null;
  readonly actorMemberId: MemberId | null;
  readonly actingMemberId: MemberId | null;
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly aggregateVersion: number | null;
  readonly correlationId: RequestId;
  readonly causationId: EventId | null;
  readonly payload: TPayload;
}
```
