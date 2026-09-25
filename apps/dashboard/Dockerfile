# syntax=docker/dockerfile:1
# Tree dashboard (apps/dashboard). Build from the repository root:
#   docker build -f apps/dashboard/Dockerfile -t openquest-dashboard .
# TypeScript runs straight from the sources through tsx, so there is no compile step.

ARG NODE_VERSION=22
ARG PNPM_VERSION=10.34.5
ARG TSX_VERSION=4.23.15

FROM node:${NODE_VERSION}-alpine AS deps
ARG PNPM_VERSION
RUN npm install -g pnpm@${PNPM_VERSION} && npm cache clean --force
WORKDIR /repo
COPY . .
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile --prod --filter "@openquest/dashboard..."
# A filtered install still links the dependencies of the workspace root (Next.js and friends), and
# `pnpm list` reports them too. Walk the dashboard's runtime dependency graph instead and copy only
# the reachable packages to /out, keeping the repository layout and pnpm's relative symlinks.
RUN <<'EOF' node
const fs = require("node:fs"), path = require("node:path");
const seen = new Set(), store = new Set();
function visit(dir) {
  if (seen.has(dir)) return;
  seen.add(dir);
  const m = dir.match(/^(\/repo\/node_modules\/\.pnpm\/[^/]+)\//);
  if (m) store.add(m[1]);
  const pkg = JSON.parse(fs.readFileSync(path.join(dir, "package.json"), "utf8"));
  const names = Object.keys({ ...pkg.dependencies, ...pkg.optionalDependencies, ...pkg.peerDependencies });
  for (const name of names) {
    // pnpm links every dependency next to the package: <pkg>/node_modules/<dep> or <store entry>/node_modules/<dep>.
    const candidates = [path.join(dir, "node_modules", name)];
    if (m) candidates.push(path.join(m[1], "node_modules", name));
    const hit = candidates.find((c) => fs.existsSync(c));
    if (hit) visit(fs.realpathSync(hit));
  }
}
visit("/repo/apps/dashboard");
fs.mkdirSync("/out/node_modules/.pnpm", { recursive: true });
for (const entry of store) fs.cpSync(entry, path.join("/out/node_modules/.pnpm", path.basename(entry)), { recursive: true, verbatimSymlinks: true });
for (const p of ["package.json", "pnpm-workspace.yaml", "packages", "apps/dashboard"])
  fs.cpSync(path.join("/repo", p), path.join("/out", p), { recursive: true, verbatimSymlinks: true });
console.log(`copied ${store.size} packages`);
EOF

FROM node:${NODE_VERSION}-alpine AS runtime
ARG TSX_VERSION
RUN npm install -g tsx@${TSX_VERSION} && npm cache clean --force
ENV NODE_ENV=production \
    PORT=8787
WORKDIR /app
# Files stay owned by root (read-only for the app); the server keeps its cache in memory.
COPY --from=deps /out ./
USER node
WORKDIR /app/apps/dashboard
EXPOSE 8787
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8787)+'/').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"
CMD ["tsx", "src/server.ts"]
