# Pterodactyl OpenClaw Domain Manager Spec

This document describes a practical architecture for supporting custom HTTPS domains for OpenClaw servers managed through Pterodactyl.

The target UX is:

1. The user enters a custom domain in the panel.
2. The platform verifies DNS ownership by checking whether the domain points to the STACloud proxy.
3. The platform provisions a Caddy route.
4. Caddy automatically issues TLS.
5. The platform updates the server environment and restarts OpenClaw.
6. The panel shows a stable status such as `active` or `failed`.

This keeps the user experience inside the panel while moving the orchestration logic into a dedicated backend service.

---

## Scope

This spec covers:

- panel-side domain submission flow
- backend domain lifecycle orchestration
- Caddy route creation
- Pterodactyl environment sync and server restart
- OpenClaw integration via `OPENCLAW_ALLOWED_ORIGINS`

This spec does not require:

- direct shell access from the panel
- modifying Caddy from inside the OpenClaw container
- exposing Caddy Admin API publicly

---

## High-level architecture

Components:

- `Panel UI`
  - place where the user enters the custom domain
- `Panel backend`
  - stores the requested domain
  - triggers provisioning jobs
- `Domain Manager`
  - verifies DNS
  - provisions and removes Caddy routes
  - syncs server environment through the Pterodactyl API
  - performs health checks and rollback
- `Caddy proxy`
  - terminates TLS
  - reverse-proxies to the OpenClaw upstream
- `Pterodactyl`
  - stores server metadata
  - restarts the target server
- `OpenClaw`
  - trusts the public HTTPS origin through `OPENCLAW_ALLOWED_ORIGINS`

Recommended ownership split:

- Pterodactyl stays responsible for server lifecycle
- Domain Manager owns custom-domain lifecycle
- Caddy owns HTTPS issuance and routing

---

## Required data model

One record per domain attachment.

Suggested table: `server_custom_domains`

Fields:

- `id`
- `server_id`
- `user_id`
- `domain`
- `normalized_domain`
- `public_origin`
- `status`
- `status_reason`
- `verification_mode`
- `expected_target_type`
- `expected_target_value`
- `node_id`
- `node_private_ip`
- `allocation_port`
- `proxy_upstream_host`
- `proxy_upstream_port`
- `caddy_route_id`
- `tls_status`
- `last_dns_check_at`
- `last_healthcheck_at`
- `activated_at`
- `detached_at`
- `created_at`
- `updated_at`

Suggested status values:

- `pending_dns`
- `verifying`
- `provisioning`
- `active`
- `conflict`
- `failed`
- `detached`

Constraints:

- unique index on `normalized_domain` where `status != detached`
- unique active domain per server if business rules require it

Notes:

- `public_origin` should be stored as `https://<domain>`
- store the normalized lowercased domain separately

---

## Panel UX

Minimum UI:

- input: `Custom Domain`
- read-only helper text showing the required DNS target
- status badge
- action buttons:
  - `Verify`
  - `Retry`
  - `Detach`

Suggested statuses shown to the user:

- `Pending DNS`
- `Provisioning`
- `Active`
- `Conflict`
- `Failed`

Suggested DNS guidance:

- if using an A record:
  - `A ai.user.com -> <public_proxy_ip>`
- if using a CNAME:
  - `CNAME ai.user.com -> proxy.stacloud.tech`

Panel behavior:

1. User submits `ai.user.com`
2. Panel backend creates record with `pending_dns`
3. Panel returns:
   - current status
   - required DNS target
   - retry instructions

---

## Backend API contract

Suggested internal endpoints for the Domain Manager.

### Create or update domain request

`POST /internal/domains`

Request:

```json
{
  "serverId": "9f43c1",
  "userId": "u_123",
  "domain": "ai.user.com"
}
```

Response:

```json
{
  "serverId": "9f43c1",
  "domain": "ai.user.com",
  "status": "pending_dns",
  "expectedTargetType": "A",
  "expectedTargetValue": "203.0.113.10"
}
```

### Verify domain now

`POST /internal/domains/{id}/verify`

### Detach domain

`POST /internal/domains/{id}/detach`

### Read domain state

`GET /internal/domains/{id}`

### List domains for a server

`GET /internal/servers/{serverId}/domains`

---

## Verification workflow

The verification worker should run on:

- explicit user action
- periodic scheduler
- retry after failure

Verification steps:

1. Normalize the domain.
2. Check whether another active record already uses that domain.
3. Resolve DNS.
4. Confirm that the resolved target matches the expected proxy target.
5. Load server routing metadata:
   - node id
   - node private IP
   - allocation port
6. Prepare provisioning payload.

Pass conditions:

- domain resolves to the platform proxy
- domain is not attached elsewhere
- upstream target exists and is routable

Failure examples:

- NXDOMAIN
- wrong IP
- stale CNAME
- duplicate domain already active
- target server missing allocation

---

## Caddy provisioning model

Recommended first implementation:

- one explicit route per domain
- manage routes through the Caddy Admin API

Why:

- easier to debug
- easier to remove
- simpler than on-demand TLS

Suggested reverse-proxy upstream:

- same node as Caddy:
  - `127.0.0.1:<allocation_port>`
- central proxy:
  - `<node_private_ip>:<allocation_port>`

Example route payload:

```json
{
  "@id": "openclaw-domain-ai.user.com",
  "match": [
    {
      "host": ["ai.user.com"]
    }
  ],
  "handle": [
    {
      "handler": "reverse_proxy",
      "upstreams": [
        {
          "dial": "10.0.0.24:8123"
        }
      ]
    }
  ],
  "terminal": true
}
```

Suggested Caddy integration:

- `POST /config/apps/http/servers/<server>/routes`
- or replace a dedicated named route group

Caddy requirements:

- Admin API bound to localhost or private network only
- public access on ports `80` and `443`
- automatic HTTPS enabled

---

## Pterodactyl integration

The Domain Manager should update the target server only after DNS verification passes.

Actions required:

1. Set or update:
   - `OPENCLAW_ALLOWED_ORIGINS=https://ai.user.com`
   - `OPENCLAW_BIND=lan`
   - `OPENCLAW_ALLOW_HOST_HEADER_ORIGIN_FALLBACK=false`
2. Restart the server
3. Wait for OpenClaw readiness

Implementation options:

- use the Pterodactyl Application API from the backend
- or use a trusted internal service that wraps Pterodactyl API calls

Suggested metadata lookup:

- server external id
- node id
- allocation port
- current Docker image
- current environment variables

Important rule:

- do not overwrite unrelated environment variables
- perform a merge update

---

## Provisioning sequence

Recommended production sequence:

1. record state -> `pending_dns`
2. verify DNS
3. state -> `provisioning`
4. create or update Caddy route
5. wait briefly for route apply
6. update Pterodactyl env
7. restart OpenClaw server
8. run health checks:
   - HTTPS reachable
   - TLS handshake succeeds
   - upstream responds
9. if healthy:
   - state -> `active`
   - set `activated_at`
10. if unhealthy:
   - rollback route or mark `failed`

---

## Health checks

Minimum checks:

- `GET https://ai.user.com`
- TLS handshake succeeds
- response is not a proxy-level error

Optional deeper checks:

- check expected OpenClaw response headers
- call a safe route like `/health` if available
- confirm certificate subject includes the domain

Suggested failure buckets:

- `dns_not_ready`
- `caddy_route_failed`
- `tls_issue_failed`
- `upstream_unreachable`
- `openclaw_config_failed`

---

## Detach workflow

When a domain is detached:

1. remove or disable Caddy route
2. update Pterodactyl env to remove that origin if needed
3. restart OpenClaw if config changed
4. mark record `detached`
5. keep an audit trail

If multiple origins are stored in `OPENCLAW_ALLOWED_ORIGINS`:

- remove only the detached origin
- preserve the rest

---

## Security requirements

Required:

- never allow one domain to be active on two servers
- do not activate before DNS verification passes
- Caddy Admin API must not be public
- log every attach, verify, retry, detach, and failure

Recommended:

- rate-limit domain submissions
- validate domains strictly
- forbid wildcard domains in the first version
- forbid internal-only hostnames
- require lowercase normalization

Operational safety:

- do not let containers mutate Caddy directly
- keep orchestration in one trusted backend

---

## Suggested implementation order

Phase 1:

- DB table
- domain submission UI
- DNS verification worker
- explicit Caddy route provisioning
- Pterodactyl env sync
- restart + health check

Phase 2:

- detach flow
- richer panel status
- audit trail UI
- retry queue

Phase 3:

- bulk operations
- certificate diagnostics
- optional on-demand TLS with `ask` endpoint

---

## Notes for OpenClaw in this repo

Current runtime support already helps the orchestration layer by writing:

- `/home/container/.openclaw/public-endpoint.json`
- `/home/container/.openclaw/caddy-route.caddy`

These files are useful as helper output, but they are not the source of truth.

The source of truth should stay in:

- the domain-manager database
- the generated Caddy config
- the Pterodactyl server environment

