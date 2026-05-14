// ─── KSU API detection ───
let KSU_API = null;
const LOG = [];

function log(msg, type) {
  const entry = { msg, type: type || 'info', time: Date.now() };
  LOG.push(entry);
  renderLog();
}

function renderLog() {
  const el = document.getElementById('log-content');
  if (!el) return;
  el.innerHTML = LOG.map(e => `<div class="log-line ${e.type}">${escapeHtml(e.msg)}</div>`).join('');
  el.scrollTop = el.scrollHeight;
}

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

async function detectAPI() {
  // Try multiple possible API locations
  const candidates = [
    { name: 'global KernelSU', obj: typeof KernelSU !== 'undefined' ? KernelSU : null },
    { name: 'window.KernelSU', obj: typeof window.KernelSU !== 'undefined' ? window.KernelSU : null },
  ];
  for (const c of candidates) {
    if (c.obj && typeof c.obj.exec === 'function') {
      try {
        const test = await c.obj.exec('echo "api_ok"');
        const out = (test && (test.stdout || test)) || '';
        if (out.includes('api_ok') || String(out).includes('api_ok')) {
          log(`KSU API detected via ${c.name}`, 'ok');
          return c.obj;
        }
      } catch (_) {}
    }
  }
  return null;
}

async function execCmd(cmd) {
  if (!KSU_API) {
    log(`API unavailable — can't run: ${cmd}`, 'err');
    return '';
  }
  try {
    log(`$ ${cmd}`, 'cmd');
    const result = await KSU_API.exec(cmd);
    let stdout = '';
    if (typeof result === 'string') {
      stdout = result;
    } else if (result && typeof result.stdout === 'string') {
      stdout = result.stdout;
    } else if (result && typeof result === 'object') {
      stdout = JSON.stringify(result);
    }
    const trimmed = stdout.trim();
    if (trimmed) log(trimmed.substring(0, 200), 'ok');
    else log('(empty)', 'info');
    return trimmed;
  } catch (e) {
    log(`Error: ${e.message || e}`, 'err');
    return '';
  }
}

function setAPIStatus(type, msg) {
  const el = document.getElementById('api-status');
  if (!el) return;
  el.className = 'api-warn ' + type;
  el.textContent = msg;
}

// ─── UI actions ───

async function refreshStatus() {
  const btn = document.getElementById('btn-refresh');
  if (btn) btn.disabled = true;

  const [kernel, ksu, susfs, ntsync, cpuGov, gpuGov, tcpCc, ioSched, zramAlgo, zramMem, thermal] = await Promise.all([
    execCmd('uname -r'),
    execCmd('[ -d /data/adb/ksu ] && echo yes || echo no'),
    execCmd('[ -e /proc/ksud ] && ksud debug 2>/dev/null | grep -qi susfs && echo yes || echo no'),
    execCmd('ls /dev/ntsync 2>/dev/null && echo yes || (lsmod 2>/dev/null | grep -q ntsync && echo yes || echo no)'),
    execCmd('cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo "?"'),
    execCmd("for d in /sys/class/devfreq/*; do [ ! -d \"$d\" ] && continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in *mali*|*gpu*) cat \"$d/governor\" 2>/dev/null; break;; esac; done || echo '?'"),
    execCmd('cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "?"'),
    execCmd("cat /sys/block/sda/queue/scheduler 2>/dev/null | grep -o '\\[[^]]*\\]' | tr -d '[]' || echo '?'"),
    execCmd("cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -oE '\\[[^]]*\\]' | tr -d '[]' || echo '?'"),
    execCmd("awk '{printf \"%.0fMB / %.0fMB\",$3/1024/1024,$1/1024/1024}' /sys/block/zram0/mm_stat 2>/dev/null || echo '?'"),
    execCmd("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf \"%.1f°C\",$1/1000}' || echo '?'"),
  ]);

  document.getElementById('kernel-version').textContent = kernel || '—';
  document.getElementById('ksu-status').textContent = ksu === 'yes' ? '✓ yes' : '✗ no';
  document.getElementById('susfs-status').textContent = susfs === 'yes' ? '✓ yes' : '✗ no';
  document.getElementById('ntsync-status').textContent = ntsync === 'yes' ? '✓ yes' : '✗ no';
  document.getElementById('cpu-gov').textContent = cpuGov || '—';
  document.getElementById('gpu-gov').textContent = gpuGov || '—';
  document.getElementById('tcp-cc').textContent = tcpCc || '—';
  document.getElementById('io-sched').textContent = ioSched || '—';
  document.getElementById('zram-info').textContent = (zramAlgo && zramAlgo !== '?' ? `${zramAlgo} (${zramMem})` : '—');
  document.getElementById('thermal-temp').textContent = thermal || '—';

  // Color badges
  setBadgeColor('ksu-status', ksu === 'yes');
  setBadgeColor('susfs-status', susfs === 'yes');
  setBadgeColor('ntsync-status', ntsync === 'yes');

  if (btn) btn.disabled = false;
}

function setBadgeColor(id, ok) {
  const el = document.getElementById(id);
  if (!el) return;
  el.style.background = ok ? '#1b4721' : '#47211b';
  el.style.color = ok ? '#7ee787' : '#ff7b72';
  el.style.padding = '1px 8px';
  el.style.borderRadius = '10px';
  el.style.fontSize = '11px';
  el.style.fontWeight = '600';
}

async function setMode(mode) {
  log(`Setting mode: ${mode}`, 'info');
  await execCmd(`sed -i '/^MODE=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo MODE=${mode} >> /data/adb/modules/dusk_companion/config.conf`);
  await execCmd('sh /data/adb/modules/dusk_companion/service.sh 2>/dev/null');
  document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
  const btn = document.querySelector(`[data-mode="${mode}"]`);
  if (btn) btn.classList.add('active');
  document.getElementById('current-mode').textContent = `Current: ${mode}`;
  refreshStatus();
}

async function toggleBatterySaver(el) {
  const val = el.checked ? 'true' : 'false';
  await execCmd(`sed -i '/^AUTO_BATTERY_SAVER=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo AUTO_BATTERY_SAVER=${val} >> /data/adb/modules/dusk_companion/config.conf`);
  log(`Auto battery saver: ${val}`, 'info');
}

async function toggleEcn(el) {
  const val = el.checked ? '1' : '0';
  await execCmd(`echo ${val} > /proc/sys/net/ipv4/tcp_ecn`);
  await execCmd(`sed -i '/^TCP_ECN=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo TCP_ECN=${el.checked} >> /data/adb/modules/dusk_companion/config.conf`);
  refreshStatus();
}

async function toggleGpu(el) {
  const gov = el.checked ? 'performance' : 'simple_ondemand';
  await execCmd(`for d in /sys/class/devfreq/*/governor; do echo ${gov} > "$d" 2>/dev/null; done`);
  await execCmd(`sed -i '/^GPU_GOVERNOR=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo GPU_GOVERNOR=${gov} >> /data/adb/modules/dusk_companion/config.conf`);
  refreshStatus();
}

async function applySettings() {
  const btn = document.getElementById('btn-apply');
  if (btn) { btn.disabled = true; btn.textContent = 'Applying...'; }
  log('Applying all settings...', 'info');
  await execCmd('sh /data/adb/modules/dusk_companion/service.sh 2>/dev/null');
  if (btn) { btn.disabled = false; btn.textContent = 'Re-apply All Settings'; }
  refreshStatus();
}

// ─── Init ───

async function init() {
  // wait a brief moment for KSU bridge to initialize
  let retries = 0;
  while (retries < 10) {
    KSU_API = await detectAPI();
    if (KSU_API) break;
    await new Promise(r => setTimeout(r, 200));
    retries++;
  }

  if (!KSU_API) {
    setAPIStatus('error', 'No KSU WebUI API available — status will not work');
    log('KSU API not found after 2s timeout', 'err');
    // Disable interactive elements
    document.querySelectorAll('button, input').forEach(el => el.disabled = true);
    const btns = document.querySelectorAll('.btn');
    btns.forEach(b => { b.disabled = false; }); // Re-enable refresh for retry
    document.getElementById('btn-refresh').disabled = false;
    return;
  }

  setAPIStatus('ok', 'KSU API connected');

  // Load initial status
  await refreshStatus();

  // Load saved mode and toggle states
  const mode = await execCmd("grep '^MODE=' /data/adb/modules/dusk_companion/config.conf | cut -d= -f2");
  if (mode) {
    document.querySelector(`[data-mode="${mode}"]`)?.classList.add('active');
    document.getElementById('current-mode').textContent = `Current: ${mode}`;
  }

  const abs = await execCmd("grep '^AUTO_BATTERY_SAVER=' /data/adb/modules/dusk_companion/config.conf | cut -d= -f2");
  if (abs === 'true' || abs === 'false') document.getElementById('toggle-battery-saver').checked = abs === 'true';

  const ecn = await execCmd('cat /proc/sys/net/ipv4/tcp_ecn 2>/dev/null || echo 0');
  if (ecn === '1' || ecn === '0') document.getElementById('toggle-ecn').checked = ecn === '1';

  const gpu = await execCmd("for d in /sys/class/devfreq/*; do [ ! -d \"$d\" ] && continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in *mali*|*gpu*) cat \"$d/governor\" 2>/dev/null; break;; esac; done || echo '?'");
  if (gpu) document.getElementById('toggle-gpu').checked = gpu === 'performance';
}

document.addEventListener('DOMContentLoaded', init);
