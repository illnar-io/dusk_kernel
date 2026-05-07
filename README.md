<div align="center">

# 🌑 DUSK Kernel

**Shhhh... No one knows**

[![KernelSU-Next](https://img.shields.io/badge/KernelSU--Next-Supported-green)](https://github.com/KernelSU-Next/KernelSU-Next)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-orange)](https://gitlab.com/simonpunk/susfs4ksu)
[![ntsync](https://img.shields.io/badge/ntsync-Backported-blue)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git)

</div>

## ⚠️ Your warranty is no longer valid!

I am **not responsible** for bricked devices, damaged hardware, or any issues that arise from using this kernel.

**Please** do thorough research and fully understand the features included in this kernel before flashing it!

By flashing this kernel, **YOU** are choosing to make these modifications. If something goes wrong, **do not blame me**!

---

### 🚨 Proceed at your own risk!

---

## 🔧 Available Kernels

| Kernel | Repository | Status |
|--------|------------|--------|
| 🌑 **DUSK** | [dusk_kernel](https://github.com/ILLnar-Nizami/dusk_kernel) | ✅ Active |

---

## 📋 DUSK Glossary

**DUSK** = **D**roidspaces + s**U**sfs + nt**S**ync + **K**ernel

| Component | Description |
|-----------|-------------|
| **Droidspaces** | Container/namespace support for running Android apps in isolated environments |
| **sUsfs (SUSFS)** | Stealth layer for root hiding and userspace filesystem masking (v2.1.0 (inline hooks)) |
| **ntSync** | Windows NT sync primitives backport for Wine/Proton on Android |
| **Kernel** | Android GKI 6.1 kernel with KernelSU-Next integration |

---

## 🔗 Additional Resources

- 🩹 [Kernel Patches](https://github.com/WildKernels/kernel_patches)
- ⚡ [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher)

---

## 📋 Installation Instructions

For GKI installation, please follow the official guide:

📖 **[KernelSU Installation Guide](https://kernelsu.org/guide/installation.html)**

---

## ✨ Features

- 🔐 **KernelSU-Next**: Kernel-mode root solution for Android GKI devices
- 🌑 **Droidspaces**: Container/namespace isolation for Android app sandboxing
- 🛡️ **SUSFS v2.1.0 (inline hooks)**: Stealth addon for root hiding and userspace masking
- ⚡ **ntSync**: Backported NT synchronization primitives for Wine/Proton performance
- 🚀 **Networking**: BBR TCP congestion control, TTL/HL masking, expanded USB-Ethernet drivers
- 💾 **Memory**: MGLRU tuning for mobile workloads
- 🛡️ **Baseband Guard (BBG)**: Baseband isolation support

---

## 🏆 Credits

 - 🔐 **KernelSU-Next**: Developed by [rifsxd](https://github.com/KernelSU-Next/KernelSU-Next)
 - 🛡️ **SUSFS**: Developed by [simonpunk](https://gitlab.com/simonpunk/susfs4ksu.git)
 - 🚀 **ntSync backport**: Source from [kernel.org v6.14](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git)
 - 🛡️ **Baseband-guard (BBG)**: Developed by [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard)
 - 📦 **SUSFS Module**: Developed by [sidex15](https://github.com/sidex15)
 - 🌑 **Droidspaces-OSS**: Developed by [ravindu644](https://github.com/ravindu644/Droidspaces-OSS)
 - 🌑 **WildKernels**: Kernel patches & CI templates by [TheWildJames](https://github.com/WildKernels)

🙏 Special thanks to the open-source community for their contributions!

## 🌟 Special Thanks

**These amazing people help make DUSK Kernel possible! ❤️**

| Contributor | Contribution |
|-------------|-------------|
| 🌑 **WildKernels (TheWildJames)** | Upstream base — [GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) |
| 📦 **AnyKernel3** (WildKernels) | AnyKernel3 gki-2.0 branch — [repo](https://github.com/WildKernels/AnyKernel3) |

---

## 💝 Donations

Any and all donations are appreciated — they keep DUSK Kernel maintained and updated!

- **PayPal**: [nizametdinov@gmail.com](mailto:nizametdinov@gmail.com)
- **Ko-Fi**: <https://ko-fi.com/illnar>
- **Bunq**: <https://bunq.me/INizametdinov>
- **Revolut**: `@illnar_nizami`

</div>
