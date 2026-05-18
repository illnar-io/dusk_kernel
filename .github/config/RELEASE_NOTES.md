**IMPORTANT DISCLAIMER**

This software is provided for testing and educational purposes only. Use at your own risk.
The developers are not responsible for any damage, data loss, or issues that may occur.
Please ensure you have proper backups before installation.

## KernelSU-Next

A kernel-based root solution for Android devices.

- Version: {{KSU_VERSION}}
- Tag: {{KSU_GIT_TAG}}
- Branch: {{KSUN_BRANCH}}
- Commit: {{KSUN_COMMIT}}

- URL: https://github.com/KernelSU-Next/KernelSU-Next
- Manager: {{KSU_MANAGER}}

## SUSFS

A KSU addon for hiding root using kernel patches and a userspace module!

- SUS_PATH - Hide suspicious paths
- SUS_MOUNT - Hide mount points (no CLI support)
- SUS_KSTAT - Spoof kernel statistics
- SPOOF_UNAME - Kernel version spoofing
- SPOOF_CMDLINE - Boot parameter spoofing
- OPEN_REDIRECT - File access redirection
- SUS_MAP - Memory mapping protection
- AVC_SPOOF - Spoof procfs avc denial logs

- Version: v2.1.0
- Branches:

{{SUSFS_BRANCHES}}

- URL: https://gitlab.com/simonpunk/susfs4ksu

## Baseband Guard (BBG)

LSM-based baseband security

- Branch: main
- URL: https://github.com/vc-teahouse/Baseband-guard

## DroidSpaces

A lightweight, LXC-inspired container runtime for Android and Linux. Run full Linux distributions natively with zero performance penalty

- URL: https://github.com/ravindu644/Droidspaces-OSS

## Networking

- BBRv1 - Improved TCP congestion control
- Wireguard - Built-in VPN support
- IP Set & IPv6 NAT Support - Advanced firewall capabilities
- TTL Target Support - Network packet manipulation

## Other Features

- TMPFS_XATTR - Extended attributes for tmpfs (Mountify support)
- TMPFS_POSIX_ACL - POSIX ACLs for tmpfs

## Kernel Flasher

Recommended flashing utility

- URL: https://github.com/fatalcoder524/KernelFlasher
