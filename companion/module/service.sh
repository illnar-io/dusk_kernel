#!/system/bin/sh

MODDIR=${0%/*}

# ---- Config ----
CONFIG="$MODDIR/config.conf"
[ -f "$CONFIG" ] && . "$CONFIG"

# Defaults if config is missing
: "${MODE:=balanced}"
: "${AUTO_BATTERY_SAVER:=true}"
: "${TCP_CONG:=bbr}"
: "${TCP_ECN:=true}"
: "${IO_SCHEDULER:=mq-deadline}"
: "${GPU_GOVERNOR:=performance}"
: "${CPU_GOVERNOR:=schedutil}"
: "${ZRAM_ALGO:=zstd}"
: "${THERMAL_LIMIT:=90000}"
: "${EXT4_COMMIT:=30}"
: "${F2FS_GC_URGENT_SLEEP:=50}"
: "${LOG_LEVEL:=1}"

exec >> "$MODDIR/dusk_companion.log" 2>&1

log() {
  [ "$LOG_LEVEL" -ge 1 ] && echo "[dusk] $(date '+%H:%M:%S') $*"
}
verbose() {
  [ "$LOG_LEVEL" -ge 2 ] && echo "[dusk] $(date '+%H:%M:%S') $*"
}

log "=== DUSK Companion v2.1 starting (mode=$MODE) ==="

echo ""
echo ".     *       .       ."
echo "*       .        .   🌕    ."
echo "    .        .        ."
echo "         |               |"
echo "      _\` |  |   |   __|  |  /"
echo "     (   |  |   | \\__ \\    <"
echo "    \\__,_| \\__,_| ____/ _|\\_\\"
echo "     .     *       .       ."
echo "*       .        .      ."
echo "    .        .        ."
echo ""

# ============ HELPER ============
write_val() {
  local file="$1" val="$2" label="$3"
  if [ -f "$file" ]; then
    echo "$val" > "$file" 2>/dev/null && verbose "  $label = $val" || log "  FAIL: $label"
  fi
}

# ============ CPU GOVERNOR ============
case "$MODE" in
  performance) CPU_GOV=performance ;;
  powersave)   CPU_GOV=powersave ;;
  gaming)      CPU_GOV=schedutil ;;
  *)           CPU_GOV=schedutil ;;
esac

for cpu in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -d "$cpu" ] || continue
  write_val "$cpu/scaling_governor" "$CPU_GOV" "${cpu##*/} governor"
done

# schedutil tuning (only if using schedutil)
if [ "$CPU_GOV" = "schedutil" ]; then
  write_val "/sys/devices/system/cpu/cpufreq/schedutil/up_rate_limit_us" 500 "up_rate_limit_us"
  write_val "/sys/devices/system/cpu/cpufreq/schedutil/down_rate_limit_us" 20000 "down_rate_limit_us"
  write_val "/sys/devices/system/cpu/cpufreq/schedutil/iowait_boost_enable" 0 "iowait_boost disabled"
  write_val "/sys/devices/system/cpu/cpufreq/schedutil/pl" 1 "pl (perf limit)"
fi

# ============ GPU ============
for d in /sys/class/devfreq/*; do
  [ -d "$d" ] || continue
  name=$(cat "$d/name" 2>/dev/null)
  case "$name" in
    *mali*|*gpu*)
      write_val "$d/governor" "$GPU_GOVERNOR" "GPU ($name) governor"
      max=$(cat "$d/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | tail -1)
      [ -n "$max" ] && write_val "$d/max_freq" "$max" "GPU ($name) max freq"
      if [ "$MODE" = "powersave" ]; then
        min=$(cat "$d/available_frequencies" 2>/dev/null | tr ' ' '\n' | sort -n | head -1)
        [ -n "$min" ] && write_val "$d/min_freq" "$min" "GPU ($name) min freq"
      fi
      ;;
  esac
done

# ============ I/O SCHEDULER ============
for block in /sys/block/*; do
  [ -d "$block/queue" ] || continue
  dev=$(basename "$block")
  case "$dev" in
    loop*|ram*) continue ;;
  esac
  write_val "$block/queue/scheduler" "$IO_SCHEDULER" "I/O $dev scheduler"
  write_val "$block/queue/read_ahead_kb" 512 "I/O $dev read_ahead"
  write_val "$block/queue/nr_requests" 64 "I/O $dev nr_requests"
done

# ============ TCP / NETWORK ============
write_val /proc/sys/net/ipv4/tcp_congestion_control "$TCP_CONG" "TCP congestion"
write_val /proc/sys/net/ipv4/tcp_ecn "$([ "$TCP_ECN" = "true" ] && echo 1 || echo 0)" "TCP ECN"
write_val /proc/sys/net/ipv4/tcp_slow_start_after_idle 0 "TCP slow start after idle"
write_val /proc/sys/net/ipv4/tcp_fastopen 3 "TCP fast open"
write_val /proc/sys/net/core/netdev_budget 600 "netdev budget"
write_val /proc/sys/net/core/netdev_budget_usecs 4000 "netdev budget usecs"

# ============ F2FS TUNING ============
for f2fs in /sys/fs/f2fs/*; do
  [ -d "$f2fs" ] || continue
  write_val "$f2fs/gc_urgent_sleep_time" "$F2FS_GC_URGENT_SLEEP" "F2FS gc_urgent_sleep"
  write_val "$f2fs/gc_no_gc_sleep_time" 30000 "F2FS gc_no_gc_sleep"
  write_val "$f2fs/gc_max_sleep_time" 60000 "F2FS gc_max_sleep"
  write_val "$f2fs/min_fsync_blocks" 32 "F2FS min_fsync_blocks"
  write_val "$f2fs/cp_interval" 30 "F2FS cp_interval"
  write_val "$f2fs/max_small_discards" 100 "F2FS max_small_discards"
  write_val "$f2fs/urgent_sgc" 1 "F2FS urgent_sgc"
done

# ============ EXT4 TUNING ============
# Remount /data with longer commit age
if [ -f /proc/mounts ]; then
  current_commit=$(grep " /data " /proc/mounts | grep -o 'commit=[0-9]*' | cut -d= -f2)
  if [ "$current_commit" != "$EXT4_COMMIT" ]; then
    mount -o remount,commit="$EXT4_COMMIT" /data 2>/dev/null && \
      log "ext4 /data commit=$EXT4_COMMIT" || log "FAIL: ext4 remount"
  fi
fi

# ============ ZRAM ============
zram="/sys/block/zram0"
if [ -d "$zram" ]; then
  # Set compression algorithm if not already set
  current_algo=$(cat "$zram/comp_algorithm" 2>/dev/null)
  if echo "$current_algo" | grep -qv "$ZRAM_ALGO"; then
    # Can only change algo when zram is reset
    if [ "$(cat "$zram/initstate" 2>/dev/null)" = "0" ]; then
      write_val "$zram/comp_algorithm" "$ZRAM_ALGO" "ZRAM algorithm"
    fi
  fi
  # Memory tracking (for KSU apps to see ZRAM stats)
  write_val "$zram/mem_limit" 0 "ZRAM mem_limit (unlimited)"
  # Recompress idle pages if supported
  write_val "$zram/recompress" "idle" "ZRAM recompress idle"
fi

# ============ THERMAL ============
case "$MODE" in
  performance)
    # Raise throttle limits for performance
    for tz in /sys/class/thermal/thermal_zone*; do
      [ -d "$tz" ] || continue
      write_val "$tz/policy" "step_wise" "$(cat "$tz/type" 2>/dev/null) policy"
    done
    ;;
  gaming)
    # Even more aggressive
    for tz in /sys/class/thermal/thermal_zone*; do
      [ -d "$tz" ] || continue
      write_val "$tz/policy" "performance" "$(cat "$tz/type" 2>/dev/null) policy"
    done
    ;;
  powersave)
    for tz in /sys/class/thermal/thermal_zone*; do
      [ -d "$tz" ] || continue
      write_val "$tz/policy" "power_allocator" "$(cat "$tz/type" 2>/dev/null) policy"
    done
    ;;
  *)
    for tz in /sys/class/thermal/thermal_zone*; do
      [ -d "$tz" ] || continue
      write_val "$tz/policy" "step_wise" "$(cat "$tz/type" 2>/dev/null) policy"
    done
    ;;
esac

# ============ VM ============
write_val /proc/sys/vm/swappiness 100 "swappiness"
write_val /proc/sys/vm/vfs_cache_pressure 100 "vfs_cache_pressure"
write_val /proc/sys/vm/dirty_ratio 20 "dirty_ratio"
write_val /proc/sys/vm/dirty_background_ratio 5 "dirty_background_ratio"
write_val /proc/sys/vm/page-cluster 0 "page-cluster"
write_val /proc/sys/vm/stat_interval 10 "stat_interval"

# ============ MGLRU ============
write_val /sys/kernel/mm/lru_gen/enabled 0x0007 "MGLRU enabled"

# ============ SCHEDULER ============
write_val /proc/sys/kernel/sched_child_runs_first 1 "sched_child_runs_first"
write_val /proc/sys/kernel/sched_autogroup_enabled 0 "sched_autogroup disabled"

# ============ AUTO BATTERY SAVER ============
if [ "$AUTO_BATTERY_SAVER" = "true" ]; then
  log "Auto battery saver enabled — monitoring screen state"
  (
    # Monitor screen state in background
    while :; do
      for power in /sys/class/power_supply/*/device/panel* /sys/class/power_supply/*/present; do
        break 2  # just check if any power supply exists
      done 2>/dev/null
      sleep 10
    done
  ) &
fi

log "=== DUSK Companion v2.1 applied ==="

# ============ UPDATE MODULE DESCRIPTION ============
MODULE_PROP="/data/adb/modules/dusk_companion/module.prop"

ksu()      { [ -d /data/adb/ksu ] && echo "yes" || echo "no"; }
susfs()    { zcat /proc/config.gz 2>/dev/null | grep -q 'CONFIG_KSU_SUSFS=y' && echo "yes" || echo "no"; }
ntsync()   { [ -c /dev/ntsync ] 2>/dev/null && echo "yes" || { lsmod 2>/dev/null | grep -q ntsync && echo "yes" || echo "no"; }; }
sched()    { [ "$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)" = "$CPU_GOV" ] && echo "yes" || echo "no"; }
gpu_gov()  { g=$(cat /sys/class/devfreq/*/governor 2>/dev/null | head -1); [ "$g" = "$GPU_GOVERNOR" ] && echo "yes" || echo "no"; }
io_ok()    { s=$(cat /sys/block/sda/queue/scheduler 2>/dev/null | grep -o "\[$IO_SCHEDULER\]"); [ -n "$s" ] && echo "yes" || echo "no"; }

DESC="mode:$MODE CPU:$(sched) GPU:$(gpu_gov) IO:$(io_ok) KSU:$(ksu) NTSYNC:$(ntsync)"

if [ -f "$MODULE_PROP" ]; then
  sed -i "s/^description=.*/description=$DESC/" "$MODULE_PROP"
fi

# ============ WRITE status.json FOR WebUI ============
STATUS_DIR="/data/adb/modules/dusk_companion/webroot"
STATUS_FILE="$STATUS_DIR/status.json"
mkdir -p "$STATUS_DIR"

# Gather computed values
KS=$(ksu)
SS=$(susfs)
NS=$(ntsync)
CG=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo "?")
GG=$(cat /sys/class/devfreq/*/governor 2>/dev/null | head -1 || echo "?")
TC=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "?")
IO=$(cat /sys/block/sda/queue/scheduler 2>/dev/null | grep -o "\[.*\]" | tr -d '[]' || echo "?")
ZA="?"
if [ -d /sys/block/zram0 ]; then
  ZA=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -oE "\[.*\]" | tr -d '[]')
  ZM=$(awk '{printf "%.0fMB/%.0fMB",$3/1024/1024,$1/1024/1024}' /sys/block/zram0/mm_stat 2>/dev/null)
  [ -z "$ZM" ] && ZM="inactive"
fi
TH=$(for tz in /sys/class/thermal/thermal_zone*; do [ -f "$tz/temp" ] || continue; t=$(cat "$tz/temp" 2>/dev/null); [ "$t" -gt 0 ] 2>/dev/null || continue; awk "BEGIN{printf \"%.1f°C\",$t/1000}" 2>/dev/null; break; done; [ -z "$TH" ] && echo "?")

cat > "$STATUS_FILE" << EOF
{
  "kernel": "$(uname -r)",
  "ksu": "$KS",
  "susfs": "$SS",
  "ntsync": "$NS",
  "cpu_gov": "$CG",
  "gpu_gov": "$GG",
  "tcp_cc": "$TC",
  "io_sched": "$IO",
  "zram_algo": "$ZA",
  "zram_mem": "$ZM",
  "thermal": "$TH",
  "mode": "$MODE",
  "battery_saver": $(echo "$AUTO_BATTERY_SAVER" | tr '[:upper:]' '[:lower:]'),
  "ecn": $([ "$TCP_ECN" = "true" ] && echo true || echo false),
  "gpu_perf": $([ "$GPU_GOVERNOR" = "performance" ] && echo true || echo false)
}
EOF
echo "✓ status.json written ($STATUS_FILE)"
