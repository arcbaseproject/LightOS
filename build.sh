#!/bin/sh
# Build wisp.iso: a live system (Alpine minirootfs + installer tools + overlay/) that
# runs from RAM and installs Wisp Linux with wisp-install. Boots on BIOS and UEFI via limine.
# apk and limine run inside a user namespace, so no sudo is needed. Run kernel.sh first.
set -e
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || exec unshare --map-auto --map-root-user --mount "$0" "$@"
[ -f bzImage ] || { echo "build.sh: no bzImage, run ./kernel.sh" >&2; exit 1; }
V=3.24.4
SHA=cdaa38cb8de3537967ee5b6c9b6cd00cc962da2b018e6eea48696bb274923012
T=alpine-minirootfs-$V-x86_64.tar.gz
# OpenRC runs services; the rest is what wisp-install needs.
PKGS="openrc busybox-openrc busybox-mdev-openrc ifupdown-ng zram-init dialog sfdisk e2fsprogs dosfstools limine tzdata kbd-bkeymaps musl-locales doas doas-sudo-shim"
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
# busybox-openrc runs klogd as this user but no package creates it.
chroot $R adduser -S -D -H -h /dev/null -s /sbin/nologin klogd
# OpenRC's modules service runs modprobe, which fails without this folder; the kernel has no modules.
KVER=$(cat kernel/linux-7.3.5/include/config/kernel.release)
mkdir -p $R/lib/modules/$KVER && touch $R/lib/modules/$KVER/modules.dep
for d in $DEVS; do umount $R/dev/$d; rm $R/dev/$d; done
rm $R/etc/resolv.conf

# The os-release symlink points into a package file; a real file in /etc survives apk upgrades.
rm $R/etc/os-release
cp -a overlay/. $R/
cp -a $R/usr/share/wisp/defaults/etc/. $R/etc/
cp bzImage $R/usr/share/wisp/bzImage
LV=$(cat VERSION)
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Wisp Linux $LV\"/" $R/etc/os-release
echo "VERSION_ID=$LV" >> $R/etc/os-release
# Packages Wisp Linux needs; wisp-update installs any that a new release adds.
echo "$PKGS" > $R/usr/share/wisp/packages
printf 'auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp\n' > $R/etc/network/interfaces
$R/usr/share/wisp/setup-services $R
# wisp-install restores these over the live versions below.
mkdir -p $R/usr/share/wisp/installed/etc
cp overlay/etc/inittab overlay/etc/motd overlay/etc/issue $R/usr/share/wisp/installed/etc/

# Live system: log in as root with password "wisp"; the login screen says so.
# wisp-install replaces the password and these files on the installed system.
echo 'root:wisp' | chroot $R chpasswd
printf '%s live system (\\l)\n\n  Log in as:  root\n  Password:   wisp\n\n  Then run wisp-install to install Wisp Linux to a disk.\n\n' "Wisp Linux $LV" > $R/etc/issue
printf 'Wisp Linux live system. Run wisp-install to install Wisp Linux to a disk.\n\n' > $R/etc/motd
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

/Wisp Linux Live
    protocol: linux
    path: boot():/boot/bzImage
    module_path: boot():/boot/initramfs.cpio.gz
    cmdline: console=ttyS0 console=tty0 quiet
CONF
xorriso -as mkisofs -quiet -V WISP -R -r -J -b boot/limine/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus -apm-block-size 2048 \
  --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image \
  --protective-msdos-label $I -o $R/tmp/wisp.iso
chroot $R limine bios-install /tmp/wisp.iso >/dev/null
mv $R/tmp/wisp.iso wisp.iso

# wisp-update payload: kernel + Wisp Linux files for installed systems. Leaves out the
# hostname (the user's).
U=build/update
mkdir -p $U/boot
cp -a overlay/. $U/
rm $U/etc/hostname
cp $R/etc/os-release $U/etc/
cp bzImage $U/boot/bzImage
mkdir -p $U/lib/modules/$KVER && touch $U/lib/modules/$KVER/modules.dep
cp bzImage $R/usr/share/wisp/packages $U/usr/share/wisp/
# Installs from before the rename (LightOS 0.2.x) run light-update, which downloads
# lightos-update.tar.gz, installs the packages in /usr/share/lightos/packages and runs
# /usr/share/lightos/post-update. Give it those; post-update then removes the old names.
mkdir -p $U/usr/share/lightos
cp $R/usr/share/wisp/packages $U/usr/share/lightos/
printf '#!/bin/sh\nexec /usr/share/wisp/post-update\n' > $U/usr/share/lightos/post-update
chmod 755 $U/usr/share/lightos/post-update
tar -C $U -czf wisp-update.tar.gz .
cp wisp-update.tar.gz lightos-update.tar.gz
sha256sum wisp.iso wisp-update.tar.gz lightos-update.tar.gz > SHA256SUMS
echo "build.sh: wrote wisp.iso ($(du -h wisp.iso | cut -f1)) and wisp-update.tar.gz for Wisp Linux $LV"
