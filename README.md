# builda-bar

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Build Multi-Arch "builda-bar" Container Images (x86_64 + arm64)](https://github.com/bytehawks-org/builda-bar/actions/workflows/docker-build-image.yml/badge.svg)](https://github.com/bytehawks-org/builda-bar/actions/workflows/docker-build-image.yml)


Alpine-based build container for ByteHawks – enabling transparent, auditable software supply chains for European digital sovereignty (x86_64/Arm64).

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Image Variants](#image-variants)
- [Pulling Images](#pulling-images)
- [Security Features](#security-features)
- [Verification & Signing](#verification--signing)
- [Using builda-bar with Distillery and Shaker](#using-builda-bar-with-distillery-and-shaker)
- [Contents & Tools](#contents--tools)
- [Build Information](#build-information)
- [Contributing](#contributing)

## Overview

**builda-bar** is a minimal Alpine Linux-based container designed for ByteHawks build orchestration and NIS2-compliant software supply chain management. It is the environment for [**Distillery**](https://github.com/bytehawks-org/distillery) (declarative builds, artifacts, signing, packages, images) and [**Shaker**](https://github.com/bytehawks-org/shaker) (install, init, run and verify): every tool they need is in the image, so a job starts working instead of installing a toolchain. It provides a transparent, auditable foundation for building statically compiled software with integrated security scanning and Software Bill of Materials (SBOM) generation.

### Key Characteristics

- **Minimal Attack Surface**: Based on Alpine Linux, reducing dependencies and vulnerabilities
- **Multi-Variant Support**: Available in `old-legacy`, `legacy`, `stable`, and `stream` Alpine versions
- **Security-First**: Automated vulnerability scanning with Trivy and Grype
- **Supply Chain Transparency**: CycloneDX SBOM generation for every build
- **Cryptographically Signed**: Cosign signatures for image verification and authenticity
- **Multi-Platform Ready**: x86_64 support with Arm64 coming soon
- **European Digital Sovereignty**: Aligned with NIS2 compliance requirements

## Quick Start

### Pull the Latest Stable Image

From GitHub Container Registry (GHCR):
```bash
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64
```

From ByteHawks Harbor Registry:
```bash
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:stable-x86_64
```

### Run the Container

```bash
docker run --rm -it ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64
```

Or with mounted volumes for builds:
```bash
docker run --rm -v $(pwd)/src:/build/src:ro -v $(pwd)/dist:/build/dist ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64
```

## Image Variants

### Alpine Versions

builda-bar is built across multiple Alpine Linux versions to support diverse use cases and stability requirements:

| Variant | Alpine Version | Min. Kernel Version | Use Case | Status |
|---------|----------------|---------------------|----------|--------|
| `old-legacy` | 3.15.11 | 3.15 | Long-term stability, legacy systems | Supported |
| `legacy` | 3.20.8 | 6.6 | Extended LTS, conservative deployments | Supported |
| `stable` | 3.21.5 | 6.12 | Recommended default, balanced approach | **Recommended** |
| `stream` | 3.22.2 | 6.12 | Cutting-edge features, latest packages | Latest |

### Platform Support

| Platform | Status | Tag Suffix |
|----------|--------|-----------|
| x86_64 | ✅ Supported | `-x86_64` |
| Arm64 | ✅ Supported  | `-arm64` |

## Pulling Images

### From GitHub Container Registry (GHCR)

GHCR is the primary public registry for builda-bar images.

#### Latest Stable (Recommended)
```bash
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64
```

#### By Alpine Variant
```bash
# Legacy LTS
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:legacy-x86_64

# Old Legacy (long-term support)
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:old-legacy-x86_64

# Stream (latest features)
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:stream-x86_64
```

#### By Full Version and Alpine Release
```bash
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:alpine-3.21.5-stable-x86_64
```

#### By Release Version
```bash
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:v1.0.0-20250101-alpine-stable-x86_64
```

#### By Digest (Immutable Reference)
```bash
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar@sha256:abc123def456...
```

### From ByteHawks Harbor Registry

Harbor registry provides additional isolation and enterprise-grade features for European deployments.

#### Latest Stable
```bash
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:stable-x86_64
```

#### By Alpine Variant
```bash
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:legacy-x86_64
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:old-legacy-x86_64
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:stream-x86_64
```

#### By Full Version
```bash
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:alpine-3.21.5-stable-x86_64
docker pull registry.bytehawks.org/bytehawks-org/builda-bar:v1.0.0-20250101-alpine-stable-x86_64
```

#### By Digest (Immutable Reference)
```bash
docker pull registry.bytehawks.org/bytehawks-org/builda-bar@sha256:abc123def456...
```

### Authentication

#### GHCR (GitHub Container Registry)
```bash
# Public access (no authentication required)
docker pull ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64

# With authentication (optional, for higher rate limits)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

#### Harbor Registry
```bash
docker login registry.bytehawks.org
# Provide your Harbor credentials when prompted
```

## Security Features

### Automated Vulnerability Scanning

Every build is scanned with industry-leading security tools:

#### Trivy Scanning
[Trivy](https://github.com/aquasecurity/trivy) performs comprehensive vulnerability assessment scanning for known CVEs across all packages in the container image. Results are uploaded to GitHub Security tab as SARIF reports.

**What Trivy checks:**
- OS package vulnerabilities
- Application dependencies
- Configuration issues
- Known malware signatures

#### Grype Scanning
[Grype](https://github.com/anchore/grype) provides dependency vulnerability detection with support for multiple package ecosystems.

**What Grype checks:**
- Application-level dependencies
- Cross-package vulnerability correlations
- Provides alternative CVE database sources

### SBOM (Software Bill of Materials)

A CycloneDX-formatted SBOM is generated for every build, providing complete transparency of container contents:

```
sbom-stable-x86_64.json
sbom-legacy-x86_64.json
sbom-old-legacy-x86_64.json
sbom-stream-x86_64.json
```

SBOMs are available as build artifacts and include:
- All Alpine packages and versions
- Package checksums and origins
- Dependency relationships
- License information

### Scan Result Retrieval

#### From GitHub Actions

1. Navigate to the [ByteHawks repository Actions tab](https://github.com/bytehawks/bytehawks/actions)
2. Select the latest "Build builda-bar Container Images" workflow run
3. Scroll to "Artifacts" section
4. Download desired SBOM or scan reports:
   - `sbom-{variant}-{arch}.json` – CycloneDX Software Bill of Materials
   - `scan-{variant}-{arch}` – Trivy vulnerability reports

#### Accessing Security Findings

1. Go to repository **Security** tab → **Code scanning alerts**
2. Results are organized by:
   - Tool (Trivy or Grype)
   - Variant and architecture
   - Severity (CRITICAL, HIGH)

#### Local SBOM Inspection

```bash
# Extract SBOM from workflow artifacts
unzip sbom-stable-x86_64.json

# View with a standard JSON tool
cat sbom-stable-x86_64.json | jq .

# Parse for specific packages
cat sbom-stable-x86_64.json | jq '.components[] | select(.name | contains("openssl"))'
```

## Verification & Signing

### Cosign Image Signing

All released images are signed with Cosign using ByteHawks project keys, ensuring:
- **Image Authenticity**: Verify images haven't been tampered with
- **Provenance Tracking**: Confirm images originate from official builds
- **Supply Chain Security**: Enforce signed images in Kubernetes policies

### Verifying Image Signatures

#### Prerequisites

Install Cosign:
```bash
# macOS
brew install cosign

# Linux
wget https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Docker
docker run ghcr.io/sigstore/cosign:latest version
```

#### Verify GHCR Image

```bash
# Verify signature
cosign verify --certificate-identity-regexp="https://github.com/bytehawks/bytehawks" \
  ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64

# Verify and inspect attestation
cosign verify-attestation ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64
```

#### Verify Harbor Image

```bash
cosign verify --certificate-identity-regexp="https://github.com/bytehawks/bytehawks" \
  registry.bytehawks.org/bytehawks-org/builda-bar:stable-x86_64
```

#### Verify by Digest

```bash
cosign verify --certificate-identity-regexp="https://github.com/bytehawks/bytehawks" \
  ghcr.io/bytehawks-org/builda-bar/builda-bar@sha256:bbdc920d45050a03710b3e4e814010602abc2ede0f111ce282481148a27de615
```

### Kubernetes Admission Control

Enforce signature verification in Kubernetes using Kyverno or OPA:

#### Kyverno Policy Example
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-bytehawks-images
spec:
  validationFailureAction: enforce
  rules:
  - name: verify-cosign-signature
    match:
      resources:
        kinds:
        - Pod
    verifyImages:
    - imageReferences:
      - "ghcr.io/bytehawks/bytehawks/*"
      - "registry.bytehawks.org/cicd-images/*"
      attestors:
      - count: 1
        entries:
        - keys:
            signatureAlgorithm: sha256
            publicKeys: |
              -----BEGIN PUBLIC KEY-----
              [ByteHawks public key here]
              -----END PUBLIC KEY-----
            signatureFormat: cosign
```

## Using builda-bar with Distillery and Shaker

```bash
# is everything there, and does it work? (exit 1 if something indispensable is missing)
docker run --rm ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64 builda-bar-selftest

# build with Distillery: the repository is mounted, the toolchain is in the image
docker run --rm -v "$PWD":/work -w /work ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64 \
  python /work/distillery/scripts/autobuilder.py build --package zlib --root /work/stage --artifacts-dir /work/dist

# musl and static builds are what this image is for: Alpine is musl, `gcc -static` works
#   autobuilder.py build --package nginx --with-deps --linkage static

# Shaker's tests / non-root use
docker run --rm -v "$PWD":/work -w /work/shaker -e BH_SHAKER_ALLOW_NONROOT=true <image> ./tests/run.sh
```

| You want | Run with |
|---|---|
| Distillery builds, `repro`, `package`, `scaffold`, `chain` | the default user `bh` (uid 1024); `/opt/bytehawks` and `/work` are writable |
| Shaker `install` (users, ownership), the `unshare` sandbox | `--user root` (GitHub Actions: `container.options: --user root`) |
| the `bwrap` / `unshare` sandboxes | a host that allows user namespaces: `--privileged` or `--security-opt seccomp=unconfined` |
| Distillery and Shaker inside the image | `--build-arg DISTILLERY_REF=<tag-or-branch> --build-arg SHAKER_REF=<tag-or-branch>`; they land in `/opt/bytehawks/core/`, Shaker's `bin` is on `PATH`. Private repositories: `--secret id=gh_token,src=FILE` (the token is not kept in the image) |

Distillery records the image in every manifest (`toolchain.builder_image`, from `BH_BUILDER_IMAGE`, set to `builda-bar:<variant>-alpine<version>`).
The image is built by Alpine's musl: it produces the `amd64-musl` / `arm64-musl` artifacts and the apk packages; glibc artifacts need a Debian-based builder
(Distillery's `docker/builder-glibc.Dockerfile`).

### The entrypoint

`docker run image` and `docker run image -c '...'` give bash, as the image always did. A command can also be given directly: `docker run image builda-bar-selftest`,
`docker run image python script.py`, `docker run image sh -c '...'` (the first argument is run when it is a command on `PATH`; otherwise it is a script for bash).
GitHub Actions `container:` jobs override the entrypoint anyway.

### Checking the image

`.github/workflows/docker-check-image.yml` builds the image on every pull request that touches it (all four Alpine variants on amd64, `stable` on arm64),
without pushing, and runs `builda-bar-selftest` as `bh` and as root. The selftest checks the required tools, the Python modules Distillery imports
(PyYAML, ruamel.yaml in `/opt/venv`), `bash` for Shaker, the user and directories, that `make` + `gcc` build a dynamic **and a static** program, that `gpg`
signs and verifies, `nfpm`, `git`, and (as information) whether the two sandboxes are allowed on that host.

## Contents & Tools

builda-bar includes a curated selection of tools for build orchestration and system configuration. *Core* tools are in every Alpine variant (the build fails without them); *extras* are installed when the variant has them and `builda-bar-selftest` reports what is missing.

### Core (in every variant)

| Group | Packages | What for |
|---|---|---|
| Compilation | `build-base` (gcc, g++, make, musl-dev, binutils, patch), `gcc`, `make`, `musl-dev`, `linux-headers`, `cmake` | the C/C++ toolchain; `gcc -static` works (musl) |
| Build helpers | `autoconf`, `automake`, `libtool`, `m4`, `flex`, `bison`, `pkgconf`, `perl` | sources that need `autoreconf`, parsers (PostgreSQL), OpenSSL's `Configure` |
| Python | `python3`, `py3-pip`, `py3-virtualenv`; `/opt/venv` with `PyYAML` and `ruamel.yaml` (first on `PATH`) | Distillery; Shaker's optional JSON/YAML parsing |
| Sources and archives | `git`, `git-perl`, `curl`, `wget`, `gnupg`, `tar`, `gzip`, `bzip2`, `xz`, `zstd`, `zip`, `unzip`, `file`, `openssh-client`, `ca-certificates` | fetching and verifying sources, signing |
| Shell and system | `bash`, `coreutils`, `findutils`, `grep`, `sed`, `diffutils`, `util-linux` (`unshare`), `su-exec`, `tini`, `jq` | Shaker (bash >= 4.2 and the usual tools), scripts |
| Isolation | `bubblewrap` | Distillery `--sandbox` (`bwrap` backend); `unshare` is the other one |
| Packaging | `nfpm` (pinned `2.48.0`, SHA-256 verified, amd64 and arm64) | deb, rpm and apk packages |
| Automation | `ansible` | infrastructure automation (inherited) |

### Extras (when the Alpine variant has them)

`util-linux-misc` (`setpriv`, Shaker drops privileges with it), `skopeo` (copy and push OCI archives), `cosign` (sign images), `shellcheck` (Shaker's lint),
`yq` (Shaker's YAML configuration), `dpkg` and `rpm` (inspect the packages Distillery writes), `rsync`, `openssl`, `py3-yaml`. What was not installed is listed in
`/etc/builda-bar-missing` and by `builda-bar-selftest`.

### Environment Variables

Container-set variables for build context:

```bash
ALPINE_VERSION=3.21.5                      # Alpine release version
VARIANT_NAME=stable                        # Variant name (stable, legacy, etc.)
BUILD_CONTAINER=builda-bar                 # Container identifier
BH_BUILDER_IMAGE=builda-bar:stable-alpine3.21.5   # recorded by Distillery in every manifest
PYTHONUNBUFFERED=1                         # Real-time Python output
PATH=/opt/venv/bin:/opt/bytehawks/core/shaker/bin:/usr/local/bin:...
```

### Build arguments

| Argument | Default | Meaning |
|---|---|---|
| `ALPINE_VERSION`, `VARIANT_NAME` | `3.20`, `stable` | the Alpine release and the variant label |
| `BUILD_DATE`, `VCS_REF`, `VERSION` | empty | OCI labels (set by the release workflow) |
| `SOURCE_URL` | this repository | the `source`, `url` and `documentation` labels (change it when the repository is renamed) |
| `NFPM_VERSION`, `NFPM_SHA256_AMD64`, `NFPM_SHA256_ARM64` | `2.48.0` + checksums | keep in step with Distillery's `packages.yaml` |
| `DISTILLERY_REF`, `SHAKER_REF` | empty (not included) | tag or branch to bake into `/opt/bytehawks/core/` |

## Build Information

### Image Metadata

Each image includes comprehensive OpenContainer Initiative (OCI) metadata:

```bash
# Inspect metadata
docker inspect ghcr.io/bytehawks-org/builda-bar/builda-bar:stable-x86_64 | jq '.[0].Config.Labels'
```

### Available Labels

- `org.opencontainers.image.title` – "builda-bar"
- `org.opencontainers.image.description` – Full description with variant and version
- `org.opencontainers.image.source` – GitHub repository URL
- `org.opencontainers.image.documentation` – Wiki URL
- `org.opencontainers.image.vendor` – "ByteHawks"
- `org.opencontainers.image.licenses` – "Apache-2.0"
- `org.opencontainers.image.created` – Build timestamp
- `org.opencontainers.image.revision` – Git commit SHA
- `org.opencontainers.image.version` – Release version
- `alpine.variant` – Alpine variant name
- `alpine.version` – Alpine version number

### Release Tagging Convention

Releases follow semantic versioning with date-based identifiers:

```
v{MAJOR}.{MINOR}.{PATCH}-{YYYYMMDD}

Example: v1.0.0-20250101
```

Each release generates images with tags:

```
{variant}-{arch}
alpine-{alpine-version}-{variant}-{arch}
{release-version}-alpine-{variant}-{arch}
```

## Contributing

### Local Building

Build locally for testing:

```bash
# x86_64
docker build --build-arg ALPINE_VERSION=3.21.5 \
  --build-arg VARIANT_NAME=stable \
  -t builda-bar:local-stable-x86_64 \
  -f Dockerfile .

# Check it, then run it
docker run --rm builda-bar:local-stable-x86_64 builda-bar-selftest
docker run --rm -it builda-bar:local-stable-x86_64
```

### Manual Workflow Trigger

Trigger builds manually with custom tags:

1. Go to **Actions** → **Build builda-bar Container Images**
2. Click **Run workflow** → **Run workflow**
3. Enter optional `tag_override` (e.g., `v1.2.3-20250115`)
4. Workflow creates images with specified version

### Reporting Issues

Found a vulnerability or issue? Please report through:

- **Security issues**: Use GitHub Security Advisory feature
- **General issues**: [GitHub Issues](https://github.com/bytehawks/bytehawks/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bytehawks/bytehawks/discussions)

## License

builda-bar is licensed under the **Apache License 2.0**. See [LICENSE](./LICENSE) file for details.

---

**ByteHawks** – European Digital Sovereignty Through Transparent Software Supply Chains
