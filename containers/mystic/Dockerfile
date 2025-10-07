# Build stage for cryptlib compilation
FROM alpine:3.20@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5 AS builder

# Install build dependencies for Alpine
RUN apk add --no-cache \
    build-base \
    gcc \
    g++ \
    make \
    unzip \
    wget \
    zlib-dev \
    python3 \
    python3-dev

# Build unrar from source
WORKDIR /tmp
RUN wget -q https://www.rarlab.com/rar/unrarsrc-7.1.10.tar.gz \
    && tar -xzf unrarsrc-7.1.10.tar.gz \
    && cd unrar \
    && make \
    && mkdir -p /build/bin \
    && cp unrar /build/bin/ \
    && cd / \
    && rm -rf /tmp/unrar*

# Build cryptlib for Mystic BBS SSH support
WORKDIR /tmp
RUN wget -q http://www.mysticbbs.com/downloads/cl345.zip \
    && mkdir cryptlib \
    && cd cryptlib \
    && unzip -a ../cl345.zip \
    && sed -i 's/-mcpu=pentium/-march=x86-64/g' tools/ccopts.sh \
    && sed -i 's/mcpu=pentium/march=x86-64/g' tools/ccopts.sh \
    && CC=gcc-9 CXX=g++-9 make shared \
    && mkdir -p /build \
    && cp libcl.so.3.4.5 /build/ \
    && cd / \
    && rm -rf /tmp/cryptlib /tmp/cl345.zip

# Download and install Mystic BBS (architecture-specific)
WORKDIR /tmp
RUN ARCH=$(uname -m) && \
    echo "Detected architecture: $ARCH" && \
    if [ "$ARCH" = "x86_64" ]; then \
        MYSTIC_URL="https://www.mysticbbs.com/downloads/mys112a48_l64.rar"; \
        MYSTIC_FILE="mys112a48_l64.rar"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        MYSTIC_URL="https://www.mysticbbs.com/downloads/mys112a48_p64.zip"; \
        MYSTIC_FILE="mys112a48_p64.zip"; \
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then \
        MYSTIC_URL="https://www.mysticbbs.com/downloads/mys112a48_p32.zip"; \
        MYSTIC_FILE="mys112a48_p32.zip"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi && \
    echo "Downloading Mystic BBS for $ARCH from $MYSTIC_URL" && \
    wget -q "$MYSTIC_URL" -O "$MYSTIC_FILE" && \
    if [ "${MYSTIC_FILE##*.}" = "rar" ]; then \
        /build/bin/unrar x "$MYSTIC_FILE"; \
    else \
        unzip -q "$MYSTIC_FILE"; \
    fi && \
    chmod +x install && \
    ./install auto /build/mystic && \
    chmod +x /build/mystic/mis && \
    chmod +x /build/mystic/*.sh 2>/dev/null || true && \
    rm -rf /tmp/"$MYSTIC_FILE" /tmp/install*

# Runtime stage
FROM alpine:3.20@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5

# Metadata
LABEL org.opencontainers.image.title="Mystic BBS"
LABEL org.opencontainers.image.description="Mystic BBS running in a container with SSH access and FidoNet BinkP support"
LABEL org.opencontainers.image.source="https://github.com/seobrien/home-ops"
LABEL org.opencontainers.image.licenses="MIT"

# Set environment variables
ENV TZ=America/Chicago

# Install runtime dependencies for Alpine
RUN apk add --no-cache \
    dcron \
    expect \
    logrotate \
    python3 \
    zip \
    bash

# Copy unrar and cryptlib from builder
COPY --from=builder /build/bin/unrar /usr/local/bin/unrar
COPY --from=builder /build/libcl.so.3.4.5 /usr/lib/libcl.so
RUN ldconfig

# Copy Mystic BBS from builder
COPY --from=builder /build/mystic /opt/mystic

# Setup logrotate
COPY logrotate.conf /etc/logrotate.d/mystic

# Create mystic user with standard UID/GID following home-operations conventions
RUN addgroup -g 65534 mystic \
    && adduser -u 65534 -G mystic -h /config -s /bin/bash -D mystic \
    && mkdir -p /config /tmp/mystic \
    && chown -R mystic:mystic /config /tmp/mystic

# Copy startup scripts
COPY entrypoint.sh /usr/local/bin/
COPY tailit.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/tailit.sh

# Expose ports (telnet, SSH, BinkP for FidoNet)
EXPOSE 23/tcp 22/tcp 24554/tcp

WORKDIR /config
USER 65534:65534

CMD ["/usr/local/bin/entrypoint.sh"]