# OpenClaw Custom Domain Flow

This document describes the recommended custom-domain flow for OpenClaw when running behind Pterodactyl with a reverse proxy such as Caddy.

## Goal

Users should be able to open OpenClaw on their own HTTPS domain, for example:

- `https://ai.user.com`

without having to interact with the random `domain:port` allocation that Pterodactyl provides.

## Recommended Flow

1. The user enters `OPENCLAW_ALLOWED_ORIGINS=https://ai.user.com`.
2. The hosting platform creates a `pending` custom-domain record.
3. The platform shows DNS instructions to the user.
4. A verification job checks:
   - the domain resolves to the hosting proxy
   - the domain is not already attached to another server
5. When verification passes, the platform:
   - creates the HTTPS route in Caddy
   - sets `OPENCLAW_ALLOWED_ORIGINS=https://ai.user.com` if not already set
   - restarts the OpenClaw server
6. The record is marked `active`.

## OpenClaw Runtime Support

The OpenClaw runtime in this repo supports the following relevant variables:

- `OPENCLAW_ALLOWED_ORIGINS`
- `OPENCLAW_PROXY_UPSTREAM_HOST`

Behavior:

- The first origin in `OPENCLAW_ALLOWED_ORIGINS` is treated as the primary public origin.
- The runtime extracts the host from that origin to generate helper files for proxy orchestration.

## Generated Files

At startup, the runtime writes:

- `/home/container/.openclaw/public-endpoint.json`
- `/home/container/.openclaw/caddy-route.caddy`

These files are meant to help external orchestration systems inspect or reuse the requested public endpoint.

Example `public-endpoint.json`:

```json
{
  "kind": "openclaw-public-endpoint",
  "version": 1,
  "publicDomain": "ai.user.com",
  "publicOrigin": "https://ai.user.com",
  "bind": "lan",
  "upstreamHost": "127.0.0.1",
  "upstreamPort": "8123",
  "upstream": "127.0.0.1:8123"
}
```

Example `caddy-route.caddy`:

```caddy
ai.user.com {
  reverse_proxy 127.0.0.1:8123
}
```

## Recommended OpenClaw Settings

- `OPENCLAW_BIND=lan`
- `OPENCLAW_ALLOWED_ORIGINS=https://ai.user.com`
- `OPENCLAW_ALLOW_HOST_HEADER_ORIGIN_FALLBACK=false`
- `OPENCLAW_GATEWAY_TOKEN=<token>`

## Security Notes

- Do not allow the same domain to be attached to multiple servers.
- Only activate the domain after DNS verification passes.
- Keep the Caddy admin API on a private interface only.
- Prefer private-node networking between the proxy and OpenClaw when possible.
- Audit every domain attach, detach, and update operation.
