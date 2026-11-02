#!/bin/bash
# builda-bar-selftest: what is in the container, and does it work.
#
#   docker run --rm builda-bar:local builda-bar-selftest          # exit 1 when something indispensable is missing or broken
#
# REQUIRED must exist and run; OPTIONAL is reported (WARN) because an older Alpine may not ship it, or the host forbids it
# (the sandboxes need namespaces: run the container with --privileged or --security-opt seccomp=unconfined to see them work).
set -u

ok=0 warn=0 fail=0
row() {   # row STATUS NAME DETAIL
    printf '[%-4s] %-26s %s\n' "$1" "$2" "$3"
    case "$1" in OK) ok=$((ok + 1)) ;; WARN) warn=$((warn + 1)) ;; *) fail=$((fail + 1)) ;; esac
}
first_line() { "$@" 2>&1 | head -n 1; }

REQUIRED=(bash git gpg tar gzip bzip2 xz zstd zip unzip file make gcc g++ cc ld ar cmake perl python3 pip curl wget jq patch
          flex bison m4 pkg-config autoconf automake libtoolize unshare su-exec tini bwrap nfpm ssh sha256sum find grep sed diff ansible)
OPTIONAL=(setpriv skopeo cosign shellcheck yq dpkg rpm rsync openssl)

for tool in "${REQUIRED[@]}"; do
    if path="$(command -v "$tool")"; then row OK "$tool" "$path"; else row FAIL "$tool" "not found"; fi
done
for tool in "${OPTIONAL[@]}"; do
    if path="$(command -v "$tool")"; then row OK "$tool" "$path"; else row WARN "$tool" "not available in this Alpine (optional)"; fi
done
[ -s /etc/builda-bar-missing ] && row WARN "extras not installed" "$(tr '\n' ' ' < /etc/builda-bar-missing)"

# --- Python: the interpreter Distillery runs with, and its two libraries --------------------------------------------------
if py="$(command -v python3)"; then
    if "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
        row OK "python >= 3.9" "$("$py" -V 2>&1) ($py)"
    else
        row FAIL "python >= 3.9" "$("$py" -V 2>&1)"
    fi
    # by import, not importlib.metadata: on Python 3.9 the latter does not find distributions whose normalized name differs (ruamel_yaml)
    for module in yaml ruamel.yaml; do
        if version="$("$py" -c "import $module; print(getattr($module, '__version__', 'installed'))" 2>&1)"; then
            row OK "python: $module" "$version"
        else
            row FAIL "python: $module" "cannot import ($py): $(printf '%s' "$version" | tail -n 1)"
        fi
    done
fi
if [ -x /opt/venv/bin/python ]; then
    row OK "/opt/venv" "python $(/opt/venv/bin/python -V 2>&1 | cut -d' ' -f2), python3 on PATH: $(command -v python3)"
else
    row FAIL "/opt/venv" "missing"
fi

# --- Shaker: bash >= 4.2, the hashing tool ----------------------------------------------------------------------------------
if [ "${BASH_VERSINFO[0]}" -gt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 2 ]; }; then
    row OK "bash >= 4.2 (Shaker)" "$BASH_VERSION"
else
    row FAIL "bash >= 4.2 (Shaker)" "$BASH_VERSION"
fi

# --- identity and layout ---------------------------------------------------------------------------------------------------
row OK "user" "$(id -un) ($(id -u):$(id -g))"
for dir in /work /opt/bytehawks /opt/bytehawks/core /opt/bytehawks/deps /opt/bytehawks/var; do
    if [ -d "$dir" ] && { [ "$(id -u)" -eq 0 ] || [ -w "$dir" ]; }; then row OK "dir $dir" "present, writable"; else row FAIL "dir $dir" "missing or not writable"; fi
done
for tool in distillery shaker; do
    if [ -d "/opt/bytehawks/core/$tool" ]; then row OK "$tool (baked in)" "/opt/bytehawks/core/$tool"; else row OK "$tool" "not baked in: check it out where it is needed"; fi
done
if [ -n "${BH_BUILDER_IMAGE:-}" ]; then row OK "BH_BUILDER_IMAGE" "$BH_BUILDER_IMAGE"; else row WARN "BH_BUILDER_IMAGE" "not set"; fi

# --- the toolchain really builds: a dynamic and a static (Distillery --linkage static) program, with make --------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/hello.c" <<'C'
#include <stdio.h>
int main(void) { puts("hello from the toolchain"); return 0; }
C
# shellcheck disable=SC2016
printf 'hello: hello.c\n\t%s -o hello hello.c\n' '$(CC)' > "$tmp/Makefile"
if (cd "$tmp" && make -s >/dev/null 2>&1 && [ "$(./hello)" = "hello from the toolchain" ]); then row OK "compile (make, gcc)" "dynamic"; else row FAIL "compile (make, gcc)" "failed"; fi
if gcc -static -o "$tmp/hello-static" "$tmp/hello.c" 2>/dev/null && [ "$("$tmp/hello-static")" = "hello from the toolchain" ]; then
    row OK "compile static (musl)" "$(file -b "$tmp/hello-static" | cut -d, -f1-3)"
else
    row FAIL "compile static (musl)" "gcc -static failed"
fi

# --- gpg can make and use a throw-away key (Distillery signing, Shaker restore) --------------------------------------------
export GNUPGHOME="$tmp/gnupg"
mkdir -m 700 "$GNUPGHOME"
if gpg --batch --quiet --passphrase '' --quick-generate-key "selftest <selftest@example.com>" ed25519 sign 1d >/dev/null 2>&1 \
   && echo test > "$tmp/data" && gpg --batch --quiet --detach-sign --output "$tmp/data.sig" "$tmp/data" 2>/dev/null \
   && gpg --batch --verify "$tmp/data.sig" "$tmp/data" >/dev/null 2>&1; then
    row OK "gpg sign and verify" "ed25519, detached"
else
    row FAIL "gpg sign and verify" "failed"
fi

# --- nfpm and git ----------------------------------------------------------------------------------------------------------
if command -v nfpm >/dev/null; then
    # nfpm prints a banner before the version line
    row OK "nfpm version" "$(nfpm --version 2>&1 | grep -m1 -Eo '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' || first_line nfpm --version)"
else
    row FAIL "nfpm version" "not found"
fi
if (cd "$tmp" && git init -q repo && cd repo && git -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m t); then row OK "git" "$(git --version)"; else row FAIL "git" "cannot commit"; fi

# --- the sandboxes: informational, they need namespaces the host may refuse -----------------------------------------------------
if unshare --mount --pid --fork --net true >/dev/null 2>&1; then
    row OK "sandbox: unshare" "namespaces available"
else
    row WARN "sandbox: unshare" "not permitted here (needs root and CAP_SYS_ADMIN, or user namespaces)"
fi
if bwrap --ro-bind / / --unshare-net true >/dev/null 2>&1; then
    row OK "sandbox: bwrap" "works"
else
    row WARN "sandbox: bwrap" "not permitted here (needs user namespaces)"
fi

echo "-- $ok ok, $warn warning, $fail failed"
[ "$fail" -eq 0 ]
