# Mystic BBS Container
# See README.md for complete documentation on:
# - Hook system for lifecycle automation
# - Install/upgrade process and detection
# - Filesystem layout following FHS
# - Environment variables and configuration

# Version definitions
ARG UBUNTU_VERSION="24.04"
ARG UNRAR_VERSION="7.1.10"
ARG CRYPTLIB_VERSION="345"
ARG CRYPTLIB_SO_VERSION="3.4.5"
ARG MYSTIC_VERSION="112a48"

# Build stage for cryptlib compilation
FROM ubuntu:${UBUNTU_VERSION} AS builder

# Re-declare ARGs for builder stage (inherit from global)
ARG UNRAR_VERSION
ARG CRYPTLIB_VERSION
ARG CRYPTLIB_SO_VERSION
ARG MYSTIC_VERSION

# Install build dependencies for Ubuntu
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-9 \
    g++-9 \
    make \
    unzip \
    unrar \
    wget \
    zlib1g-dev \
    python3 \
    python3-dev \
    linux-libc-dev \
    && rm -rf /var/lib/apt/lists/*


# Build cryptlib for Mystic BBS SSH support (architecture-specific)
WORKDIR /tmp
RUN ARCH=$(uname -m) && \
    echo "Building cryptlib for architecture: $ARCH" && \
    wget -q http://www.mysticbbs.com/downloads/cl${CRYPTLIB_VERSION}.zip \
    && mkdir cryptlib \
    && cd cryptlib \
    && unzip -a ../cl${CRYPTLIB_VERSION}.zip \
    && echo "Patching cryptlib for compatibility..." \
    && find . -name "*.h" -exec sed -i 's/static_assert(/assert(/g' {} \; 2>/dev/null || true \
    && if [ "$ARCH" = "x86_64" ]; then \
        sed -i 's/-mcpu=pentium/-march=x86-64/g' tools/ccopts.sh && \
        sed -i 's/mcpu=pentium/march=x86-64/g' tools/ccopts.sh; \
    elif [ "$ARCH" = "aarch64" ]; then \
        sed -i 's/-mcpu=pentium/-march=armv8-a/g' tools/ccopts.sh && \
        sed -i 's/mcpu=pentium/march=armv8-a/g' tools/ccopts.sh && \
        sed -i 's/-O3/-O1/g' tools/ccopts.sh && \
        find . -name "*.sh" -exec sed -i 's/-O3/-O1/g' {} \; && \
        find . -name "makefile*" -exec sed -i 's/-O3/-O1/g' {} \; && \
        find . -name "Makefile*" -exec sed -i 's/-O3/-O1/g' {} \;; \
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "arm" ]; then \
        sed -i 's/-mcpu=pentium/-march=armv7-a/g' tools/ccopts.sh && \
        sed -i 's/mcpu=pentium/march=armv7-a/g' tools/ccopts.sh && \
        sed -i 's/-O3/-O1/g' tools/ccopts.sh && \
        find . -name "*.sh" -exec sed -i 's/-O3/-O1/g' {} \; && \
        find . -name "makefile*" -exec sed -i 's/-O3/-O1/g' {} \; && \
        find . -name "Makefile*" -exec sed -i 's/-O3/-O1/g' {} \;; \
    else \
        echo "Unsupported architecture for cryptlib: $ARCH"; \
        exit 1; \
    fi \
    && CC=gcc-9 CXX=g++-9 make shared \
    && mkdir -p /build \
    && cp libcl.so.${CRYPTLIB_SO_VERSION} /build/ \
    && cd / \
    && rm -rf /tmp/cryptlib /tmp/cl${CRYPTLIB_VERSION}.zip

# Download Mystic BBS installer (architecture-specific)
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
        unrar x "$MYSTIC_FILE"; \
    else \
        unzip -q "$MYSTIC_FILE"; \
    fi && \
    chmod +x install && \
    chmod +x upgrade 2>/dev/null || true && \
    mkdir -p /build && \
    cp install /build/ && \
    cp install_data.mys /build/ 2>/dev/null || true && \
    cp upgrade /build/ 2>/dev/null || true && \
    cp whatsnew.txt /build/ 2>/dev/null || true && \
    cp upgrade.txt /build/ 2>/dev/null || true && \
    rm -rf /tmp/"$MYSTIC_FILE"

# Runtime stage
FROM ubuntu:${UBUNTU_VERSION}

# Re-declare ARG for runtime stage
ARG UBUNTU_VERSION
ARG CRYPTLIB_SO_VERSION
ARG MYSTIC_VERSION

# Metadata
LABEL org.opencontainers.image.title="Mystic BBS"
LABEL org.opencontainers.image.description="Mystic BBS running in a container with SSH access and FidoNet BinkP support"
LABEL org.opencontainers.image.source="https://github.com/sob/home-ops"
LABEL org.opencontainers.image.url="https://github.com/sob/home-ops/tree/main/containers/mysticbbs"
LABEL org.opencontainers.image.documentation="https://github.com/sob/home-ops/blob/main/containers/mysticbbs/README.md"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="sob"
LABEL org.opencontainers.image.authors="sob"
LABEL org.opencontainers.image.version="${MYSTIC_VERSION}"

# Set environment variables
ENV TZ=America/Chicago

# Install runtime dependencies for Ubuntu
RUN apt-get update && apt-get install -y \
    cron \
    expect \
    logrotate \
    python3 \
    zip \
    bash \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# Copy cryptlib from builder and rename to generic name (per Mystic BBS docs)
COPY --from=builder /build/libcl.so.${CRYPTLIB_SO_VERSION} /usr/lib/libcl.so


# Configure dynamic linker (required for Mystic BBS SSH support)
RUN echo "Verifying cryptlib installation:" && \
    ls -la /usr/lib/libcl.so && \
    echo "Testing library load:" && \
    ldd /usr/lib/libcl.so && \
    echo "Running ldconfig:" && \
    ldconfig

# Copy Mystic BBS installer and upgrade utility from builder
# Keep all mystic installer files together in /usr/local/share/mystic
RUN mkdir -p /usr/local/share/mystic
COPY --from=builder /build/install /usr/local/share/mystic/install
COPY --from=builder /build/install_data.mys /usr/local/share/mystic/install_data.mys
COPY --from=builder /build/upgrade /usr/local/share/mystic/upgrade
COPY --from=builder /build/whatsnew.txt /usr/local/share/mystic/whatsnew.txt
COPY --from=builder /build/upgrade.txt /usr/local/share/mystic/upgrade.txt
RUN chmod +x /usr/local/share/mystic/install && \
    chmod +x /usr/local/share/mystic/upgrade 2>/dev/null || true && \
    chmod 644 /usr/local/share/mystic/install_data.mys && \
    chmod 644 /usr/local/share/mystic/whatsnew.txt && \
    chmod 644 /usr/local/share/mystic/upgrade.txt && \
    chown -R 65534:65534 /usr/local/share/mystic && \
    ln -s /usr/local/share/mystic/install /usr/local/bin/mystic-install && \
    ln -s /usr/local/share/mystic/upgrade /usr/local/bin/mystic-upgrade

# Setup logrotate
COPY logrotate.conf /etc/logrotate.d/mystic

# Create mystic user with standard UID/GID following home-operations conventions
RUN echo "Checking existing user/group 65534:" && \
    getent passwd 65534 && getent group 65534 && \
    echo "Using existing nobody user (65534:65534) for mystic" && \
    mkdir -p /config /tmp/mystic && \
    chown -R 65534:65534 /config /tmp/mystic

# Copy startup scripts
COPY entrypoint.sh /usr/local/bin/
COPY tailit.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/tailit.sh

# Expose ports (telnet, SSH, BinkP for FidoNet)
EXPOSE 23/tcp 22/tcp 24554/tcp

WORKDIR /config
USER 65534:65534

CMD ["/usr/local/bin/entrypoint.sh"]