#!/bin/sh
# Publish GitHub release v$(cat VERSION) with wisp.iso, wisp-update.tar.gz and SHA256SUMS.
# Installed systems pick it up with wisp-update (light-update on installs from before the
# rename, which downloads lightos-update.tar.gz). Bump VERSION, commit, push and run build.sh first.
set -e
cd "$(dirname "$0")"
V=$(cat VERSION)
die() { echo "release.sh: $*" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || die "uncommitted changes; commit them first"
[ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')" ] || die "push your commits first"
grep -q "^VERSION_ID=$V$" build/root/etc/os-release 2>/dev/null || die "build is not for $V; run ./build.sh"
sha256sum -c --quiet SHA256SUMS || die "SHA256SUMS doesn't match the files; run ./build.sh"
gh release create "v$V" wisp.iso wisp-update.tar.gz lightos-update.tar.gz SHA256SUMS \
  --target "$(git rev-parse HEAD)" --title "Wisp Linux $V" --notes "Install: boot wisp.iso and run wisp-install. Update an installed system: wisp-update."
