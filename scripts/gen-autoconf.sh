#!/usr/bin/env bash
# Generate include/generated/autoconf.h from kernel .config when
# modules_prepare fails (e.g. distro headers omit arch-specific Kconfig).
# Run with sudo so we can write into the kernel build tree.

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo 'Run with sudo so we can write into the kernel build tree.' >&2
    exit 1
fi

KVERSION="${1:-$(uname -r)}"
KDIR="/lib/modules/${KVERSION}/build"
CONFIG="${KDIR}/.config"
OUT="${KDIR}/include/generated/autoconf.h"

if ! [ -r "$CONFIG" ]; then
    echo "No .config at ${CONFIG}" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT")"

awk '
/^CONFIG_[A-Za-z0-9_]+=y$/ {
    sub(/=y$/, "", $0)
    printf "#define %s 1\n", $0
    next
}
/^CONFIG_[A-Za-z0-9_]+=m$/ {
    sub(/=m$/, "", $0)
    printf "#define %s_MODULE 1\n", $0
    next
}
/^CONFIG_[A-Za-z0-9_]+="/ {
    n = index($0, "=\"")
    key = substr($0, 1, n-1)
    val = substr($0, n+2)
    sub(/"$/, "", val)
    sub(/^"/, "", val)
    gsub(/\\/, "\\\\", val)
    gsub(/"/, "\\\"", val)
    printf "#define %s \"%s\"\n", key, val
    next
}
/^CONFIG_[A-Za-z0-9_]+=/ {
    n = index($0, "=")
    key = substr($0, 1, n-1)
    val = substr($0, n+1)
    printf "#define %s %s\n", key, val
    next
}
{ next }
' "$CONFIG" > "$OUT"

echo "Wrote ${OUT}"
exit 0
