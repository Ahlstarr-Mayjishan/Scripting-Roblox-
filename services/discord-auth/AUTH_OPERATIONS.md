# NULLSCAPE Discord Auth

Cloudflare Worker authentication for the protected NULLSCAPE loader.

## Authentication flow

1. The loader creates a random client token and starts a 10-minute OAuth request.
2. Discord confirms the account, guild membership, and one of the allowed roles.
3. The Worker issues a 12-hour session bound to the client token.
4. D1 allows at most two active trusted devices for each Discord user.
5. The OAuth success page shows a one-time recovery code. A mobile user can relaunch
   Roblox, enter that code, and recover the approved request without sharing a key.
6. Moving an existing trusted slot to a new device is limited to once every 24 hours.

Raw IP addresses are never stored. The Worker stores a keyed IP digest plus country
and ASN as risk signals. An existing session used recently from a different country
or ASN must authenticate again. A fresh Discord OAuth approval is always allowed to
update the network signal, so VPN users are not permanently locked out.

No client-side mechanism can prove physical hardware identity in an executor. A user
who copies both their session and network environment may still evade detection. The
server-side device cap, short session lifetime, live role check, one-time recovery,
transfer cooldown, and concurrent-network re-auth reduce sharing without claiming to
make it impossible.

## Development

```text
npm install
npm run db:local
npm run check
```

Production deployments apply pending D1 migrations before publishing the Worker.

## Device administration

These commands use the Cloudflare account authenticated by Wrangler and do not expose
an administrative HTTP endpoint:

```text
npm run devices -- list 1446732482194968630
npm run devices -- revoke 1446732482194968630
```

`revoke` removes all active sessions and trusted-device slots for that Discord user.
Their next loader run must complete Discord OAuth again.

## Operational settings

- `MAX_TRUSTED_DEVICES`: active device slots per Discord user, default `2`.
- `DEVICE_TRANSFER_COOLDOWN_SECONDS`: trusted-device transfer cooldown, default `86400`.
- `CONCURRENT_NETWORK_WINDOW_SECONDS`: recent-session window for network step-up,
  default `180`.

Discord secrets and `TOKEN_PEPPER` must remain Worker secrets. They must never be
committed to the repository or returned to the loader.
