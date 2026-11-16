#!/usr/bin/env python3
"""Run installer safety regressions without touching real disks: python3 tests/test-installer.py."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = (Path(__file__).resolve().parents[1] / "overlay/usr/local/sbin/light-install").read_text()


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name, value in {
            "sys/block/vda/dev": "254:0\n",
            "sys/block/vda/ro": "0\n",
            "sys/block/vda/vda1/dev": "254:1\n",
            "dev/vda": "",
            "proc/self/mountinfo": "",
            "proc/swaps": "Filename Type Size Used Priority\n",
            "etc/passwd": "root:x:0:0::/:/bin/sh\ndaemon:x:2:2::/:/bin/false\n",
            "etc/group": "root:x:0:\nreserved:x:100:\n",
        }.items():
            self.write(name, value)

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)

    def run_shell(self, code, **env):
        return subprocess.run(["sh", "-c", code], capture_output=True, text=True,
                              env={**os.environ, **env})

    def disk_available(self):
        code = SOURCE.split("disk_available()", 1)[1].split("user_available()", 1)[0]
        code = "disk_available()" + code
        for directory in ("sys", "proc", "dev"):
            code = code.replace(f"/{directory}/", f"{self.root}/{directory}/")
        # Fixture files stand in for block nodes; stat supplies their device numbers.
        code = code.replace('[ -b ', '[ -e ')
        return self.run_shell("stat() { printf 'fe 1\\n'; };\n" + code + "\ndisk_available vda").returncode

    def test_unused_disk_allowed(self):
        self.assertEqual(self.disk_available(), 0)

    def test_missing_or_readonly_disk_rejected(self):
        self.write("sys/block/vda/ro", "1\n")
        self.assertNotEqual(self.disk_available(), 0)
        (self.root / "sys/block/vda/ro").unlink()
        self.assertNotEqual(self.disk_available(), 0)

    def test_mounted_disk_and_partition_rejected_even_with_alias(self):
        for dev in ("254:0", "254:1"):
            self.write("proc/self/mountinfo", f"12 1 {dev} / /data rw - ext4 /dev/disk/by-uuid/example rw\n")
            self.assertNotEqual(self.disk_available(), 0)

    def test_unrelated_mount_allowed(self):
        self.write("proc/self/mountinfo", "12 1 254:10 / /data rw - ext4 /dev/vda10 rw\n")
        self.assertEqual(self.disk_available(), 0)

    def test_missing_mount_information_rejected(self):
        (self.root / "proc/self/mountinfo").unlink()
        self.assertNotEqual(self.disk_available(), 0)

    def test_swap_partition_rejected(self):
        self.write("proc/swaps", "/dev/disk/by-uuid/swap partition 1024 0 -2\n")
        self.assertNotEqual(self.disk_available(), 0)

    def test_device_mapper_or_raid_holder_rejected(self):
        for node in ("sys/block/vda", "sys/block/vda/vda1"):
            holder = self.root / node / "holders/dm-0"
            holder.mkdir(parents=True)
            self.assertNotEqual(self.disk_available(), 0)
            holder.rmdir()

    def test_disk_rechecked_before_partitioning(self):
        code = "do_install()" + SOURCE.split("do_install()", 1)[1].split("\ninstall()", 1)[0]
        result = self.run_shell('''
            part() { printf '/dev/vda%s' "$2"; }
            progress() { :; }
            disk_available() { return 1; }
            sfdisk() { touch "$MARKER"; }
            DISK=vda
            LOG=$TEST_LOG
        ''' + code + "\ndo_install", TEST_LOG=str(self.root / "install.log"),
                                MARKER=str(self.root / "partitioned"))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "partitioned").exists())
        self.assertIn("Disk unavailable or in use", (self.root / "install.log").read_text())

    def test_existing_user_or_group_rejected(self):
        code = "user_available()" + SOURCE.split("user_available()", 1)[1].split("# --- Settings", 1)[0]
        code = code.replace("/etc/", f"{self.root}/etc/")
        for name, expected in (("root", False), ("daemon", False), ("reserved", False), ("alice", True)):
            self.assertEqual(self.run_shell(code + f"\nuser_available {name}").returncode == 0, expected)

    def test_password_bytes_preserved(self):
        code = "ask_password()" + SOURCE.split("ask_password()", 1)[1].split("set_rootpw()", 1)[0]
        code = 'D() { printf "%s" "$PASSWORD"; }; msg() { exit 99; };\n' + code
        for password in ("-n", "-e", "with spaces", r"back\slash", "colon:password"):
            result = self.run_shell(code + "\nask_password root", PASSWORD=password)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, password + "\n")

    def test_private_workspace_ignores_legacy_symlinks(self):
        self.write("victim", "untouched")
        for name in ("light-install.log", "light-install.rc", "light-install.us.bmap"):
            (self.root / name).symlink_to(self.root / "victim")
        code = "WORK=" + SOURCE.split("WORK=", 1)[1].split("export DIALOGRC", 1)[0]
        code = code.replace("/tmp/", f"{self.root}/")
        result = self.run_shell(code + '\nprintf log > "$LOG"; printf status > "$RC"; printf "%s" "$WORK"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout).stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.root / "victim").read_text(), "untouched")


if __name__ == "__main__":
    unittest.main()
