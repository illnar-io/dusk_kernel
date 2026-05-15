#!/system/bin/sh

echo ""
echo ".     *       .       ."
echo "*       .        .   🌕    ."
echo "    .        .        ."
echo "         |               |"
echo "      _\` |  |   |   __|  |  /"
echo "     (   |  |   | \\__ \\    <"
echo "    \\__,_| \\__,_| ____/ _|\\_\\"
echo "     .     *       .       ."
echo "*       .        .      ."
echo "    .        .        ."
echo ""
echo "=============================="
echo "  DUSK Kernel Companion v2.1"
echo "=============================="
echo ""

MODDIR=${0%/*}
CONFIG="$MODDIR/config.conf"
[ -f "$CONFIG" ] && . "$CONFIG"

check() {
  local label="$1" result="$2"
  if [ "$result" = "yes" ]; then
    echo "  [✓] $label"
  else
    echo "  [✗] $label"
  fi
}

check_ksu()    { [ -d /data/adb/ksu ] && echo yes || echo no; }
susfs_check()  { zcat /proc/config.gz 2>/dev/null | grep -q 'CONFIG_KSU_SUSFS=y' && echo yes || echo no; }
check_ntsync() { [ -c /dev/ntsync ] && echo yes || (lsmod 2>/dev/null | grep -q ntsync && echo yes || echo no); }

# Kernel
echo "--- Kernel ---"
echo "  $(uname -r)"
echo ""

# KernelSU
check "KernelSU-Next" "$(check_ksu)"

# SUSFS
check "SUSFS" "$(susfs_check)"

# NTSYNC
check "NTSYNC" "$(check_ntsync)"

# Mode
echo ""
echo "--- Profile ---"
echo "  Mode: ${MODE:-balanced}"

# CPU
echo ""
echo "--- CPU ---"
gov=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)
check "Governor (${CPU_GOVERNOR:-schedutil})" "$([ "$gov" = "${CPU_GOVERNOR:-schedutil}" ] && echo yes || echo no)"
[ -n "$gov" ] && echo "  Current: $gov"
for path in /sys/devices/system/cpu/cpufreq/schedutil; do
  [ -f "$path/up_rate_limit_us" ] && echo "  up_rate_limit_us: $(cat $path/up_rate_limit_us)µs"
  [ -f "$path/down_rate_limit_us" ] && echo "  down_rate_limit_us: $(cat $path/down_rate_limit_us)µs"
done

# GPU
echo ""
echo "--- GPU ---"
gpu_ok="no"
for d in /sys/class/devfreq/*; do
  [ -d "$d" ] || continue
  name=$(cat "$d/name" 2>/dev/null)
  case "$name" in *mali*|*gpu*)
    g=$(cat "$d/governor" 2>/dev/null)
    f=$(cat "$d/cur_freq" 2>/dev/null)
    [ "$g" = "${GPU_GOVERNOR:-performance}" ] && gpu_ok="yes"
    echo "  $name: gov=$g freq=${f}Hz"
    ;;
  esac
done
check "GPU ${GPU_GOVERNOR:-performance}" "$gpu_ok"

# I/O
echo ""
echo "--- I/O ---"
io_ok="no"
for block in /sys/block/[a-z]*; do
  [ -d "$block/queue" ] || continue
  dev=$(basename "$block")
  case "$dev" in loop*|ram*) continue;; esac
  s=$(cat "$block/queue/scheduler" 2>/dev/null)
  ra=$(cat "$block/queue/read_ahead_kb" 2>/dev/null)
  echo "  $dev: $s | read_ahead=${ra}KB"
  echo "$s" | grep -q "\[${IO_SCHEDULER:-mq-deadline}\]" && io_ok="yes"
done
check "I/O ${IO_SCHEDULER:-mq-deadline}" "$io_ok"

# TCP
echo ""
echo "--- Network ---"
cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)
check "TCP congestion (${TCP_CONG:-bbr})" "$([ "$cc" = "${TCP_CONG:-bbr}" ] && echo yes || echo no)"
echo "  Current: $cc"
ecn=$(cat /proc/sys/net/ipv4/tcp_ecn 2>/dev/null)
check "TCP ECN" "$([ "$ecn" = "1" ] && echo yes || echo no)"

# ZRAM
echo ""
echo "--- ZRAM ---"
algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)
check "Compression (${ZRAM_ALGO:-zstd})" "$(echo "$algo" | grep -q "${ZRAM_ALGO:-zstd}" && echo yes || echo no)"
[ -n "$algo" ] && echo "  Algorithms: $algo"
mm=$(cat /sys/block/zram0/mm_stat 2>/dev/null | awk '{printf "%.0fMB/%.0fMB", $3/1024/1024, $1/1024/1024}' 2>/dev/null)
[ -n "$mm" ] && echo "  Memory: $mm"

# F2FS
echo ""
echo "--- F2FS ---"
for f2fs in /sys/fs/f2fs/*; do
  [ -d "$f2fs" ] || continue
  echo "  $(basename $f2fs):"
  for param in gc_urgent_sleep_time gc_max_sleep_time min_fsync_blocks; do
    val=$(cat "$f2fs/$param" 2>/dev/null) && echo "    $param=$val"
  done
done

# Thermal
echo ""
echo "--- Thermal ---"
for tz in /sys/class/thermal/thermal_zone*; do
  [ -d "$tz" ] || continue
  type=$(cat "$tz/type" 2>/dev/null)
  temp=$(cat "$tz/temp" 2>/dev/null)
  pol=$(cat "$tz/policy" 2>/dev/null)
  [ -n "$pol" ] && echo "  $type: ${temp}°C (${temp:0: -3}μC) policy=$pol"
done

# ext4 commit
echo ""
echo "--- Filesystem ---"
commit=$(grep " /data " /proc/mounts 2>/dev/null | grep -o 'commit=[0-9]*' | cut -d= -f2)
check "ext4 /data commit (${EXT4_COMMIT:-30}s)" "$([ "$commit" = "${EXT4_COMMIT:-30}" ] && echo yes || echo no)"
[ -n "$commit" ] && echo "  Current: ${commit}s"

# ============ WRITE status.json FOR WebUI ============
STATUS_DIR="/data/adb/modules/dusk_companion/webroot"
STATUS_FILE="$STATUS_DIR/status.json"
mkdir -p "$STATUS_DIR"

KS=$(check_ksu)
SS=$(susfs_check)
NS=$(check_ntsync)
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
  "mode": "${MODE:-balanced}",
  "battery_saver": $(echo "${AUTO_BATTERY_SAVER:-true}" | tr '[:upper:]' '[:lower:]'),
  "ecn": $([ "${TCP_ECN:-false}" = "true" ] && echo true || echo false),
  "gpu_perf": $([ "${GPU_GOVERNOR:-performance}" = "performance" ] && echo true || echo false)
}
EOF
echo ""
echo "✓ status.json written"

echo ""
echo "=============================="
