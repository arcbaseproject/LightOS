# LightOS

LightOS is a small Linux distribution. It pairs a 3 MB custom kernel with Alpine Linux's userland, so you install software from Alpine's 28,000 packages with `lpkg`.

You boot the 16 MB ISO into a live system that runs from RAM, then run `light-install` to put LightOS on a disk. The installed system boots on BIOS and UEFI machines.

## Requirements

Arch Linux package names:

```
base-devel bc flex bison libelf cpio xorriso qemu-system-x86 edk2-ovmf
```

`build.sh` runs apk without sudo inside a user namespace. Your user needs an entry in `/etc/subuid` and `/etc/subgid`; Arch's `useradd` creates them.

Fetch the Linux source into the repo folder:

```sh
mkdir kernel && curl -L https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.4.tar.xz | tar xJ -C kernel
```

## Build and run

```sh
./kernel.sh   # builds bzImage
./build.sh    # builds lightos.iso
./run.sh      # boots it in QEMU
```

`run.sh` attaches a 4 GB `disk.img` and boots from it once LightOS is installed there. Until then it boots the ISO. Set `UEFI=1` to boot with UEFI firmware instead of BIOS.

To leave QEMU, press Ctrl-A, then X.

## Installing

The live system logs you in as root. Run:

```sh
light-install
```

The installer asks for a disk, a hostname, a root password and an optional user, then shows a summary. Nothing touches the disk until you confirm.

It erases the disk and creates three partitions: a 1 MiB BIOS boot partition, a 256 MiB EFI system partition mounted at `/boot`, and an ext4 root. Then it copies the live system over and installs limine. If a step fails, it shows the end of `/tmp/light-install.log`.

To install on a real machine, write the ISO to a USB stick:

```sh
dd if=lightos.iso of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with your USB stick. `dd` overwrites whatever device you name.

## Packages

```sh
lpkg update
lpkg add python3 htop
lpkg del htop
lpkg search editor
```

`lpkg` passes every command to Alpine's `apk`, and `apk` itself still works. Alpine's [package search](https://pkgs.alpinelinux.org/packages) lists what you can install. apk checks Alpine's signatures on every package.

`lpkg add fastfetch` shows system info with the LightOS logo.

## Layout

| Path | Purpose |
|------|---------|
| `kernel.sh` | Starts from `tinyconfig` and enables only the drivers LightOS uses. Builds no modules. |
| `build.sh` | Builds the live system from Alpine 3.24 minirootfs, the installer's tools and `overlay/`, then packs `lightos.iso`. |
| `run.sh` | Boots QEMU with `disk.img` and the ISO. |
| `overlay/` | Files copied onto the system as-is. |
| `overlay/usr/local/sbin/light-install` | The installer. |
| `overlay/usr/local/bin/lpkg` | The package command. |
| `overlay/etc/init.d/rcS` | Mounts filesystems, sets the hostname and runs DHCP on `eth0`. |
| `overlay/usr/share/lightos/logo.txt` | The fastfetch logo. |

## Limits

- The kernel drives virtio, SATA, NVMe and USB disks, Intel e1000 and virtio network cards, and USB keyboards. Wi-Fi and most other network cards don't work yet.
- The installer takes a whole disk. It doesn't dual-boot, encrypt or resize.
- New kernels don't arrive through `lpkg`. Rebuild with `kernel.sh` and copy `bzImage` to `/boot`.
- `poweroff -f` skips unmounting the disk. Use `poweroff`.

## License

GPL-2.0. See [LICENSE](LICENSE). Linux carries its own GPL-2.0 license, and Alpine packages keep their own licenses.
