#!/bin/sh
# Boot LightOS in QEMU. Build bzImage with kernel.sh first. Exit: Ctrl-A X.
set -e
cd "$(dirname "$0")"
KERNEL=${KERNEL:-bzImage}
[ -f disk.img ] || truncate -s 256M disk.img
exec qemu-system-x86_64 -m 256M -kernel "$KERNEL" -initrd initramfs.cpio.gz \
  -append "console=ttyS0 quiet" -drive file=disk.img,format=raw,if=virtio -nic user,model=virtio-net-pci -nographic $( [ -w /dev/kvm ] && echo -enable-kvm )
