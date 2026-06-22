#!/bin/bash
# =============================================================================
# KSUN SUSFS Integration (originally for 0608dfd7, now pinned to 30802e7260e2)
#
# Provides all symbols that SUSFS (via the 50_add patch) expects from KSUN
# when CONFIG_KSU_SUSFS=y.  The 50_add patch writes hook calls into VFS
# files (fs/open.c, fs/exec.c, fs/stat.c, ...) that reference extern
# symbols from the KSUN kernel module.  KSUN commit 0608dfd7 does not
# define these symbols, causing MODPOST/linker errors.
#
# What this script does:
#   1. Changes `bool ksu_su_compat_enabled` → DEFINE_STATIC_KEY_TRUE in sucompat.c
#      and updates su_compat_feature_get/set to use static_branch_* calls
#   2. Updates sucompat.h extern to match
#   3. Copies susfs_integration.c into the KSUN tree (provides selinux SID/hide
#      symbols + hook stubs + su redirects)
#   4. Adds susfs_integration.o to Kbuild under CONFIG_KSU_SUSFS guard
#   5. Updates syscall_event_bridge.c to use static_branch_unlikely for the
#      now-static-key ksu_su_compat_enabled
# =============================================================================

set -euo pipefail

KSUN_DIR="$1"  # e.g. kernel/KernelSU-Next/kernel

if [ ! -d "$KSUN_DIR" ]; then
  echo "::error::KSUN directory not found: $KSUN_DIR"
  exit 1
fi

echo "=== KSUN SUSFS Integration for 0608dfd7 ==="

SUCOMPAT_C="$KSUN_DIR/feature/sucompat.c"
SUCOMPAT_H="$KSUN_DIR/feature/sucompat.h"
KBUILD="$KSUN_DIR/Kbuild"
INTEGRATION_SRC="$(dirname "$0")/susfs_integration.c"
INTEGRATION_DST="$KSUN_DIR/susfs_integration.c"

# ---------------------------------------------------------------
# Step 1: sucompat.c — bool → DEFINE_STATIC_KEY_TRUE
# ---------------------------------------------------------------
echo "[1/5] Patching sucompat.c — bool → static_key_true"
if grep -q "^bool ksu_su_compat_enabled" "$SUCOMPAT_C" 2>/dev/null; then
  perl -i -0777 -pe '
    # 3a. Definition: bool → DEFINE_STATIC_KEY_TRUE + EXPORT_SYMBOL
    s/^bool ksu_su_compat_enabled __read_mostly = (?:true|false);/DEFINE_STATIC_KEY_TRUE(ksu_su_compat_enabled);\nEXPORT_SYMBOL(ksu_su_compat_enabled);/gm;

    # 3b. su_compat_feature_get: bool ternary → static_branch_unlikely
    s/\*value = ksu_su_compat_enabled \? 1 : 0;/*value = static_branch_unlikely(\&ksu_su_compat_enabled) ? 1 : 0;/g;

    # 3c. su_compat_feature_set: bool assignment → static_branch_enable/disable
    s/bool enable = value != 0;\n\tksu_su_compat_enabled = enable;\n\tpr_info\("su_compat: set to %d\\n", enable\);/if (value)\n\t\tstatic_branch_enable(\&ksu_su_compat_enabled);\n\telse\n\t\tstatic_branch_disable(\&ksu_su_compat_enabled);\n\tpr_info("su_compat: set to %llu\\n", value);/g;
  ' "$SUCOMPAT_C"
  echo "  ✓ ksu_su_compat_enabled changed to static_key_true"
  echo "  ✓ su_compat_feature_get/set uses updated"
else
  echo "  ✓ pattern not found (may already be changed), checking..."
  if grep -q "DEFINE_STATIC_KEY_TRUE.*ksu_su_compat_enabled" "$SUCOMPAT_C" 2>/dev/null; then
    echo "  ✓ already DEFINE_STATIC_KEY_TRUE"
    # Ensure EXPORT_SYMBOL is present
    if ! grep -q "EXPORT_SYMBOL(ksu_su_compat_enabled)" "$SUCOMPAT_C" 2>/dev/null; then
      perl -i -0777 -pe '
        s/(DEFINE_STATIC_KEY_TRUE\(ksu_su_compat_enabled\);\n)/${1}EXPORT_SYMBOL(ksu_su_compat_enabled);\n/gm;
      ' "$SUCOMPAT_C"
      echo "  ✓ added missing EXPORT_SYMBOL"
    fi
    # Still verify the uses are updated
    if grep -q "ksu_su_compat_enabled ? 1 : 0" "$SUCOMPAT_C" 2>/dev/null; then
      perl -i -0777 -pe '
        s/\*value = ksu_su_compat_enabled \? 1 : 0;/*value = static_branch_unlikely(\&ksu_su_compat_enabled) ? 1 : 0;/g;
        s/bool enable = value != 0;\n\tksu_su_compat_enabled = enable;\n\tpr_info\("su_compat: set to %d\\n", enable\);/if (value)\n\t\tstatic_branch_enable(\&ksu_su_compat_enabled);\n\telse\n\t\tstatic_branch_disable(\&ksu_su_compat_enabled);\n\tpr_info("su_compat: set to %llu\\n", value);/g;
      ' "$SUCOMPAT_C"
      echo "  ✓ su_compat_feature_get/set uses updated"
    fi
  fi
fi

# ---------------------------------------------------------------
# Step 2: sucompat.h — update extern declaration
# ---------------------------------------------------------------
echo "[2/5] Patching sucompat.h — updating extern"
if grep -q "^extern bool ksu_su_compat_enabled;" "$SUCOMPAT_H" 2>/dev/null; then
  sed -i 's/^extern bool ksu_su_compat_enabled;/extern struct static_key_true ksu_su_compat_enabled;/' "$SUCOMPAT_H"
  echo "  ✓ sucompat.h updated"
else
  echo "  ✓ already updated or not found, skipping"
fi

# ---------------------------------------------------------------
# Step 3: Copy susfs_integration.c into KSUN tree
# ---------------------------------------------------------------
echo "[3/5] Copying susfs_integration.c → $INTEGRATION_DST"
if [ -f "$INTEGRATION_SRC" ]; then
  cp "$INTEGRATION_SRC" "$INTEGRATION_DST"
  echo "  ✓ susfs_integration.c copied"
else
  echo "::error::susfs_integration.c not found at $INTEGRATION_SRC"
  exit 1
fi

# ---------------------------------------------------------------
# Step 4: Kbuild — add susfs_integration.o under CONFIG_KSU_SUSFS
# ---------------------------------------------------------------
echo "[4/5] Patching Kbuild — adding susfs_integration.o"
if grep -q "susfs_integration" "$KBUILD" 2>/dev/null; then
  echo "  ✓ already present, skipping"
else
  # Add after the last kernelsu-objs entry, guarded by CONFIG_KSU_SUSFS
  perl -i -0777 -pe '
    # Find the end of the kernelsu-objs assignment and append guarded obj
    if (s/(kernelsu-objs \+= .*\n)(.*?)(?=\n\S|\z)/$1$2\nifneq (\$(CONFIG_KSU_SUSFS),)\nkernelsu-objs += susfs_integration.o\nendif\n/s) {
      # success
    } else {
      # Fallback: append at end of file
      s/\z/\nifneq (\$(CONFIG_KSU_SUSFS),)\nkernelsu-objs += susfs_integration.o\nendif\n/;
    }
  ' "$KBUILD"
  echo "  ✓ Kbuild updated"
fi

# ---------------------------------------------------------------
# Step 5: syscall_event_bridge.c — use static_branch_unlikely
# ---------------------------------------------------------------
echo "[5/5] Patching syscall_event_bridge.c — use static_branch_unlikely"
SYSCALL_BRIDGE="$KSUN_DIR/hook/syscall_event_bridge.c"
if grep -q "!ksu_su_compat_enabled" "$SYSCALL_BRIDGE" 2>/dev/null; then
  perl -i -0777 -pe '
    s/if \(!ksu_su_compat_enabled\)/if (!static_branch_unlikely(\&ksu_su_compat_enabled))/g;
    s/\} else if \(ksu_su_compat_enabled\)/\} else if (static_branch_unlikely(\&ksu_su_compat_enabled))/g;
  ' "$SYSCALL_BRIDGE"
  echo "  ✓ syscall_event_bridge.c patched"
else
  echo "  ✓ already patched or not found, skipping"
fi

echo ""
echo "=== KSUN SUSFS Integration complete ==="
echo "Patched files:"
echo "  $SUCOMPAT_C"
echo "  $SUCOMPAT_H"
echo "  $KBUILD"
echo "  ${SYSCALL_BRIDGE:-(none)}"
echo "Created:"
echo "  $INTEGRATION_DST"
