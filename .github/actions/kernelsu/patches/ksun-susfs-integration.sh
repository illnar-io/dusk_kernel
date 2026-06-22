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
#   1. Removes `static` from 6 variables in selinux_hide.c + adds EXPORT_SYMBOL
#   2. Changes `bool ksu_su_compat_enabled` → DEFINE_STATIC_KEY_TRUE in sucompat.c
#      and updates su_compat_feature_get/set to use static_branch_* calls
#   3. Updates sucompat.h extern to match
#   4. Copies susfs_integration.c into the KSUN tree (provides SID symbols +
#      hook stubs + su redirects)
#   5. Adds susfs_integration.o to Kbuild under CONFIG_KSU_SUSFS guard
#   6. Updates syscall_event_bridge.c to use static_branch_unlikely for the
#      now-static-key ksu_su_compat_enabled
# =============================================================================

set -euo pipefail

KSUN_DIR="$1"  # e.g. kernel/KernelSU-Next/kernel

if [ ! -d "$KSUN_DIR" ]; then
  echo "::error::KSUN directory not found: $KSUN_DIR"
  exit 1
fi

echo "=== KSUN SUSFS Integration for 0608dfd7 ==="

SELINUX_HIDE="$KSUN_DIR/feature/selinux_hide.c"
SUCOMPAT_C="$KSUN_DIR/feature/sucompat.c"
SUCOMPAT_H="$KSUN_DIR/feature/sucompat.h"
KBUILD="$KSUN_DIR/Kbuild"
INTEGRATION_SRC="$(dirname "$0")/susfs_integration.c"
INTEGRATION_DST="$KSUN_DIR/susfs_integration.c"

# ---------------------------------------------------------------
# Step 1: selinux_hide.c - remove static from 6 vars, add EXPORT_SYMBOL
# ---------------------------------------------------------------
echo "[1/6] Patching selinux_hide.c — static → non-static + EXPORT_SYMBOL"

# Remove `static` from all definitions that SUSFS 50_add references.
# Use sed (function-name based) to stay resilient against KSUN version changes.
for sym in ksu_selinux_hide_enabled ksu_selinux_hide_running fake_status fake_status_initialize_key initialize_fake_status fake_state; do
  sed -i "/^static.*${sym}/s/^static //" "$SELINUX_HIDE"
done

# Add EXPORT_SYMBOL after each definition (skip if already present).
# Use unique line-matching patterns to avoid false matches.
for pair in \
  'ksu_selinux_hide_enabled __read_mostly:ksu_selinux_hide_enabled' \
  'ksu_selinux_hide_running __read_mostly:ksu_selinux_hide_running' \
  'struct page \*fake_status:fake_status'; do
  pattern="${pair%%:*}"
  sym="${pair#*:}"
  grep -q "EXPORT_SYMBOL(${sym})" "$SELINUX_HIDE" 2>/dev/null && continue
  sed -i "/${pattern}/a\\EXPORT_SYMBOL(${sym});" "$SELINUX_HIDE"
done

# fake_status_initialize_key — macro-based, add after the DEFINE line
grep -q "EXPORT_SYMBOL(fake_status_initialize_key)" "$SELINUX_HIDE" 2>/dev/null ||
  sed -i '/DEFINE_STATIC_KEY_FALSE(fake_status_initialize_key)/a\EXPORT_SYMBOL(fake_status_initialize_key);' "$SELINUX_HIDE"

# initialize_fake_status — is a function definition, not a variable.
# EXPORT_SYMBOL must go after the function body; append to EOF.
grep -q "EXPORT_SYMBOL(initialize_fake_status)" "$SELINUX_HIDE" 2>/dev/null ||
  echo "EXPORT_SYMBOL(initialize_fake_status);" >> "$SELINUX_HIDE"

# fake_state — guarded by #if < 6.6, may not exist on >= 6.6
if grep -q "struct selinux_state fake_state;" "$SELINUX_HIDE" 2>/dev/null; then
  grep -q "EXPORT_SYMBOL(fake_state)" "$SELINUX_HIDE" 2>/dev/null ||
    sed -i '/^struct selinux_state fake_state;$/a\EXPORT_SYMBOL(fake_state);' "$SELINUX_HIDE"
fi

echo "  ✓ selinux_hide.c patched"

# ---------------------------------------------------------------
# Step 2: sucompat.c — bool → DEFINE_STATIC_KEY_TRUE
# ---------------------------------------------------------------
echo "[2/6] Patching sucompat.c — bool → static_key_true"
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
# Step 3: sucompat.h — update extern declaration
# ---------------------------------------------------------------
echo "[3/6] Patching sucompat.h — updating extern"
if grep -q "^extern bool ksu_su_compat_enabled;" "$SUCOMPAT_H" 2>/dev/null; then
  sed -i 's/^extern bool ksu_su_compat_enabled;/extern struct static_key_true ksu_su_compat_enabled;/' "$SUCOMPAT_H"
  echo "  ✓ sucompat.h updated"
else
  echo "  ✓ already updated or not found, skipping"
fi

# ---------------------------------------------------------------
# Step 4: Copy susfs_integration.c into KSUN tree
# ---------------------------------------------------------------
echo "[4/6] Copying susfs_integration.c → $INTEGRATION_DST"
if [ -f "$INTEGRATION_SRC" ]; then
  cp "$INTEGRATION_SRC" "$INTEGRATION_DST"
  echo "  ✓ susfs_integration.c copied"
else
  echo "::error::susfs_integration.c not found at $INTEGRATION_SRC"
  exit 1
fi

# ---------------------------------------------------------------
# Step 5: Kbuild — add susfs_integration.o under CONFIG_KSU_SUSFS
# ---------------------------------------------------------------
echo "[5/6] Patching Kbuild — adding susfs_integration.o"
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
# Step 6: syscall_event_bridge.c — use static_branch_unlikely
# ---------------------------------------------------------------
echo "[6/6] Patching syscall_event_bridge.c — use static_branch_unlikely"
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
echo "  $SELINUX_HIDE"
echo "  $SUCOMPAT_C"
echo "  $SUCOMPAT_H"
echo "  $KBUILD"
echo "  ${SYSCALL_BRIDGE:-(none)}"
echo "Created:"
echo "  $INTEGRATION_DST"
