FROM ghcr.io/openclaw/openclaw:latest

# Configure npm global prefix for non-root user so `npm install -g` works
# (install_gws, install_gws_auth use npm install -g)
USER root
RUN mkdir -p /home/node/.npm-global/lib /home/node/.npm-global/bin /home/node/.local/bin && \
    chown -R node:node /home/node/.npm-global /home/node/.local
USER node
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=/home/node/.npm-global/bin:/home/node/.local/bin:$PATH
WORKDIR /home/node
