#!/bin/sh
# Build a minimal LightOS kernel: tinyconfig + only what LightOS uses. Drivers built in, no modules.
set -e
cd "$(dirname "$0")/kernel/linux-7.3.4"
make tinyconfig >/dev/null
./scripts/config \
  -e 64BIT -e PRINTK -e TTY -e SERIAL_8250 -e SERIAL_8250_CONSOLE \
  -e VT -e VT_CONSOLE -e VGA_CONSOLE -e INPUT -e INPUT_KEYBOARD -e KEYBOARD_ATKBD -e SERIO -e SERIO_I8042 \
  -e BINFMT_ELF -e BINFMT_SCRIPT -e MULTIUSER -e FUTEX -e POSIX_TIMERS -e FILE_LOCKING -e EPOLL -e SIGNALFD \
  -e SHMEM -e TMPFS -e PROC_FS -e SYSFS -e DEVTMPFS -e DEVTMPFS_MOUNT -e UNIX98_PTYS \
  -e BLK_DEV_INITRD -e RD_GZIP -e ACPI -e PCI -e PCI_MSI \
  -e BLOCK -e EXT4_FS -e EXT4_USE_FOR_EXT2 \
  -e VIRTIO_MENU -e VIRTIO_PCI -e VIRTIO_BLK \
  -e NET -e INET -e PACKET -e UNIX -e NETDEVICES -e NET_CORE -e VIRTIO_NET \
  -e ETHERNET -e NET_VENDOR_INTEL -e E1000 \
  -e EFI -e EFI_STUB -e SYSFB_SIMPLEFB -e DRM -e DRM_SIMPLEDRM -e DRM_FBDEV_EMULATION -e FRAMEBUFFER_CONSOLE \
  -e USB_SUPPORT -e USB -e USB_XHCI_HCD -e USB_EHCI_HCD -e HID -e HID_GENERIC -e USB_HID
make olddefconfig >/dev/null
make -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage ../../bzImage
