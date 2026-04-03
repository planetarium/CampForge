FROM node:20-bookworm

# System deps needed by install scripts and openclaw
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git python3 && \
    rm -rf /var/lib/apt/lists/*

# Install openclaw globally
RUN npm install -g openclaw

# Non-root user for realistic testing
RUN useradd -m -s /bin/bash tester

# Configure npm global prefix for non-root user so `npm install -g` works
RUN mkdir -p /home/tester/.npm-global/lib /home/tester/.npm-global/bin /home/tester/.local/bin && \
    chown -R tester:tester /home/tester/.npm-global /home/tester/.local
USER tester
ENV NPM_CONFIG_PREFIX=/home/tester/.npm-global
ENV PATH=/home/tester/.npm-global/bin:/home/tester/.local/bin:$PATH
WORKDIR /home/tester
