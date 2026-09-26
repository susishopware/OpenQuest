#!/bin/sh
# Builds .NET settings from the separate values that hosting platforms (e.g. Render) provide.
# Explicit ConnectionStrings__Default / Storage__* always win, so docker compose keeps working unchanged.
set -e
if [ -z "${ConnectionStrings__Default:-}" ] && [ -n "${DB_HOST:-}" ]; then
  export ConnectionStrings__Default="Host=${DB_HOST};Port=${DB_PORT:-5432};Database=${DB_NAME};Username=${DB_USER};Password=${DB_PASSWORD}"
fi
if [ -z "${Storage__AccessKey:-}" ] && [ -n "${MINIO_ROOT_USER:-}" ]; then
  export Storage__AccessKey="${MINIO_ROOT_USER}" Storage__SecretKey="${MINIO_ROOT_PASSWORD}"
fi
exec dotnet OpenQuest.Api.dll "$@"
