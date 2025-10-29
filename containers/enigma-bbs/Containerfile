# ENiGMA½ BBS Container - Non-Root
# Extends official enigmabbs/enigma-bbs image to run as non-root user 1000:1000

ARG ENIGMA_VERSION="latest"

FROM docker.io/enigmabbs/enigma-bbs:${ENIGMA_VERSION}

# Re-declare for labels
ARG ENIGMA_VERSION

# Metadata
LABEL org.opencontainers.image.title="ENiGMA½ BBS (Non-Root)"
LABEL org.opencontainers.image.description="ENiGMA½ BBS running as non-root user 1000:1000"
LABEL org.opencontainers.image.source="https://github.com/sob/home-ops"
LABEL org.opencontainers.image.url="https://github.com/sob/home-ops/tree/main/containers/enigma-bbs"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="sob"
LABEL org.opencontainers.image.authors="sob"
LABEL org.opencontainers.image.version="${ENIGMA_VERSION}"

# Fix ownership for non-root execution
# The 'node' user (1000:1000) already exists in the base image
USER root
RUN chown -R 1000:1000 /enigma-bbs && \
    chmod -R u+w /enigma-bbs

# Switch to non-root user
USER 1000:1000

# Use the same entrypoint and command as the base image
