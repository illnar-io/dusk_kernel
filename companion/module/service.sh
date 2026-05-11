#!/system/bin/sh

MODDIR=${0%/*}

exec > "$MODDIR/dusk_companion.log" 2>&1

log() {
  echo "[dusk] $(date '+%H:%M:%S') $*"
}

log "=== DUSK Companion starting ==="

# ---- CPU schedutil governor & rate limits ----
for cpu in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$cpu" ] || continue
  gov=$(cat "$cpu/scaling_governor" 2>/dev/null)
  if [ "$gov" != "schedutil" ]; then
    echo schedutil > "$cpu/scaling_governor" 2>/dev/null && \
      log "Set ${cpu##*/} governor to schedutil"
  fi
done

for path in /sys/devices/system/cpu/cpufreq/schedutil; do
  [ -f "$path/up_rate_limit_us" ] && echo 500 > "$path/up_rate_limit_us" 2>/dev/null && \
    log "schedutil up_rate_limit_us = 500"
  [ -f "$path/down_rate_limit_us" ] && echo 20000 > "$path/down_rate_limit_us" 2>/dev/null && \
    log "schedutil down_rate_limit_us = 20000"
  [ -f "$path/iowait_boost_enable" ] && echo 0 > "$path/iowait_boost_enable" 2>/dev/null && \
    log "schedutil iowait_boost disabled"
done

# ---- GPU governor & max freq ----
mali_devfreq="/sys/class/misc/mali0/device/devfreq"
if [ -d "$mali_devfreq" ]; then
  echo performance > "$mali_devfreq/governor" 2>/dev/null && \
    log "GPU governor = performance"
  max_freq=$(cat "$mali_devfreq/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)
  if [ -n "$max_freq" ]; then
    echo "$max_freq" > "$mali_devfreq/max_freq" 2>/dev/null && \
      log "GPU max freq = $max_freq"
  fi
fi

for d in /sys/class/devfreq/*; do
  [ -d "$d" ] || continue
  name=$(cat "$d/name" 2>/dev/null)
  case "$name" in
    *mali*|*gpu*)
      echo performance > "$d/governor" 2>/dev/null
      max=$(cat "$d/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)
      [ -n "$max" ] && echo "$max" > "$d/max_freq" 2>/dev/null
      log "GPU ($name): performance governor, max=$max"
      ;;
  esac
done

# ---- Thermal policy ----
for tz in /sys/class/thermal/thermal_zone*; do
  [ -d "$tz" ] || continue
  type=$(cat "$tz/type" 2>/dev/null)
  if [ -f "$tz/policy" ]; then
    current=$(cat "$tz/policy")
    case "$current" in
      *governor*|*step*|*power*)
        echo step_wise > "$tz/policy" 2>/dev/null
        log "Thermal zone $type: step_wise"
        ;;
    esac
  fi
done

for trip in /sys/class/thermal/thermal_message/trip_point_*_temp; do
  [ -f "$trip" ] && echo 65000 > "$trip" 2>/dev/null && \
    log "${trip##*/} = 65°C"
done

# ---- ZRAM recompression ----
zram="/sys/block/zram0"
if [ -d "$zram" ]; then
  [ -f "$zram/recompress" ] && echo idle > "$zram/recompress" 2>/dev/null && \
    log "ZRAM recompress = idle"
  [ -f "$zram/comp_algorithm" ] && echo zstd > "$zram/comp_algorithm" 2>/dev/null && \
    log "ZRAM comp_algorithm = zstd"
fi

log "=== DUSK Companion done ==="

# ---- Build status description for module.prop ----
MODULE_PROP="/data/adb/modules/dusk_companion/module.prop"

ksu()      { [ -e /proc/manager ] && echo "yes" || echo "no"; }
susfs()    { [ -e /proc/fs/susfs ] && echo "yes" || echo "no"; }
ntsync()   { lsmod 2>/dev/null | grep -q ntsync && echo "yes" || echo "no"; }
sched()    { [ "$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)" = "schedutil" ] && echo "yes" || echo "no"; }
gpu_gov()  { g=$(cat /sys/class/devfreq/*/governor 2>/dev/null | head -1); [ "$g" = "performance" ] && echo "yes" || echo "no"; }
zram()     { cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -q zstd && echo "yes" || echo "no"; }

DESC="KSU:$(ksu) SUSFS:$(susfs) NTSYNC:$(ntsync) CPU:$(sched) GPU:$(gpu_gov) ZRAM:$(zram)"

if [ -f "$MODULE_PROP" ]; then
  sed -i "s/^description=.*/description=$DESC/" "$MODULE_PROP"
fi
