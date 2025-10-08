# Version definitions
ARG ALPINE_VERSION="3.20@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5"
ARG UNRAR_VERSION="7.1.10"
ARG CRYPTLIB_VERSION="345" 
ARG CRYPTLIB_SO_VERSION="3.4.5"
ARG MYSTIC_VERSION="112a48"

# Build stage for cryptlib compilation
FROM alpine:${ALPINE_VERSION} AS builder

# Re-declare ARGs for builder stage (inherit from global)
ARG UNRAR_VERSION
ARG CRYPTLIB_VERSION
ARG CRYPTLIB_SO_VERSION
ARG MYSTIC_VERSION

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
    python3-dev \
    linux-headers

# Build unrar from source (only needed for x86_64)
WORKDIR /tmp  
RUN if [ "$(uname -m)" = "x86_64" ]; then \
        echo "Building unrar for x86_64..." && \
        echo "Attempting to download unrarsrc-${UNRAR_VERSION}.tar.gz" && \
        if wget --timeout=30 -v https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz; then \
            echo "Download successful, file info:" && \
            ls -la unrarsrc-${UNRAR_VERSION}.tar.gz && \
            echo "Extracting..." && \
            tar -xzf unrarsrc-${UNRAR_VERSION}.tar.gz && \
            cd unrar && \
            echo "Directory contents:" && \
            ls -la && \
            echo "Checking makefile..." && \
            head -20 makefile && \
            echo "Starting compilation..." && \
            make lib && \
            make unrar && \
            mkdir -p /build/bin && \
            cp unrar /build/bin/ && \
            echo "Unrar build successful"; \
        else \
            echo "Download failed, trying alternative source..." && \
            apk add --no-cache curl && \
            curl -L -o unrarsrc.tar.gz https://github.com/pmachapman/unrar/archive/refs/tags/v${UNRAR_VERSION}.tar.gz && \
            tar -xzf unrarsrc.tar.gz && \
            cd unrar-${UNRAR_VERSION} && \
            make lib && \
            make unrar && \
            mkdir -p /build/bin && \
            cp unrar /build/bin/; \
        fi && \
        cd / && \
        rm -rf /tmp/unrar*; \
    else \
        echo "Skipping unrar build for non-x86_64 architecture" && \
        mkdir -p /build/bin; \
    fi

# Build cryptlib for Mystic BBS SSH support
WORKDIR /tmp
RUN wget -q http://www.mysticbbs.com/downloads/cl${CRYPTLIB_VERSION}.zip \
    && mkdir cryptlib \
    && cd cryptlib \
    && unzip -a ../cl${CRYPTLIB_VERSION}.zip \
    && sed -i 's/-mcpu=pentium/-march=x86-64/g' tools/ccopts.sh \
    && sed -i 's/mcpu=pentium/march=x86-64/g' tools/ccopts.sh \
    && CC=gcc-9 CXX=g++-9 make shared \
    && mkdir -p /build \
    && cp libcl.so.${CRYPTLIB_SO_VERSION} /build/ \
    && echo ${CRYPTLIB_SO_VERSION} > /build/cryptlib_version \
    && cd / \
    && rm -rf /tmp/cryptlib /tmp/cl${CRYPTLIB_VERSION}.zip

# Download and install Mystic BBS (architecture-specific)
WORKDIR /tmp
RUN ARCH=$(uname -m) && \
    echo "Detected architecture: $ARCH" && \
    if [ "$ARCH" = "x86_64" ]; then \
        MYSTIC_URL="https://www.mysticbbs.com/downloads/mys${MYSTIC_VERSION}_l64.rar"; \
        MYSTIC_FILE="mys${MYSTIC_VERSION}_l64.rar"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        MYSTIC_URL="https://www.mysticbbs.com/downloads/mys${MYSTIC_VERSION}_p64.zip"; \
        MYSTIC_FILE="mys${MYSTIC_VERSION}_p64.zip"; \
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then \
        MYSTIC_URL="https://www.mysticbbs.com/downloads/mys${MYSTIC_VERSION}_p32.zip"; \
        MYSTIC_FILE="mys${MYSTIC_VERSION}_p32.zip"; \
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
FROM alpine:${ALPINE_VERSION}

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
COPY --from=builder /build/libcl.so.* /usr/lib/
COPY --from=builder /build/cryptlib_version /tmp/cryptlib_version
RUN CRYPTLIB_VERSION=$(cat /tmp/cryptlib_version) && \
    ln -s /usr/lib/libcl.so.${CRYPTLIB_VERSION} /usr/lib/libcl.so && \
    rm /tmp/cryptlib_version && \
    ldconfig

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