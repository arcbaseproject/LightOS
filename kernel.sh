#!/bin/sh
# Build a minimal LightOS kernel: tinyconfig + only what LightOS uses. Drivers built in, no modules.
set -e
cd "$(dirname "$0")/kernel/linux-7.3.4"
OLD=$(cat .config 2>/dev/null | md5sum)
make tinyconfig >/dev/null
./scripts/config \
  -e 64BIT -e PRINTK -e TTY -e SERIAL_8250 -e SERIAL_8250_CONSOLE \
  -e VT -e VT_CONSOLE -e VGA_CONSOLE -e INPUT -e INPUT_KEYBOARD -e KEYBOARD_ATKBD -e SERIO -e SERIO_I8042 \
  -e BINFMT_ELF -e BINFMT_SCRIPT -e MULTIUSER -e FUTEX -e POSIX_TIMERS -e FILE_LOCKING -e EPOLL -e SIGNALFD \
  -e NAMESPACES -e USER_NS -e PID_NS -e NET_NS -e IPC_NS -e UTS_NS -e SECCOMP -e SECCOMP_FILTER \
  -e SYSVIPC -e POSIX_MQUEUE -e TMPFS_XATTR -e FUSE_FS \
  -e EVENTFD -e TIMERFD -e INOTIFY_USER -e MEMFD_CREATE -e AIO -e FHANDLE -e ADVISE_SYSCALLS \
  -e MEMBARRIER -e RSEQ -e KCMP -e CROSS_MEMORY_ATTACH -e IO_URING \
  -e RTC_CLASS -e RTC_DRV_CMOS -e INPUT_EVDEV -e ACPI_BUTTON -e UEVENT_HELPER -e SYN_COOKIES -e IPV6 -e BPF_SYSCALL \
  -e SHMEM -e TMPFS -e PROC_FS -e SYSFS -e DEVTMPFS -e DEVTMPFS_MOUNT -e UNIX98_PTYS \
  -e BLK_DEV_INITRD -e RD_GZIP -e ACPI -e PCI -e PCI_MSI \
  -e BLOCK -e EXT4_FS -e EXT4_USE_FOR_EXT2 \
  -e VIRTIO_MENU -e VIRTIO_PCI -e VIRTIO_BLK \
  -e NET -e INET -e PACKET -e UNIX -e NETDEVICES -e NET_CORE -e VIRTIO_NET \
  -e NETFILTER -e NF_CONNTRACK -e NF_TABLES -e NF_TABLES_INET -e NFT_CT -e NFT_LIMIT \
  -e NFT_REJECT -e NFT_REJECT_INET -e NF_NAT -e NFT_NAT -e NFT_MASQ -e NFT_REDIR \
  -e ETHERNET -e NET_VENDOR_INTEL -e E1000 \
  -e EFI -e EFI_STUB -e SYSFB_SIMPLEFB -e DRM -e DRM_SIMPLEDRM -e DRM_FBDEV_EMULATION -e FRAMEBUFFER_CONSOLE \
  -e USB_SUPPORT -e USB -e USB_XHCI_HCD -e USB_EHCI_HCD -e HID -e HID_GENERIC -e USB_HID \
  -e PARTITION_ADVANCED -e EFI_PARTITION -e MSDOS_PARTITION -e SCSI -e BLK_DEV_SD -e ATA -e SATA_AHCI \
  -e BLK_DEV_NVME -e USB_STORAGE -e FAT_FS -e VFAT_FS -e NLS -e NLS_CODEPAGE_437 -e NLS_ISO8859_1
make olddefconfig >/dev/null
# Config changed: rebuild from clean. An incremental build after adding NET_NS once produced a
# kernel that panicked at boot (struct layouts mixed between old and new objects).
[ "$OLD" = "$(md5sum < .config)" ] || make clean
make -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage ../../bzImage
