// Build template. Core runs in a private namespace and owned Shadow DOM.
(async () => {
  const realWindow = globalThis;
  if (realWindow.__codexSequence) throw Error('Sequence already mounted');
  const parent = document.getElementById('codex-skin-root');
  if (!parent) throw Error('Validated visual root required');
  const media = /* ASSET_DATA */;
  const urls = new Map();
  function asset(name) {
    if (!urls.has(name)) {
      // Avoid materializing a character iterable for multi-megabyte assets in the host renderer.
      const item = media[name], binary = atob(item.data), bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
      urls.set(name, URL.createObjectURL(new Blob([bytes], { type: item.type })));
      delete media[name];
    }
    return urls.get(name);
  }
  const mount = document.createElement('div');
  mount.style.cssText = 'position:fixed;inset:0;pointer-events:none';
  const shadow = mount.attachShadow({ mode: 'open' });
  shadow.innerHTML = /* MARKUP */;
  const style = document.createElement('style');
  style.textContent = /* CSS */;
  style.textContent += `
    :host([data-ex-video-playing="true"]) #skinLayerB { inset:0; transform:none; filter:none; }
    :host([data-ex-video-playing="true"]) .ex-ambient-video { inset:0; width:100%; height:100%; object-fit:cover; }
  `;
  shadow.prepend(style);
  parent.appendChild(mount);
  const window = {}, events = new EventTarget(), abort = new AbortController(), frames = new Set();
  let disposed = false, busy = false, stopRequested = false, visited = new Set(), exSeen = false, videoPlayed = false;
  let selectionSerial = 0;
  const requestAnimationFrame = callback => {
    const id = realWindow.requestAnimationFrame(time => { frames.delete(id); if (!disposed) callback(time); });
    frames.add(id); return id;
  };
  const cancelAnimationFrame = id => { frames.delete(id); realWindow.cancelAnimationFrame(id); };
  const query = selector => shadow.querySelector(selector);
  const motion = realWindow.matchMedia('(prefers-reduced-motion: reduce)');
  window.previewHost = {
    nodes: { root: mount, body: mount, skinLayerA: query('#skinLayerA'), skinLayerB: query('#skinLayerB'),
      skinTint: query('.skin-tint'), ambientLight: query('#ambientLightDemo'), exVideo: query('#exAmbientVideo'),
      pelicanOverlay: query('#pelicanTransitionOverlay'), pelicanImage: query('#pelicanOcclusion'),
      pelicanEdgeSoftener: query('#pelicanEdgeSoftener'), pelicanEdgeErode: query('#pelicanEdgeErode'), pelicanEdgeTint: query('#pelicanEdgeTint') },
    createElement: tag => document.createElement(tag),
    getViewport: () => ({ width: innerWidth, height: innerHeight }),
    reducedMotion: { matches: () => motion.matches, onChange: fn => motion.addEventListener('change', fn, { signal: abort.signal }) },
    visibility: { isHidden: () => document.hidden, onChange: fn => document.addEventListener('visibilitychange', fn, { signal: abort.signal }) },
    events: { emit: (type, detail) => events.dispatchEvent(new CustomEvent(type, { detail })), on: (type, fn) => events.addEventListener(type, fn, { signal: abort.signal }) },
  };
  query('video').addEventListener('playing', () => { videoPlayed = true; }, { signal: abort.signal });
  const controls = document.createElement('div');
  controls.style.cssText = 'position:fixed;right:20px;top:56px;max-width:calc(100vw - 40px);z-index:2147483646;pointer-events:auto';
  const panel = controls.attachShadow({ mode: 'open' });
  panel.innerHTML = '<style>:host{font:13px system-ui;color:#f4f1ec}nav{background:#26221fec;padding:10px;border-radius:12px;display:flex;gap:6px;align-items:center}button{font:inherit;background:#494139;color:inherit;border:1px solid #938475;border-radius:6px;padding:7px;cursor:pointer}button:disabled{opacity:.5}button[aria-pressed=true]{background:#866746}output{min-width:70px}</style><nav aria-label="换肤档位"><output aria-live="polite">载入中</output></nav>';
  const nav = panel.querySelector('nav'), output = panel.querySelector('output');
  nav.style.flexWrap = 'wrap';
  // The desktop panel owns Stop; direct legacy launches retain their controls.
  if (!realWindow.__codexSequenceTransfer?.externalStop) document.body.appendChild(controls);
  let nativeObserver = null, nativeFrame = 0, nativeKey = null, nativePending = null;
  let nativePower = { state: 'WAITING_FOR_MENU' };
  function flushNativePower() {
    if (disposed || stopRequested || nativePending === null) return;
    if (busy && (nativePending === 'ex' || window.exMotion.getState().phase !== 'mainline')) return;
    const level = nativePending; nativePending = null;
    if (level === 'ex' && window.exMotion.getState().phase !== 'mainline') return;
    select(level).catch(() => { nativePower = { state: 'SYNC_FAILED' }; output.textContent = '联动失败'; });
  }
  function readNativePower() {
    // Store 26.901.5280.0: read only the Power slider's public numeric attributes.
    const roots = [...document.querySelectorAll('[data-reasoning-slider] [data-model-picker-power-slider]')].filter(n => {
      const r = n.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && getComputedStyle(n).visibility === 'visible'
        && !n.closest('[inert],[data-disabled],[aria-disabled="true"]');
    });
    if (roots.length !== 1) { nativeKey = null; nativePower = { state: roots.length ? 'AMBIGUOUS' : 'MENU_CLOSED' }; return; }
    const thumbs = roots[0].querySelectorAll('[role="slider"]');
    if (thumbs.length !== 1) { nativePower = { state: 'UNSUPPORTED' }; return; }
    const raw = ['aria-valuemin', 'aria-valuemax', 'aria-valuenow'].map(a => thumbs[0].getAttribute(a));
    const [min, max, value] = raw.map(Number);
    if (raw.some(v => v === null || v.trim() === '') || ![min,max,value].every(Number.isInteger)
      || min !== 0 || max < 1 || max > 19 || value < min || value > max) { nativePower = { state: 'UNSUPPORTED' }; return; }
    const ticks = roots[0].querySelectorAll('[data-selected]');
    if (ticks.length !== max + 1 || ticks[value].getAttribute('data-locked') === 'true') {
      nativePower = { state: 'UNSUPPORTED_OR_LOCKED' }; return;
    }
    // ponytail: distribute the visible native positions across six images; fewer positions skip images.
    const fastRoots = roots[0].querySelectorAll('[data-fast-mode]');
    const fastValue = fastRoots.length === 1 ? fastRoots[0].getAttribute('data-fast-mode') : null;
    const fastKnown = fastValue === 'true' || fastValue === 'false', fast = fastValue === 'true';
    const level = 1 + Math.round(value / max * 5), key = `${max}:${value}:${fastValue}`;
    nativePower = { state: 'FOLLOWING', position: value + 1, count: max + 1, level, fast: fastKnown ? fast : null };
    panel.querySelectorAll('input,[data-value]').forEach(n => {
      if (n.tagName === 'INPUT' || /^\d+$/.test(n.dataset.value) || fastKnown) n.hidden = true;
    });
    if (key !== nativeKey) { nativeKey = key; nativePending = fast ? 'ex' : level; flushNativePower(); }
  }
  function scheduleNativePower() {
    if (nativeFrame || disposed || stopRequested) return;
    nativeFrame = requestAnimationFrame(() => { nativeFrame = 0; readNativePower(); });
  }
  function status() {
    const skin = window.skinEngine.diagnostics();
    return { ready: skin.ready, level: skin.currentLevel, targetLevel: skin.targetLevel, phase: window.exMotion.getState().phase,
      visibleLayers: skin.visibleLayers.map(l => ({ anchor: l.anchor, opacity: l.opacity })),
      visited: [...visited], exSeen, videoPlayed, video: window.exVideoBackground.getState(), nativePower, busy, stopRequested };
  }
  async function select(value) {
    if (disposed || stopRequested) return false;
    if (value !== 'ex' && value !== 'return' && ![1,2,3,4,5,6].includes(value)) throw Error('Invalid level');
    const mainlineRequest = typeof value === 'number' && window.exMotion.getState().phase === 'mainline';
    if (busy && !mainlineRequest) return false;
    const serial = ++selectionSerial;
    busy = true;
    panel.querySelectorAll('[data-value]').forEach(b => b.disabled = true);
    const slider = panel.querySelector('input');
    if (slider) slider.disabled = !mainlineRequest;
    if (mainlineRequest) output.textContent = `L${value}`;
    try {
      if (value === 'ex') { await window.exMotion.enter(window.skinEngine.diagnostics().currentLevel); exSeen = true; }
      else {
        if (window.exMotion.getState().phase !== 'mainline') await window.exMotion.exit();
        if (value !== 'return') await window.skinEngine.setLevel(value);
        if (serial === selectionSerial) visited.add(window.skinEngine.diagnostics().currentLevel);
      }
      if (disposed || serial !== selectionSerial) return false;
      output.textContent = value === 'ex' ? 'EX · 逍遥' : `L${window.skinEngine.diagnostics().currentLevel}`;
      const slider = panel.querySelector('input');
      if (slider) slider.value = window.skinEngine.diagnostics().currentLevel;
      panel.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.value === (value === 'ex' ? 'ex' : String(window.skinEngine.diagnostics().currentLevel)))));
      return status();
    } finally {
      if (serial === selectionSerial) {
        busy = false; panel.querySelectorAll('[data-value],input').forEach(b => b.disabled = stopRequested);
        if (stopRequested) output.textContent = '正在结束换肤…';
        else flushNativePower();
      }
    }
  }
  function cleanup() {
    nativeObserver?.disconnect(); nativePending = null;
    disposed = true; abort.abort(); frames.forEach(id => realWindow.cancelAnimationFrame(id)); frames.clear();
    for (const video of shadow.querySelectorAll('video')) { video.pause(); video.removeAttribute('src'); video.replaceChildren(); video.load(); }
    controls.remove(); mount.remove(); urls.forEach(url => URL.revokeObjectURL(url)); urls.clear();
    delete realWindow.__codexSequence;
    return { removed: !mount.isConnected && !controls.isConnected, frames: frames.size, objectUrls: urls.size };
  }
  realWindow.__codexSequence = { select, status, cleanup };
  try {
    /* VISUAL_CORE */
    window.exMotion.configure({ ambientEnabled: false, warmLightDemoEnabled: false });
    realWindow.__codexD4Glass?.removeDiagnosticSample();
    events.addEventListener('visualstatechange', event => realWindow.__codexD4Glass?.setTheme(event.detail.tokens), { signal: abort.signal });
    await window.skinEngine.init();
    if (disposed) return false;
    for (const [value, label] of [...window.SKIN_CONFIG.levels.map(l => [l.index, `${l.displayLabel} ${l.narrativeLabel}`]), ['ex', 'EX 逍遥'], ['return', '返回']]) {
      const button = document.createElement('button'); button.type = 'button'; button.textContent = label; button.dataset.value = String(value);
      button.addEventListener('click', () => select(value).catch(() => { output.textContent = '切换失败'; }), { signal: abort.signal });
      nav.appendChild(button);
    }
    const slider = document.createElement('input');
    slider.type = 'range'; slider.min = '1'; slider.max = '6'; slider.step = '1'; slider.value = '1';
    slider.setAttribute('aria-label', '换肤档位');
    slider.addEventListener('input', () => select(Number(slider.value)).catch(() => { output.textContent = '切换失败'; }), { signal: abort.signal });
    nav.appendChild(slider);
    const stop = document.createElement('button'); stop.type = 'button'; stop.textContent = '结束换肤';
    stop.addEventListener('click', () => {
      stopRequested = true; output.textContent = '正在结束换肤…';
      panel.querySelectorAll('button,input').forEach(n => n.disabled = true);
    }, { signal: abort.signal });
    nav.appendChild(stop);
    await select(1);
    nativeObserver = new MutationObserver(scheduleNativePower);
    nativeObserver.observe(document.body, { subtree: true, childList: true, attributes: true,
      attributeFilter: ['aria-valuenow','aria-valuemin','aria-valuemax','data-selected','data-locked','data-fast-mode','data-disabled','aria-disabled','hidden'] });
    realWindow.addEventListener('resize', scheduleNativePower, { signal: abort.signal });
    readNativePower();
    return status();
  } catch (error) { cleanup(); throw error; }
})();
