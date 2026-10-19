# Security design

How Groundwork authenticates admins, authorizes requests and protects research data. Update this
file in the same pull request as any change to authentication, authorization or data exposure.

## What we protect

| Asset | Risk if exposed or changed |
|---|---|
| Unpublished research (draft, researching, in review) | Unreviewed claims about real companies reaching the public (breaks "Trust over volume") |
| Published research | Defacement or false claims shown to users |
| Admin accounts and sessions | Full control of research |
| (Later) user profiles and CVs | Personal data; users must be able to delete it |

## Architecture

```
Browser ──HTTPS──▶ Next.js on Vercel ──HTTPS + Bearer token──▶ Rails API on Render ──▶ Postgres (Neon)
         cookie: __Host- HttpOnly Secure SameSite=Strict
```

- The browser never sees an API token. The client app's server (Next.js server actions and Server
  Components) holds it in an HttpOnly cookie and sends it to the API as `Authorization: Bearer`.
- Public research endpoints need no authentication. Every `/api/v1/admin/*` endpoint does.

## Admin authentication

- **Accounts** are created only by `bin/rails admin:create` (interactive, the password is never in
  shell history) or, once, by `admin:bootstrap` on hosts without a console. There is no sign-up or
  admin-creation endpoint.
- **Passwords**: bcrypt (`has_secure_password`), 12–72 characters.
- **Login** (`POST /api/v1/admin/session`):
  - `User.authenticate_by` takes the same time whether or not the email exists (no account enumeration by timing);
  - unknown email, wrong password and non-admin account all get the same `401 invalid_credentials`;
  - rate limited per IP (10/minute) and per email address (10 per 15 minutes; also covers attacks
    spread over many IPs), then `429`;
  - every attempt is audited (`admin.login`, `admin.login_failed`).
- **Sessions**: a 256-bit random token, returned once at login. Only its SHA-256 digest is stored,
  so a database leak doesn't grant access. A session ends after **8 hours**, after **2 idle hours**,
  or at logout (revoked on the server). Expired sessions are deleted daily.
- **Tokens are accepted only from the `Authorization: Bearer` header**, never from URLs (which end up
  in logs and history) or cookies (the API has no cookie auth, so no CSRF surface).

## Authorization

- `Api::V1::Admin::BaseController` runs before every admin action: no valid session → `401`;
  valid session but not an admin → `403`.
- A test walks every `/api/v1/admin` route and asserts it refuses requests without a session.
- Public endpoints only ever read `Company.published`. Unpublished companies return the same `404`
  as missing ones.

## Input handling

- Strong parameters with explicit shapes (`params.expect`); unknown fields are dropped. Admins can't
  set `status`, `slug` (after creation) or `published_at` through edit endpoints.
- Status changes go through `Research::ChangeStatus` (allowed transitions only; publishing needs a
  complete report).
- Report edits go through `Research::ReplaceReport`: one transaction, all or nothing, with size
  limits (≤ 100 sources, ≤ 30 items per list) and length limits on every text field.
- URLs: absolute `http(s)` only, enforced by `HttpUrlValidator` and database check constraints.
- Database check constraints and foreign keys back the core rules (see the research migration).

## Responses

- Serializers list every field explicitly. Users are serialized with `User#as_api_json` (never the
  password digest); session digests are never serialized.
- Admin responses send `Cache-Control: no-store`.
- Errors use one JSON shape and never include stack traces.

## Audit log

`audit_events` records logins, failed logins, logouts, company creation, edits, report replacements
and status changes, with the admin, subject, IP and details. Rows are read-only in the app.

## Client (groundwork-client)

- The session cookie: `HttpOnly`, `Secure`, `SameSite=Strict`, `__Host-` prefix in production,
  expires with the API session.
- A data access layer (`lib/admin/`) verifies the session with the API on every admin page and in
  every server action. Layouts are never relied on for auth checks.
- Next.js server actions check the request's `Origin`, which protects them against CSRF.

## Known limitations and follow-ups

- **Rate limiting by IP behind proxies.** The API sees the visitor's IP for public requests only if
  Render/Cloudflare forward it in a way Rails trusts; admin logins arrive from Vercel's servers. The
  per-email login limit protects accounts regardless. Verify `request.remote_ip` on staging.
- **No multi-factor authentication yet.** Recommended before inviting more admins.
- **No account lockout** (deliberately: lockouts let attackers lock admins out). Rate limits apply instead.
- Audit log retention and review screens don't exist yet.
