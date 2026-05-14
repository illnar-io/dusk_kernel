let KSU_API = null;
let UI_READONLY = false;
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
    const result = await KSU_API.api.exec(KSU_API.ctx, cmd);
    return (result.stdout || '').trim();
  } catch (_) {
    return '';
  }
}

function setReadonlyUI() {
  UI_READONLY = true;
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

async function init() {
  log('DUSK Companion WebUI loading...', 'info');

  KSU_API = await detectAPI();
  if (KSU_API) {
    setAPIStatus('ok', `${KSU_API.api.name} connected`);
    log('Interactive mode enabled', 'ok');
  } else {
    setAPIStatus('error', 'Read-only — use KSU Manager Action button or terminal for changes');
    setReadonlyUI();
    log('API unavailable — read-only mode', 'warn');
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
  init();
});
