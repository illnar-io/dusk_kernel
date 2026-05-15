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

const backends = [
  {
    name: 'JS (ksu bridge)',
    detect: async () => {
      for (const scope of [() => ksu, () => window.ksu]) {
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
  },
  {
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
  }
];

async function detectAPI() {
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
  if (!KSU_API) return '';
  try {
    log(`$ ${cmd}`, 'cmd');
    const result = await KSU_API.api.exec(KSU_API.ctx, cmd);
    const out = result.stdout || '';
    if (out) log(out.length > 150 ? out.substring(0, 150) + '...' : out, 'ok');
    else log('(done)', 'info');
    if (result.stderr) log(result.stderr, 'err');
    return out;
  } catch (e) {
    log(`Error: ${e.message || e}`, 'err');
    return '';
  }
}

function setReadonlyUI() {
  document.querySelectorAll('.mode-btn, #btn-apply').forEach(el => { el.disabled = true; });
  document.querySelectorAll('.switch input[type=checkbox]').forEach(el => { el.disabled = true; });
  document.getElementById('readonly-notice').style.display = 'block';
}

async function refreshStatus() {
  const btn = document.getElementById('btn-refresh');
  if (btn) btn.disabled = true;
  try {
    const res = await fetch('status.json?' + Date.now());
    if (res.ok) {
      const data = await res.json();
      applyStatusData(data);
    }
  } catch (_) {}
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

  if (d.mode) {
    document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
    const m = document.querySelector(`[data-mode="${d.mode}"]`);
    if (m) m.classList.add('active');
    document.getElementById('current-mode').textContent = `Current: ${d.mode}`;
  }
  if (d.battery_saver !== undefined) document.getElementById('toggle-battery-saver').checked = d.battery_saver;
  if (d.ecn !== undefined) document.getElementById('toggle-ecn').checked = d.ecn;
  if (d.gpu_perf !== undefined) document.getElementById('toggle-gpu').checked = d.gpu_perf;
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

async function init() {
  log('DUSK Companion WebUI loading...', 'info');

  KSU_API = await detectAPI();
  if (KSU_API) {
    setAPIStatus('ok', `${KSU_API.api.name} connected`);
    log('Interactive mode enabled', 'ok');
  } else {
    setAPIStatus('error', 'Read-only — use Action button or terminal for changes');
    setReadonlyUI();
    log('API unavailable — read-only mode', 'warn');
    document.getElementById('readonly-notice').style.display = 'block';
  }

  try {
    const res = await fetch('status.json?' + Date.now());
    if (res.ok) {
      const data = await res.json();
      applyStatusData(data);
      log('Status loaded from status.json', 'ok');
    }
  } catch (_) {
    log('No status.json found', 'err');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('btn-refresh')?.addEventListener('click', refreshStatus);
  document.getElementById('btn-apply')?.addEventListener('click', applySettings);

  document.querySelectorAll('.mode-btn').forEach(el => {
    el.addEventListener('click', () => setMode(el.dataset.mode));
  });

  document.getElementById('toggle-battery-saver')?.addEventListener('change', function() {
    toggleBatterySaver(this);
  });
  document.getElementById('toggle-ecn')?.addEventListener('change', function() {
    toggleEcn(this);
  });
  document.getElementById('toggle-gpu')?.addEventListener('change', function() {
    toggleGpu(this);
  });

  init();
});
