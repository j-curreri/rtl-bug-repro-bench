# Sandbox for one benchmark episode: Claude Code plus make. No git, curl or wget, so the
# model cannot pull the upstream CVA6 history; the episode workspace is the only bind mount
# besides read-only toolchains.
FROM ubuntu:26.04
RUN apt-get update && apt-get install -y --no-install-recommends make ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY claude /usr/local/bin/claude
# The base image's `ubuntu` user is uid 1000, matching the host owner of the workspace.
USER ubuntu
WORKDIR /work
