# AGENTS.md — groundwork-api

Instructions for AI coding agents (and people) working in this repository. Keep it accurate: when a
convention or workflow changes, update this file in the same pull request.

## What this is

The backend for **Groundwork** (working name): company research before you apply — sourced company
reports, a personal fit verdict, and the right people to contact. The web app is
[groundwork-client](https://github.com/muddasir03/groundwork-client) (locally `../groundwork-client`).

- **Read [docs/PRODUCT.md](docs/PRODUCT.md) before designing any feature.** Every feature must serve
  at least one of its four promises and must not break its principles (see "Product rules" below).
- **Status:** company research is modelled (companies, sources, claims, facts, problems,
  technologies, people, citations) and served read-only at `GET /api/v1/companies` and
  `GET /api/v1/companies/:slug` (published companies only). Admins log in and edit research through
  `/api/v1/admin/*` (sessions, companies, report replacement, status changes). Member accounts, fit
  verdicts and AI features don't exist yet. Never describe features as built when they aren't.
- **Security design: [docs/SECURITY.md](docs/SECURITY.md).** Read it before touching authentication,
  authorization or anything that exposes data, and update it in the same PR.
- **API reference: [docs/API.md](docs/API.md)**, kept in sync with every endpoint change.
- **Stack:** Rails 8.1 in API mode, Ruby 4.0.7, PostgreSQL, Solid Queue/Cache/Cable, Minitest.

## Commands

```sh
bin/setup                       # install gems, prepare the database
bin/dev                         # server on http://localhost:3001 (the client uses :3000)
bin/rails test                  # run the test suite
bin/rubocop                     # style check (bin/rubocop -a to autocorrect)
bin/brakeman --no-pager -q      # security scan
bin/bundler-audit               # vulnerable gem check
bin/rails db:migrate            # apply migrations (updates db/schema.rb)
```

Ruby comes from rbenv via `.ruby-version`. If `ruby -v` shows 2.6, the rbenv shims aren't on `PATH`.

**Before opening a PR**, run `bin/rubocop`, `bin/brakeman --no-pager -q` and `bin/rails test`.
CI runs the same checks (`scan_ruby`, `lint`, `test`) and they must pass to merge.

## Git workflow

- `develop` deploys to **staging**, `main` deploys to **production**. Both are protected: changes
  arrive only by pull request, with CI green. No force-pushes, no direct pushes.
- Branch from the latest `develop`: `feature/<name>`, `fix/<name>`, `chore/<name>` or `docs/<name>`.
  Open the PR into `develop`.
- **Releases** are a PR from `develop` into `main`, merged by the project owner only. Agents never
  merge into `main`.
- `main` only receives merges from `develop`, so no back-merge is needed after a release (GitHub may
  show `develop` as "behind" by the release merge commit; that's harmless). If a fix ever has to go
  straight to `main`, merge `main` back into `develop` with a merge commit, not a squash.
- Keep PRs small and focused on one change. Commit messages: imperative mood, and say *why*.
- Update `README.md`, this file and `render.yaml` in the same PR when behaviour or setup changes.

## Code conventions

### API design
- JSON only. Version every endpoint: routes inside `namespace :api do namespace :v1 do ... end end`,
  controllers in `app/controllers/api/v1/`, inheriting from `Api::V1::BaseController` (create it with
  the first endpoint).
- Errors always use one shape, with the matching HTTP status:
  `{ "error": { "code": "not_found", "message": "Company not found" } }`.
  Map common exceptions in the base controller (`ActiveRecord::RecordNotFound` → 404,
  `ActionController::ParameterMissing` and `ActiveRecord::RecordInvalid` → 422), not in each action.
- List endpoints are paginated and filterable through query params (e.g. `country`, `sector`).
- Use resourceful routes and RESTful actions; avoid custom verbs unless there is no fitting resource.

### Serialization
- JSON is built by plain Ruby serializers in `app/serializers/` (no serialization gem). Each one lists
  every field explicitly, so new columns are never exposed by accident.
- Keys are **camelCase** and must match the client's contract (groundwork-client `lib/api/types.ts`).
  Change both, and `docs/API.md`, in step.
- Personal data (fit verdicts, approaches, "also on your profile") never appears in public
  endpoints; it belongs to authenticated, per-user endpoints.

### Security
- **Public endpoints expose published research only.** Unpublished records return the same 404 as
  missing ones (`Company.published`), so nothing in the pipeline can be probed.
- **Every write endpoint requires authentication and authorization.** Admin endpoints live under
  `Api::V1::Admin` and inherit `Api::V1::Admin::BaseController` (session + admin role, `no-store`).
  A test walks every admin route and checks it refuses requests without a session; keep it passing.
- Tokens come only from the `Authorization: Bearer` header. Store secrets as digests (session
  tokens) or bcrypt hashes (passwords); never serialize them.
- Audit every admin change with `audit!(...)` (AuditEvent, append-only).
- Writes that span several records go through a service in one transaction and return every
  validation problem with its path (see `Research::ReplaceReport`).
- Accounts are never created through the API: `bin/rails admin:create` (local) or the one-time
  `admin:bootstrap` (hosts without a console).
- URLs that reach the client are validated with `http_url: true` **and** a database check
  constraint (http(s) only).
- Rules the product depends on are enforced in the database as well as the model: check
  constraints, foreign keys, NOT NULL. Test that the database refuses bad data even when
  validations are skipped (`update_column`).
- List endpoints paginate with a hard cap (`pagination` in `Api::V1::BaseController`).
- `Api::V1::BaseController` rate limits per IP (`API_RATE_LIMIT`, default 300/minute).
- Queries for a response must not grow with the data (preload with scopes like
  `Company.with_report`); tests assert a fixed query count.

### Where code goes
- **Controllers stay thin:** read params, authorize, call a model or service, render.
- **Models** hold validations, associations, scopes and domain logic for one record.
- **Services** (`app/services/`) hold workflows that span several models or call external systems.
  Plain Ruby objects named for what they do (`Fit::Calculate`), with one public `call` method.
- **Jobs** (`app/jobs/`, Solid Queue) for slow or external work: research refreshes, CV parsing,
  fit calculation. Jobs must be safe to run twice (idempotent).
- Always use strong parameters.

### Database
- Database constraints match validations: `null: false`, foreign keys, unique indexes.
- Index foreign keys and every column used for filtering or sorting.
- Avoid N+1 queries: use `includes`/`preload` for associations rendered in lists.
- Migrations are reversible and do one thing. Never edit a migration that is already merged; add a
  new one. Commit `db/schema.rb` with every migration.
- One database per environment. Solid Cache, Queue and Cable tables live in the primary database
  (see the `CreateSolidTables` migration); don't reintroduce separate cache/queue/cable databases.

### Style and dependencies
- Style is `rubocop-rails-omakase` (`.rubocop.yml`). Don't disable a cop inline without a comment
  explaining why.
- Prefer what Rails already provides. **Ask the owner before adding a gem**, and say why in the PR.
- **Not decided yet — ask before choosing:** authentication approach, JSON serialization library,
  file storage for CV uploads, and the research/LLM provider.

## Testing

- Minitest, in `test/`. Every endpoint gets integration tests (`test/integration/` or
  `test/controllers/`) covering the success path and its main error cases. Models get unit tests for
  validations and domain logic. Services and jobs get their own tests.
- Build test data with the helpers in `test/support/` (e.g. `ResearchFactory#create_company`).
  Tests never make real network calls; stub external services.
- Database check constraints are tested inside `transaction(requires_new: true)`: a failed statement
  aborts the enclosing test transaction otherwise.
- A bug fix comes with a test that fails without the fix.

## Product rules that shape the code

These come from [docs/PRODUCT.md](docs/PRODUCT.md) and are requirements, not suggestions.

- **Every research claim has a source and a date.** Store the source URL and the researched-at date
  with each claim. A claim without a source is not stored.
- **Unknown is explicit.** Values that can't be verified are stored as `unconfirmed` or `not_public`,
  never guessed, and never as a bare `null` that could mean either.
- **Human review before publishing.** Company reports have a status (draft → in review → published).
  Users only ever see published reports.
- **Verdicts carry reasons.** A fit verdict stores the score, the band (`strong`, `possible`,
  `weak`), what matches, what's missing and an explanation. Never return a bare score.
- **Public information only about people.** No LinkedIn scraping, no private email addresses.
- **Users can delete all their data.** Every table holding user data must be removed when the user
  deletes their account (`dependent: :destroy` or a cascading foreign key), with a test proving it.
- **Research is shared.** Research is done once per company and shared by all users; don't compute
  per user anything that can be shared.

## Environments and deployment

| Environment | Branch      | API                                         | Database                 |
|-------------|-------------|---------------------------------------------|--------------------------|
| Local       | `feature/*` | http://localhost:3001                       | local Postgres           |
| Staging     | `develop`   | https://groundwork-api-staging.onrender.com    | Neon branch `staging`    |
| Production  | `main`      | https://groundwork-api-production.onrender.com | Neon branch `production` |

- Hosted on **Render's free plan**, defined in `render.yaml`. Render deploys only after CI passes.
- Services start with `bin/render-start`, which runs `db:prepare`, seeds the fictional sample data
  when `SEED_SAMPLE_DATA=true` (staging only), and then starts the server. Render's
  `dockerCommand` bypasses `bin/docker-entrypoint`, so keep database preparation in `bin/render-start`.
- Free plan limits: **512 MB RAM** (`WEB_CONCURRENCY=0`, jobs run inside Puma via
  `SOLID_QUEUE_IN_PUMA`), and the service sleeps after 15 minutes idle. Keep memory use low.
- `CORS_ORIGINS` lists the client URLs allowed to call the API; `*` is a wildcard.
- **New environment variable:** add it to `render.yaml` (`sync: false` for secrets), to the README's
  variables table, and tell the owner to set its values in the Render dashboard.
- Everything must stay within free tiers. Don't add a paid service, plan or add-on.

## Secrets

This repository is **public**.
- Never commit, print or paste `config/master.key`, `RAILS_MASTER_KEY`, `DATABASE_URL` values, or
  any token or password.
- App secrets go in encrypted credentials (`bin/rails credentials:edit`); deployment secrets go in
  Render's dashboard, entered by the owner.
