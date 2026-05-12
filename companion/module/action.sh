#!/system/bin/sh

echo "=============================="
echo "  DUSK Kernel Companion Status"
echo "=============================="
echo ""

check() {
  local label="$1" result="$2"
  if [ "$result" = "yes" ]; then
    echo "  [✓] $label"
  else
    echo "  [✗] $label"
  fi
}

# Kernel info
echo "--- Kernel ---"
echo "  $(uname -r)"
echo ""

# KernelSU
if [ -d /data/adb/ksu ]; then
  check "KernelSU-Next" "yes"
else
  check "KernelSU-Next" "no"
fi

# SUSFS (compiled into KSU, no standalone proc path)
if dmesg 2>/dev/null | grep -q "KernelSU.*susfs"; then
  check "SUSFS" "yes"
else
  check "SUSFS" "no"
fi

# NTSYNC (built-in or module)
if [ -c /dev/ntsync ] 2>/dev/null; then
  check "NTSYNC" "yes"
elif lsmod 2>/dev/null | grep -q ntsync; then
  check "NTSYNC" "yes"
else
  check "NTSYNC" "no"
fi

# CPU governor
echo ""
echo "--- CPU ---"
gov=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)
if [ "$gov" = "schedutil" ]; then
  check "Governor (schedutil)" "yes"
  for path in /sys/devices/system/cpu/cpufreq/schedutil; do
    [ -f "$path/up_rate_limit_us" ] && echo "  up_rate_limit_us: $(cat $path/up_rate_limit_us)µs"
    [ -f "$path/down_rate_limit_us" ] && echo "  down_rate_limit_us: $(cat $path/down_rate_limit_us)µs"
  done
else
  check "Governor (schedutil)" "no"
  echo "  Current: $gov"
fi

# GPU
echo ""
echo "--- GPU ---"
gpu_ok="no"
for d in /sys/class/devfreq/*; do
  [ -d "$d" ] || continue
  name=$(cat "$d/name" 2>/dev/null)
  case "$name" in
    *mali*|*gpu*)
      g=$(cat "$d/governor" 2>/dev/null)
      f=$(cat "$d/cur_freq" 2>/dev/null)
      if [ "$g" = "performance" ]; then
        gpu_ok="yes"
      fi
      echo "  $name: governor=$g freq=${f}Hz"
      ;;
  esac
done
check "GPU performance" "$gpu_ok"

# ZRAM
echo ""
echo "--- ZRAM ---"
algo=$(cat /sys/block/zram0/comp_algorithm 2>/dev/null)
if echo "$algo" | grep -q zstd; then
  check "Compression (zstd)" "yes"
  echo "  Algorithms: $algo"
else
  check "Compression (zstd)" "no"
  [ -n "$algo" ] && echo "  Algorithms: $algo"
fi

# Thermal
echo ""
echo "--- Thermal ---"
tz_count=0
for tz in /sys/class/thermal/thermal_zone*; do
  [ -d "$tz" ] || continue
  type=$(cat "$tz/type" 2>/dev/null)
  pol=$(cat "$tz/policy" 2>/dev/null)
  [ -n "$pol" ] && echo "  $type: $pol" && tz_count=$((tz_count + 1))
done
[ "$tz_count" -gt 0 ] && check "Thermal zones" "yes" || check "Thermal zones" "no"

echo ""
echo "=============================="
