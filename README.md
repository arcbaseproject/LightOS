# LightOS

LightOS is a small Linux distribution: a 2.7 MB kernel and a busybox userland that boots from RAM. You get a login prompt, DHCP networking, and a disk that keeps your files in `/root` across reboots.

## Requirements

Arch Linux package names:

```
base-devel bc flex bison libelf qemu-system-x86 cpio xorriso limine
```

You also need the LightOS sources:

- `busybox/`: busybox source, built static (`CONFIG_STATIC=y`).
- `kernel/linux-7.3.4/`: Linux 7.3.4 source from kernel.org.

## Build and run

```sh
make -C busybox && make -C busybox CONFIG_PREFIX=../rootfs install
./kernel.sh                         # builds bzImage
ROOT_PASSWORD=yourpass ./build.sh   # packs rootfs into initramfs.cpio.gz
./run.sh                            # boots in QEMU
```

Log in as `root`. If you leave `ROOT_PASSWORD` unset, `build.sh` uses `lightos` and prints a warning.

To leave QEMU, press Ctrl-A, then X. Type `poweroff` to unmount the disk and shut down.

## Bootable ISO

```sh
./iso.sh
```

`iso.sh` writes `lightos.iso`, which boots on BIOS and UEFI machines through limine.

## Layout

| Path | Purpose |
|------|---------|
| `kernel.sh` | Starts from `tinyconfig` and enables only the drivers LightOS uses. Builds no modules. |
| `build.sh` | Writes `/etc/shadow` and packs `rootfs/` into `initramfs.cpio.gz`. |
| `run.sh` | Boots QEMU with a virtio disk (`disk.img`, 256 MB, created on first run) and virtio networking. |
| `iso.sh` | Builds `lightos.iso`. |
| `rootfs/etc/init.d/rcS` | Mounts filesystems, runs DHCP on `eth0`, and mounts the disk over `/root`. |
| `rootfs/etc/inittab` | Starts `rcS` and a login prompt on the console. |

## Limits

- Changes outside `/root` disappear at reboot, `passwd` included. Set the password at build time.
- Busybox `wget` speaks HTTPS but skips certificate checks.
- The kernel has drivers for virtio and Intel e1000 hardware only. On a real PC you get a shell with no disk.
- `poweroff -f` skips unmounting the disk. Use `poweroff`.

## License

GPL-2.0. See [LICENSE](LICENSE). Busybox and Linux carry their own GPL-2.0 licenses.
