# syntax=docker/dockerfile:1
#
# builda-bar: the ByteHawks build container (Alpine, musl).
#
# It is the environment for the two ByteHawks tools and what they need:
#   Distillery  declarative builds, artifacts, signing, deb/rpm/apk packages, OCI images
#   Shaker      install / init / run / verify of what Distillery built (bash)
# Everything is in the image, so a job does not install a toolchain every time. Distillery and Shaker themselves are NOT baked in by
# default (a job checks the version it needs out); pass DISTILLERY_REF / SHAKER_REF to include a tag or branch under /opt/bytehawks/core.
#
#   docker build --build-arg ALPINE_VERSION=3.21.5 --build-arg VARIANT_NAME=stable -t builda-bar:local .
#   docker run --rm builda-bar:local builda-bar-selftest          # what is in the image, and does it work
#   docker run --rm -v "$PWD":/work -w /work builda-bar:local python /opt/bytehawks/core/distillery/scripts/autobuilder.py list
#
# The default user is `bh` (uid 1024) and /opt/bytehawks is its. Shaker `install` and the `unshare` sandbox need root: run with
# `--user root` (GitHub Actions: `container.options: --user root`) for those.
ARG ALPINE_VERSION=3.20
ARG VARIANT_NAME=stable

FROM alpine:${ALPINE_VERSION} AS base

ARG ALPINE_VERSION
ARG VARIANT_NAME
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG SOURCE_URL=https://github.com/bytehawks-org/bytehawks-buildabar
ARG TARGETARCH
# keep in step with the nfpm entry of Distillery's packages.yaml
ARG NFPM_VERSION=2.48.0
ARG NFPM_SHA256_AMD64=6d7f9a28b2f397934403950fcbba83f598b08d02edbe79a0815b3b4897341750
ARG NFPM_SHA256_ARM64=a9a75213763783b7669719e505474c748c5ad7dc66591a195619deb50f85c2f4
# optional: bake a Distillery / Shaker tag or branch into /opt/bytehawks/core (private repositories: --secret id=gh_token,src=FILE)
ARG DISTILLERY_REF=""
ARG SHAKER_REF=""

LABEL org.opencontainers.image.title="builda-bar"
LABEL org.opencontainers.image.description="ByteHawks build container for Distillery and Shaker - Alpine ${VARIANT_NAME} (${ALPINE_VERSION})"
LABEL org.opencontainers.image.url="${SOURCE_URL}"
LABEL org.opencontainers.image.source="${SOURCE_URL}"
LABEL org.opencontainers.image.documentation="${SOURCE_URL}#readme"
LABEL org.opencontainers.image.vendor="ByteHawks"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.authors="ByteHawks Contributors"
LABEL org.bytehawks.alpine.variant="${VARIANT_NAME}"
LABEL org.bytehawks.alpine.version="${ALPINE_VERSION}"

# --- core: must exist in every Alpine variant, the build fails otherwise -----------------------------------------------------
#   toolchain      build-base (gcc g++ make musl-dev binutils patch), linux-headers, cmake, perl, autoconf automake libtool m4,
#                  flex bison, pkgconf           what Distillery compiles openssl, nginx, valkey, mosquitto... with
#   python         python3, pip, virtualenv      Distillery (PyYAML, ruamel.yaml in /opt/venv) and Shaker's optional JSON/YAML parsing
#   sources        git, curl, wget, gnupg, tar, gzip, bzip2, xz, zstd, zip, unzip, file, openssh-client, ca-certificates
#   shell/system   bash, coreutils, findutils, grep, sed, diffutils, util-linux (unshare, setpriv), su-exec, tini, jq
#   isolation      bubblewrap                    Distillery --sandbox (bwrap backend)
#   inherited      ansible, git-perl             already part of the image
RUN apk add --no-cache \
      build-base linux-headers cmake perl autoconf automake libtool m4 flex bison pkgconf \
      python3 py3-pip py3-virtualenv \
      git git-perl curl wget gnupg tar gzip bzip2 xz zstd zip unzip file openssh-client ca-certificates \
      bash coreutils findutils grep sed diffutils util-linux su-exec tini jq \
      bubblewrap \
      ansible \
      gcc make musl-dev

# --- extras: best effort, an older Alpine may not have them (builda-bar-selftest lists what is missing) --------------------
#   util-linux-misc (setpriv on newer Alpine), skopeo (copy/push OCI archives), cosign (sign images), shellcheck (Shaker's lint),
#   yq (Shaker's YAML config), dpkg and rpm (inspect the packages Distillery writes), rsync, openssl, py3-yaml
RUN : > /etc/builda-bar-missing; \
    for pkg in util-linux-misc skopeo cosign shellcheck yq dpkg rpm rsync openssl py3-yaml; do \
      apk add --no-cache "$pkg" >/dev/null 2>&1 || { echo "$pkg" >> /etc/builda-bar-missing; echo "builda-bar: $pkg is not available in Alpine ${ALPINE_VERSION}"; }; \
    done

# --- Python environment for Distillery (the same names as its scripts/requirements.txt) ------------------------------------
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
 && /opt/venv/bin/pip install --no-cache-dir "PyYAML>=6.0" "ruamel.yaml>=0.18"

# --- nfpm: deb / rpm / apk packages, pinned and checksum-verified ------------------------------------------------------------
RUN set -eux; \
    case "${TARGETARCH:-$(apk --print-arch | sed 's/x86_64/amd64/; s/aarch64/arm64/')}" in \
      amd64) arch=x86_64; sha="${NFPM_SHA256_AMD64}" ;; \
      arm64) arch=arm64;  sha="${NFPM_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/nfpm.tar.gz "https://github.com/goreleaser/nfpm/releases/download/v${NFPM_VERSION}/nfpm_${NFPM_VERSION}_Linux_${arch}.tar.gz"; \
    echo "${sha}  /tmp/nfpm.tar.gz" | sha256sum -c -; \
    tar -C /usr/local/bin -xzf /tmp/nfpm.tar.gz nfpm; \
    rm /tmp/nfpm.tar.gz; \
    nfpm --version

# --- the ByteHawks user, the ByteHawks layout, optionally the tools themselves ----------------------------------------------
RUN addgroup -g 1024 bh && \
    adduser -D -u 1024 -G bh -h /home/bh -s /bin/bash bh && \
    mkdir -p /home/bh /work /opt/bytehawks/core /opt/bytehawks/deps /opt/bytehawks/var && \
    chown -R bh:bh /home/bh /work /opt/bytehawks && \
    chmod -R 755 /home/bh

RUN --mount=type=secret,id=gh_token,required=false \
    set -eu; \
    token="$(cat /run/secrets/gh_token 2>/dev/null || true)"; \
    for spec in "distillery:${DISTILLERY_REF}" "shaker:${SHAKER_REF}"; do \
      name="${spec%%:*}"; ref="${spec#*:}"; \
      [ -n "$ref" ] || continue; \
      git clone --depth 1 --branch "$ref" "https://${token:+x-access-token:${token}@}github.com/bytehawks-org/${name}" "/opt/bytehawks/core/${name}"; \
      git -C "/opt/bytehawks/core/${name}" remote set-url origin "https://github.com/bytehawks-org/${name}"; \
      chown -R bh:bh "/opt/bytehawks/core/${name}"; \
    done

COPY scripts/selftest.sh /usr/local/bin/builda-bar-selftest
COPY scripts/entrypoint.sh /usr/local/bin/builda-bar-entrypoint
RUN chmod 755 /usr/local/bin/builda-bar-selftest /usr/local/bin/builda-bar-entrypoint

USER bh
WORKDIR /home/bh

ENV PATH="/opt/venv/bin:/opt/bytehawks/core/shaker/bin:/usr/local/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV ALPINE_VERSION="${ALPINE_VERSION}"
ENV VARIANT_NAME="${VARIANT_NAME}"
ENV BUILD_CONTAINER="builda-bar"
# recorded by Distillery in the manifest of every unit built here (toolchain.builder_image)
ENV BH_BUILDER_IMAGE="builda-bar:${VARIANT_NAME}-alpine${ALPINE_VERSION}"

# bash as before (`docker run image`, `docker run image -c ...`), and a command can be given directly (`docker run image python script.py`)
ENTRYPOINT ["/usr/local/bin/builda-bar-entrypoint"]
