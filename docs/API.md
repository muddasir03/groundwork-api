# Groundwork API

Version 1, served under `/api/v1`. JSON only. Keys are camelCase and match the client's data
contract in [groundwork-client `lib/api/types.ts`](https://github.com/muddasir03/groundwork-client/blob/develop/lib/api/types.ts).

| Environment | Base URL |
|---|---|
| Local | `http://localhost:3001/api/v1` |
| Staging | `https://groundwork-api-staging.onrender.com/api/v1` (fictional sample data) |
| Production | `https://groundwork-api-production.onrender.com/api/v1` |

## Conventions

- **Errors** always have this shape, with the matching HTTP status:
  `{ "error": { "code": "not_found", "message": "Not found" } }`.
  Codes so far: `not_found` (404), `parameter_missing` (422), `rate_limited` (429).
- **Lists** return `{ "data": [...], "meta": { "page", "perPage", "total" } }`. `page` starts at 1;
  `per_page` defaults to 20 and is capped at 50.
- **Dates** are ISO 8601 calendar dates (`"2026-09-30"`).
- **Unknowns are explicit.** A fact's `value` is `null` unless its `status` is `"verified"`; a
  person's `name` is `null` when it isn't public. Clients show "Unconfirmed" / "Not public", never a guess.
- **Personal data is not here yet.** Fit verdicts, approaches and "also on your profile" depend on
  the signed-in user and arrive with accounts.

## Endpoints

### `GET /companies`

Published companies, ordered by name.

| Query parameter | Meaning |
|---|---|
| `country`, `sector`, `city` | Exact match |
| `size` | `1-50`, `51-200`, `201-1000` or `1000+` |
| `page`, `per_page` | Pagination (see above) |

```json
{
  "data": [
    {
      "slug": "brisa-people", "name": "Brisa People",
      "description": "HR and payroll platform for small and mid-sized businesses.",
      "city": "Valencia", "country": "Spain", "sector": "HR tech", "size": "201-1000",
      "stage": "Series C", "researchedAt": "2026-09-30", "sourceCount": 6
    }
  ],
  "meta": { "page": 1, "perPage": 20, "total": 6 }
}
```

### `GET /companies/:slug`

One published company's full research report. Unpublished and unknown companies both return the
same `404`, so the research pipeline can't be probed.

```json
{
  "data": {
    "slug": "brisa-people", "name": "Brisa People", "...": "summary fields as above",
    "peopleVerifiedAt": "2026-09-30",
    "report": {
      "summary": { "text": "…", "sourceIds": ["1", "5"] },
      "keyFacts": [{ "label": "Founded", "value": "2018", "status": "verified", "sourceIds": ["1"] }],
      "problems": { "core": { "text": "…", "sourceIds": ["2"] }, "rows": [{ "who": "…", "problem": "…", "solution": "…", "sourceIds": ["2"] }] },
      "clients": [], "competitors": [], "goals": [],
      "productEngineering": { "stack": [{ "name": "Ruby on Rails" }], "points": [] },
      "teamHiring": [{ "label": "Pay", "value": null, "status": "not_public", "sourceIds": [] }],
      "marketRisks": []
    },
    "sources": [{ "id": "1", "title": "…", "url": "https://…", "dateKind": "published", "date": "2026-06-12" }],
    "people": [{ "id": "3", "name": null, "role": "Chief Technology Officer", "profileUrl": null }]
  }
}
```

Every `sourceIds` entry refers to a source in the same response's `sources` list.

## Security

- **Read-only and public:** these endpoints expose only *published* research, which the product
  brief says anyone may read. There are no write endpoints yet; editing will come with the admin
  area, behind admin authentication.
- **Rate limited** per client IP: `API_RATE_LIMIT` requests per minute (default 300), then `429`.
  Counters live in Solid Cache in production.
- **Safe links:** source and profile URLs must be absolute `http(s)` URLs, enforced by the models
  (`HttpUrlValidator`) and by database check constraints, so `javascript:` or `data:` links can't
  reach the client.
- **Integrity in the database:** check constraints and foreign keys back the model rules (known
  statuses and sizes, slug format, a value only on verified facts, cascading deletes).
- **No accidental exposure:** serializers list every field explicitly, so new columns are never
  exposed by default.
- **CORS** allows only the configured client origins (`CORS_ORIGINS`).
- **Known follow-up:** the rate limit keys on `request.remote_ip`. Confirm on staging that this is the
  visitor's IP and not a proxy's (Render sits behind Cloudflare). Until then, all visitors behind one
  proxy IP could share a counter.
