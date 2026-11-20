# syntax=docker/dockerfile:1
#
# code-server 4.145.2 (VS Code in the browser) with a developer toolchain, for Railway.
#
# Base: coder's release image (Debian 13), multi-arch index digest from
# Docker Hub. To upgrade, replace tag and digest together with a newer
# release from https://github.com/coder/code-server/releases.
FROM codercom/code-server:4.145.2-debian@sha256:09565f9e07f5624554e295e8bab0e2fec4a7c533eb3cff459ed6596a4d3d7c1c

# Node.js LTS from nodejs.org (release tarballs stay downloadable; checked
# against the release's SHASUMS256.txt). Distribution packages give Python,
# compilers and the usual command-line tools.
ARG NODE_VERSION=26.13.1
ARG NODE_SHA256=5c063e46bab0fbc1c17cc445d7ff129cbdcd0471be6ed83b6ab864f8143bc864

USER root

RUN set -eux; \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential ca-certificates file jq less make openssh-client pkg-config \
    python3 python3-dev python3-pip python3-venv pipx ripgrep rsync tmux tree \
    unzip xz-utils zip; \
  curl -fsSL --retry 5 --retry-all-errors -o /tmp/node.tar.xz \
    "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"; \
  echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c -; \
  tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
    --exclude='*/CHANGELOG.md' --exclude='*/README.md' --exclude='*/LICENSE'; \
  rm -f /tmp/node.tar.xz; \
  node --version; npm --version; python3 --version; git --version; \
  apt-get clean; \
  rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start
COPY --chmod=0755 pkg-restore.sh /usr/local/bin/railway-pkg-restore
COPY --chmod=0644 profile.sh /etc/profile.d/railway-dev.sh
COPY --chmod=0644 settings.json /usr/local/share/railway-code-server/settings.json

# Image defaults. Variables set on the Railway service win.
#  - npm and pip install "global" tools into the home directory, which is
#    the Railway volume, so they survive redeploys.
ENV PORT=8080 \
    NPM_CONFIG_PREFIX=/home/coder/.local \
    PIPX_HOME=/home/coder/.local/share/pipx \
    PIPX_BIN_DIR=/home/coder/.local/bin \
    PATH=/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 8080
WORKDIR /home/coder

# railway-start runs as root only long enough to prepare the volume, then
# starts code-server as the unprivileged user "coder" (uid 1000).
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/railway-start"]
