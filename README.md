# LightOS

LightOS is a small Linux distribution. It pairs a 2.7 MB custom kernel with Alpine Linux's userland, so you install software from Alpine's 28,000 packages with `lpkg`. The system runs from an ext4 disk, and everything you install or change stays across reboots.

A busybox-only live system boots from the ISO and runs from RAM.

## Requirements

Arch Linux package names:

```
base-devel bc flex bison libelf qemu-system-x86 cpio xorriso limine fakeroot
```

Fetch busybox and Linux into the repo folder:

```sh
git clone https://git.busybox.net/busybox
git -C busybox checkout 8d79a6335cc5bf052635c1a22a3f76918f682bdf
cp busybox.config busybox/.config
mkdir kernel && curl -L https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.4.tar.xz | tar xJ -C kernel
```

## Build and run

```sh
make -C busybox                     # disk.sh uses it to hash the root password
./kernel.sh                         # builds bzImage
ROOT_PASSWORD=yourpass ./disk.sh    # builds disk.img
./run.sh                            # boots in QEMU
```

Log in as `root`. If you leave `ROOT_PASSWORD` unset, `disk.sh` uses `lightos` and prints a warning.

To leave QEMU, press Ctrl-A, then X. Type `poweroff` to unmount the disk and shut down.

`disk.sh` refuses to touch an existing `disk.img`. Delete the file yourself to start over, and you lose everything on it.

## Packages

```sh
lpkg update
lpkg add python3 htop
lpkg del htop
lpkg search editor
```

`lpkg` passes every command to Alpine's `apk`, and `apk` itself still works. Alpine's [package search](https://pkgs.alpinelinux.org/packages) lists what you can install. apk checks Alpine's signatures on every package.

`lpkg add fastfetch` shows system info with the LightOS logo, `diskfs/usr/share/lightos/logo.txt`.

## Bootable ISO

```sh
make -C busybox CONFIG_PREFIX=../rootfs install
./build.sh    # packs rootfs/ into initramfs.cpio.gz
./iso.sh      # writes lightos.iso
```

The ISO boots the busybox live system on BIOS and UEFI machines through limine. It has no `lpkg`. Attach a virtio disk and the live system mounts it over `/root`.

## Layout

| Path | Purpose |
|------|---------|
| `kernel.sh` | Starts from `tinyconfig` and enables only the drivers LightOS uses. Builds no modules. |
| `disk.sh` | Builds a 2 GB `disk.img` from Alpine 3.24 minirootfs plus LightOS's boot files and root password. |
| `diskfs/` | Files `disk.sh` copies onto the disk as-is: `lpkg`, the logo and its fastfetch config. |
| `run.sh` | Boots `disk.img` in QEMU with virtio networking. |
| `busybox.config` | Busybox config for the live system: static, with init, login, DHCP and HTTPS `wget`. |
| `build.sh` | Packs `rootfs/` into the live system's `initramfs.cpio.gz`. |
| `iso.sh` | Builds `lightos.iso`. |
| `rootfs/etc/init.d/rcS` | Mounts filesystems and runs DHCP on `eth0`. Both systems use it. |
| `rootfs/etc/inittab` | Starts `rcS` and login prompts on `tty1` and `ttyS0`. |

## Limits

- The kernel has drivers for virtio and Intel e1000 hardware only. On a real PC the live system gets no disk.
- The live system loses changes outside `/root` at reboot, and its busybox `wget` skips certificate checks.
- `poweroff -f` skips unmounting the disk. Use `poweroff`.

## License

GPL-2.0. See [LICENSE](LICENSE). Busybox and Linux carry their own GPL-2.0 licenses. Alpine packages keep their own licenses.
