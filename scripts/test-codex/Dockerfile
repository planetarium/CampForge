FROM node:20-bookworm

# Minimal deps for install scripts + codex
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git python3 bubblewrap && \
    rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -s /bin/bash tester

# npm global prefix for non-root
RUN mkdir -p /home/tester/.npm-global/lib /home/tester/.npm-global/bin /home/tester/.local/bin && \
    chown -R tester:tester /home/tester/.npm-global /home/tester/.local
USER tester
ENV NPM_CONFIG_PREFIX=/home/tester/.npm-global
ENV PATH=/home/tester/.npm-global/bin:/home/tester/.local/bin:$PATH
WORKDIR /home/tester

# Install Codex CLI (pinned for reproducible builds)
ARG CODEX_VERSION=0.118.0
RUN npm install -g @openai/codex@${CODEX_VERSION}
