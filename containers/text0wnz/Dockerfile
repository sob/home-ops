# text0wnz with server-side file storage
# Custom server implementation with file management API

FROM node:22-alpine AS base

WORKDIR /app

# Install build dependencies (cached layer)
RUN apk add --no-cache git curl

# Clone repository (cached layer)
RUN git clone https://github.com/xero/text0wnz.git .

# Install dependencies early (cached layer - only rebuilds if package.json changes)
RUN npm install --legacy-peer-deps --prefer-offline --no-audit

# --- Customization layer ---
FROM base AS customized

# Copy custom files (invalidates cache when these change)
COPY file-api.js ./
COPY storage-adapter.js ./
COPY server.js ./

# Pre-create dist directory to prevent build errors
RUN mkdir -p ./dist && touch ./dist/robots.txt

# Force install rollup native binaries for target platform
RUN npm rebuild @rollup/rollup-linux-arm64-musl @rollup/rollup-linux-x64-musl || true

# Build with increased memory and better error handling
RUN NODE_OPTIONS="--max-old-space-size=4096" npm run bake || \
    (echo "Build failed, trying with clean install..." && \
     rm -rf node_modules package-lock.json && \
     npm install --legacy-peer-deps && \
     NODE_OPTIONS="--max-old-space-size=4096" npm run bake)

# Inject storage adapter into built HTML
RUN cp storage-adapter.js ./dist/ && \
    find ./dist -name "index.html" -type f -exec sed -i 's|</head>|<script src="/storage-adapter.js"></script></head>|' {} \;

# Production stage
FROM node:22-alpine

WORKDIR /app

# Install production dependencies
RUN apk add --no-cache tini

# Copy only what we need for production
COPY --from=customized /app/dist ./dist
COPY --from=customized /app/server.js ./
COPY --from=customized /app/file-api.js ./
COPY --from=customized /app/package.json ./
COPY --from=customized /app/node_modules ./node_modules

# Setup directories for node user (UID 1000)
RUN mkdir -p /art && \
    chown -R node:node /app /art

# Environment configuration (all can be overridden at runtime)
ENV NODE_ENV=production \
    TZ=UTC \
    PORT=3000 \
    FILES_DIR=/art \
    DEBUG=false

EXPOSE 3000

VOLUME ["/art"]

USER node

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]
