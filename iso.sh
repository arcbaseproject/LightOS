#!/bin/sh
# Build lightos.iso (BIOS + UEFI) with limine. Needs: pacman -S limine xorriso. Run kernel.sh and build.sh first.
set -e
cd "$(dirname "$0")"
L=/usr/share/limine
rm -rf iso_root && mkdir -p iso_root/boot/limine iso_root/EFI/BOOT
cp bzImage initramfs.cpio.gz iso_root/boot/
cp $L/limine-bios.sys $L/limine-bios-cd.bin $L/limine-uefi-cd.bin iso_root/boot/limine/
cp $L/BOOTX64.EFI iso_root/EFI/BOOT/
# Last console= gets the shell: screen (tty0), kernel log mirrored to serial.
cat > iso_root/boot/limine/limine.conf <<'CONF'
timeout: 3

/LightOS
    protocol: linux
    path: boot():/boot/bzImage
    module_path: boot():/boot/initramfs.cpio.gz
    cmdline: console=ttyS0 console=tty0 quiet
CONF
xorriso -as mkisofs -R -r -J -b boot/limine/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus -apm-block-size 2048 \
  --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image \
  --protective-msdos-label iso_root -o lightos.iso 2>/dev/null
limine bios-install lightos.iso 2>/dev/null
rm -rf iso_root
