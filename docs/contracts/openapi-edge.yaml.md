# 원본 파일 문서화: `contracts/openapi-edge.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/openapi-edge.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
openapi: 3.1.0
info:
  title: KinFlow Edge API
  version: "2026-08-08-wp07-03a"
  description: >-
    Normative contract for transactional and provider-backed operations.
    Simple RLS-protected reads/writes may use Supabase Data API and are not duplicated here.
servers:
  - url: https://{projectRef}.supabase.co/functions/v1/api
    variables:
      projectRef:
        default: example
security:
  - bearerAuth: []
tags:
  - name: Household
  - name: Invite
  - name: Member
  - name: Chore
  - name: Calendar
  - name: Today
  - name: Notification
  - name: Billing
  - name: Privacy
paths:
  /households:
    post:
      tags: [Household]
      operationId: createHousehold
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateHouseholdRequest'
      responses:
        '201':
          $ref: '#/components/responses/HouseholdResponse'
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '401': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/invites:
    post:
      tags: [Invite]
      operationId: createInvite
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateInviteRequest'
      responses:
        '201': {$ref: '#/components/responses/InviteResponse'}
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '429': {$ref: '#/components/responses/ErrorResponse'}
  /invites/preview:
    post:
      tags: [Invite]
      security: []
      operationId: previewInvite
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/InviteTokenRequest'
      responses:
        '200': {$ref: '#/components/responses/InvitePreviewResponse'}
        '404': {$ref: '#/components/responses/ErrorResponse'}
        '410': {$ref: '#/components/responses/ErrorResponse'}
        '429': {$ref: '#/components/responses/ErrorResponse'}
  /invites/accept:
    post:
      tags: [Invite]
      operationId: acceptInvite
      x-kinflow-stable-errors:
        - FEATURE_POLICY_UNAVAILABLE
        - FEATURE_LIMIT_REACHED
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/AcceptInviteRequest'
      responses:
        '200': {$ref: '#/components/responses/InviteMemberResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '410': {$ref: '#/components/responses/ErrorResponse'}
        '429': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/owner-transfer:
    post:
      tags: [Household, Member]
      operationId: transferHouseholdOwner
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [newOwnerMemberId, expectedVersion]
              properties:
                newOwnerMemberId: {$ref: '#/components/schemas/Uuid'}
                expectedVersion: {type: integer, minimum: 1}
      responses:
        '200': {$ref: '#/components/responses/HouseholdResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/members/{memberId}/role:
    put:
      tags: [Member]
      operationId: changeMemberRole
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/MemberId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [role, expectedVersion]
              properties:
                role:
                  $ref: '#/components/schemas/AdultRole'
                expectedVersion: {type: integer, minimum: 1}
      responses:
        '200': {$ref: '#/components/responses/MemberResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /households/{householdId}/acting-contexts:
    post:
      tags: [Member]
      operationId: createActingContext
      parameters:
        - $ref: '#/components/parameters/HouseholdId'
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [managedChildMemberId]
              properties:
                managedChildMemberId: {$ref: '#/components/schemas/Uuid'}
                deviceBinding: {type: string, minLength: 16, maxLength: 256}
      responses:
        '201':
          description: Acting context created
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/ActingContext'
        '403': {$ref: '#/components/responses/ErrorResponse'}
  /chores/occurrences/{occurrenceId}/complete:
    post:
      tags: [Chore]
      operationId: completeChoreOccurrence
      parameters:
        - $ref: '#/components/parameters/OccurrenceId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [expectedVersion]
              properties:
                expectedVersion: {type: integer, minimum: 1}
                completedAtClient: {type: string, format: date-time}
      responses:
        '200': {$ref: '#/components/responses/ChoreOccurrenceResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /chores/series/{seriesId}:
    put:
      tags: [Chore]
      operationId: reviseChoreSeries
      parameters:
        - $ref: '#/components/parameters/SeriesId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviseSeriesRequest'
      responses:
        '200': {$ref: '#/components/responses/SeriesResponse'}
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /calendar/series/{seriesId}:
    put:
      tags: [Calendar]
      operationId: reviseCalendarSeries
      parameters:
        - $ref: '#/components/parameters/SeriesId'
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/ActingContext'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ReviseSeriesRequest'
      responses:
        '200': {$ref: '#/components/responses/SeriesResponse'}
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /today:
    get:
      tags: [Today]
      operationId: getToday
      parameters:
        - $ref: '#/components/parameters/HouseholdIdQuery'
        - name: localDate
          in: query
          required: true
          schema: {type: string, format: date}
        - name: limit
          in: query
          schema: {type: integer, minimum: 1, maximum: 500, default: 200}
      responses:
        '200':
          description: Today aggregate
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/TodayPayload'
        '403': {$ref: '#/components/responses/ErrorResponse'}
  /notification-endpoint:
    post:
      tags: [Notification]
      operationId: registerNotificationEndpoint
      description: >-
        WP05-03 native-push registration. The function authenticates the bearer
        token with GoTrue, seals the raw provider token in Edge memory, and returns
        metadata only. Query parameters and undeclared body properties are rejected.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      parameters:
        - name: idempotency-key
          in: header
          required: true
          schema: {$ref: '#/components/schemas/Uuid'}
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/NotificationEndpointRegistrationRequest'
      responses:
        '200':
          description: Endpoint registered, refreshed, rotated, or replayed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEndpointRegistrationResponse'
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '401': {$ref: '#/components/responses/ErrorResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '404': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
    delete:
      tags: [Notification]
      operationId: revokeNotificationEndpoint
      description: >-
        Revokes a binding using its account-bound secret proof. A live bearer
        token is not required, and the response never discloses endpoint existence.
        Query parameters and undeclared body properties are rejected.
      security: []
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/NotificationEndpointRevocationRequest'
      responses:
        '200':
          description: Generic idempotent revocation acknowledgement
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEndpointRevocationResponse'
        '400': {$ref: '#/components/responses/ErrorResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
  /notification-push-worker:
    post:
      tags: [Notification]
      operationId: runNotificationPushWorkerBatch
      description: >-
        WP05-04/05 server-only Android FCM batch. It accepts no query or request
        body, authorizes an exact dedicated Bearer secret, marks the provider
        submission boundary before FCM I/O, opens sealed endpoint tokens only in
        worker memory, and returns aggregate counts only.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      security:
        - pushWorkerAuth: []
      responses:
        '200':
          description: One bounded push batch completed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationPushWorkerResponse'
        '400':
          description: Body or query parameters are forbidden
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationPushWorkerErrorResponse'
        '401':
          description: Dedicated worker secret missing or incorrect
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationPushWorkerErrorResponse'
        '405':
          description: Only POST is accepted
          headers:
            Allow: {schema: {type: string, const: POST}}
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationPushWorkerErrorResponse'
        '503':
          description: Worker configuration, claim, or provider boundary unavailable
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationPushWorkerErrorResponse'
  /notification-email-worker:
    post:
      tags: [Notification]
      operationId: runNotificationEmailWorkerBatch
      description: >-
        WP05-14 server-only generic email fallback batch. It accepts no query
        or request body, authorizes an exact dedicated Bearer secret, resolves
        one confirmed Auth email only in the service claim, records a durable
        submission marker before fixed SendGrid I/O, and returns aggregate
        counts only. No address or family content is persisted in its queue.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      security:
        - emailWorkerAuth: []
      responses:
        '200':
          description: One bounded email batch completed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEmailWorkerResponse'
        '400':
          description: Body or query parameters are forbidden
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEmailWorkerErrorResponse'
        '401':
          description: Dedicated worker secret missing or incorrect
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEmailWorkerErrorResponse'
        '405':
          description: Only POST is accepted
          headers:
            Allow: {schema: {type: string, const: POST}}
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEmailWorkerErrorResponse'
        '503':
          description: Worker configuration, claim, marker, completion, or provider boundary unavailable
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/NotificationEmailWorkerErrorResponse'
  /billing/sync:
    post:
      tags: [Billing]
      operationId: syncBillingCustomer
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [provider, householdId]
              properties:
                provider: {type: string, enum: [appStore, playStore, web]}
                householdId: {$ref: '#/components/schemas/Uuid'}
      responses:
        '200': {$ref: '#/components/responses/EntitlementResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
  /billing/assign-household:
    post:
      tags: [Billing]
      operationId: assignBillingHousehold
      description: >-
        WP06-05 purchase/restore preflight. The deployed client invokes the
        equivalent Supabase RPC public.prepare_billing_household_assignment;
        this route is the provider-neutral API facade contract. The server
        derives provider, environment and customer identity from trusted
        runtime/auth context and never accepts them from this request.
      x-runtime-rpc: public.prepare_billing_household_assignment
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [householdId]
              properties:
                householdId: {$ref: '#/components/schemas/Uuid'}
      responses:
        '200': {$ref: '#/components/responses/BillingAssignmentPrepareResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
  /billing/assignment-status/{householdId}:
    get:
      tags: [Billing]
      operationId: getBillingHouseholdAssignmentStatus
      description: >-
        Aggregate assignment projection for an active household member. It
        omits provider/customer/transaction references, the billing-owner user
        ID and every other household ID.
      x-runtime-rpc: public.get_billing_household_assignment_status
      parameters:
        - name: householdId
          in: path
          required: true
          schema: {$ref: '#/components/schemas/Uuid'}
      responses:
        '200': {$ref: '#/components/responses/BillingAssignmentStatusResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
  /billing/release-household:
    post:
      tags: [Billing]
      operationId: releaseBillingHouseholdAssignment
      description: >-
        Idempotently releases only a current-user provisional assignment.
        Confirmed bindings return supportRequired and are never moved by a
        client command.
      x-runtime-rpc: public.release_billing_household_assignment
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [householdId, expectedAssignmentVersion]
              properties:
                householdId: {$ref: '#/components/schemas/Uuid'}
                expectedAssignmentVersion: {type: integer, minimum: 1}
      responses:
        '200': {$ref: '#/components/responses/BillingAssignmentReleaseResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /billing/assignment-remediation:
    post:
      tags: [Billing]
      operationId: requestBillingAssignmentRemediation
      description: >-
        Opens or reuses an aggregate support request. Free-form case text and
        provider/customer identifiers are not accepted or returned.
      x-runtime-rpc: public.request_billing_assignment_remediation
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [householdId, issueKind]
              properties:
                householdId: {$ref: '#/components/schemas/Uuid'}
                issueKind:
                  type: string
                  enum:
                    - customerConflict
                    - householdConflict
                    - ownerMembershipChanged
                    - restoreConflict
      responses:
        '200': {$ref: '#/components/responses/BillingAssignmentRemediationResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '503': {$ref: '#/components/responses/ErrorResponse'}
  /revenuecat-webhook:
    post:
      tags: [Billing]
      description: >-
        WP06-04 RevenueCat ingress. Both the configured full Authorization
        value and the raw-body HMAC are required before JSON parsing. The body
        is limited to 256 KiB, query parameters are forbidden, and successful
        queue, replay, ignore, or manual-review routing returns quickly without
        provider identifiers.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      security:
        - webhookAuth: []
          revenueCatSignature: []
      operationId: receiveRevenueCatWebhook
      requestBody:
        required: true
        content:
          application/json:
            schema: {$ref: '#/components/schemas/RevenueCatWebhookRequest'}
      responses:
        '200':
          description: Durable aggregate acknowledgement
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingWebhookResponse'}
        '400':
          description: Invalid content type, query, JSON, or common event fields
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '401':
          description: Authorization or raw-body HMAC rejected
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '405':
          description: Only POST is accepted
          headers:
            Allow: {schema: {type: string, const: POST}}
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '409':
          description: Provider event ID was reused with a different raw body
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '413':
          description: Request body exceeds 256 KiB
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '503':
          description: Durable enqueue is temporarily unavailable
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
  /billing-reconciliation-worker:
    post:
      tags: [Billing]
      operationId: runBillingReconciliationBatch
      description: >-
        WP06-04 server-only empty POST. It schedules stale assigned customers,
        claims a bounded leased batch, fetches the authoritative RevenueCat v1
        subscriber snapshot, applies a normalized reconciliation event, and
        returns aggregate counts only. Missing household assignment fails closed.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      security:
        - billingWorkerAuth: []
      responses:
        '200':
          description: One bounded reconciliation batch completed
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingReconciliationWorkerResponse'}
        '400':
          description: Body or query parameters are forbidden
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '401':
          description: Dedicated worker Bearer secret missing or incorrect
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '405':
          description: Only POST is accepted
          headers:
            Allow: {schema: {type: string, const: POST}}
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
        '503':
          description: Scheduling, claim, completion, or worker configuration unavailable
          content:
            application/json:
              schema: {$ref: '#/components/schemas/BillingEdgeErrorResponse'}
  /account-deletion:
    post:
      tags: [Privacy]
      operationId: accountDeletionCommand
      description: >-
        WP07-01 exact-shape operation endpoint. Idempotency-Key is required for
        request and cancel; X-KinFlow-Recent-Auth is additionally required for
        request and must prove same-user OAuth within 600 seconds.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      x-kinflow-contract-version: '2026-08-08-wp07-01'
      x-kinflow-stable-errors:
        - AUTH_REQUIRED
        - IDEMPOTENCY_KEY_REQUIRED
        - IDEMPOTENCY_KEY_REUSED
        - NOT_FOUND
        - OWNER_TRANSFER_REQUIRED
        - PERMISSION_DENIED
        - PRIVACY_REQUEST_ALREADY_PENDING
        - RECENT_AUTH_REQUIRED
        - REQUEST_NOT_CANCELLABLE
        - REQUESTS_PAUSED
        - SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED
        - TEMPORARILY_UNAVAILABLE
        - VALIDATION_FAILED
        - VERSION_CONFLICT
      parameters:
        - name: Idempotency-Key
          in: header
          required: false
          description: Required only for request and cancel operations.
          schema: {type: string, minLength: 16, maxLength: 200}
        - name: X-KinFlow-Recent-Auth
          in: header
          required: false
          description: Required only for request; never forwarded to the database.
          schema: {type: string, minLength: 16, maxLength: 2048}
      requestBody:
        required: true
        content:
          application/json:
            schema: {$ref: '#/components/schemas/AccountDeletionOperationRequest'}
      responses:
        '200':
          description: Preflight, status, or cancellation result
          content:
            application/json:
              schema: {$ref: '#/components/schemas/AccountDeletionResponse'}
        '202':
          description: Deletion request accepted and delayed for cancellation
          content:
            application/json:
              schema: {$ref: '#/components/schemas/AccountDeletionResponse'}
        '400': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '401': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '403': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '404': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '409': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '503': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
  /account-deletion-worker:
    post:
      tags: [Privacy]
      operationId: processAccountDeletionRequests
      security:
        - accountDeletionWorkerAuth: []
      description: Dedicated scheduler call with an empty POST body.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      x-kinflow-contract-version: '2026-08-08-wp07-01'
      responses:
        '200':
          description: Aggregate processing result without user or request identifiers
          content:
            application/json:
              schema: {$ref: '#/components/schemas/AccountDeletionWorkerResponse'}
        '400': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '401': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '405': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
        '503': {$ref: '#/components/responses/AccountDeletionErrorResponse'}
  /data-export:
    post:
      tags: [Privacy]
      operationId: personalDataExportCommand
      description: >-
        WP07-02A exact-shape personal export endpoint. Request, download and
        revoke require same-user OAuth within 600 seconds. Request, cancel and
        revoke use Idempotency-Key. Download returns a one-time URL only.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      x-kinflow-contract-version: '2026-08-08-wp07-02a'
      x-kinflow-stable-errors:
        - ARTIFACT_UNAVAILABLE
        - AUTH_REQUIRED
        - DOWNLOADS_PAUSED
        - EXPORT_TOO_LARGE
        - IDEMPOTENCY_KEY_REQUIRED
        - IDEMPOTENCY_KEY_REUSED
        - NOT_FOUND
        - PERMISSION_DENIED
        - PRIVACY_REQUEST_ALREADY_PENDING
        - RECENT_AUTH_REQUIRED
        - REQUEST_NOT_CANCELLABLE
        - REQUESTS_PAUSED
        - TEMPORARILY_UNAVAILABLE
        - VALIDATION_FAILED
        - VERSION_CONFLICT
      parameters:
        - name: Idempotency-Key
          in: header
          required: false
          description: Required for request, cancel and revoke operations.
          schema: {type: string, minLength: 16, maxLength: 200}
        - name: X-KinFlow-Recent-Auth
          in: header
          required: false
          description: Required for request, download and revoke; never forwarded to PostgreSQL.
          schema: {type: string, minLength: 16, maxLength: 2048}
      requestBody:
        required: true
        content:
          application/json:
            schema: {$ref: '#/components/schemas/DataExportOperationRequest'}
      responses:
        '200':
          description: Preflight, status, cancel, revoke or one-time download result
          content:
            application/json:
              schema: {$ref: '#/components/schemas/DataExportResponse'}
        '202':
          description: Personal export generation accepted
          content:
            application/json:
              schema: {$ref: '#/components/schemas/DataExportResponse'}
        '400': {$ref: '#/components/responses/DataExportErrorResponse'}
        '401': {$ref: '#/components/responses/DataExportErrorResponse'}
        '403': {$ref: '#/components/responses/DataExportErrorResponse'}
        '404': {$ref: '#/components/responses/DataExportErrorResponse'}
        '409': {$ref: '#/components/responses/DataExportErrorResponse'}
        '410': {$ref: '#/components/responses/DataExportErrorResponse'}
        '413': {$ref: '#/components/responses/DataExportErrorResponse'}
        '503': {$ref: '#/components/responses/DataExportErrorResponse'}
  /data-export-worker:
    post:
      tags: [Privacy]
      operationId: processPersonalDataExports
      security:
        - dataExportWorkerAuth: []
      description: Dedicated scheduler call with an empty POST body.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      x-kinflow-contract-version: '2026-08-08-wp07-02a'
      responses:
        '200':
          description: Aggregate generation and purge result without identifiers
          content:
            application/json:
              schema: {$ref: '#/components/schemas/DataExportWorkerResponse'}
        '400': {$ref: '#/components/responses/DataExportErrorResponse'}
        '401': {$ref: '#/components/responses/DataExportErrorResponse'}
        '405': {$ref: '#/components/responses/DataExportErrorResponse'}
        '503': {$ref: '#/components/responses/DataExportErrorResponse'}
  /data-export-download:
    get:
      tags: [Privacy]
      operationId: consumePersonalDataExportDownload
      security: []
      description: >-
        Atomically consumes one hash-only grant and streams a checksum-verified
        private JSON or text artifact with no-store attachment headers.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef:
              default: example
      x-kinflow-contract-version: '2026-08-08-wp07-02a'
      parameters:
        - name: token
          in: query
          required: true
          schema: {type: string, pattern: '^[A-Za-z0-9_-]{43}$'}
      responses:
        '200':
          description: One JSON or readable-text attachment, maximum 10 MiB
          headers:
            Cache-Control: {schema: {type: string, const: 'private, no-store, max-age=0'}}
            Content-Disposition: {schema: {type: string}}
            X-Content-Sha256: {schema: {type: string, pattern: '^[0-9a-f]{64}$'}}
          content:
            application/json: {schema: {type: string, format: binary}}
            text/plain: {schema: {type: string, format: binary}}
        '410': {$ref: '#/components/responses/DataExportErrorResponse'}
        '405': {$ref: '#/components/responses/DataExportErrorResponse'}
        '503': {$ref: '#/components/responses/DataExportErrorResponse'}
  /household-privacy:
    post:
      tags: [Privacy]
      operationId: householdPrivacyCommand
      description: >-
        WP07-02B current-Owner exact-shape household export and deletion
        endpoint. Export request/download/revoke and deletion request require
        same-user OAuth within 600 seconds. Mutations use Idempotency-Key.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef: {default: example}
      x-kinflow-contract-version: '2026-08-08-wp07-02b'
      x-kinflow-stable-errors:
        - ARTIFACT_UNAVAILABLE
        - AUTH_REQUIRED
        - CONFIRMATION_MISMATCH
        - DELETION_REQUESTS_PAUSED
        - DOWNLOADS_PAUSED
        - EXPORT_REQUESTS_PAUSED
        - HOUSEHOLD_ALREADY_DELETED
        - IDEMPOTENCY_KEY_REQUIRED
        - IDEMPOTENCY_KEY_REUSED
        - NOT_FOUND
        - OWNER_REQUIRED
        - PRIVACY_REQUEST_ALREADY_PENDING
        - RECENT_AUTH_REQUIRED
        - REQUEST_NOT_MUTABLE
        - SUBSCRIPTION_ACK_REQUIRED
        - TEMPORARILY_UNAVAILABLE
        - VALIDATION_FAILED
        - VERSION_CONFLICT
      parameters:
        - name: Idempotency-Key
          in: header
          required: false
          description: Required for request, cancel, and revoke operations.
          schema: {type: string, minLength: 16, maxLength: 200}
        - name: X-KinFlow-Recent-Auth
          in: header
          required: false
          description: Required for export request/download/revoke and deletion request.
          schema: {type: string, minLength: 16, maxLength: 2048}
      requestBody:
        required: true
        content:
          application/json:
            schema: {$ref: '#/components/schemas/HouseholdPrivacyOperationRequest'}
      responses:
        '200':
          description: Preflight, status, cancel, revoke, or one-time download result
          content:
            application/json:
              schema: {$ref: '#/components/schemas/HouseholdPrivacyResponse'}
        '202':
          description: Household export generation or deletion accepted
          content:
            application/json:
              schema: {$ref: '#/components/schemas/HouseholdPrivacyResponse'}
        '400': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '401': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '403': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '404': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '409': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '410': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '503': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
  /household-privacy-worker:
    post:
      tags: [Privacy]
      operationId: processHouseholdPrivacyRequests
      security:
        - householdPrivacyWorkerAuth: []
      description: >-
        Dedicated empty-body scheduler call for bounded household export,
        artifact purge, and deletion leases.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef: {default: example}
      x-kinflow-contract-version: '2026-08-08-wp07-02b'
      responses:
        '200':
          description: Aggregate processing counters without identifiers
          content:
            application/json:
              schema: {$ref: '#/components/schemas/HouseholdPrivacyWorkerResponse'}
        '400': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '401': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '405': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '503': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
  /household-export-download:
    get:
      tags: [Privacy]
      operationId: consumeHouseholdExportDownload
      security: []
      description: >-
        Atomically consumes one hash-only grant and streams one checksum-verified
        private household JSON or text artifact with no-store headers.
      servers:
        - url: https://{projectRef}.supabase.co/functions/v1
          variables:
            projectRef: {default: example}
      x-kinflow-contract-version: '2026-08-08-wp07-02b'
      parameters:
        - name: token
          in: query
          required: true
          schema: {type: string, pattern: '^[A-Za-z0-9_-]{43}$'}
      responses:
        '200':
          description: One household JSON or readable-text attachment, maximum 20 MiB
          headers:
            Cache-Control: {schema: {type: string, const: 'private, no-store, max-age=0'}}
            Content-Disposition: {schema: {type: string}}
            X-Content-Sha256: {schema: {type: string, pattern: '^[0-9a-f]{64}$'}}
          content:
            application/json: {schema: {type: string, format: binary}}
            text/plain: {schema: {type: string, format: binary}}
        '410': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '405': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
        '503': {$ref: '#/components/responses/HouseholdPrivacyErrorResponse'}
  /privacy/requests:
    post:
      tags: [Privacy]
      operationId: createPrivacyRequest
      description: >-
        Legacy deferred facade retained only as a future compatibility shape.
        Implemented personal export, account deletion, and Owner household
        privacy flows use the versioned /data-export, /account-deletion, and
        /household-privacy operation endpoints above.
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
        - $ref: '#/components/parameters/RecentAuth'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              additionalProperties: false
              required: [type]
              properties:
                type: {type: string, enum: [export, deleteHousehold]}
                householdId: {$ref: '#/components/schemas/Uuid'}
      responses:
        '202':
          description: Request accepted
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/PrivacyRequest'
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /privacy/requests/{requestId}:
    get:
      tags: [Privacy]
      operationId: getPrivacyRequest
      parameters:
        - name: requestId
          in: path
          required: true
          schema: {$ref: '#/components/schemas/Uuid'}
      responses:
        '200':
          description: Privacy request status
          content:
            application/json:
              schema:
                allOf:
                  - $ref: '#/components/schemas/SuccessEnvelope'
                  - type: object
                    properties:
                      data:
                        $ref: '#/components/schemas/PrivacyRequest'
        '404': {$ref: '#/components/responses/ErrorResponse'}
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    pushWorkerAuth:
      type: http
      scheme: bearer
      bearerFormat: opaque dedicated scheduler secret
    emailWorkerAuth:
      type: http
      scheme: bearer
      bearerFormat: opaque dedicated scheduler secret
    billingWorkerAuth:
      type: http
      scheme: bearer
    accountDeletionWorkerAuth:
      type: http
      scheme: bearer
      bearerFormat: opaque dedicated scheduler secret
    dataExportWorkerAuth:
      type: http
      scheme: bearer
      bearerFormat: opaque dedicated scheduler secret
    householdPrivacyWorkerAuth:
      type: http
      scheme: bearer
      bearerFormat: opaque dedicated scheduler secret
    webhookAuth:
      type: apiKey
      in: header
      name: Authorization
    revenueCatSignature:
      type: apiKey
      in: header
      name: X-RevenueCat-Webhook-Signature
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: true
      schema: {type: string, minLength: 16, maxLength: 200}
    RecentAuth:
      name: X-KinFlow-Recent-Auth
      in: header
      required: true
      schema: {type: string, minLength: 16, maxLength: 2048}
    ActingContext:
      name: X-KinFlow-Acting-Context
      in: header
      required: false
      schema: {type: string, minLength: 16, maxLength: 2048}
    HouseholdId:
      name: householdId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    HouseholdIdQuery:
      name: householdId
      in: query
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    MemberId:
      name: memberId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    OccurrenceId:
      name: occurrenceId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
    SeriesId:
      name: seriesId
      in: path
      required: true
      schema: {$ref: '#/components/schemas/Uuid'}
  schemas:
    Uuid: {type: string, format: uuid}
    AdultRole: {type: string, enum: [owner, admin, member]}
    ErrorEnvelope:
      type: object
      additionalProperties: false
      required: [error]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, messageKey, retryable, requestId]
          properties:
            code: {type: string}
            messageKey: {type: string}
            details: {type: object, additionalProperties: true}
            retryable: {type: boolean}
            requestId: {$ref: '#/components/schemas/Uuid'}
    SuccessEnvelope:
      type: object
      required: [data, meta]
      properties:
        data: {}
        meta:
          type: object
          required: [requestId, contractVersion]
          properties:
            requestId: {$ref: '#/components/schemas/Uuid'}
            contractVersion: {type: string, const: '2026-07-21'}
    InviteSuccessEnvelope:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {}
        meta:
          type: object
          additionalProperties: false
          required: [requestId, contractVersion]
          properties:
            requestId: {$ref: '#/components/schemas/Uuid'}
            contractVersion: {type: string, const: '2026-08-08-wp06-06'}
    CreateHouseholdRequest:
      type: object
      additionalProperties: false
      required: [name, timezone]
      properties:
        name: {type: string, minLength: 1, maxLength: 80}
        timezone: {type: string, minLength: 1, maxLength: 100}
    Household:
      type: object
      required: [id, name, timezone, ownerMemberId, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        name: {type: string}
        timezone: {type: string}
        ownerMemberId: {$ref: '#/components/schemas/Uuid'}
        version: {type: integer, minimum: 1}
    CreateInviteRequest:
      type: object
      additionalProperties: false
      required: [role]
      properties:
        role: {type: string, enum: [admin, member]}
        targetEmail: {type: string, format: email}
        expiresInHours: {type: integer, minimum: 1, maximum: 720, default: 168}
    InviteTokenRequest:
      oneOf:
        - type: object
          additionalProperties: false
          required: [token]
          properties:
            token:
              type: string
              minLength: 20
              maxLength: 512
              pattern: '^[A-Za-z0-9_-]+$'
        - type: object
          additionalProperties: false
          required: [shortCode]
          properties:
            shortCode:
              type: string
              minLength: 8
              maxLength: 16
              description: >-
                Eight unambiguous symbols, optionally formatted with ASCII spaces
                or a hyphen; normalized and hashed before database access.
    AcceptInviteRequest:
      oneOf:
        - type: object
          additionalProperties: false
          required: [token]
          properties:
            token:
              type: string
              minLength: 20
              maxLength: 512
              pattern: '^[A-Za-z0-9_-]+$'
            setActiveHousehold: {type: boolean, default: true}
        - type: object
          additionalProperties: false
          required: [shortCode]
          properties:
            shortCode:
              type: string
              minLength: 8
              maxLength: 16
              description: >-
                Eight unambiguous symbols, optionally formatted with ASCII spaces
                or a hyphen.
            setActiveHousehold: {type: boolean, default: true}
    Invite:
      type: object
      additionalProperties: false
      required: [id, householdId, role, expiresAt, status]
      oneOf:
        - required: [rawToken, shortCode, shortCodeExpiresAt]
        - not:
            anyOf:
              - required: [rawToken]
              - required: [shortCode]
              - required: [shortCodeExpiresAt]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        role: {type: string, enum: [admin, member]}
        expiresAt: {type: string, format: date-time}
        status: {type: string, enum: [active, accepted, revoked, expired]}
        rawToken:
          type: string
          description: Returned only once at creation and never stored in plaintext.
        shortCode:
          type: string
          pattern: '^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}$'
          description: Returned with rawToken only once at creation; never stored in plaintext.
        shortCodeExpiresAt:
          type: string
          format: date-time
          description: At most 24 hours after creation and never after expiresAt.
    InvitePreview:
      type: object
      additionalProperties: false
      required: [valid, householdDisplayName, inviterDisplayName, role, expiresAt]
      properties:
        valid: {type: boolean}
        householdDisplayName: {type: string}
        inviterDisplayName: {type: string}
        role: {type: string, enum: [admin, member]}
        expiresAt: {type: string, format: date-time}
    Member:
      type: object
      required: [id, householdId, displayName, role, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        authUserId: {$ref: '#/components/schemas/Uuid'}
        displayName: {type: string}
        role: {type: string, enum: [owner, admin, member, managedChild]}
        version: {type: integer, minimum: 1}
    ActingContext:
      type: object
      required: [contextToken, householdId, actingMemberId, expiresAt]
      properties:
        contextToken: {type: string}
        householdId: {$ref: '#/components/schemas/Uuid'}
        actingMemberId: {$ref: '#/components/schemas/Uuid'}
        expiresAt: {type: string, format: date-time}
    RecurrenceEnd:
      oneOf:
        - type: object
          additionalProperties: false
          required: [type]
          properties: {type: {const: never}}
        - type: object
          additionalProperties: false
          required: [type, count]
          properties:
            type: {const: count}
            count: {type: integer, minimum: 1, maximum: 1000}
        - type: object
          additionalProperties: false
          required: [type, localDate]
          properties:
            type: {const: until}
            localDate: {type: string, format: date}
    RecurrenceRule:
      oneOf:
        - type: object
          additionalProperties: false
          required: [frequency, interval, end]
          properties:
            frequency: {const: daily}
            interval: {type: integer, minimum: 1, maximum: 30}
            end: {$ref: '#/components/schemas/RecurrenceEnd'}
        - type: object
          additionalProperties: false
          required: [frequency, interval, weekdays, end]
          properties:
            frequency: {const: weekly}
            interval: {type: integer, minimum: 1, maximum: 30}
            weekdays:
              type: array
              minItems: 1
              uniqueItems: true
              items: {type: string, enum: [MO, TU, WE, TH, FR, SA, SU]}
            end: {$ref: '#/components/schemas/RecurrenceEnd'}
        - type: object
          additionalProperties: false
          required: [frequency, interval, monthDay, end]
          properties:
            frequency: {const: monthly}
            interval: {type: integer, minimum: 1, maximum: 30}
            monthDay: {type: integer, minimum: 1, maximum: 31}
            end: {$ref: '#/components/schemas/RecurrenceEnd'}
    ReviseSeriesRequest:
      type: object
      additionalProperties: false
      required: [scope, expectedVersion, patch]
      properties:
        scope: {type: string, enum: [thisOccurrence, entireSeries]}
        occurrenceId: {$ref: '#/components/schemas/Uuid'}
        expectedVersion: {type: integer, minimum: 1}
        patch: {type: object, additionalProperties: true}
    ChoreOccurrence:
      type: object
      required: [id, householdId, status, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        status: {type: string, enum: [scheduled, completed, skipped, cancelled]}
        dueDate: {type: string, format: date}
        dueAt: {type: string, format: date-time}
        version: {type: integer, minimum: 1}
    SeriesSummary:
      type: object
      required: [id, householdId, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        version: {type: integer, minimum: 1}
    TodayPayload:
      type: object
      required: [householdId, localDate, householdTimezone, chores, events]
      properties:
        householdId: {$ref: '#/components/schemas/Uuid'}
        localDate: {type: string, format: date}
        householdTimezone: {type: string}
        chores: {type: array, maxItems: 500, items: {$ref: '#/components/schemas/ChoreOccurrence'}}
        events: {type: array, maxItems: 500, items: {type: object, additionalProperties: true}}
        generatedAt: {type: string, format: date-time}
    NotificationEndpointRegistrationRequest:
      type: object
      additionalProperties: false
      required:
        - householdId
        - installationId
        - platform
        - token
        - revocationSecret
        - permissionState
        - timezone
        - appVersion
        - runtimeVersion
        - expectedVersion
      properties:
        householdId: {$ref: '#/components/schemas/Uuid'}
        installationId: {$ref: '#/components/schemas/Uuid'}
        platform: {type: string, enum: [ios, android]}
        token: {type: string, minLength: 20, maxLength: 4096, pattern: '^[!-~]+$'}
        revocationSecret:
          type: string
          minLength: 43
          maxLength: 43
          pattern: '^[A-Za-z0-9_-]{43}$'
        permissionState: {type: string, const: granted}
        locale:
          type: string
          pattern: '^[A-Za-z]{2,3}(?:[_-][A-Za-z0-9]{2,8})*$'
        timezone: {type: string, minLength: 1, maxLength: 100}
        appVersion: {type: string, minLength: 1, maxLength: 64}
        runtimeVersion: {type: string, minLength: 1, maxLength: 64}
        expectedVersion: {type: integer, minimum: 0}
    NotificationEndpointRevocationRequest:
      type: object
      additionalProperties: false
      required: [installationId, channel, registrationId, revocationSecret]
      properties:
        installationId: {$ref: '#/components/schemas/Uuid'}
        channel: {type: string, const: native_push}
        registrationId: {$ref: '#/components/schemas/Uuid'}
        revocationSecret:
          type: string
          minLength: 43
          maxLength: 43
          pattern: '^[A-Za-z0-9_-]{43}$'
    NotificationEndpointMetadata:
      type: object
      additionalProperties: false
      required:
        - endpointId
        - householdId
        - memberId
        - installationId
        - channel
        - platform
        - permissionState
        - locale
        - timezone
        - appVersion
        - runtimeVersion
        - lastRegistrationId
        - lastSeenAt
        - revokedAt
        - revocationReason
        - version
      properties:
        endpointId: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        memberId: {$ref: '#/components/schemas/Uuid'}
        installationId: {$ref: '#/components/schemas/Uuid'}
        channel: {type: string, const: native_push}
        platform: {type: string, enum: [ios, android]}
        permissionState: {type: string, const: granted}
        locale: {type: [string, 'null']}
        timezone: {type: string}
        appVersion: {type: string}
        runtimeVersion: {type: string}
        lastRegistrationId: {$ref: '#/components/schemas/Uuid'}
        lastSeenAt: {type: string, format: date-time}
        revokedAt: {type: [string, 'null'], format: date-time}
        revocationReason:
          type: [string, 'null']
          enum:
            - client_revoked
            - token_reassigned
            - provider_unregistered
            - provider_invalid_argument
            - membership_removed
            - permission_revoked
            - rollback_disabled
            - null
        version: {type: integer, minimum: 1}
    NotificationEndpointResponseMeta:
      type: object
      additionalProperties: false
      required: [requestId, contractVersion]
      properties:
        requestId: {$ref: '#/components/schemas/Uuid'}
        contractVersion: {type: string, const: '2026-08-08-wp05-03'}
    NotificationEndpointRegistrationResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {$ref: '#/components/schemas/NotificationEndpointMetadata'}
        meta: {$ref: '#/components/schemas/NotificationEndpointResponseMeta'}
    NotificationEndpointRevocationResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data:
          type: object
          additionalProperties: false
          required: [revoked]
          properties:
            revoked: {type: boolean, const: true}
        meta: {$ref: '#/components/schemas/NotificationEndpointResponseMeta'}
    NotificationPushWorkerSummary:
      type: object
      additionalProperties: false
      required:
        - acceptedCount
        - ambiguousCount
        - claimedCount
        - endpointInvalidatedCount
        - failedCount
        - retryScheduledCount
        - submissionStartedCount
        - unrecordedCompletionCount
      properties:
        acceptedCount: {type: integer, minimum: 0, maximum: 100}
        ambiguousCount: {type: integer, minimum: 0, maximum: 100}
        claimedCount: {type: integer, minimum: 0, maximum: 100}
        endpointInvalidatedCount: {type: integer, minimum: 0, maximum: 100}
        failedCount: {type: integer, minimum: 0, maximum: 100}
        retryScheduledCount: {type: integer, minimum: 0, maximum: 100}
        submissionStartedCount: {type: integer, minimum: 0, maximum: 100}
        unrecordedCompletionCount: {type: integer, minimum: 0, maximum: 100}
    NotificationPushWorkerMeta:
      type: object
      additionalProperties: false
      required: [contractVersion]
      properties:
        contractVersion: {type: string, const: '2026-08-08-wp05-05'}
    NotificationPushWorkerResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {$ref: '#/components/schemas/NotificationPushWorkerSummary'}
        meta: {$ref: '#/components/schemas/NotificationPushWorkerMeta'}
    NotificationPushWorkerErrorResponse:
      type: object
      additionalProperties: false
      required: [error, meta]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, retryable]
          properties:
            code:
              type: string
              enum:
                - INVALID_REQUEST
                - METHOD_NOT_ALLOWED
                - PUSH_WORKER_AUTH_REQUIRED
                - PUSH_WORKER_UNAVAILABLE
            retryable: {type: boolean}
        meta: {$ref: '#/components/schemas/NotificationPushWorkerMeta'}
    NotificationEmailWorkerSummary:
      type: object
      additionalProperties: false
      required:
        - acceptedCount
        - ambiguousCount
        - claimedCount
        - failedCount
        - retryScheduledCount
        - submissionStartedCount
        - unrecordedCompletionCount
      properties:
        acceptedCount: {type: integer, minimum: 0, maximum: 100}
        ambiguousCount: {type: integer, minimum: 0, maximum: 100}
        claimedCount: {type: integer, minimum: 0, maximum: 100}
        failedCount: {type: integer, minimum: 0, maximum: 100}
        retryScheduledCount: {type: integer, minimum: 0, maximum: 100}
        submissionStartedCount: {type: integer, minimum: 0, maximum: 100}
        unrecordedCompletionCount: {type: integer, minimum: 0, maximum: 100}
    NotificationEmailWorkerMeta:
      type: object
      additionalProperties: false
      required: [contractVersion]
      properties:
        contractVersion: {type: string, const: '2026-08-10-wp05-14'}
    NotificationEmailWorkerResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {$ref: '#/components/schemas/NotificationEmailWorkerSummary'}
        meta: {$ref: '#/components/schemas/NotificationEmailWorkerMeta'}
    NotificationEmailWorkerErrorResponse:
      type: object
      additionalProperties: false
      required: [error, meta]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, retryable]
          properties:
            code:
              type: string
              enum:
                - INVALID_REQUEST
                - METHOD_NOT_ALLOWED
                - EMAIL_WORKER_AUTH_REQUIRED
                - EMAIL_WORKER_UNAVAILABLE
            retryable: {type: boolean}
        meta: {$ref: '#/components/schemas/NotificationEmailWorkerMeta'}
    RevenueCatWebhookRequest:
      type: object
      additionalProperties: true
      required: [api_version, event]
      properties:
        api_version: {type: string, minLength: 1, maxLength: 32}
        event:
          type: object
          additionalProperties: true
          required: [id, type, event_timestamp_ms]
          properties:
            id: {type: string, minLength: 1, maxLength: 255}
            type:
              type: string
              pattern: '^[A-Z][A-Z0-9_]{0,79}$'
            event_timestamp_ms: {type: integer, minimum: 946684800000}
            app_user_id: {type: string}
            environment: {type: string}
    BillingAssignmentMeta:
      type: object
      additionalProperties: false
      required: [contractVersion, requestId]
      properties:
        contractVersion: {type: string, const: '2026-08-08-wp06-05'}
        requestId: {$ref: '#/components/schemas/Uuid'}
    BillingAssignmentPrepare:
      type: object
      additionalProperties: false
      required:
        - intentId
        - outcome
        - bindingState
        - assignmentVersion
        - intentExpiresAt
        - requeuedJobCount
        - duplicate
      properties:
        intentId: {$ref: '#/components/schemas/Uuid'}
        outcome:
          type: string
          enum: [ready, alreadyReady, customerConflict, householdConflict]
        bindingState:
          anyOf:
            - {type: string, enum: [provisional, confirmed]}
            - {type: 'null'}
        assignmentVersion:
          anyOf:
            - {type: integer, minimum: 1}
            - {type: 'null'}
        intentExpiresAt:
          anyOf:
            - {type: string, format: date-time}
            - {type: 'null'}
        requeuedJobCount: {type: integer, minimum: 0, maximum: 1000}
        duplicate: {type: boolean}
    BillingAssignmentStatus:
      type: object
      additionalProperties: false
      required:
        - householdId
        - assignmentState
        - ownershipState
        - ownerMembershipState
        - canPrepare
        - requiresSupport
        - assignmentVersion
        - intentExpiresAt
      properties:
        householdId: {$ref: '#/components/schemas/Uuid'}
        assignmentState: {type: string, enum: [none, provisional, confirmed]}
        ownershipState: {type: string, enum: [unassigned, currentUser, anotherUser]}
        ownerMembershipState: {type: string, enum: [none, active, removed]}
        canPrepare: {type: boolean}
        requiresSupport: {type: boolean}
        assignmentVersion:
          anyOf:
            - {type: integer, minimum: 1}
            - {type: 'null'}
        intentExpiresAt:
          anyOf:
            - {type: string, format: date-time}
            - {type: 'null'}
    BillingAssignmentRelease:
      type: object
      additionalProperties: false
      required: [outcome, assignmentVersion, duplicate]
      properties:
        outcome:
          type: string
          enum: [released, alreadyReleased, supportRequired]
        assignmentVersion:
          anyOf:
            - {type: integer, minimum: 1}
            - {type: 'null'}
        duplicate: {type: boolean}
    BillingAssignmentRemediation:
      type: object
      additionalProperties: false
      required: [requestId, status, issueKind, duplicate]
      properties:
        requestId: {$ref: '#/components/schemas/Uuid'}
        status: {type: string, enum: [open, resolved, rejected]}
        issueKind:
          type: string
          enum:
            - customerConflict
            - householdConflict
            - ownerMembershipChanged
            - restoreConflict
        duplicate: {type: boolean}
    BillingEdgeMeta:
      type: object
      additionalProperties: false
      required: [contractVersion, requestId]
      properties:
        contractVersion: {type: string, const: '2026-08-08-wp06-04'}
        requestId: {$ref: '#/components/schemas/Uuid'}
    BillingWebhookResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data:
          type: object
          additionalProperties: false
          required: [accepted, disposition, duplicate]
          properties:
            accepted: {type: boolean, const: true}
            disposition:
              type: string
              enum: [queued, duplicate, ignored, manualReview]
            duplicate: {type: boolean}
        meta: {$ref: '#/components/schemas/BillingEdgeMeta'}
    BillingReconciliationWorkerResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data:
          type: object
          additionalProperties: false
          required: [scheduled, claimed, succeeded, retryScheduled, deadLetter]
          properties:
            scheduled: {type: integer, minimum: 0, maximum: 100}
            claimed: {type: integer, minimum: 0, maximum: 100}
            succeeded: {type: integer, minimum: 0, maximum: 100}
            retryScheduled: {type: integer, minimum: 0, maximum: 100}
            deadLetter: {type: integer, minimum: 0, maximum: 100}
        meta: {$ref: '#/components/schemas/BillingEdgeMeta'}
    BillingEdgeErrorResponse:
      type: object
      additionalProperties: false
      required: [error]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, requestId, retryable]
          properties:
            code:
              type: string
              enum:
                - AUTHENTICATION_FAILED
                - BODY_TOO_LARGE
                - EVENT_ID_COLLISION
                - METHOD_NOT_ALLOWED
                - TEMPORARILY_UNAVAILABLE
                - VALIDATION_FAILED
            requestId: {$ref: '#/components/schemas/Uuid'}
            retryable: {type: boolean}
    Entitlement:
      type: object
      required: [householdId, plan, status, features, verifiedAt, version]
      properties:
        householdId: {$ref: '#/components/schemas/Uuid'}
        plan: {type: string, enum: [free, plus]}
        status: {type: string, enum: [none, trialing, active, grace, billingIssue, expired, revoked]}
        features: {type: object, additionalProperties: {oneOf: [{type: boolean}, {type: number}]}}
        verifiedAt: {type: string, format: date-time}
        version: {type: integer, minimum: 0}
    AccountDeletionOperationRequest:
      oneOf:
        - type: object
          additionalProperties: false
          required: [operation]
          properties:
            operation: {type: string, const: preflight}
        - type: object
          additionalProperties: false
          required: [operation]
          properties:
            operation: {type: string, const: status}
            requestId: {$ref: '#/components/schemas/Uuid'}
        - type: object
          additionalProperties: false
          required: [operation, subscriptionAcknowledged]
          properties:
            operation: {type: string, const: request}
            subscriptionAcknowledged: {type: boolean}
        - type: object
          additionalProperties: false
          required: [operation, requestId, expectedVersion]
          properties:
            operation: {type: string, const: cancel}
            requestId: {$ref: '#/components/schemas/Uuid'}
            expectedVersion: {type: integer, minimum: 1}
    AccountDeletionPreflight:
      type: object
      additionalProperties: false
      required:
        - canRequest
        - ownerHouseholdCount
        - hasActiveSubscription
        - pendingRequestId
        - pendingStatus
        - pendingRequestVersion
        - requestsEnabled
        - cancellationWindowSeconds
        - evaluatedAt
      properties:
        canRequest: {type: boolean}
        ownerHouseholdCount: {type: integer, minimum: 0}
        hasActiveSubscription: {type: boolean}
        pendingRequestId:
          anyOf:
            - {$ref: '#/components/schemas/Uuid'}
            - {type: 'null'}
        pendingStatus:
          anyOf:
            - {type: string, enum: [queued, verifying, processing]}
            - {type: 'null'}
        pendingRequestVersion:
          anyOf:
            - {type: integer, minimum: 1}
            - {type: 'null'}
        requestsEnabled: {type: boolean}
        cancellationWindowSeconds: {type: integer, minimum: 3600, maximum: 604800}
        evaluatedAt: {type: string, format: date-time}
    AccountDeletionRequest:
      type: object
      additionalProperties: false
      required:
        - id
        - type
        - status
        - requestedAt
        - scheduledFor
        - processingStartedAt
        - completedAt
        - failedAt
        - cancelledAt
        - failureCode
        - activeSubscriptionAtRequest
        - subscriptionAcknowledged
        - cancellable
        - version
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        type: {type: string, const: deleteAccount}
        status: {type: string, enum: [queued, verifying, processing, completed, failed, cancelled]}
        requestedAt: {type: string, format: date-time}
        scheduledFor: {type: string, format: date-time}
        processingStartedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        completedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        failedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        cancelledAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        failureCode:
          anyOf: [{type: string}, {type: 'null'}]
        activeSubscriptionAtRequest: {type: boolean}
        subscriptionAcknowledged: {type: boolean}
        cancellable: {type: boolean}
        version: {type: integer, minimum: 1}
    AccountDeletionMeta:
      type: object
      additionalProperties: false
      required: [requestId, contractVersion]
      properties:
        requestId: {$ref: '#/components/schemas/Uuid'}
        contractVersion: {type: string, const: '2026-08-08-wp07-01'}
    AccountDeletionResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data:
          oneOf:
            - {$ref: '#/components/schemas/AccountDeletionPreflight'}
            - {$ref: '#/components/schemas/AccountDeletionRequest'}
            - {type: 'null'}
        meta: {$ref: '#/components/schemas/AccountDeletionMeta'}
    AccountDeletionWorkerSummary:
      type: object
      additionalProperties: false
      required:
        - recoveredRetryScheduled
        - recoveredDeadLetter
        - claimed
        - succeeded
        - retryScheduled
        - deadLetter
      properties:
        recoveredRetryScheduled: {type: integer, minimum: 0}
        recoveredDeadLetter: {type: integer, minimum: 0}
        claimed: {type: integer, minimum: 0, maximum: 10}
        succeeded: {type: integer, minimum: 0, maximum: 10}
        retryScheduled: {type: integer, minimum: 0, maximum: 10}
        deadLetter: {type: integer, minimum: 0, maximum: 10}
    AccountDeletionWorkerResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {$ref: '#/components/schemas/AccountDeletionWorkerSummary'}
        meta: {$ref: '#/components/schemas/AccountDeletionMeta'}
    AccountDeletionErrorEnvelope:
      type: object
      additionalProperties: false
      required: [error]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, messageKey, retryable, requestId]
          properties:
            code:
              type: string
              enum:
                - AUTH_REQUIRED
                - IDEMPOTENCY_KEY_REQUIRED
                - IDEMPOTENCY_KEY_REUSED
                - INTERNAL_ERROR
                - METHOD_NOT_ALLOWED
                - NOT_FOUND
                - OWNER_TRANSFER_REQUIRED
                - PERMISSION_DENIED
                - PRIVACY_REQUEST_ALREADY_PENDING
                - RECENT_AUTH_REQUIRED
                - REQUEST_NOT_CANCELLABLE
                - REQUESTS_PAUSED
                - SUBSCRIPTION_ACKNOWLEDGEMENT_REQUIRED
                - TEMPORARILY_UNAVAILABLE
                - VALIDATION_FAILED
                - VERSION_CONFLICT
            messageKey: {type: string}
            retryable: {type: boolean}
            requestId: {$ref: '#/components/schemas/Uuid'}
    DataExportOperationRequest:
      oneOf:
        - type: object
          additionalProperties: false
          required: [operation]
          properties:
            operation: {type: string, const: preflight}
        - type: object
          additionalProperties: false
          required: [operation]
          properties:
            operation: {type: string, const: status}
            requestId: {$ref: '#/components/schemas/Uuid'}
        - type: object
          additionalProperties: false
          required: [operation]
          properties:
            operation: {type: string, const: request}
        - type: object
          additionalProperties: false
          required: [operation, requestId, expectedVersion]
          properties:
            operation: {type: string, const: cancel}
            requestId: {$ref: '#/components/schemas/Uuid'}
            expectedVersion: {type: integer, minimum: 1}
        - type: object
          additionalProperties: false
          required: [operation, requestId, format]
          properties:
            operation: {type: string, const: download}
            requestId: {$ref: '#/components/schemas/Uuid'}
            format: {type: string, enum: [json, text]}
        - type: object
          additionalProperties: false
          required: [operation, requestId, expectedArtifactVersion]
          properties:
            operation: {type: string, const: revoke}
            requestId: {$ref: '#/components/schemas/Uuid'}
            expectedArtifactVersion: {type: integer, minimum: 1}
    DataExportPreflight:
      type: object
      additionalProperties: false
      required:
        - canRequest
        - pendingRequestId
        - pendingStatus
        - pendingRequestVersion
        - conflictingRequestPending
        - requestsEnabled
        - downloadsEnabled
        - artifactTtlSeconds
        - downloadGrantTtlSeconds
        - evaluatedAt
      properties:
        canRequest: {type: boolean}
        pendingRequestId:
          anyOf: [{$ref: '#/components/schemas/Uuid'}, {type: 'null'}]
        pendingStatus:
          anyOf:
            - {type: string, enum: [queued, verifying, processing]}
            - {type: 'null'}
        pendingRequestVersion:
          anyOf: [{type: integer, minimum: 1}, {type: 'null'}]
        conflictingRequestPending: {type: boolean}
        requestsEnabled: {type: boolean}
        downloadsEnabled: {type: boolean}
        artifactTtlSeconds: {type: integer, minimum: 3600, maximum: 604800}
        downloadGrantTtlSeconds: {type: integer, minimum: 60, maximum: 900}
        evaluatedAt: {type: string, format: date-time}
    DataExportArtifact:
      type: object
      additionalProperties: false
      required:
        - id
        - version
        - schemaVersion
        - expiresAt
        - revokedAt
        - purgedAt
        - machineSizeBytes
        - humanSizeBytes
        - available
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        version: {type: integer, minimum: 1}
        schemaVersion: {type: string, const: '2026-08-08-wp07-02a'}
        expiresAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        revokedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        purgedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        machineSizeBytes:
          anyOf: [{type: integer, minimum: 1, maximum: 10485760}, {type: 'null'}]
        humanSizeBytes:
          anyOf: [{type: integer, minimum: 1, maximum: 10485760}, {type: 'null'}]
        available: {type: boolean}
    DataExportRequest:
      type: object
      additionalProperties: false
      required:
        - id
        - status
        - requestedAt
        - processingStartedAt
        - completedAt
        - failedAt
        - cancelledAt
        - failureCode
        - cancellable
        - version
        - artifact
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        status: {type: string, enum: [queued, verifying, processing, completed, failed, cancelled]}
        requestedAt: {type: string, format: date-time}
        processingStartedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        completedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        failedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        cancelledAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        failureCode:
          anyOf: [{type: string}, {type: 'null'}]
        cancellable: {type: boolean}
        version: {type: integer, minimum: 1}
        artifact: {$ref: '#/components/schemas/DataExportArtifact'}
    DataExportDownload:
      type: object
      additionalProperties: false
      required: [format, expiresAt, downloadUrl]
      properties:
        format: {type: string, enum: [json, text]}
        expiresAt: {type: string, format: date-time}
        downloadUrl:
          type: string
          format: uri
          pattern: '^https://[^?#]+[?]token=[A-Za-z0-9_-]{43}$'
    DataExportMeta:
      type: object
      additionalProperties: false
      required: [requestId, contractVersion]
      properties:
        requestId: {$ref: '#/components/schemas/Uuid'}
        contractVersion: {type: string, const: '2026-08-08-wp07-02a'}
    DataExportResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data:
          oneOf:
            - {$ref: '#/components/schemas/DataExportPreflight'}
            - {$ref: '#/components/schemas/DataExportRequest'}
            - {$ref: '#/components/schemas/DataExportDownload'}
            - {type: 'null'}
        meta: {$ref: '#/components/schemas/DataExportMeta'}
    DataExportWorkerSummary:
      type: object
      additionalProperties: false
      required:
        - generationRecoveredRetryScheduled
        - generationRecoveredDeadLetter
        - generationClaimed
        - generationSucceeded
        - generationRetryScheduled
        - generationDeadLetter
        - purgeRecoveredRetryScheduled
        - purgeRecoveredDeadLetter
        - purgeClaimed
        - purgeSucceeded
        - purgeRetryScheduled
        - purgeDeadLetter
      properties:
        generationRecoveredRetryScheduled: {type: integer, minimum: 0}
        generationRecoveredDeadLetter: {type: integer, minimum: 0}
        generationClaimed: {type: integer, minimum: 0, maximum: 3}
        generationSucceeded: {type: integer, minimum: 0, maximum: 3}
        generationRetryScheduled: {type: integer, minimum: 0, maximum: 3}
        generationDeadLetter: {type: integer, minimum: 0, maximum: 3}
        purgeRecoveredRetryScheduled: {type: integer, minimum: 0}
        purgeRecoveredDeadLetter: {type: integer, minimum: 0}
        purgeClaimed: {type: integer, minimum: 0, maximum: 10}
        purgeSucceeded: {type: integer, minimum: 0, maximum: 10}
        purgeRetryScheduled: {type: integer, minimum: 0, maximum: 10}
        purgeDeadLetter: {type: integer, minimum: 0, maximum: 10}
    DataExportWorkerResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {$ref: '#/components/schemas/DataExportWorkerSummary'}
        meta: {$ref: '#/components/schemas/DataExportMeta'}
    DataExportErrorEnvelope:
      type: object
      additionalProperties: false
      required: [error]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, messageKey, retryable, requestId]
          properties:
            code:
              type: string
              enum:
                - ARTIFACT_UNAVAILABLE
                - AUTH_REQUIRED
                - DOWNLOADS_PAUSED
                - DOWNLOAD_GRANT_INVALID
                - EXPORT_TOO_LARGE
                - IDEMPOTENCY_KEY_REQUIRED
                - IDEMPOTENCY_KEY_REUSED
                - INTERNAL_ERROR
                - METHOD_NOT_ALLOWED
                - NOT_FOUND
                - PERMISSION_DENIED
                - PRIVACY_REQUEST_ALREADY_PENDING
                - RECENT_AUTH_REQUIRED
                - REQUEST_NOT_CANCELLABLE
                - REQUESTS_PAUSED
                - TEMPORARILY_UNAVAILABLE
                - VALIDATION_FAILED
                - VERSION_CONFLICT
            messageKey: {type: string}
            retryable: {type: boolean}
            requestId: {$ref: '#/components/schemas/Uuid'}
    HouseholdPrivacyOperationRequest:
      oneOf:
        - type: object
          additionalProperties: false
          required: [operation, householdId]
          properties:
            operation: {type: string, const: preflight}
            householdId: {$ref: '#/components/schemas/Uuid'}
        - type: object
          additionalProperties: false
          required: [operation, requestId]
          properties:
            operation: {type: string, const: status}
            requestId: {$ref: '#/components/schemas/Uuid'}
        - type: object
          additionalProperties: false
          required: [operation, householdId]
          properties:
            operation: {type: string, const: requestExport}
            householdId: {$ref: '#/components/schemas/Uuid'}
        - type: object
          additionalProperties: false
          required:
            - operation
            - householdId
            - expectedHouseholdVersion
            - confirmationName
            - acknowledgeMemberAccessLoss
            - acknowledgeSharedDataRedaction
            - acknowledgeSubscriptionNotCancelled
          properties:
            operation: {type: string, const: requestDeletion}
            householdId: {$ref: '#/components/schemas/Uuid'}
            expectedHouseholdVersion: {type: integer, minimum: 1}
            confirmationName: {type: string, minLength: 1, maxLength: 80}
            acknowledgeMemberAccessLoss: {type: boolean, const: true}
            acknowledgeSharedDataRedaction: {type: boolean, const: true}
            acknowledgeSubscriptionNotCancelled: {type: boolean}
        - type: object
          additionalProperties: false
          required: [operation, requestId, expectedVersion]
          properties:
            operation: {type: string, enum: [cancelExport, cancelDeletion]}
            requestId: {$ref: '#/components/schemas/Uuid'}
            expectedVersion: {type: integer, minimum: 1}
        - type: object
          additionalProperties: false
          required: [operation, requestId, expectedArtifactVersion]
          properties:
            operation: {type: string, const: revokeExport}
            requestId: {$ref: '#/components/schemas/Uuid'}
            expectedArtifactVersion: {type: integer, minimum: 1}
        - type: object
          additionalProperties: false
          required: [operation, requestId, format]
          properties:
            operation: {type: string, const: downloadExport}
            requestId: {$ref: '#/components/schemas/Uuid'}
            format: {type: string, enum: [json, text]}
    HouseholdPrivacyHousehold:
      type: object
      additionalProperties: false
      required: [id, name, version]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        name: {type: string, minLength: 1, maxLength: 80}
        version: {type: integer, minimum: 1}
    HouseholdExportArtifact:
      type: object
      additionalProperties: false
      required:
        - id
        - version
        - schemaVersion
        - expiresAt
        - revokedAt
        - purgedAt
        - machineSizeBytes
        - humanSizeBytes
        - available
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        version: {type: integer, minimum: 1}
        schemaVersion: {type: string, const: '2026-08-08-wp07-02b'}
        expiresAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        revokedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        purgedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        machineSizeBytes:
          anyOf: [{type: integer, minimum: 1, maximum: 20971520}, {type: 'null'}]
        humanSizeBytes:
          anyOf: [{type: integer, minimum: 1, maximum: 20971520}, {type: 'null'}]
        available: {type: boolean}
    HouseholdDeletionProgress:
      type: object
      additionalProperties: false
      required:
        - retentionBlocked
        - retentionReviewAt
        - accessRevokedAt
        - redactedAt
        - billingUnlinkedAt
      properties:
        retentionBlocked: {type: boolean}
        retentionReviewAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        accessRevokedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        redactedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        billingUnlinkedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
    HouseholdPrivacyRequest:
      type: object
      additionalProperties: false
      required:
        - requestId
        - kind
        - householdId
        - status
        - requestedAt
        - scheduledFor
        - processingStartedAt
        - completedAt
        - failedAt
        - cancelledAt
        - failureCode
        - cancellable
        - version
        - activeSubscriptionAtRequest
        - artifact
        - deletion
      properties:
        requestId: {$ref: '#/components/schemas/Uuid'}
        kind: {type: string, enum: [export, deletion]}
        householdId: {$ref: '#/components/schemas/Uuid'}
        status: {type: string, enum: [queued, verifying, processing, completed, failed, cancelled]}
        requestedAt: {type: string, format: date-time}
        scheduledFor: {type: string, format: date-time}
        processingStartedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        completedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        failedAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        cancelledAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        failureCode:
          anyOf: [{type: string}, {type: 'null'}]
        cancellable: {type: boolean}
        version: {type: integer, minimum: 1}
        activeSubscriptionAtRequest: {type: boolean}
        artifact:
          anyOf:
            - {$ref: '#/components/schemas/HouseholdExportArtifact'}
            - {type: 'null'}
        deletion:
          anyOf:
            - {$ref: '#/components/schemas/HouseholdDeletionProgress'}
            - {type: 'null'}
    HouseholdPrivacyPreflight:
      type: object
      additionalProperties: false
      required:
        - household
        - memberCount
        - activeSubscription
        - canExport
        - canDelete
        - conflictingRequestPending
        - pendingRequest
        - exportRequestsEnabled
        - deletionRequestsEnabled
        - downloadsEnabled
        - artifactTtlSeconds
        - downloadGrantTtlSeconds
        - deletionCancellationWindowSeconds
        - retentionBlocked
        - retentionReviewAt
        - evaluatedAt
      properties:
        household: {$ref: '#/components/schemas/HouseholdPrivacyHousehold'}
        memberCount: {type: integer, minimum: 1}
        activeSubscription: {type: boolean}
        canExport: {type: boolean}
        canDelete: {type: boolean}
        conflictingRequestPending: {type: boolean}
        pendingRequest:
          anyOf:
            - {$ref: '#/components/schemas/HouseholdPrivacyRequest'}
            - {type: 'null'}
        exportRequestsEnabled: {type: boolean}
        deletionRequestsEnabled: {type: boolean}
        downloadsEnabled: {type: boolean}
        artifactTtlSeconds: {type: integer, minimum: 3600, maximum: 604800}
        downloadGrantTtlSeconds: {type: integer, minimum: 60, maximum: 900}
        deletionCancellationWindowSeconds: {type: integer, minimum: 3600, maximum: 604800}
        retentionBlocked: {type: boolean}
        retentionReviewAt:
          anyOf: [{type: string, format: date-time}, {type: 'null'}]
        evaluatedAt: {type: string, format: date-time}
    HouseholdExportDownload:
      type: object
      additionalProperties: false
      required: [format, expiresAt, downloadUrl]
      properties:
        format: {type: string, enum: [json, text]}
        expiresAt: {type: string, format: date-time}
        downloadUrl:
          type: string
          format: uri
          pattern: '^https://[^?#]+[?]token=[A-Za-z0-9_-]{43}$'
    HouseholdPrivacyMeta:
      type: object
      additionalProperties: false
      required: [requestId, contractVersion]
      properties:
        requestId: {$ref: '#/components/schemas/Uuid'}
        contractVersion: {type: string, const: '2026-08-08-wp07-02b'}
    HouseholdPrivacyResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data:
          oneOf:
            - {$ref: '#/components/schemas/HouseholdPrivacyPreflight'}
            - {$ref: '#/components/schemas/HouseholdPrivacyRequest'}
            - {$ref: '#/components/schemas/HouseholdExportDownload'}
        meta: {$ref: '#/components/schemas/HouseholdPrivacyMeta'}
    HouseholdPrivacyWorkerSummary:
      type: object
      additionalProperties: false
      required:
        - exportRecoveredRetryScheduled
        - exportRecoveredDeadLetter
        - exportClaimed
        - exportSucceeded
        - exportRetryScheduled
        - exportDeadLetter
        - purgeRecoveredRetryScheduled
        - purgeRecoveredDeadLetter
        - purgeClaimed
        - purgeSucceeded
        - purgeRetryScheduled
        - purgeDeadLetter
        - deletionRecoveredRetryScheduled
        - deletionRecoveredDeadLetter
        - deletionClaimed
        - deletionSucceeded
        - deletionRetryScheduled
        - deletionDeadLetter
      properties:
        exportRecoveredRetryScheduled: {type: integer, minimum: 0}
        exportRecoveredDeadLetter: {type: integer, minimum: 0}
        exportClaimed: {type: integer, minimum: 0, maximum: 2}
        exportSucceeded: {type: integer, minimum: 0, maximum: 2}
        exportRetryScheduled: {type: integer, minimum: 0, maximum: 2}
        exportDeadLetter: {type: integer, minimum: 0, maximum: 2}
        purgeRecoveredRetryScheduled: {type: integer, minimum: 0}
        purgeRecoveredDeadLetter: {type: integer, minimum: 0}
        purgeClaimed: {type: integer, minimum: 0, maximum: 10}
        purgeSucceeded: {type: integer, minimum: 0, maximum: 10}
        purgeRetryScheduled: {type: integer, minimum: 0, maximum: 10}
        purgeDeadLetter: {type: integer, minimum: 0, maximum: 10}
        deletionRecoveredRetryScheduled: {type: integer, minimum: 0}
        deletionRecoveredDeadLetter: {type: integer, minimum: 0}
        deletionClaimed: {type: integer, minimum: 0, maximum: 5}
        deletionSucceeded: {type: integer, minimum: 0, maximum: 5}
        deletionRetryScheduled: {type: integer, minimum: 0, maximum: 5}
        deletionDeadLetter: {type: integer, minimum: 0, maximum: 5}
    HouseholdPrivacyWorkerResponse:
      type: object
      additionalProperties: false
      required: [data, meta]
      properties:
        data: {$ref: '#/components/schemas/HouseholdPrivacyWorkerSummary'}
        meta: {$ref: '#/components/schemas/HouseholdPrivacyMeta'}
    HouseholdPrivacyErrorEnvelope:
      type: object
      additionalProperties: false
      required: [error]
      properties:
        error:
          type: object
          additionalProperties: false
          required: [code, messageKey, retryable, requestId]
          properties:
            code:
              type: string
              enum:
                - ARTIFACT_UNAVAILABLE
                - AUTH_REQUIRED
                - CONFIRMATION_MISMATCH
                - DELETION_REQUESTS_PAUSED
                - DOWNLOADS_PAUSED
                - DOWNLOAD_GRANT_INVALID
                - EXPORT_REQUESTS_PAUSED
                - HOUSEHOLD_ALREADY_DELETED
                - IDEMPOTENCY_KEY_REQUIRED
                - IDEMPOTENCY_KEY_REUSED
                - INTERNAL_ERROR
                - METHOD_NOT_ALLOWED
                - NOT_FOUND
                - OWNER_REQUIRED
                - PRIVACY_REQUEST_ALREADY_PENDING
                - RECENT_AUTH_REQUIRED
                - REQUEST_NOT_MUTABLE
                - SUBSCRIPTION_ACK_REQUIRED
                - TEMPORARILY_UNAVAILABLE
                - VALIDATION_FAILED
                - VERSION_CONFLICT
            messageKey: {type: string}
            retryable: {type: boolean}
            requestId: {$ref: '#/components/schemas/Uuid'}
    PrivacyRequest:
      type: object
      required: [id, type, status, createdAt]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        type: {type: string, enum: [export, deleteAccount, deleteHousehold]}
        status: {type: string, enum: [queued, verifying, processing, completed, failed, cancelled]}
        createdAt: {type: string, format: date-time}
        completedAt: {type: string, format: date-time}
  responses:
    AccountDeletionErrorResponse:
      description: Exact privacy-minimized account deletion error envelope
      content:
        application/json:
          schema: {$ref: '#/components/schemas/AccountDeletionErrorEnvelope'}
    DataExportErrorResponse:
      description: Exact privacy-minimized personal data export error envelope
      content:
        application/json:
          schema: {$ref: '#/components/schemas/DataExportErrorEnvelope'}
    HouseholdPrivacyErrorResponse:
      description: Exact privacy-minimized household export and deletion error envelope
      content:
        application/json:
          schema: {$ref: '#/components/schemas/HouseholdPrivacyErrorEnvelope'}
    ErrorResponse:
      description: Stable error envelope
      content:
        application/json:
          schema: {$ref: '#/components/schemas/ErrorEnvelope'}
    HouseholdResponse:
      description: Household result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Household'}
    InviteResponse:
      description: >-
        Invite result. rawToken, shortCode, and shortCodeExpiresAt are returned
        together only for the first successful create and omitted on replay.
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/InviteSuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Invite'}
    InvitePreviewResponse:
      description: Minimal public preview
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/InviteSuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/InvitePreview'}
    InviteMemberResponse:
      description: Accepted invite member result with WP06-06 capacity errors
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/InviteSuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Member'}
    MemberResponse:
      description: Household member result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Member'}
    ChoreOccurrenceResponse:
      description: Chore occurrence result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/ChoreOccurrence'}
    SeriesResponse:
      description: Series result
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/SeriesSummary'}
    BillingAssignmentPrepareResponse:
      description: Explicit household preflight result
      content:
        application/json:
          schema:
            type: object
            additionalProperties: false
            required: [data, meta]
            properties:
              data: {$ref: '#/components/schemas/BillingAssignmentPrepare'}
              meta: {$ref: '#/components/schemas/BillingAssignmentMeta'}
    BillingAssignmentStatusResponse:
      description: Privacy-minimized household assignment status
      content:
        application/json:
          schema:
            type: object
            additionalProperties: false
            required: [data, meta]
            properties:
              data: {$ref: '#/components/schemas/BillingAssignmentStatus'}
              meta: {$ref: '#/components/schemas/BillingAssignmentMeta'}
    BillingAssignmentReleaseResponse:
      description: Provisional assignment release result
      content:
        application/json:
          schema:
            type: object
            additionalProperties: false
            required: [data, meta]
            properties:
              data: {$ref: '#/components/schemas/BillingAssignmentRelease'}
              meta: {$ref: '#/components/schemas/BillingAssignmentMeta'}
    BillingAssignmentRemediationResponse:
      description: Aggregate support remediation request result
      content:
        application/json:
          schema:
            type: object
            additionalProperties: false
            required: [data, meta]
            properties:
              data: {$ref: '#/components/schemas/BillingAssignmentRemediation'}
              meta: {$ref: '#/components/schemas/BillingAssignmentMeta'}
    EntitlementResponse:
      description: Authoritative household entitlement
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Entitlement'}
```
