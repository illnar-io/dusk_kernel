#!/system/bin/sh

SKIPUNZIP=0

ui_print ""
ui_print ".     *       .       ."
ui_print "*       .        .   🌕    ."
ui_print "    .        .        ."
ui_print "         |               |"
ui_print "      _\` |  |   |   __|  |  /"
ui_print "     (   |  |   | \\__ \\    <"
ui_print "    \\__,_| \\__,_| ____/ _|\\_\\"
ui_print "     .     *       .       ."
ui_print "*       .        .      ."
ui_print "    .        .        ."
ui_print ""
ui_print "=============================="
ui_print "  DUSK Companion v2.1"
ui_print "=============================="
ui_print ""

if [ "$BOOTMODE" ] && [ "$KSU" ]; then
  ui_print "- Installing from KernelSU Manager"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
  ui_print "- Installing from Magisk Manager"
else
  ui_print "- Installing from recovery"
fi

# Extract all files
unzip -o "$ZIPFILE" module.prop -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" config.conf -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" service.sh -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" action.sh -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >/dev/null 2>&1

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644

ui_print "- Companion settings: /data/adb/modules/dusk_companion/config.conf"
ui_print "- Reboot or run: su -c /data/adb/modules/dusk_companion/service.sh"
