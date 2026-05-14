#!/system/bin/sh

echo "=============================="
echo "  DUSK Kernel Companion v2.0"
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

# Kernel
echo "--- Kernel ---"
echo "  $(uname -r)"
echo ""

# KernelSU
check "KernelSU-Next" "$([ -d /data/adb/ksu ] && echo yes || echo no)"

# SUSFS
susfs_check() { [ -e /proc/ksud ] && ksud debug 2>/dev/null | grep -qi susfs && echo yes || echo no; }
check "SUSFS" "$(susfs_check)"

# NTSYNC
if [ -c /dev/ntsync ] 2>/dev/null; then
  check "NTSYNC" "yes"
elif lsmod 2>/dev/null | grep -q ntsync; then
  check "NTSYNC" "yes"
else
  check "NTSYNC" "no"
fi

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

echo ""
echo "=============================="
