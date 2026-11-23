# Deploy and Host code-server with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/code-server-4-vs-code-in-your-browser?referralCode=20H68q)

code-server is Coder's open-source build of VS Code that runs on a server and opens in any browser. This template deploys code-server 4.145.2 behind its own password login, with a persistent home directory for your projects, extensions and settings, and a ready toolchain: git, Node.js 26 LTS, Python 3 and build tools.

## About Hosting code-server

code-server needs one long-running process, a public HTTPS URL, a password and storage that survives redeploys. This community template builds on coder's pinned `codercom/code-server:4.145.2-debian` image and adds Node.js from nodejs.org (SHA-256 checked) plus Debian's Python, gcc, make, ripgrep, jq and tmux. A start script makes the Railway volume at `/home/coder` usable by the unprivileged `coder` user, checks the password, optionally clones a Git repository and installs extensions, and then starts code-server with password authentication. The `/healthz` endpoint is Railway's healthcheck.

## Common Use Cases

- Code from a tablet, a Chromebook or a borrowed computer with the same editor, terminal and extensions everywhere
- Keep a cloud development box for side projects, scripts and bots that runs while your laptop is off
- Give workshops and classes a ready environment per participant (one deploy each)
- Edit and test code close to your other Railway services over the private network

## Dependencies for code-server Hosting

- One service built from a small Dockerfile on top of `codercom/code-server` (no database, no API keys)
- A Railway volume mounted at `/home/coder`

### Deployment Dependencies

- [code-server on GitHub](https://github.com/coder/code-server)
- [code-server documentation](https://coder.com/docs/code-server)
- [code-server FAQ (extensions, Open VSX)](https://coder.com/docs/code-server/FAQ)
- [Open VSX extension registry](https://open-vsx.org/)
- [Node.js releases](https://nodejs.org/en/about/previous-releases)

### Implementation Details

| Service | What runs inside | Volume | Port |
|---|---|---|---|
| code-server | code-server 4.145.2 as user `coder` (uid 1000), password login, `/healthz` | `/home/coder` | 8080 (public HTTPS domain) |

**Plan:** Trial or higher. Measured on Railway: about 0.12 GB RAM idle with no editor open; an open editor with language servers and builds typically needs 0.3–2 GB. Give the service more RAM for large projects.

**First login**

1. Wait until the deploy is healthy (the first build takes a few minutes).
2. Open the public URL and enter `PASSWORD` from the service's Variables tab.
3. The editor opens the folder `~/project`. Open a terminal with Ctrl+` (backquote).

**Optional settings**

- `GIT_REPO`: a Git URL that is cloned into `~/project` on the first start, when the folder is empty. For a private repository, clone it from the terminal instead, or add an SSH key under `~/.ssh` (the volume keeps it).
- `EXTENSIONS`: extension ids from Open VSX, for example `ms-python.python esbenp.prettier-vscode`, installed at each start (already installed ones are skipped). Microsoft's own marketplace is not available in code-server; most popular extensions are on Open VSX.
- `APT_PACKAGES`: Debian packages reinstalled after every redeploy, for example `postgresql-client redis-tools`. You can also list them in `~/.config/railway/packages`.
- `~/entrypoint.d/`: executable scripts there run as `coder` before code-server starts, as in coder's own image.

**What persists**

Everything under `/home/coder`: projects, extensions (`~/.local/share/code-server`), editor settings, shell history, SSH keys, and tools installed with `npm install -g`, `pip install --user` or `pipx` (they go to `~/.local`). Packages installed with `sudo apt install` live in the image and reset on redeploy; use `APT_PACKAGES` for those.

**Security**

- code-server always runs with password authentication and rate-limits failed logins. An empty password, or one shorter than 8 characters or longer than 256 bytes, never opens the editor: code-server then starts with a random password nobody knows and the deploy log says how to fix it. Use 12 or more characters.
- code-server removes `PASSWORD` from its environment, so terminals and extensions cannot read it. To use a hash instead, set `HASHED_PASSWORD` (argon2).
- Anyone with the password gets a shell with passwordless `sudo` inside the container, and can read every secret you store there. Do not share the login.

**Scaling and upgrades**

One user, one volume: keep one replica and give the service more RAM or CPU when builds or language servers need it. To upgrade, change the `FROM` line in `services/code-server/Dockerfile` to a newer release tag and digest (and `NODE_VERSION` with its SHA-256 if you want a newer Node.js), then redeploy; the home directory is kept.

**Limits**

No Docker inside the container (Railway runs no nested containers), so Dev Containers and `docker build` do not work; deploy those as separate Railway services. The service listens on one port: preview other ports through code-server's built-in proxy at `/proxy/{port}/`. Railway's Fair Use Policy applies: no cryptocurrency mining, proxies or reselling compute.

### Why Deploy code-server on Railway?

Railway gives code-server HTTPS, a persistent volume and usage-based billing without a server to maintain. You get your editor at a URL in a few minutes, pay for the RAM and CPU it actually uses, and can resize it from the dashboard. This is a community template, not affiliated with Coder, Microsoft or Railway.
