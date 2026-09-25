# syntax=docker/dockerfile:1
# OpenQuest API (.NET 10, apps/api/OpenQuest.Api). Build from the repository root:
#   docker build -f apps/api/Dockerfile -t openquest-api .
# EF Core migrations run on startup (Database:MigrateOnStartup, default true), so there is no extra step.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG TARGETARCH
WORKDIR /src
# Publish for the target Linux architecture only; otherwise native assets (SkiaSharp) for every OS ship too.
RUN echo "linux-$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x64)" > /tmp/rid
# Restore first so the package layer stays cached until a project file changes.
COPY apps/api/OpenQuest.Api/OpenQuest.Api.csproj apps/api/OpenQuest.Api/
COPY packages/core/OpenQuest.Core/OpenQuest.Core.csproj packages/core/OpenQuest.Core/
COPY packages/adapters/de-muenster/OpenQuest.Adapters.Muenster/OpenQuest.Adapters.Muenster.csproj packages/adapters/de-muenster/OpenQuest.Adapters.Muenster/
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet restore apps/api/OpenQuest.Api/OpenQuest.Api.csproj -r "$(cat /tmp/rid)"
COPY apps/api/OpenQuest.Api apps/api/OpenQuest.Api
COPY packages/core/OpenQuest.Core packages/core/OpenQuest.Core
COPY packages/adapters/de-muenster/OpenQuest.Adapters.Muenster packages/adapters/de-muenster/OpenQuest.Adapters.Muenster
RUN --mount=type=cache,id=nuget,target=/root/.nuget/packages \
    dotnet publish apps/api/OpenQuest.Api/OpenQuest.Api.csproj -c Release -r "$(cat /tmp/rid)" --self-contained false -o /app --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .
# Same port as launchSettings.json, so clients work the same with and without Docker.
ENV ASPNETCORE_HTTP_PORTS=5076
EXPOSE 5076
# The image ships no curl; bash speaks HTTP through /dev/tcp. The OpenAPI document doubles as health endpoint.
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/5076 && printf 'GET /openapi/v1.json HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && head -n1 <&3 | grep -q ' 200 '"]
USER $APP_UID
ENTRYPOINT ["dotnet", "OpenQuest.Api.dll"]
