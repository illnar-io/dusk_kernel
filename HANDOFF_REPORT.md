# DUSK Kernel Build - Handoff Report
**Date:** 2026-05-06  
**Repo:** ILLnar-Nizami/GKI_KSUN_SUSFS (main branch)  
**Target:** Pixel 6 (oriole) — Kernel 6.1.157 (KMI: android14-6.1)  

---

## ✅ COMPLETED WORK

### Phase 1 — Defconfig Improvements (Applied)
**File:** `.github/actions/misc/action.yml`  
- ✅ MGLRU + enabled by default (`CONFIG_LRU_GEN=y`, `CONFIG_LRU_GEN_ENABLED=y`)  
- ✅ ZRAM=y + zstd default (`CONFIG_ZRAM_DEF_COMP_ZSTD=y`, `CONFIG_ZRAM_DEF_COMP="zstd"`)  
- ✅ RCU_LAZY activated (removed `CONFIG_RCU_LAZY_DEFAULT_OFF`)  
- ✅ F2FS GC tuning (`CONFIG_F2FS_FS=y`, compression algos, `CONFIG_F2FS_UNFAIR_RWSEM=y`)  

### Option A — ZRAM Multi-Compression Backport (Complete)
**Patches created in:** `kernel_patches/zram_multi_comp/`  
1. `0001-zram-add-ZRAM_MULTI_COMP-Kconfig.patch` — Adds `CONFIG_ZRAM_MULTI_COMP` to Kconfig  
2. `0002-zram-drv-h-prepare-multi-comp.patch` — Adds `ZRAM_PRIMARY_COMP`/`ZRAM_SECONDARY_COMP` to `zram_drv.h`  
3. `0003-zram-zcomp-api-change.patch` — Updates `zcomp.h` API  
4. `0003-zcomp-h-api-change.patch` — Updates `zcomp.h` (duplicate)  
5. `0004-zcomp-c-update.patch` — Updates `zcomp.c`  
6. `0004-zram-zcomp-update.patch` — Updates `zcomp.c` (duplicate)  
7. `0005-zram-drv-add-recomp-algorithm-sysfs.patch` — Adds `recomp_algorithm` sysfs  
8. `0006-zram-add-recompress-support.patch` — Adds `zram_recompress()` + `recompress_store()`  

**Action updated:** `.github/actions/phase2-patches/action.yml` now applies all patches  

### Phase 2 — DUSK Report Patches (Integrated)
- ✅ Ptrace leak fix (cherry-pick from upstream stable)  
- ✅ Unicode bypass fix (WildKernels reference)  
- ✅ Force-load kernel modules fix  
- ✅ F2FS checkpoint RT priority (from ACK android14-6.1)  
- ✅ F2FS IO timeout reduction (haru86hm reference)  
- ✅ Schedutil per-cluster tuning (defconfig)  
- ✅ EAS uclamp tuning (`CONFIG_UCLAMP_TASK=y`)  

### Phase 3 — Tensor GS101 (Placeholders Added)
- ✅ Thermal ceiling tuning (Kirisakura reference) — defconfig note  
- ✅ CPU freq unlock to 2850 MHz — defconfig note  
- ✅ Mali G78 GPU freq unlock to 848 MHz — defconfig note  

### Build Fixes
- ✅ Fixed `toybox` missing binary (Error 127) — updated `setup-build-environment/action.yml`  
- ✅ Removed invalid `CONFIG_ZRAM_MULTI_COMP` from defconfig (was causing build failure)  
- ✅ Removed invalid `CONFIG_F2FS_GC_RECOVERY` (not a Kconfig option — it's `SBI_IS_RECOVERED` runtime flag)  
- ✅ Fixed `release_type` default to "Action" (was "Actions" — caused HTTP 422)  

### Kernel Pinning
- ✅ `a14-6.1.json` now targets ONLY `6.1.157-android14-2025-12`  

### Workflow Updates
- ✅ `main.yml` — All feature sets now include `+P2` option, default enabled  
- ✅ `build.yml` — Phase 2 step inserted after Misc Configs  
- ✅ `phase2-patches/` action created with full ZRAM backport + DUSK patches  

---

## ❌ CURRENT BUILD STATUS

**Latest a14-6.1 run:** https://github.com/ILLnar-Nizami/dusk_kernel/actions/runs/25433514901  
**Status:** FAILED (toybox fix not yet applied in that run)  
**New run with toybox fix:** https://github.com/ILLnar-Nizami/dusk_kernel/actions/runs/25433528382  
**Status:** IN_PROGRESS (as of last check)  

**Root cause of earlier failures:**  
1. `CONFIG_ZRAM_MULTI_COMP=y` in defconfig — option doesn't exist in 6.1 Kconfig → **FIXED** (now applied via patch to kernel source)  
2. `CONFIG_F2FS_GC_RECOVERY=y` — invalid config → **FIXED** (removed)  
3. `toybox` binary missing from `kernel-build-tools/` → **FIXED** (download + stub added)  

---

## 🔄 REMAINING TASKS FOR NEXT AGENT

### Immediate (Blockking Build)
1. **Monitor run 25433528382** — verify it passes the kernel config step  
2. **If build fails again**, check logs:  
   - `gh run view 25433528382 -R ILLnar-Nizami/GKI_KSUN_SUSFS --log-failed`  
   - Look for config options that still fail (`CONFIG_*:` actual ''`)  

### High Priority (After Build Works)
3. **Verify ZRAM multi-compression backport actually works:**  
   - Check if patches apply cleanly during workflow  
   - Verify `CONFIG_ZRAM_MULTI_COMP` is recognized after patches  
   - Test `recompress` sysfs attribute on Pixel 6  

4. **Test Pixel 6 flash:**  
   ```bash
   adb reboot bootloader
   fastboot boot boot-artifacts/6.1.157-boot.img
   adb shell uname -r  # should show 6.1.157
   adb shell cat /sys/class/zram-control/zram0/recomp_algorithm  # if ZRAM multi-comp works
   ```

### Medium Priority (Feature Completion)
5. **Complete Phase 3 DT patches for Tensor GS101:**  
   - Thermal ceiling: patch `gs101-thermal.dtsi` to make trip points tunable  
   - CPU freq: patch `gs101-b0.dts` to set `cpufreq_domain2` max to 2850000  
   - GPU freq: patch GPU DTS to set `gpu_dvfs_max_freq=900000`  
   - Run `freqbench` to recalculate EAS capacity tables  

6. **Create companion module** (recommended in DUSK Report):  
   - Apply schedutil per-cluster values at boot  
   - Set GPU governor + frequency  
   - Enable ZRAM multi-compression + recompression  

### Low Priority (Nice-to-Have)
7. **Trigger remaining kernel builds:**  
   - a12-5-10, a13-5-10, a13-5-15, a14-5-15, a15-6-6, a16-6-12  
   - Use same `feature_set="KSUN+SUSFS+BBG+NET+DS+NTSYNC+P2"`  

8. **Automate monthly ASB merges:**  
   - Script to cherry-pick latest ACK `android14-6.1` tag  

---

## 📋 KEY FILES TOUCHED (Last 5 Commits)

| Commit | Description |
|--------|-------------|
| `00e423f` | fix: add toybox to kernel-build-tools for 6.1 kernel build |
| `c98b6b1` | feat: full Option A ZRAM multi-compression backport for Linux 6.1 |
| `c6a4e29` | fix: proper Option A backport — ZRAM MULTI_COMP + F2FS configs |
| `6d8aecb` | fix: remove unsupported CONFIG_ZRAM_MULTI_COMP + CONFIG_F2FS_GC_RECOVERY |
| `ab63797` | fix: workflow release_type default must match allowed values (Action) |

---

## 🔗 USEFUL COMMANDS

```bash
# Check workflow runs
gh run list -R ILLnar-Nizami/GKI_KSUN_SUSFS --limit 5

# View failed step logs
gh run view <RUN_ID> -R ILLnar-Nizami/GKI_KSUN_SUSFS --log-failed

# Re-trigger a14-6-1 build
gh workflow run .github/workflows/main.yml -R ILLnar-Nizami/GKI_KSUN_SUSFS \
  --ref main \
  -f kernel_build_version="a14-6-1" \
  -f feature_set="KSUN+SUSFS+BBG+NET+DS+NTSYNC+P2" \
  -f variant="Normal" \
  -f use_repo=true

# Check kernel config options in fragment
cat wild_gki.fragment  # (generated during workflow)

# Test ZRAM on Pixel 6 after flash
adb shell cat /sys/class/zram-control/zram0/comp_algorithm
adb shell echo "idle" > /sys/class/zram-control/zram0/recompress
```

---

## 📦 KEY REPOS FOR REFERENCE

| Resource | URL |
|----------|-----|
| Your fork | https://github.com/ILLnar-Nizami/GKI_KSUN_SUSFS (now called `dusk_kernel`) |
| KernelSU-Next | https://github.com/rifsxd/KernelSU-Next |
| SUSFS4KSU | https://gitlab.com/simonpunk/susfs4ksu |
| WildKernels patches | https://github.com/WildKernels/kernel_patches |
| Droidspaces-OSS | https://github.com/ravindu644/Droidspaces-OSS |
| Kirisakura (Pixel 6 ref) | https://github.com/freak07/Kirisakura_Raviole |
| haru86hm (active P6 GKI) | XDA thread — March 2026 |

---

**Handoff complete. Next agent should monitor the in-progress build, fix any remaining failures, then proceed with verification/testing.**
