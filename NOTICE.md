# NOTICE: code-server template

This is a community template. It is not made, endorsed or supported by Coder, Microsoft or Railway. Visual Studio Code and VS Code are trademarks of Microsoft Corporation; code-server is an open-source project by Coder Technologies, Inc.

## Components

| Component | Source | License | How it is used |
|---|---|---|---|
| code-server 4.145.2 (release image `codercom/code-server:4.145.2-debian`, digest `sha256:09565f9e07f5624554e295e8bab0e2fec4a7c533eb3cff459ed6596a4d3d7c1c`) | https://github.com/coder/code-server | MIT (Copyright (c) 2019 Coder Technologies Inc.) | Base image (`FROM`), unmodified |
| Code - OSS (VS Code open-source core, bundled in code-server) | https://github.com/microsoft/vscode | MIT | Inside the base image |
| Node.js 26.13.1 (`node-v26.13.1-linux-x64.tar.xz`, SHA-256 `5c063e46bab0fbc1c17cc445d7ff129cbdcd0471be6ed83b6ab864f8143bc864`) | https://nodejs.org/dist/v26.13.1/ | MIT, with bundled components under their own licenses | Downloaded at build time into `/usr/local` |
| Debian 13 packages (Python 3, build-essential, ripgrep, jq, tmux and others) | https://packages.debian.org/trixie/ | Each package's own license (`/usr/share/doc/*/copyright`) | Installed with apt at build time |
| dumb-init, fixuid | in coder's image | MIT | `dumb-init` is the entrypoint wrapper; fixuid is not used |

The MIT license of code-server requires the copyright notice above to be kept with copies of the software. The image carries code-server's own `LICENSE` under `/usr/lib/code-server`.

## Files written for this template

`Dockerfile`, `railway-start.sh`, `profile.sh`, `settings.json` and the documentation were written for this template and are offered under the MIT License. `pkg-restore.sh` comes from our own desktop and browser templates. No file of coder/code-server or coder/deploy-code-server was copied; the `~/entrypoint.d` hook re-implements the behaviour of code-server's `ci/release-image/entrypoint.sh`.

## Upstream files checked

- `ci/release-image/Dockerfile` and `ci/release-image/entrypoint.sh` of coder/code-server (main, matching v4.145.2): user `coder` uid 1000, passwordless sudo, `dumb-init`, `ENTRYPOINTD`.
- `src/node/cli.ts` at v4.145.2: `PASSWORD`/`HASHED_PASSWORD` are read from the environment and then deleted from it.
- `src/node/routes/index.ts` at v4.145.2: unauthenticated `/healthz`.
- Docker Hub tag `4.145.2-debian` (pushed 2026-11-07), same digest as `4.145.2`.

## Market templates

The marketplace's "Code Server" template (coder/deploy-code-server, no volume, empty password by default) and "VS Code Dev Box (code-server)" were reviewed for features only. No files or text were copied.
