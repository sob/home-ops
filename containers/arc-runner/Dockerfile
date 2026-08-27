# Custom ARC runner with Android SDK and the GitHub CLI
# Based on the official GitHub Actions runner image

# renovate: datasource=docker depName=ghcr.io/actions/actions-runner
ARG RUNNER_VERSION="2.337.0"

FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

ARG ANDROID_CMDLINE_TOOLS_VERSION="11076708"
ARG ANDROID_BUILD_TOOLS_VERSION="37.0.0"
# 36, not 37: Google publishes build-tools;37.0.0 but the highest platform in
# the SDK repository is platforms;android-36. 631bdcad bumped both, so every
# image build since 2026-07-17 has died here with
#   Warning: Failed to find package 'platforms;android-37'
# before reaching any later layer. Raise this to 37 once Google ships it.
ARG ANDROID_PLATFORM_VERSION="36"

USER root

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# bc and python3 are here for the same reason gh is installed below: every
# GitHub-hosted ubuntu-* image ships them, the actions-runner base image does
# not, and jobs that moved onto this pool assume them. Each absence shows up as
# a bare exit 127 in an unrelated-looking step:
#   bc      doorgames-io/blockhead's nightly "Update Coverage Badges"
#   python3 the same repo pins actions/setup-python in five workflows to
#           work around it; with python3 here those pins become optional
# Ubuntu noble's python3 is 3.12, which is what those pins ask for.
#
# The base already provides curl, jq, git, sed, awk, timeout and (via
# build-essential -> dpkg-dev -> perl) shasum, so this list is the whole gap
# for the commands blockhead's arc-linux jobs actually invoke.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    build-essential \
    openjdk-17-jdk-headless \
    python3 \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && bc --version | head -1 \
    && python3 --version

ARG TARGETARCH
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-${TARGETARCH}

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools && \
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null 2>&1 && \
    sdkmanager \
      "platform-tools" \
      "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
      "build-tools;35.0.0" \
      "platforms;android-${ANDROID_PLATFORM_VERSION}" \
      "platforms;android-35"

RUN chown -R runner:runner ${ANDROID_HOME}

# GitHub CLI. The official actions-runner base image does not ship `gh`, but
# every GitHub-hosted ubuntu-* image does — so workflows moved onto this pool
# from `ubuntu-latest` bring `gh` calls with them and fail at job time with
# `gh: command not found` (exit 127). Worse where the call is wrapped in
# `2>/dev/null || true`: those degrade silently rather than going red.
# (doorgames-io/blockhead lost 8 jobs to this, including its Sentry
# crash-alert pipeline, which dropped alerts unnoticed for three days.)
#
# Installed from the release tarball rather than the cli.github.com apt repo:
# the version stays pinned and renovate-visible, no extra keyring/source to
# maintain, and one expression covers both build platforms via TARGETARCH.
# Placed after the Android SDK layers so a gh bump doesn't invalidate them.
#
# The trailing `gh --version` fails the build here rather than at job time on a
# runner — the check that would have caught this gap when the pool was created.
#
# renovate: datasource=github-releases depName=cli/cli
ARG GH_CLI_VERSION="2.96.0"
RUN gh_dir="/tmp/gh_${GH_CLI_VERSION}_linux_${TARGETARCH}" && \
    wget -qO- "https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_${TARGETARCH}.tar.gz" \
      | tar -xz -C /tmp && \
    install -m 0755 "${gh_dir}/bin/gh" /usr/local/bin/gh && \
    rm -rf "${gh_dir}" && \
    gh --version

USER runner
