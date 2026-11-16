#!/bin/sh
# Boot LightOS in QEMU: from disk.img if LightOS is installed there, else the live ISO.
# UEFI=1 boots with OVMF firmware instead of BIOS. Exit: Ctrl-A X.
set -e
cd "$(dirname "$0")"
[ -f lightos.iso ] || { echo "run.sh: no lightos.iso, run ./build.sh" >&2; exit 1; }
[ -f disk.img ] || truncate -s 4G disk.img
FW=
[ -n "$UEFI" ] && FW="-bios /usr/share/edk2/x64/OVMF.4m.fd"
exec qemu-system-x86_64 -m 1G $FW -boot order=cd -cdrom lightos.iso \
  -drive file=disk.img,format=raw,if=virtio -nic user,model=virtio-net-pci \
  -nographic $( [ -w /dev/kvm ] && echo -enable-kvm )
