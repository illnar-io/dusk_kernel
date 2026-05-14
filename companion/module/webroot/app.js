const API = window.KernelSU || { exec: (cmd) => ({ stdout: '', stderr: '' }) };

async function run(cmd) {
  try {
    const result = await API.exec(cmd);
    return (result.stdout || '').trim();
  } catch (e) {
    return 'error';
  }
}

async function readFile(path) {
  return await run(`cat ${path} 2>/dev/null || echo ''`);
}

function badge(text, isOk) {
  return `<span class="badge" style="background:${isOk?'#1b4721':'#47211b'};color:${isOk?'#7ee787':'#ff7b72'}">${isOk?'✓':'✗'} ${text}</span>`;
}

async function refreshStatus() {
  const [kernel, ksu, susfs, ntsyncDev, ntsyncMod, cpuGov, gpuGov, tcpCc, ioSched, zramAlgo, zramMem, thermalTemp] = await Promise.all([
    run('uname -r'),
    run('[ -d /data/adb/ksu ] && echo yes || echo no'),
    run('dmesg 2>/dev/null | grep -q "KernelSU.*susfs" && echo yes || echo no'),
    run('[ -c /dev/ntsync ] && echo yes || echo no'),
    run('lsmod 2>/dev/null | grep -q ntsync && echo yes || echo no'),
    run('cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo "?"'),
    run('for d in /sys/class/devfreq/*; do [ -d "$d" ] || continue; n=$(cat "$d/name" 2>/dev/null); case "$n" in *mali*|*gpu*) cat "$d/governor" 2>/dev/null; break;; esac; done'),
    run('cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null'),
    run('cat /sys/block/sda/queue/scheduler 2>/dev/null | grep -o "\[.*\]" | tr -d "[]" || echo "?"'),
    run('cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -oE "\[.*\]" | tr -d "[]" || echo "?"'),
    run("awk '{printf \"%.0fMB/%.0fMB\", $3/1024/1024, $1/1024/1024}' /sys/block/zram0/mm_stat 2>/dev/null || echo '?'"),
    run('cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | sed "s/...$/.&°C/" || echo "?"'),
  ]);

  const ntsync = ntsyncDev === 'yes' || ntsyncMod === 'yes' ? 'yes' : 'no';

  document.getElementById('kernel-version').textContent = kernel;
  document.getElementById('ksu-status').innerHTML = badge('KSU', ksu === 'yes');
  document.getElementById('susfs-status').innerHTML = badge('SUSFS', susfs === 'yes');
  document.getElementById('ntsync-status').innerHTML = badge('NTSYNC', ntsync === 'yes');
  document.getElementById('cpu-gov').textContent = cpuGov;
  document.getElementById('gpu-gov').textContent = gpuGov;
  document.getElementById('tcp-cc').textContent = tcpCc;
  document.getElementById('io-sched').textContent = ioSched;
  document.getElementById('zram-info').textContent = `${zramAlgo} (${zramMem})`;
  document.getElementById('thermal-temp').textContent = thermalTemp;
}

async function setMode(mode) {
  await run(`echo 'MODE=${mode}' >> /data/adb/modules/dusk_companion/config.conf`);
  // Replace or append the MODE line
  await run(`sed -i '/^MODE=/d' /data/adb/modules/dusk_companion/config.conf`);
  await run(`echo 'MODE=${mode}' >> /data/adb/modules/dusk_companion/config.conf`);
  // Re-apply
  await run('sh /data/adb/modules/dusk_companion/service.sh 2>/dev/null');
  document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
  document.querySelector(`[data-mode="${mode}"]`).classList.add('active');
  document.getElementById('current-mode').textContent = `Current: ${mode}`;
  document.getElementById('footer-mode').textContent = mode;
  refreshStatus();
}

async function toggleBatterySaver(el) {
  const val = el.checked ? 'true' : 'false';
  await run(`sed -i '/^AUTO_BATTERY_SAVER=/d' /data/adb/modules/dusk_companion/config.conf`);
  await run(`echo 'AUTO_BATTERY_SAVER=${val}' >> /data/adb/modules/dusk_companion/config.conf`);
}

async function toggleEcn(el) {
  const val = el.checked ? '1' : '0';
  await run(`echo ${val} > /proc/sys/net/ipv4/tcp_ecn`);
  await run(`sed -i '/^TCP_ECN=/d' /data/adb/modules/dusk_companion/config.conf`);
  await run(`echo 'TCP_ECN=${el.checked}' >> /data/adb/modules/dusk_companion/config.conf`);
}

async function toggleGpu(el) {
  const gov = el.checked ? 'performance' : 'simple_ondemand';
  for (const d of ['0','1','2']) {
    await run(`echo ${gov} > /sys/class/devfreq/${d}/governor 2>/dev/null`);
  }
  await run(`sed -i '/^GPU_GOVERNOR=/d' /data/adb/modules/dusk_companion/config.conf`);
  await run(`echo 'GPU_GOVERNOR=${gov}' >> /data/adb/modules/dusk_companion/config.conf`);
  refreshStatus();
}

async function applySettings() {
  document.querySelector('.btn-primary').textContent = 'Applying...';
  await run('sh /data/adb/modules/dusk_companion/service.sh 2>/dev/null');
  document.querySelector('.btn-primary').textContent = 'Re-apply All Settings';
  refreshStatus();
}

// Load saved mode and status on startup
async function init() {
  await refreshStatus();
  const mode = await run("grep '^MODE=' /data/adb/modules/dusk_companion/config.conf | cut -d= -f2");
  if (mode) {
    document.querySelector(`[data-mode="${mode}"]`)?.classList.add('active');
    document.getElementById('current-mode').textContent = `Current: ${mode}`;
    document.getElementById('footer-mode').textContent = mode;
  }
  const abs = await run("grep '^AUTO_BATTERY_SAVER=' /data/adb/modules/dusk_companion/config.conf | cut -d= -f2");
  if (abs) document.getElementById('toggle-battery-saver').checked = abs === 'true';
  const ecn = await run('cat /proc/sys/net/ipv4/tcp_ecn 2>/dev/null || echo 0');
  document.getElementById('toggle-ecn').checked = ecn === '1';
  const gpu = await run("for d in /sys/class/devfreq/*; do [ -d \"$d\" ] || continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in *mali*|*gpu*) cat \"$d/governor\" 2>/dev/null; break;; esac; done");
  document.getElementById('toggle-gpu').checked = gpu === 'performance';
}

document.addEventListener('DOMContentLoaded', init);
