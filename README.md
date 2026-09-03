# DUSK Kernel

Custom OnePlus kernel with KernelSU-Next, SUSFS, BBG, and optimization patches.
Forked from [freeza-inc/OnePlus-Remote-Action-Build](https://github.com/freeza-inc/OnePlus-Remote-Action-Build).

## How to Build

1. Fork this repo
2. Edit `configs/oos16/OP15.json` for your device
3. Go to Actions → "Build OnePlus Kernel" → Run workflow

## Build Options

- **op_model**: Select your device (e.g. `OP15_oos16`)
- **ksu_options**: KernelSU build JSON (default: `[{"type":"ksun","hash":"dev"}]`)
- **optimize_level**: Compiler optimization (`O2` recommended)
- **clean_build**: Clean build without ccache

## Supported Devices

| Device | OOS16 |
| :--- | :---: |
| OP15 | ✅ |
| OP15T | ✅ |
| OP15r | ✅ |
| OP13 | ✅ |
| OP13r | ✅ |
| OP13S | ✅ |
| OP13T | ✅ |
| OP12 | ✅ |
| OP12r | ✅ |
| OP11 | ✅ |
| OP11r | ✅ |

## Features

- KernelSU-Next / WildKSU Manager
- SUSFS root hiding
- BBG (Baseband Guard) with EFISP/ABL support
- ThinLTO
- Droidspaces
- BBR/BBRv3 TCP congestion
- NTSync
- TTL, IP Set, IPv6 NAT
- TMPFS XATTR / POSIX ACL
- Unicode Bypass Fix (Experimental)
- Optimization patches (memory, I/O, CPU, network)
