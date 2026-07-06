# Custom ARC runner with Android SDK
# Based on the official GitHub Actions runner image

# renovate: datasource=docker depName=ghcr.io/actions/actions-runner
ARG RUNNER_VERSION="2.325.0"

FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

ARG ANDROID_CMDLINE_TOOLS_VERSION="11076708"
ARG ANDROID_BUILD_TOOLS_VERSION="35.0.0"
ARG ANDROID_PLATFORM_VERSION="35"

USER root

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null 2>&1 && \
    sdkmanager \
      "platform-tools" \
      "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
      "platforms;android-${ANDROID_PLATFORM_VERSION}"

RUN chown -R runner:runner ${ANDROID_HOME}

USER runner
