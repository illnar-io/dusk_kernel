#!/system/bin/sh

# DUSK Companion — Magisk/KernelSU module install

SKIPUNZIP=0

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "- Installing from KernelSU Manager"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
  ui_print "- Installing from Magisk Manager"
else
  ui_print "- Installing from recovery"
fi

# Extract and place all files
unzip -o "$ZIPFILE" module.prop -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" service.sh -d "$MODPATH" >/dev/null 2>&1

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755

ui_print "- DUSK Companion installed"
