#!/bin/sh
# Publish GitHub release v$(cat VERSION) with lightos.iso, lightos-update.tar.gz and SHA256SUMS.
# Installed systems pick it up with light-update. Bump VERSION, commit, push and run build.sh first.
set -e
cd "$(dirname "$0")"
V=$(cat VERSION)
die() { echo "release.sh: $*" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || die "uncommitted changes; commit them first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')" ] || die "push your commits first"
grep -q "^VERSION_ID=$V$" build/root/etc/os-release 2>/dev/null || die "build is not for $V; run ./build.sh"
sha256sum -c --quiet SHA256SUMS || die "SHA256SUMS doesn't match the files; run ./build.sh"
gh release create "v$V" lightos.iso lightos-update.tar.gz SHA256SUMS \
  --target "$(git rev-parse HEAD)" --title "LightOS $V" --notes "Install: boot lightos.iso and run light-install. Update an installed system: light-update."
