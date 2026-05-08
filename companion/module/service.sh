#!/system/bin/sh

MODDIR=${0%/*}

# ============================================
# DUSK Kernel Companion - Boot-time tunings
# ============================================

exec 2>"$MODDIR/dusk_companion.log"

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

# schedutil rate limits
for path in /sys/devices/system/cpu/cpufreq/schedutil; do
  [ -f "$path/up_rate_limit_us" ] && echo 500 > "$path/up_rate_limit_us" 2>/dev/null && \
    log "schedutil up_rate_limit_us = 500"
  [ -f "$path/down_rate_limit_us" ] && echo 20000 > "$path/down_rate_limit_us" 2>/dev/null && \
    log "schedutil down_rate_limit_us = 20000"
  [ -f "$path/iowait_boost_enable" ] && echo 0 > "$path/iowait_boost_enable" 2>/dev/null && \
    log "schedutil iowait_boost disabled"
done

# ---- GPU governor & max freq (Mali G78) ----
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

# fallback: find any devfreq device matching gpu/mali
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
  # Set all thermal zones to 'step_wise' or 'user_space' for reduced throttling
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

# Raise trip point temperatures where writable
for trip in /sys/class/thermal/thermal_message/trip_point_*_temp; do
  [ -f "$trip" ] && echo 65000 > "$trip" 2>/dev/null && \
    log "${trip##*/} = 65°C"
done

# ---- ZRAM recompression (multi-comp supported on 6.1.157+) ----
zram="/sys/block/zram0"
if [ -d "$zram" ]; then
  # Enable recompression if supported
  [ -f "$zram/recompress" ] && echo idle > "$zram/recompress" 2>/dev/null && \
    log "ZRAM recompress = idle"
  # Set algo to zstd (highest ratio)
  [ -f "$zram/comp_algorithm" ] && echo zstd > "$zram/comp_algorithm" 2>/dev/null && \
    log "ZRAM comp_algorithm = zstd"
fi

log "=== DUSK Companion done ==="
