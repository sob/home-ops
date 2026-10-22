# SenseLink on a current Python, with its dependencies pinned.

# Set from VERSION in docker-bake.hcl (the single, Renovate-tracked source).
ARG SENSELINK_VERSION

FROM python:3.15-slim AS builder

ARG SENSELINK_VERSION

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN python -m venv /opt/senselink

# Upstream's own ranges, pinned: aiomqtt 1.2 needs paho-mqtt 1.x, and dpath 2.x
# still has the dpath.util module SenseLink imports. websockets is only used
# by the Home Assistant source, but senselink imports it unconditionally.
RUN /opt/senselink/bin/pip install \
      aiomqtt==1.2.1 \
      dpath==2.2.0 \
      paho-mqtt==1.6.1 \
      PyYAML==6.0.3 \
      websockets==17.3 \
 && /opt/senselink/bin/pip install --no-deps \
      "https://github.com/cbpowell/SenseLink/archive/refs/tags/${SENSELINK_VERSION}.tar.gz"

# Fail the build if this Python breaks the MQTT JSON path or the UDP replies.
COPY selftest.py /tmp/selftest.py
RUN /opt/senselink/bin/python -I /tmp/selftest.py

FROM python:3.15-slim

COPY --from=builder /opt/senselink /opt/senselink

ENV PATH=/opt/senselink/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LOGLEVEL=INFO

USER 568:568

# Sense queries plugs with UDP broadcasts to 9999.
EXPOSE 9999/udp

# Reads /etc/senselink/config.yml (or CONFIG_LOCATION).
ENTRYPOINT ["python", "-m", "senselink"]
