#!/bin/sh
# Pack rootfs into a gzip'd initramfs. Root password: ROOT_PASSWORD env, default "lightos".
set -e
cd "$(dirname "$0")"
[ -n "$ROOT_PASSWORD" ] || echo "build.sh: ROOT_PASSWORD unset, using default 'lightos'" >&2
mkdir -p rootfs/proc rootfs/sys rootfs/dev rootfs/run rootfs/tmp rootfs/root
umask 077
echo "root:$(echo "${ROOT_PASSWORD:-lightos}" | busybox/busybox cryptpw -m sha512):0:0:99999:7:::" > rootfs/etc/shadow
cd rootfs
find . -print0 | cpio --null -o -H newc --owner=0:0 | gzip -9 > ../initramfs.cpio.gz
