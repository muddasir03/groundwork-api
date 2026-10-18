# Groundwork API

> **Groundwork does the company research before you apply: what they do, whether you fit, and who to talk to, in minutes instead of days.**
>
> "Groundwork" is a working name; the final name will be chosen before launch.

## The problem

Job seekers spend days researching each company and still end up applying blindly, because they can't quickly answer three questions:

1. What does this company actually do?
2. Am I a good fit, and why or why not?
3. Who should I contact, and how should I approach them?

Answering these properly takes hours per company, so most people send generic CVs to dozens of companies instead. Groundwork is the opposite of mass-applying: fewer applications, better matched, each backed by real knowledge.

## The four promises

- **Instant and comparable.** Companies are researched in advance, so you can filter by country and sector and compare them side by side.
- **Verified and current.** Every claim shows its source and the date it was researched, and reports are refreshed regularly.
- **Personal and persistent.** You enter your profile once, and every company shows a fit verdict for you, saved for later.
- **Actionable.** Each company lists its senior people and suggests a way to approach them.

## Product principles

- **Trust over volume.** No invented facts. Anything that can't be verified is marked "Unconfirmed" or "Not public", and a person reviews every report before it's published.
- **Show the reasons.** A fit verdict is never a bare number; you always see why you fit or don't.
- **Respect privacy.** Only public information about companies and their people. No LinkedIn scraping, no private email addresses. Your CV and profile are yours, and you can delete all your data at any time.
- **Help people act, not just read.** Every company page leads to a next step.
- **Be honest about limits.** Groundwork informs decisions; it doesn't guarantee outcomes.
- **Stay affordable.** Each company is researched once and shared by all users.

## The user journey

1. **Create a profile:** upload a CV, link GitHub, GitLab, LinkedIn and a portfolio, and choose target countries and sectors.
2. **Confirm it:** review the skills, experience and languages Groundwork extracted, and correct anything wrong.
3. **Search companies** by country, sector, city, size and fit level.
4. **Read the report:** a sourced overview of what the company does, its clients and competitors, business model, product and engineering, team and hiring, market and risks.
5. **See your fit:** a score, a band (strong, possible or weak), what matches, what's missing, and why. Rate whether the verdict is right.
6. **Find the right people:** CEO, CTO, engineering leaders and talent leads, linked to their public profiles.
7. **Get an approach:** a proof-of-work idea based on the company's real gaps, who to contact, and a draft message.
8. **Compare and shortlist:** compare up to three companies, save them with notes, and track each from research to interview.

An internal admin area lets the team research, review, edit and publish companies, manage contacts, review verdict feedback and monitor costs.

## MVP scope

Groundwork is an MVP in early development. This repository currently serves published company research read-only (on fictional sample data); accounts, fit verdicts and the admin area are not built yet.

- **Planned for the MVP:** the journey above, launching with about 30 researched software and SaaS companies in Spain, for engineers looking for roles there.
- **Not included yet:** live job listings, visa sponsorship information, payments, sending messages or applying on your behalf, native mobile apps, and countries beyond Spain.

The full product brief is in [docs/PRODUCT.md](docs/PRODUCT.md).

## This repository

The backend for Groundwork. It stores company research and serves published reports read-only at `/api/v1/companies` (see [docs/API.md](docs/API.md)). User profiles, fit verdicts, shortlists and the admin area come next.

Rails 8.1 (API mode), Ruby 4.0.7, PostgreSQL.

### Local development

```sh
bin/setup        # installs gems, prepares the database, starts the server
bin/rails db:seed  # fictional sample research (6 published companies)
bin/dev          # http://localhost:3001 (the client runs on :3000)
bin/rails test
```

Requires Ruby 4.0.7 (see `.ruby-version`) and a local PostgreSQL server.

### Environments & releasing

| Environment | Branch      | Runs on                                   | Database                 |
|-------------|-------------|-------------------------------------------|--------------------------|
| Development | `feature/*` | your machine                              | local Postgres           |
| Staging     | `develop`   | Render (free) `groundwork-api-staging`    | Neon branch `staging`    |
| Production  | `main`      | Render (free) `groundwork-api-production` | Neon branch `production` |

`develop` and `main` are protected: changes arrive only through pull requests, and CI must pass.

1. Branch off `develop` (`feature/<name>`), open a PR into `develop`. CI must pass.
2. Merging into `develop` deploys to **staging** once CI passes. Test there.
3. To release, open a PR from `develop` into `main`. Merging deploys to **production**.

Staging and production both run with `RAILS_ENV=production`; only their environment variables differ:

| Variable              | Value                                                                                |
|-----------------------|--------------------------------------------------------------------------------------|
| `RAILS_MASTER_KEY`    | contents of `config/master.key` (never commit it)                                    |
| `DATABASE_URL`        | Neon connection string for that environment's branch (the direct one, not `-pooler`) |
| `CORS_ORIGINS`        | the client's URL(s), comma-separated; `*` is a wildcard for preview URLs             |
| `SOLID_QUEUE_IN_PUMA` | `true`: background jobs run inside the web process (set in `render.yaml`)            |
| `WEB_CONCURRENCY`     | `0`: a single Puma process, to fit the free plan's 512 MB (set in `render.yaml`)     |
| `SEED_SAMPLE_DATA`    | `true` on **staging only**: loads fictional sample research on start. Never on production |
| `API_RATE_LIMIT`      | Optional. Requests per minute per IP for `/api/v1` (default 300)                      |

Both Render services are defined in [`render.yaml`](render.yaml) and start with `bin/render-start`, which
prepares the database (creating tables and running migrations) before booting the server. Solid Cache,
Queue and Cable share the primary database (see the `CreateSolidTables` migration), so each environment
needs only one database.

Free-tier caveat: Render free services sleep after 15 minutes idle, so the first request after
a quiet period takes up to a minute.
