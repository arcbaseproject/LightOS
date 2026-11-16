#!/bin/sh
# Build lightos.iso: a live system (Alpine minirootfs + installer tools + overlay/) that
# runs from RAM and installs LightOS with light-install. Boots on BIOS and UEFI via limine.
# apk and limine run inside a user namespace, so no sudo is needed. Run kernel.sh first.
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || exec unshare --map-auto --map-root-user --mount "$0" "$@"
[ -f bzImage ] || { echo "build.sh: no bzImage, run ./kernel.sh" >&2; exit 1; }
V=3.24.4
SHA=cdaa38cb8de3537967ee5b6c9b6cd00cc962da2b018e6eea48696bb274923012
T=alpine-minirootfs-$V-x86_64.tar.gz
PKGS="dialog sfdisk e2fsprogs dosfstools limine"   # what light-install needs
R=build/root

mkdir -p dl
[ -f dl/$T ] || curl -sSfL "https://dl-cdn.alpinelinux.org/alpine/v${V%.*}/releases/x86_64/$T" -o dl/$T
echo "$SHA  dl/$T" | sha256sum -c --quiet

rm -rf build && mkdir -p $R
tar -xzf dl/$T -C $R
cp /etc/resolv.conf $R/etc/resolv.conf
DEVS="null zero random urandom"
for d in $DEVS; do touch $R/dev/$d; mount --bind /dev/$d $R/dev/$d; done
chroot $R /sbin/apk add --no-cache -q $PKGS
for d in $DEVS; do umount $R/dev/$d; rm $R/dev/$d; done
rm $R/etc/resolv.conf

# The os-release symlink points into a package file; a real file in /etc survives apk upgrades.
rm $R/etc/os-release
cp -a overlay/. $R/
cp bzImage $R/usr/share/lightos/bzImage
# light-install restores these over the live versions below.
mkdir -p $R/usr/share/lightos/installed/etc
cp overlay/etc/inittab overlay/etc/motd $R/usr/share/lightos/installed/etc/

# Live system: root logs in without a password, motd points at the installer.
sed -i 's|/sbin/getty |/sbin/getty -n -l /usr/local/sbin/autologin |' $R/etc/inittab
printf 'LightOS live system. Run light-install to install LightOS to a disk.\n\n' > $R/etc/motd
ln -s sbin/init $R/init

# Pack the live root into an initramfs (inside the namespace, so files keep root ownership).
(cd $R && find . -print0 | cpio --null -o -H newc --quiet | gzip -9) > build/initramfs.cpio.gz

I=build/iso
mkdir -p $I/boot/limine $I/EFI/BOOT
cp bzImage build/initramfs.cpio.gz $I/boot/
cp $R/usr/share/limine/limine-bios.sys $R/usr/share/limine/limine-bios-cd.bin $R/usr/share/limine/limine-uefi-cd.bin $I/boot/limine/
cp $R/usr/share/limine/BOOTX64.EFI $I/EFI/BOOT/
# Last console= gets the login prompt's /dev/console: the screen. Kernel log also goes to serial.
cat > $I/boot/limine/limine.conf <<'CONF'
timeout: 3

/LightOS Live
    protocol: linux
    path: boot():/boot/bzImage
    module_path: boot():/boot/initramfs.cpio.gz
    cmdline: console=ttyS0 console=tty0 quiet
CONF
xorriso -as mkisofs -quiet -V LIGHTOS -R -r -J -b boot/limine/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus -apm-block-size 2048 \
  --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image \
  --protective-msdos-label $I -o $R/tmp/lightos.iso
chroot $R limine bios-install /tmp/lightos.iso >/dev/null
mv $R/tmp/lightos.iso lightos.iso
echo "build.sh: wrote lightos.iso ($(du -h lightos.iso | cut -f1))"
