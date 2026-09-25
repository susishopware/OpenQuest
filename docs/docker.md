# Running OpenQuest with Docker

`docker-compose.yml` in the repository root starts the whole stack locally. Every image is built from the
repository root as build context (shared `.dockerignore`).

| Service | Image / Dockerfile | Host port | Notes |
|---|---|---|---|
| `web` | `Dockerfile.web` | 3000 | Next.js player app and admin prototype (`src/app`), standalone server |
| `api` | `apps/api/Dockerfile` | 5076 | .NET 10 API, applies EF Core migrations and seeds on startup |
| `dashboard` | `apps/dashboard/Dockerfile` | 8787 | Tree dashboard with map and Jev search, runs the TypeScript sources through `tsx` |
| `db` | `postgis/postgis:17-3.5` | 5432 | PostgreSQL with PostGIS, volume `db-data` |
| `minio` | `bitnamilegacy/minio` | 9000 (S3 API), 9001 | Photo and snapshot storage, bucket `openquest-photos`, volume `minio-data` |

All application containers run as non-root users and have a Docker health check.

## Start

```bash
cp .env.example .env            # optional; add OPENROUTER_API_KEY for Jev search and photo verification
docker compose up -d --build
docker compose ps               # wait until everything is "healthy"
```

Without `.env` everything still starts: the dashboard falls back to rule based search and the API runs in Development.

Checks:

```bash
curl -s --compressed localhost:8787/api/trees | head -c 100
curl -s --compressed -X POST localhost:8787/api/search -H 'content-type: application/json' -d '{"q":"größte Birken"}'
curl -s -o /dev/null -w '%{http_code}\n' localhost:5076/openapi/v1.json    # API health (no dedicated endpoint yet)
curl -s -o /dev/null -w '%{http_code}\n' localhost:3000/
```

Stop with `docker compose down` (data stays in the volumes); `docker compose down -v` also deletes database and storage.

## Configuration

- `.env` is optional (`env_file` with `required: false`) and is passed to `api` and `dashboard`. Compose also uses it
  for the variables in `docker-compose.yml`, see the "Docker Compose" section of `.env.example`.
- Inside the containers the database and storage addresses point to the `db` and `minio` services. They override the
  `localhost` values in `.env`, so the same `.env` works for `dotnet run` on the host.
- Host ports can be moved when one is taken, e.g. `DASHBOARD_PORT=18787 docker compose up -d`.
- The API runs with `ASPNETCORE_ENVIRONMENT=Development` by default: the JWT key is random per start and the admin
  password is generated on first start and printed once: `docker compose logs api | grep "generated password"`.
  Set `Admin__Password` in `.env` to choose it. Load the trees of Münster as described in `apps/api/README.md`.

## Only the backing services

```bash
docker compose up -d db minio
dotnet run --project apps/api/OpenQuest.Api
pnpm dev                                        # Next.js on the host
pnpm --filter @openquest/dashboard start        # dashboard on the host
```

## Known limitations

- `postgis/postgis` is published for amd64 only. On Apple Silicon it runs through emulation (`platform: linux/amd64`).
  A native arm64 image can be set with `DB_IMAGE=imresamu/postgis:17-3.5` and `DB_PLATFORM=linux/arm64` (use a fresh
  `db-data` volume when switching).
- The frozen Bitnami MinIO build has no web console, so port 9001 does not answer. Use the S3 API on port 9000
  (for example with `mc` or the AWS CLI).
- `Dockerfile.web` needs `output: "standalone"` in `next.config.*`.
