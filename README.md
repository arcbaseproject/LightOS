<p align="center"><img src="logo.svg" alt="LightOS logo" width="220"></p>

# LightOS

LightOS is a small Linux distribution. It pairs a 4 MB custom kernel with Alpine Linux's userland, so you install software from Alpine's 28,000 packages with `lpkg`.

You boot the 21 MB ISO into a live system that runs from RAM, then run `light-install` to put LightOS on a disk. The installed system boots on BIOS and UEFI machines.

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

`run.sh` attaches a 4 GB `disk.img` and boots from it once LightOS is installed there. Until then it boots the ISO. Set `UEFI=1` to boot with UEFI firmware instead of BIOS, and `VNC=1` to forward port 5901 for the VNC desktop.

To leave QEMU, press Ctrl-A, then X.

## Installing

The live system shows its boot log, then a login prompt. Log in as `root` with password `lightos`, then run:

```sh
light-install
```

The installer works like archinstall: a main menu lists every setting with its current value. Set them in any order, then choose Install.

| Item | Options |
|------|---------|
| Keyboard layout | 83 console layouts and their variants. Applies right away, so the passwords you type use it. |
| Locale | `LANG`, from the 16 languages musl has translations for. |
| Disk | Required. Lists disks of 1 GiB or more that aren't in use. |
| Hostname | Defaults to `lightos`. |
| Root password | Required. |
| User account | Optional, with or without `sudo` (doas, with a `sudo` command). |
| Timezone | Region, then city. |
| Time sync (NTP) | Busybox `ntpd` at boot, against `pool.ntp.org`. |
| Network | Wired DHCP on `eth0`, or none. |
| Desktop | None, XFCE, LXQt, MATE or JWM, reached over VNC. Needs a user account and the network. |
| Extra packages | Alpine packages to install along with the system. Needs a network connection. |

Install shows a summary and erases nothing until you confirm. Then it creates three partitions: a 1 MiB BIOS boot partition, a 256 MiB EFI system partition mounted at `/boot`, and an ext4 root. It copies the live system over, applies your settings and installs limine. If a step fails, it shows the end of its log in a private `/tmp/light-install.XXXXXX/` directory and prints the exact path.

The installer's root password replaces `lightos` on the installed system.

## Services

LightOS runs Alpine's OpenRC under busybox init, so services from Alpine packages work as installed:

```sh
rc-status                    # what's running
rc-service sshd start        # start a service now
rc-update add sshd default   # start it at every boot
```

The boot log shows each service with `[ ok ]` or `[ !! ]` on the screen and the serial port. LightOS enables the same services as a stock Alpine install: mdev, hwclock, fsck, syslog and klogd, networking, seedrng, acpid (the power button shuts down), crond, `local` (runs your scripts in `/etc/local.d`) and, if you chose time sync, ntpd. On top of that it mounts cgroups v2, gives each install its own `/etc/machine-id`, and sets up compressed swap in RAM (zram, half the size of RAM, configured in `/etc/conf.d/zram-init`).

Settings live in Alpine's usual files: network in `/etc/network/interfaces`, keyboard in `/etc/conf.d/loadkmap`, NTP servers in `/etc/conf.d/ntpd`.

To install on a real machine, write the ISO to a USB stick:

```sh
dd if=lightos.iso of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with your USB stick. `dd` overwrites whatever device you name.

## Updating

```sh
sudo light-update --check   # only report
sudo light-update           # install the latest release, then Alpine updates
```

`light-update` compares `VERSION_ID` in `/etc/os-release` with the latest GitHub release. If the release is newer, it downloads `lightos-update.tar.gz`, checks it against the release's `SHA256SUMS` and installs the new kernel to `/boot` along with LightOS's system files. It then runs `apk upgrade` and refreshes limine. Reboot to start the new kernel.

It never touches your hostname, users, passwords or network settings. Before it replaces any other file in `/etc`, it saves the old copy in `/var/backups/light-update/<old version>/`. Config files you're meant to edit, such as `/etc/conf.d/lightos-vnc` and `/etc/conf.d/zram-init`, are only installed when missing.

To update a system installed from 0.1.0, first get the current `light-update`, since 0.1.0's copy can't switch to OpenRC:

```sh
wget -O /usr/local/sbin/light-update https://raw.githubusercontent.com/arcbaseproject/LightOS/main/overlay/usr/local/sbin/light-update
```

To publish an update: bump `VERSION`, commit and push, run `./build.sh`, then `./release.sh`.

## Desktop over VNC

Pick a desktop under Desktop in `light-install`, or add one later:

```sh
sudo setup-desktop
```

`setup-desktop` asks for a desktop (XFCE, LXQt, MATE or JWM), the user it runs as, and a VNC password. It then installs the desktop, `tigervnc` and `dbus` and starts the `lightos-vnc` service. Without the menu: `echo PASSWORD | sudo setup-desktop xfce USER`.

`lightos-vnc` runs `Xvnc` on port 5901 with the desktop and restarts it if it crashes. Its settings are in `/etc/conf.d/lightos-vnc`. In QEMU, start the VM with `VNC=1 ./run.sh` to forward port 5901, then connect from your computer with `vncviewer localhost:5901`.

VNC only checks the first 8 characters of a password, and its traffic isn't encrypted. Off your own machine, set `LISTEN="localhost"` in `/etc/conf.d/lightos-vnc` and connect through an SSH tunnel.

## Containers

The kernel has what Docker and Podman need:

```sh
sudo lpkg add docker
sudo rc-update add docker default
sudo rc-service docker start
sudo docker run --rm alpine echo hello
```

## Packages

```sh
lpkg update
lpkg add python3 htop
lpkg del htop
lpkg search editor
```

`lpkg` passes every command to Alpine's `apk`, and `apk` itself still works. Commands that change the system (`add`, `del`, `update`, `upgrade`) need root: `sudo lpkg add …`. Alpine's [package search](https://pkgs.alpinelinux.org/packages) lists what you can install. apk checks Alpine's signatures on every package.

`lpkg add fastfetch` shows system info with the LightOS logo.

### Flatpak

```sh
lpkg add flatpak
flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak --user install flathub org.freedesktop.Platform//26.08
flatpak run --command=sh org.freedesktop.Platform//26.08
```

Install with `--user`, or as root. A system-wide install from a normal account needs D-Bus and polkit, which LightOS doesn't run. LightOS has no desktop yet, so only command-line apps work.

## Layout

| Path | Purpose |
|------|---------|
| `kernel.sh` | Starts from `tinyconfig` and enables only the drivers LightOS uses. Builds no modules. |
| `build.sh` | Builds the live system from Alpine 3.24 minirootfs, the installer's tools and `overlay/`, then packs `lightos.iso`. |
| `release.sh` | Publishes `v$VERSION` on GitHub with the ISO, update package and checksums. |
| `VERSION` | The LightOS version `build.sh` stamps into `/etc/os-release`. |
| `run.sh` | Boots QEMU with `disk.img` and the ISO. |
| `overlay/` | Files copied onto the system as-is. |
| `overlay/usr/local/sbin/light-install` | The installer. |
| `overlay/usr/local/sbin/light-update` | The updater. |
| `overlay/usr/local/sbin/setup-desktop` | Installs a VNC desktop. |
| `overlay/usr/local/bin/lpkg` | The package command. |
| `overlay/usr/share/lightos/rc` | Runs OpenRC from `inittab` and shows its log on every console. |
| `overlay/usr/share/lightos/setup-services` | Enables the standard OpenRC services. |
| `overlay/usr/share/lightos/post-update` | Run by `light-update` to bring older installs up to date. |
| `overlay/usr/share/lightos/logo.txt` | The fastfetch logo. |

## Limits

- The kernel drives virtio, SATA, NVMe and USB disks, Intel (e1000, e1000e, igb, igc), Realtek (r8169, RTL8152 USB), USB CDC Ethernet and virtio network cards, and USB keyboards. Wi-Fi doesn't work yet.
- Flatpak runs command-line apps only. Graphical apps need a desktop, which LightOS doesn't have yet.
- The installer takes a whole disk. It doesn't dual-boot, encrypt, resize, add swap or install a desktop.
- `poweroff -f` skips unmounting the disk. Use `poweroff`.

## License

GPL-2.0. See [LICENSE](LICENSE). Linux carries its own GPL-2.0 license, and Alpine packages keep their own licenses.
