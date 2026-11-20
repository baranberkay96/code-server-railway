# TEMPLATE: code-server 4.145 VS Code in Your Browser

Composer spec. `template.json` is the machine-readable copy.

## Service

| Field | Value |
|---|---|
| Name | code-server |
| Source | repo `baranberkay96/code-server-railway`, root `/services/code-server` |
| Base | `codercom/code-server:4.145.2-debian@sha256:09565f9e…` (2026-11-07) |
| Added | Node.js 26.13.1 (nodejs.org, SHA-256), Python 3, build-essential, ripgrep, jq, tmux, pipx |
| Public domain | yes, target port 8080 |
| Healthcheck | `/healthz`, timeout 300 s |
| Restart | ON_FAILURE, 10 retries |
| Volume | `/home/coder` |

Variables: `PASSWORD` (`secret(32)`), `PORT` (8080), `TZ`, `GIT_REPO`, `EXTENSIONS`, `APT_PACKAGES`, `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` (10).

## Improvements over market templates

- Market leader (1.29k active projects) has no volume and an empty default password; here the whole home directory persists and the password is generated.
- Pinned code-server release by digest; Node.js pinned by version and SHA-256 (STANDARD 8.27).
- Short/empty/overlong passwords lock the login with a random password instead of failing the deploy or opening the editor (8.29).
- Volume ownership fixed once for the non-root `coder` user; shell files and editor settings seeded on a fresh volume.
- npm/pip/pipx "global" installs go to `~/.local` on the volume; `APT_PACKAGES` restore after redeploys.
- Optional `GIT_REPO` clone (credentials never logged), `EXTENSIONS` from Open VSX, `~/entrypoint.d` hook.
- Telemetry and update checks off.

## Resources

| Service | Idle RAM | Typical RAM | CPU |
|---|---|---|---|
| code-server | 0.12 GB (measured, no editor open) | 0.5–2 GB with language servers and builds | near 0 idle, 1–2 vCPU during builds |

Estimated cost: $2–10/month for occasional use. Minimum plan: Trial works for light editing; Hobby for real projects.

## Verification checklist

- `/healthz` 200; `/` redirects to `/login`; POST `/login` with the generated password sets a session cookie and `/` then returns 200.
- Terminal: `node --version`, `python3 --version`, `git --version`.
- Redeploy: files in `~/project` and installed extensions survive.
- `PASSWORD=abc`: deploy stays healthy, login locked, log explains.

## Open questions

- Extensions only from Open VSX (Microsoft marketplace terms forbid other products from using it).
