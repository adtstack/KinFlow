# 원본 파일 문서화: `contracts/openapi-edge.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/openapi-edge.yaml`
- 원본 형식: `yaml`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.

```yaml
openapi: 3.1.0
info:
  title: KinFlow Edge API
  version: "2026-07-21"
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
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/AcceptInviteRequest'
      responses:
        '200': {$ref: '#/components/responses/MemberResponse'}
        '403': {$ref: '#/components/responses/ErrorResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
        '410': {$ref: '#/components/responses/ErrorResponse'}
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
  /notification-endpoints:
    post:
      tags: [Notification]
      operationId: registerNotificationEndpoint
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/NotificationEndpointRequest'
      responses:
        '200':
          description: Endpoint registered or rotated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessEnvelope'
        '409': {$ref: '#/components/responses/ErrorResponse'}
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
              required: [householdId, expectedEntitlementVersion]
              properties:
                householdId: {$ref: '#/components/schemas/Uuid'}
                expectedEntitlementVersion: {type: integer, minimum: 0}
      responses:
        '200': {$ref: '#/components/responses/EntitlementResponse'}
        '409': {$ref: '#/components/responses/ErrorResponse'}
  /webhooks/revenuecat:
    post:
      tags: [Billing]
      security:
        - webhookAuth: []
      operationId: receiveRevenueCatWebhook
      requestBody:
        required: true
        content:
          application/json:
            schema: {type: object, additionalProperties: true}
      responses:
        '202': {description: Receipt accepted for idempotent processing}
        '401': {$ref: '#/components/responses/ErrorResponse'}
        '409': {description: Duplicate receipt already accepted}
  /privacy/requests:
    post:
      tags: [Privacy]
      operationId: createPrivacyRequest
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
                type: {type: string, enum: [export, deleteAccount, deleteHousehold]}
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
    webhookAuth:
      type: apiKey
      in: header
      name: Authorization
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
      type: object
      additionalProperties: false
      properties:
        token: {type: string, minLength: 20, maxLength: 512}
        shortCode: {type: string, minLength: 6, maxLength: 16}
      anyOf:
        - required: [token]
        - required: [shortCode]
    AcceptInviteRequest:
      allOf:
        - $ref: '#/components/schemas/InviteTokenRequest'
        - type: object
          properties:
            setActiveHousehold: {type: boolean, default: true}
    Invite:
      type: object
      required: [id, householdId, role, expiresAt, status]
      properties:
        id: {$ref: '#/components/schemas/Uuid'}
        householdId: {$ref: '#/components/schemas/Uuid'}
        role: {type: string, enum: [admin, member]}
        expiresAt: {type: string, format: date-time}
        status: {type: string, enum: [active, accepted, revoked, expired]}
        rawToken:
          type: string
          description: Returned only once at creation and never stored in plaintext.
    InvitePreview:
      type: object
      required: [valid, role]
      properties:
        valid: {type: boolean}
        householdDisplayName: {type: string}
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
    NotificationEndpointRequest:
      type: object
      additionalProperties: false
      required: [channel, platform, installationId, tokenOrEndpoint, permissionState]
      properties:
        channel: {type: string, enum: [nativePush, webPush]}
        platform: {type: string, enum: [ios, android, web]}
        installationId: {type: string, minLength: 16, maxLength: 200}
        tokenOrEndpoint: {type: string, minLength: 16, maxLength: 4096}
        permissionState: {type: string, enum: [granted, denied, prompt, unsupported]}
        locale: {type: string}
        timezone: {type: string}
        appVersion: {type: string}
        runtimeVersion: {type: string}
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
      description: Invite result; rawToken is returned once on create
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/Invite'}
    InvitePreviewResponse:
      description: Minimal public preview
      content:
        application/json:
          schema:
            allOf:
              - $ref: '#/components/schemas/SuccessEnvelope'
              - type: object
                properties:
                  data: {$ref: '#/components/schemas/InvitePreview'}
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
