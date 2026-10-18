# groundwork-api

Rails 8.1 API (Ruby 4.0.7, PostgreSQL) for [groundwork-client](https://github.com/muddasir03/groundwork-client).

## Local development

```sh
bin/setup        # installs gems, prepares the database, starts the server
bin/dev          # http://localhost:3001 (the client runs on :3000)
bin/rails test
```

Requires Ruby 4.0.7 (see `.ruby-version`) and a local PostgreSQL server.

## Environments & releasing

| Environment | Branch    | Runs on                     | Database                      |
|-------------|-----------|-----------------------------|-------------------------------|
| Development | `feature/*` | your machine              | local Postgres                |
| Staging     | `develop` | Render (free) `groundwork-api-staging`    | Neon branch `staging`    |
| Production  | `main`    | Render (free) `groundwork-api-production` | Neon branch `production` |

1. Branch off `develop` (`feature/<name>`), open a PR into `develop`. CI must pass.
2. Merging into `develop` deploys to **staging** once CI passes. Test there.
3. To release, open a PR from `develop` into `main`. Merging deploys to **production**.

Staging and production both run with `RAILS_ENV=production`; only their environment variables differ:

| Variable           | Value                                                                 |
|--------------------|-----------------------------------------------------------------------|
| `RAILS_MASTER_KEY` | contents of `config/master.key` (never commit it)                     |
| `DATABASE_URL`     | Neon connection string for that environment's branch (the direct one, not `-pooler`) |
| `CORS_ORIGINS`     | the client's URL(s), comma-separated; `*` is a wildcard for preview URLs |
| `SOLID_QUEUE_IN_PUMA` | `true`: background jobs run inside the web process (set in `render.yaml`) |

Both Render services are defined in [`render.yaml`](render.yaml). Solid Cache, Queue and Cable share the
primary database (see the `CreateSolidTables` migration), so each environment needs only one database.
Migrations run automatically on deploy (`bin/docker-entrypoint` calls `db:prepare`).

Free-tier caveat: Render free services sleep after 15 minutes idle, so the first request after
a quiet period takes up to a minute.
