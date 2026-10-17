<div align="center">

# 🌑 DUSK Kernel

**Shhhh... No one knows**

[![KernelSU-Next](https://img.shields.io/badge/KernelSU--Next-Supported-green)](https://github.com/KernelSU-Next/KernelSU-Next)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-orange?logo=gitlab)](https://gitlab.com/simonpunk/susfs4ksu)
[![BBG](https://img.shields.io/badge/BBG-Baseband_Guard-cb2431)](https://github.com/vc-teahouse/Baseband-guard)
[![NTSync](https://img.shields.io/badge/ntsync-Backported-blue)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git)
[![BBRv3](https://img.shields.io/badge/BBRv3-Enabled-purple)](https://github.com/google/bbr)
[![OnePlusOSS Tracking](https://img.shields.io/badge/OnePlusOSS--Tracker-active-green)](https://github.com/illnar-io/dusk_kernel/blob/status-page/README.md)

</div>

---

## ⚠️ Disclaimer

I am **not responsible** for bricked devices, damaged hardware, or any issues that arise from using this kernel. Please make sure to:

- 💾 Back up your data
- 🧠 Understand the risks before proceeding
- 📖 Do thorough research before flashing

By flashing this kernel, **YOU** are choosing to make these modifications. If something goes wrong, **do not blame me**!

<div align="center">

### 🚨 Proceed at your own risk!

</div>

---

## 🔧 Available Kernels

<div align="center">

| Kernel | Repository | Status |
|--------|------------|--------|
| 🌑 **DUSK** | [dusk_kernel](https://github.com/illnar-io/dusk_kernel) | ✅ Active |

</div>

---

## 📱 Supported Devices

All builds are based on **OnePlus official source** and target **Stock OOS16 (android16-6.12)**.

<div align="center">

| Device | Config | Status |
|--------|--------|--------|
| 🔥 **OnePlus 15** | `configs/a16/OP15.json` | ✅ Active |
| 🔥 **OnePlus 15T** | `configs/a16/OP15T.json` | ✅ Active |
| 🔥 **OnePlus 15R** | `configs/a16/OP15r.json` | ✅ Active |

</div>

- 📖 Full compatibility notes: [Compatibility_Info](https://github.com/illnar-io/dusk_kernel/blob/main/compatibility.md)
- ⚠️ Do **not** flash across a major Android OTA (a15 → a16) unless it is verified for your exact model.

---

## 📋 DUSK Glossary

**DUSK** = **D**roidspaces + s**U**sfs + nt**S**ync + **K**ernel

| Component | Description |
|-----------|-------------|
| **Droidspaces** | Container/namespace support for running full Linux environments in isolation |
| **sUsfs (SUSFS)** | Stealth layer for root hiding and userspace filesystem masking |
| **ntSync** | Windows NT sync primitives backport for Wine/Proton performance |
| **Kernel** | OnePlus/Qualcomm kernel with KernelSU-Next integration |

---

## 🔗 Additional Resources

- 🩹 [Kernel Patches](https://github.com/WildKernels/kernel_patches)
- ⚡ [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher)

---

## 📱 OnePlusOSS Repositories Tracking

- 📊 **Live Dashboard**: [OnePlus Repos Tracking & Changes](https://github.com/illnar-io/dusk_kernel/blob/status-page/README.md)
- ⏱️ **Update Frequency**: Every 2 hours (Automated)

---

## ✨ Features

- 🔐 **KernelSU / KernelSU-Next**: A root solution for Android GKI devices that works in kernel mode and grants root permission to userspace applications directly in kernel space
- 🥷 **SUSFS**: An addon root hiding kernel patches and userspace module for KernelSU
- 🛡️ **BBG**: LSM-based Baseband Guard security to protect critical device partitions
- 🖧 **BBRv1 / BBRv3**: Improved TCP congestion control
- 🚦 **CAKE and PIE qdisc Support**: Better Net Schedulers
- 🌐 **TTL Target Support**: Network packet manipulation
- 🧱 **IP Set & IPv6 NAT Support**: Advanced firewall capabilities and IPv6 NAT support
- ⚡️ **TMPFS XATTR / POSIX ACL**: Extended TMPFS support for meta modules and Mountify
- 🖥️ **Droidspaces Support**: Portable Linux containers to run full Linux environments
- 🔃 **NTSync**: High-performance, low-latency synchronization primitives compatible with the Windows NT kernel API
- </> **Unicode Bypass Fix**: Prevent path traversal and other detections using non-printable Unicode codepoints `[Experimental]`
- 🚀 **Optimisation patches**: Memory, I/O, CPU scheduler, network and other general tunings
- ✅ **LTO**: Link Time Optimisation support

---

## 📋 Installation Instructions

For GKI installation, please follow the official guide:

📖 **[KernelSU Installation Guide](https://kernelsu.org/guide/installation.html)**

You can also find installation instructions in the release notes.

---

## 🌟 Special Thanks

**These amazing people help make this project possible! ❤️**

<div align="center">

| 🔧 **Project** | 👨‍💻 **Developer** | 🔗 **Link** |
|:---------------:|:----------------:|:-----------:|
| **KernelSU** | tiann | [![GitHub](https://img.shields.io/badge/GitHub-tiann-blue?style=flat-square&logo=github)](https://github.com/tiann/KernelSU) |
| **KernelSU-Next** | rifsxd | [![GitHub](https://img.shields.io/badge/GitHub-rifsxd-blue?style=flat-square&logo=github)](https://github.com/KernelSU-Next/KernelSU-Next) |
| **Magic-KSU** | 5ec1cff | [![GitHub](https://img.shields.io/badge/GitHub-5ec1cff-blue?style=flat-square&logo=github)](https://github.com/5ec1cff/KernelSU) |
| **SUSFS** | simonpunk | [![GitLab](https://img.shields.io/badge/GitLab-simonpunk-orange?style=flat-square&logo=gitlab)](https://gitlab.com/simonpunk/susfs4ksu.git) |
| **SUSFS Module** | sidex15 | [![GitHub](https://img.shields.io/badge/GitHub-sidex15-blue?style=flat-square&logo=github)](https://github.com/sidex15) |
| **Sultan Kernels** | kerneltoast | [![GitHub](https://img.shields.io/badge/GitHub-kerneltoast-blue?style=flat-square&logo=github)](https://github.com/kerneltoast) |
| **Baseband Guard** | vc-teahouse | [![GitHub](https://img.shields.io/badge/GitHub-vc--teahouse-blue?style=flat-square&logo=github)](https://github.com/vc-teahouse/Baseband-guard.git) |
| **Droidspaces** | ravindu644 | [![GitHub](https://img.shields.io/badge/GitHub-ravindu644-blue?style=flat-square&logo=github)](https://github.com/ravindu644/Droidspaces-OSS.git) |
| **WildKernels** | TheWildJames | [![GitHub](https://img.shields.io/badge/GitHub-WildKernels-blue?style=flat-square&logo=github)](https://github.com/WildKernels) |

</div>

*If you have contributed and are not listed here, please remind me!* 🙏

---

## 💬 Support

If you encounter any issues or need help, feel free to:

- 🐛 Open an issue in this repository
- 💬 Reach out to me directly via [Telegram](https://t.me/ILLnar)

---

## 📱 Connect With Us

<div align="center">

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-illnar--io-ea4aaa?logo=github-sponsors&logoColor=white)](https://github.com/sponsors/illnar-io)
[![Telegram](https://img.shields.io/badge/Telegram-ILLnar-blue?logo=telegram)](https://t.me/ILLnar)
[![GitHub](https://img.shields.io/badge/GitHub-illnar--io-181717?logo=github)](https://github.com/illnar-io)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-illnar-0077B5?logo=linkedin)](https://linkedin.com/in/illnar)
[![Email](https://img.shields.io/badge/Email-nizametdinov%40gmail.com-D14836?logo=gmail)](mailto:nizametdinov@gmail.com)

</div>

---

## 💝 Donations

Any and all donations are appreciated — they keep DUSK Kernel maintained and updated!

- ⭐ **GitHub Sponsors**: <https://github.com/sponsors/illnar-io>
- **PayPal**: [nizametdinov@gmail.com](mailto:nizametdinov@gmail.com)
- **Ko-Fi**: <https://ko-fi.com/illnar>
- **Bunq**: <https://bunq.me/INizametdinov>
- **Revolut**: `@illnar_nizami`
