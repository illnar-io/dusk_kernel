// ─── KSU API detection ───
let KSU_API = null;
const LOG = [];

function log(msg, type) {
  LOG.push({ msg, type: type || 'info' });
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

function setAPIStatus(type, msg) {
  const el = document.getElementById('api-status');
  if (!el) return;
  el.className = 'api-warn ' + type;
  el.textContent = msg;
}

// ─── API backends ───

const JSAPI = {
  name: 'JS (KernelSU)',
  detect: async () => {
    for (const scope of [() => KernelSU, () => window.KernelSU]) {
      try {
        const api = scope();
        if (api && typeof api.exec === 'function') {
          const r = await api.exec('echo dusk_api_check');
          const out = typeof r === 'string' ? r : (r && r.stdout) || '';
          if (out.includes('dusk_api_check')) return api;
        }
      } catch (_) {}
    }
    return null;
  },
  exec: async (api, cmd) => {
    const r = await api.exec(cmd);
    return {
      stdout: typeof r === 'string' ? r : (r && r.stdout) || '',
      stderr: (r && r.stderr) || '',
      code: (r && r.result_code) || 0,
    };
  }
};

const HTTPAPI = {
  name: 'HTTP (/api/exec)',
  detect: async () => {
    const origin = window.location.origin;
    if (!origin || origin === 'null' || origin.startsWith('file://')) return null;
    const payloads = [
      { url: `${origin}/api/exec`, opts: { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ cmd: 'echo dusk_api_check' }) } },
      { url: `${origin}/api/exec?cmd=echo+dusk_api_check`, opts: { method: 'GET' } },
    ];
    for (const p of payloads) {
      try {
        const res = await fetch(p.url, { ...p.opts, signal: AbortSignal.timeout(3000) });
        if (!res.ok) continue;
        const text = await res.text();
        let data;
        try { data = JSON.parse(text); } catch { data = { stdout: text }; }
        const out = (data.stdout || '').trim();
        if (out.includes('dusk_api_check')) return { origin, method: p.opts.method };
      } catch (_) {}
    }
    return null;
  },
  exec: async (ctx, cmd) => {
    const { origin, method } = ctx;
    let res;
    if (method === 'POST') {
      res = await fetch(`${origin}/api/exec`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ cmd }) });
    } else {
      res = await fetch(`${origin}/api/exec?cmd=${encodeURIComponent(cmd)}`);
    }
    const text = await res.text();
    let data;
    try { data = JSON.parse(text); } catch { data = { stdout: text }; }
    return {
      stdout: (data.stdout || '').trim(),
      stderr: (data.stderr || '').trim(),
      code: data.result_code !== undefined ? data.result_code : (res.ok ? 0 : 1),
    };
  }
};

const STATUSFILE_API = {
  name: 'status.json',
  exec: async (_ctx, cmd) => {
    throw new Error('Cannot execute commands via status file. Use action.sh or service.sh.');
  }
};

// ─── detect API ───

async function detectAPI() {
  // Order: JS bridge, HTTP POST, HTTP GET
  const backends = [JSAPI, HTTPAPI];
  for (const bk of backends) {
    log(`Trying ${bk.name}...`, 'info');
    const ctx = await bk.detect();
    if (ctx) {
      log(`✓ ${bk.name} available`, 'ok');
      return { api: bk, ctx };
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
    const result = await KSU_API.api.exec(KSU_API.ctx, cmd);
    const out = result.stdout || '';
    if (out) log(out.length > 200 ? out.substring(0, 200) + '...' : out, 'ok');
    else log('(empty)', 'info');
    if (result.stderr) log(result.stderr, 'err');
    return out;
  } catch (e) {
    log(`Error: ${e.message || e}`, 'err');
    return '';
  }
}

// ─── UI (read-only status from JSON, exec for interaction) ───

async function refreshStatus() {
  const btn = document.getElementById('btn-refresh');
  if (btn) btn.disabled = true;

  // Try status.json first (fast, no API needed)
  try {
    let data = null;
    const res = await fetch('status.json?' + Date.now());
    if (res.ok) data = await res.json();
    if (data) {
      applyStatusData(data);
      if (btn) btn.disabled = false;
      return;
    }
  } catch (_) {}

  // Fallback: API
  if (!KSU_API) {
    if (btn) btn.disabled = false;
    return;
  }

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

  applyStatusData({
    kernel, ksu, susfs, ntsync,
    cpu_gov: cpuGov, gpu_gov: gpuGov, tcp_cc: tcpCc,
    io_sched: ioSched, zram_algo: zramAlgo, zram_mem: zramMem,
    thermal: thermal,
  });

  if (btn) btn.disabled = false;
}

function applyStatusData(d) {
  const set = (id, val, badge) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = val || '—';
    if (badge !== undefined) {
      el.style.background = badge ? '#1b4721' : '#47211b';
      el.style.color = badge ? '#7ee787' : '#ff7b72';
      el.style.padding = '1px 8px';
      el.style.borderRadius = '10px';
      el.style.fontSize = '11px';
      el.style.fontWeight = '600';
    }
  };

  set('kernel-version', d.kernel);
  set('ksu-status', d.ksu === 'yes' ? '✓ yes' : '✗ no', d.ksu === 'yes');
  set('susfs-status', d.susfs === 'yes' ? '✓ yes' : '✗ no', d.susfs === 'yes');
  set('ntsync-status', d.ntsync === 'yes' ? '✓ yes' : '✗ no', d.ntsync === 'yes');
  set('cpu-gov', d.cpu_gov);
  set('gpu-gov', d.gpu_gov);
  set('tcp-cc', d.tcp_cc);
  set('io-sched', d.io_sched);
  set('zram-info', (d.zram_algo && d.zram_algo !== '?' ? `${d.zram_algo} (${d.zram_mem})` : ''));
  set('thermal-temp', d.thermal);
}

async function setMode(mode) {
  if (!KSU_API) { log('API unavailable — mode change disabled', 'err'); return; }
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
  if (!KSU_API) { el.checked = !el.checked; log('API unavailable', 'err'); return; }
  const val = el.checked ? 'true' : 'false';
  await execCmd(`sed -i '/^AUTO_BATTERY_SAVER=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo AUTO_BATTERY_SAVER=${val} >> /data/adb/modules/dusk_companion/config.conf`);
  log(`Auto battery saver: ${val}`, 'info');
}

async function toggleEcn(el) {
  if (!KSU_API) { el.checked = !el.checked; log('API unavailable', 'err'); return; }
  const val = el.checked ? '1' : '0';
  await execCmd(`echo ${val} > /proc/sys/net/ipv4/tcp_ecn`);
  await execCmd(`sed -i '/^TCP_ECN=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo TCP_ECN=${el.checked} >> /data/adb/modules/dusk_companion/config.conf`);
  refreshStatus();
}

async function toggleGpu(el) {
  if (!KSU_API) { el.checked = !el.checked; log('API unavailable', 'err'); return; }
  const gov = el.checked ? 'performance' : 'simple_ondemand';
  await execCmd(`for d in /sys/class/devfreq/*/governor; do echo ${gov} > "$d" 2>/dev/null; done`);
  await execCmd(`sed -i '/^GPU_GOVERNOR=/d' /data/adb/modules/dusk_companion/config.conf`);
  await execCmd(`echo GPU_GOVERNOR=${gov} >> /data/adb/modules/dusk_companion/config.conf`);
  refreshStatus();
}

async function applySettings() {
  if (!KSU_API) { log('API unavailable', 'err'); return; }
  const btn = document.getElementById('btn-apply');
  if (btn) { btn.disabled = true; btn.textContent = 'Applying...'; }
  log('Applying all settings...', 'info');
  await execCmd('sh /data/adb/modules/dusk_companion/service.sh 2>/dev/null');
  if (btn) { btn.disabled = false; btn.textContent = 'Re-apply All Settings'; }
  refreshStatus();
}

// ─── Init ───

async function init() {
  log('DUSK Companion WebUI loading...', 'info');

  // Try to detect API
  KSU_API = await detectAPI();
  if (KSU_API) {
    setAPIStatus('ok', `${KSU_API.api.name} connected`);
  }

  // Always try to load status.json (no API needed)
  try {
    const res = await fetch('status.json?' + Date.now());
    if (res.ok) {
      const data = await res.json();
      applyStatusData(data);
      if (data.mode) {
        const m = document.querySelector(`[data-mode="${data.mode}"]`);
        if (m) m.classList.add('active');
        document.getElementById('current-mode').textContent = `Current: ${data.mode}`;
      }
      if (data.battery_saver !== undefined) document.getElementById('toggle-battery-saver').checked = data.battery_saver;
      if (data.ecn !== undefined) document.getElementById('toggle-ecn').checked = data.ecn;
      if (data.gpu_perf !== undefined) document.getElementById('toggle-gpu').checked = data.gpu_perf;
      log('Status loaded from status.json', 'ok');
      return; // status.json has all we need
    }
  } catch (_) {}

  // No status.json — try live API for status
  if (!KSU_API) {
    setAPIStatus('error', 'No KSU API — WebUI is read-only. Tap Action in KSU Manager to update status.');
    log('No API or status.json found', 'err');
    return;
  }

  await refreshStatus();

  // Load config for toggle states
  const abs = await execCmd("grep '^AUTO_BATTERY_SAVER=' /data/adb/modules/dusk_companion/config.conf | cut -d= -f2");
  if (abs === 'true' || abs === 'false') document.getElementById('toggle-battery-saver').checked = abs === 'true';
  const ecn = await execCmd('cat /proc/sys/net/ipv4/tcp_ecn 2>/dev/null || echo 0');
  if (ecn === '1' || ecn === '0') document.getElementById('toggle-ecn').checked = ecn === '1';
  const gpu = await execCmd("for d in /sys/class/devfreq/*; do [ ! -d \"$d\" ] && continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in *mali*|*gpu*) cat \"$d/governor\" 2>/dev/null; break;; esac; done || echo '?'");
  if (gpu) document.getElementById('toggle-gpu').checked = gpu === 'performance';
}

document.addEventListener('DOMContentLoaded', init);
