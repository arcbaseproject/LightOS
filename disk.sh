#!/bin/sh
# Build disk.img (2G ext4): Alpine minirootfs + LightOS boot config. apk is the package manager.
# Root password: ROOT_PASSWORD env, default "lightos".
set -e
cd "$(dirname "$0")"
[ ! -e disk.img ] || { echo "disk.sh: disk.img exists; delete it first (its data is lost)" >&2; exit 1; }
[ -n "$ROOT_PASSWORD" ] || echo "disk.sh: ROOT_PASSWORD unset, using default 'lightos'" >&2
V=3.24.4
SHA=cdaa38cb8de3537967ee5b6c9b6cd00cc962da2b018e6eea48696bb274923012
T=alpine-minirootfs-$V-x86_64.tar.gz
mkdir -p dl
[ -f dl/$T ] || curl -sSfL "https://dl-cdn.alpinelinux.org/alpine/v${V%.*}/releases/x86_64/$T" -o dl/$T
echo "$SHA  dl/$T" | sha256sum -c --quiet
HASH=$(echo "${ROOT_PASSWORD:-lightos}" | busybox/busybox cryptpw -m sha512)
rm -rf disk_root
# fakeroot keeps root ownership from the tarball through to mke2fs.
fakeroot sh -c "
  mkdir disk_root && tar -xzf dl/$T -C disk_root
  cp rootfs/etc/inittab rootfs/etc/issue disk_root/etc/
  echo 'Welcome to LightOS. Install software with: apk add NAME' > disk_root/etc/motd
  mkdir -p disk_root/etc/init.d && cp rootfs/etc/init.d/rcS disk_root/etc/init.d/rcS
  sed -i 's|^root:[^:]*:|root:$HASH:|' disk_root/etc/shadow
  mke2fs -q -t ext4 -L lightos -d disk_root disk.img 2G
"
rm -rf disk_root
