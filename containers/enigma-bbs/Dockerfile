# ENiGMA½ BBS Container - Multi-Arch Build
# Builds ENiGMA½ BBS from source using node:bookworm-slim for amd64 and arm64

ARG ENIGMA_VERSION="master"
ARG NODE_VERSION="22"

FROM node:${NODE_VERSION}-bookworm-slim AS builder

ARG ENIGMA_VERSION
ARG TARGETPLATFORM
ARG BUILDPLATFORM

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    python3 \
    libssl-dev \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install global npm tools (rarely changes - good cache layer)
RUN npm set progress=false && \
    npm config set depth 0 && \
    npm install -g npm@latest && \
    npm install -g pm2

# Clone ENiGMA½ BBS repository
RUN git clone --depth 1 --branch ${ENIGMA_VERSION} https://github.com/NuSkooler/enigma-bbs.git /build

# Install project dependencies (will be cached unless package.json changes)
# Skip prepare scripts (husky) but allow native module builds (sqlite3)
RUN npm install --production --ignore-scripts && \
    npm rebuild sqlite3

# Prepare entrypoint script
RUN dos2unix /build/docker/bin/docker-entrypoint.sh && \
    chmod +x /build/docker/bin/docker-entrypoint.sh

# Create pre-populated volume staging
RUN mkdir -p /enigma-bbs-pre/art /enigma-bbs-pre/mods /enigma-bbs-pre/config && \
    cp -rp art/* /enigma-bbs-pre/art/ && \
    cp -rp mods/* /enigma-bbs-pre/mods/

# Final stage
FROM node:${NODE_VERSION}-bookworm-slim

# Re-declare for labels
ARG ENIGMA_VERSION
ARG NODE_VERSION

# Metadata
LABEL org.opencontainers.image.title="ENiGMA½ BBS (Multi-Arch)"
LABEL org.opencontainers.image.description="ENiGMA½ BBS built from source for amd64 and arm64"
LABEL org.opencontainers.image.source="https://github.com/sob/home-ops"
LABEL org.opencontainers.image.url="https://github.com/sob/home-ops/tree/main/containers/enigma-bbs"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="sob"
LABEL org.opencontainers.image.authors="sob"
LABEL org.opencontainers.image.version="${ENIGMA_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    lrzsz \
    arj \
    lhasa \
    unrar-free \
    p7zip-full \
    dos2unix \
    && npm install -g pm2 \
    && rm -rf /var/lib/apt/lists/*

# Copy ENiGMA½ from builder
COPY --from=builder --chown=1000:1000 /build /enigma-bbs
COPY --from=builder --chown=1000:1000 /enigma-bbs-pre /enigma-bbs-pre

# Copy sexyz binary to system path
RUN cp -f /enigma-bbs/docker/bin/sexyz /usr/local/bin/ && \
    chmod +x /usr/local/bin/sexyz

# Set working directory
WORKDIR /enigma-bbs

# Create volume directories with correct ownership
RUN mkdir -p /enigma-bbs/art \
             /enigma-bbs/mods \
             /enigma-bbs/config \
             /enigma-bbs/db \
             /enigma-bbs/filebase \
             /enigma-bbs/logs \
             /enigma-bbs/mail && \
    chown -R 1000:1000 /enigma-bbs

# Define volumes
VOLUME ["/enigma-bbs/art", "/enigma-bbs/config", "/enigma-bbs/db", "/enigma-bbs/filebase", "/enigma-bbs/logs", "/enigma-bbs/mods", "/enigma-bbs/mail"]

# Expose default port
EXPOSE 8888

# Switch to non-root user
USER 1000:1000

# Set entrypoint
ENTRYPOINT ["/enigma-bbs/docker/bin/docker-entrypoint.sh"]
