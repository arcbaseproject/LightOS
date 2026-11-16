#!/bin/sh
# Boot LightOS from disk.img in QEMU. Build bzImage with kernel.sh and disk.img with disk.sh first. Exit: Ctrl-A X.
set -e
cd "$(dirname "$0")"
KERNEL=${KERNEL:-bzImage}
[ -f disk.img ] || { echo "run.sh: no disk.img, run ./disk.sh" >&2; exit 1; }
exec qemu-system-x86_64 -m 512M -kernel "$KERNEL" \
  -append "root=/dev/vda rw console=ttyS0 quiet" -drive file=disk.img,format=raw,if=virtio \
  -nic user,model=virtio-net-pci -nographic $( [ -w /dev/kvm ] && echo -enable-kvm )
