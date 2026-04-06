FROM ghcr.io/openclaw/openclaw:latest@sha256:0b2170d5ec3a487a6313ed0556d377c5c5c80a0f806043daa2e685a4bedd45e3

# Configure npm global prefix for non-root user so `npm install -g` works
# (install_gws, install_gws_auth use npm install -g)
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 curl && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /home/node/.npm-global/lib /home/node/.npm-global/bin /home/node/.local/bin && \
    chown -R node:node /home/node/.npm-global /home/node/.local
USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=/home/node/.npm-global/bin:/home/node/.local/bin:$PATH
WORKDIR /home/node
