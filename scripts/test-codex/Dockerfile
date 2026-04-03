FROM ghcr.io/openai/codex-universal:latest

# codex-universal runs as root; create non-root user
RUN useradd -m -s /bin/bash tester && \
    mkdir -p /home/tester/.npm-global/lib /home/tester/.npm-global/bin /home/tester/.local/bin && \
    chown -R tester:tester /home/tester/.npm-global /home/tester/.local
USER tester
ENV NPM_CONFIG_PREFIX=/home/tester/.npm-global
ENV PATH=/home/tester/.npm-global/bin:/home/tester/.local/bin:$PATH
WORKDIR /home/tester

# Install Codex CLI
RUN npm install -g @openai/codex@latest
