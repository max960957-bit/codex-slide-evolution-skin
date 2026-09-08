(() => {
  "use strict";
  if (window.__codexD4Glass) throw new Error("D4 already mounted");
  const MAIN = "main[data-app-shell-main-surface]";
  const COMPOSER = "[data-codex-composer-root]";
  const EDITOR = "[data-codex-composer]";
  const turns = "[data-turn-key], [data-content-search-turn-key]";
  const changed = [];
  let sample = null;
  let applied = false;
  let evidence = null;
  let nativeTarget = null;
  let nativeEvidence = null;
  let nativeObserver = null, nativeFrame = 0, nativeSwitches = 0;
  let nativeRestored = true;
  let theme = null;
  function removeDiagnosticSample() {
    sample?.remove();
    sample = null;
  }
  function themeStyle(kind) {
    const { material: m, palette: p } = theme;
    const tint = kind === 'sidebar' ? p.sidebarTint : kind === 'input' ? p.inputTint : p.cardTint;
    const opacity = kind === 'sidebar' ? m.sidebarOpacity : kind === 'input' ? m.inputOpacity : m.cardOpacity;
    return { 'background-color': kind === 'card' ? 'transparent' : `rgba(${tint},${opacity})`,
      'backdrop-filter': kind === 'card' ? 'none' : `blur(${m.backdropBlur}px)`,
      color: `rgb(${p.textPrimary})`, '--color-text': `rgb(${p.textPrimary})`,
      '--color-text-secondary': `rgb(${p.textSecondary})`, '--color-text-tertiary': `rgb(${p.textMuted})`,
      '--color-token-text-primary': `rgb(${p.textPrimary})`, '--color-token-text-secondary': `rgb(${p.textSecondary})` };
  }
  function setTheme(tokens) {
    theme = tokens;
    refreshNativeSurfaces();
    for (const { node } of [...changed]) {
      const kind = node === nativeTarget ? 'card' : node.matches('[data-app-action-sidebar-scroll]') ? 'sidebar'
        : node.closest(COMPOSER) ? 'input' : null;
      if (kind) patch(node, themeStyle(kind));
    }
  }
  function findComposerSurface(editor) {
    const composer = editor?.closest(COMPOSER);
    for (let node = editor?.parentElement; node && composer?.contains(node); node = node.parentElement) {
      const s = getComputedStyle(node);
      if (s.backgroundImage === 'none' && parseFloat(s.borderTopLeftRadius) >= 8
          && s.backgroundColor !== 'rgba(0, 0, 0, 0)' && s.backgroundColor !== 'transparent') return node;
    }
    return null;
  }
  function refreshNativeSurfaces() {
    if (!theme) return;
    for (let i = changed.length - 1; i >= 0; i--) {
      if (!changed[i].node.isConnected && changed[i].node !== nativeTarget)
        nativeRestored = restoreEntry(changed.splice(i, 1)[0]) && nativeRestored;
    }
    const mains = document.querySelectorAll(MAIN);
    if (mains.length !== 1) return;
    const main = mains[0], editors = [...main.querySelectorAll(EDITOR)].filter(visible);
    const surface = editors.length === 1 ? findComposerSurface(editors[0]) : null;
    const sidebars = [...document.querySelectorAll('[data-app-action-sidebar-scroll]')].filter(node => {
      const r = node.getBoundingClientRect();
      return visible(node) && r.width >= 160 && r.width <= 360 && r.right <= main.getBoundingClientRect().left + 2;
    });
    for (const [node, kind] of [[surface, 'input'], [sidebars.length === 1 ? sidebars[0] : null, 'sidebar']]) {
      if (node && !changed.some(entry => entry.node === node)) patch(node, themeStyle(kind));
    }
  }
  const visible = node => {
    const r = node.getBoundingClientRect(), s = getComputedStyle(node);
    return r.width > 2 && r.height > 2 && s.display !== "none" && s.visibility === "visible";
  };
  const rect = node => {
    if (!node) return null;
    const r = node.getBoundingClientRect();
    return [r.left, r.top, r.width, r.height].map(n => Math.round(n * 100) / 100);
  };
  // Structural path only: never serialize IDs, attribute values, classes or content.
  function anchor(node) {
    const parts = [];
    for (let n = node; n && n !== document.body; n = n.parentElement) {
      parts.unshift(`${n.localName}:nth-child(${[...n.parentElement.children].indexOf(n) + 1})`);
    }
    return "body > " + parts.join(" > ");
  }
  function blankEditor(editor) {
    if (!editor || !visible(editor)) return false;
    if (editor.matches("textarea,input")) return editor.matches(":placeholder-shown");
    if (!editor.matches('[contenteditable="true"]')) return false;
    // Fail closed on ANY text node, including whitespace; inspect no text values.
    const emptyTree = node => [...node.childNodes].every(child =>
      child.nodeType === 1 && ["P", "BR", "DIV"].includes(child.tagName) && emptyTree(child));
    return emptyTree(editor);
  }
  function safeScreenshot() {
    const editors = [...document.querySelectorAll(EDITOR)];
    return document.visibilityState === "visible"
      && document.querySelectorAll(MAIN).length === 1
      && editors.length === 1 && blankEditor(editors[0])
      && !document.querySelector(turns)
      && ![...document.querySelectorAll('[role="dialog"],iframe,canvas,[data-codex-terminal]')].some(visible);
  }
  function snapshot(node) {
    const s = getComputedStyle(node);
    return { anchor: anchor(node), rect: rect(node), background: s.backgroundColor,
      backgroundImage: s.backgroundImage, boxShadow: s.boxShadow,
      borderTopColor: s.borderTopColor, borderBottomColor: s.borderBottomColor,
      backdropFilter: s.backdropFilter, color: s.color };
  }
  function patch(node, declarations) {
    let entry = changed.find(item => item.node === node);
    if (!entry) {
      entry = { node, before: new Map() };
      changed.push(entry);
    }
    for (const [name, value] of Object.entries(declarations)) {
      if (!entry.before.has(name)) entry.before.set(name, {
        value: node.style.getPropertyValue(name), priority: node.style.getPropertyPriority(name),
      });
      node.style.setProperty(name, value, "important");
    }
  }
  function lightPaint(value) {
    const match = value.match(/^rgba?\(([^)]+)\)$/);
    if (!match) return false;
    const c = match[1].split(/[, /]+/).map(Number);
    return c.length >= 3 && Math.min(...c.slice(0, 3)) > 210 && (c[3] ?? 1) > 0.45;
  }
  async function apply() {
    if (applied) return evidence;
    const main = document.querySelector(MAIN), editor = document.querySelector(EDITOR);
    const composer = editor?.closest(COMPOSER);
    if (!main || !composer || !visible(main) || !visible(composer)) throw new Error("D4 native anchors unavailable");
    const m = main.getBoundingClientRect();
    // Store 26.901.5280.0 home hero is a div, verified in packaged D0r.
    const headlines = [...main.querySelectorAll('div.heading-xl[data-feature="game-source"]')].filter(node => visible(node)
      && !node.closest(`${turns}, header, ${COMPOSER}`)
      && parseFloat(getComputedStyle(node).fontSize) >= 22);
    const headline = headlines.length === 1 ? headlines[0] : null;
    evidence = { headline: { status: headline ? "MATCHED" : "UNRESOLVED", count: headlines.length },
      nativeContent: { turnContainers: document.querySelectorAll("[data-turn-key]").length,
        virtualizedContainers: document.querySelectorAll("[data-virtualized-turn-content]").length,
        integration: "NOT_APPLIED" }, island: { mode: "NOT_CREATED" },
      composer: { status: "UNRESOLVED" }, topStrip: { status: "UNRESOLVED", candidates: [] } };
    applied = true; // Cleanup must also work if a later operation throws.
    if (headline) {
      evidence.headline.before = snapshot(headline);
      patch(headline, { color: "#f4f1ec", "text-shadow": "0 1px 4px rgba(14,10,7,.62)" });
      evidence.headline.after = snapshot(headline);
    }
    // Only the nearest painted, rounded ancestor of the observed editor is changed.
    const surface = findComposerSurface(editor);
    const glassStyle = { "background-color": "rgba(29,24,20,.76)", "backdrop-filter": "blur(14px) saturate(105%)",
        color: "#f4f1ec",
        "box-shadow": "inset 0 1px 0 rgba(255,239,216,.12), inset 0 -1px 0 rgba(0,0,0,.18), 0 6px 20px rgba(0,0,0,.14)",
        "--color-text": "#f4f1ec", "--color-text-secondary": "#d8cec1",
        "--color-text-tertiary": "#bfb3a4", "--color-token-text-primary": "#f4f1ec",
        "--color-token-text-secondary": "#d8cec1" };
    if (surface && composer.contains(surface)) {
      evidence.composer.before = snapshot(surface);
      patch(surface, glassStyle);
      evidence.composer.status = "APPLIED";
      evidence.composer.after = snapshot(surface);
    }
    // ponytail: one bounded geometry survey; ambiguous/pseudo-element paint remains unresolved.
    const candidates = [...main.querySelectorAll("*")].filter(node => {
      if (!visible(node) || composer.contains(node) || node.closest(turns)) return false;
      const r = node.getBoundingClientRect();
      return r.width >= m.width * .6 && r.height <= 90 && r.top >= m.top - 2 && r.top <= m.top + 100;
    }).slice(0, 24);
    const removable = [];
    for (const node of candidates) {
      const s = getComputedStyle(node);
      const paint = snapshot(node);
      paint.beforePseudoBackground = getComputedStyle(node, "::before").backgroundImage;
      paint.afterPseudoBackground = getComputedStyle(node, "::after").backgroundImage;
      const decoration = (s.pointerEvents === "none" || node.getAttribute("aria-hidden") === "true")
        && !node.querySelector('button,a,input,textarea,[contenteditable="true"],[role="button"]')
        && !node.matches('button,a,input,textarea,[role="button"]');
      paint.decorative = decoration;
      evidence.topStrip.candidates.push(paint);
      // Exact 16px fades observed in saved light and dark host runs.
      const knownFade = node.getBoundingClientRect().height <= 20
        && ["linear-gradient(rgb(255, 255, 255), rgba(0, 0, 0, 0))", "linear-gradient(rgb(24, 24, 24), rgba(0, 0, 0, 0))"].includes(s.backgroundImage)
        && s.backgroundColor === "rgba(0, 0, 0, 0)";
      if (decoration && paint.beforePseudoBackground === "none" && paint.afterPseudoBackground === "none"
          && s.boxShadow === "none" && ((lightPaint(s.backgroundColor) && s.backgroundImage === "none") || knownFade)) removable.push(node);
    }
    if (removable.length === 1) {
      evidence.topStrip.target = snapshot(removable[0]);
      patch(removable[0], { "background-color": "transparent", "background-image": "none" });
      evidence.topStrip.status = "DECORATIVE_BACKGROUND_CLEARED_NEEDS_VISUAL_REVIEW";
    }
    // Verified Vsr / ComposerHomeUtilityBar in Store 26.901.5280.0, not a message/banner.
    const contextSelector = '[data-composer-rail-item][data-composer-placement="home"][data-composer-rail-variant="controls"]';
    // The native utility bar is lazy-loaded and may mount after the editor.
    let contextWaitMs = 0;
    while (!main.querySelector(contextSelector) && contextWaitMs < 1500) {
      await new Promise(resolve => setTimeout(resolve, 100));
      contextWaitMs += 100;
    }
    // Measure after style/layout commits, rather than reusing the pre-patch composer rect.
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    // The root can expand upward to include the toolbar; use the actual input surface.
    const composerSurface = surface || composer;
    const c = composerSurface.getBoundingClientRect();
    const contextAnchors = [...main.querySelectorAll(contextSelector)];
    const contextSurfaces = contextAnchors.filter(node => {
      if (!visible(node) || node.contains(editor) || node.closest(`${turns}, [inert], [aria-hidden="true"]`)) return false;
      const r = node.getBoundingClientRect(), s = getComputedStyle(node);
      // The real toolbar is inset about 13px on both sides of the composer.
      const leftInset = r.left - c.left, rightInset = c.right - r.right;
      return r.height >= 12 && r.height <= 64 && leftInset >= -2 && leftInset <= 24
        && rightInset >= -2 && rightInset <= 24 && Math.abs(leftInset - rightInset) <= 4
        && r.bottom <= c.top + 8 && r.bottom >= c.top - 48
        && s.backgroundImage === "none" && s.backgroundColor !== "rgba(0, 0, 0, 0)";
    });
    evidence.composerContext = { status: "UNRESOLVED", count: contextSurfaces.length, contextWaitMs,
      composerRect: rect(composerSurface), rootRect: rect(composer), candidates: contextAnchors.slice(0, 12).map(node => ({ ...snapshot(node), accepted: contextSurfaces.includes(node) })) };
    if (contextSurfaces.length === 1) {
      const toolbar = contextSurfaces[0];
      patch(toolbar, glassStyle);
      evidence.composerContext.status = "APPLIED";
      evidence.composerContext.after = snapshot(toolbar);
    }
    const islandWidth = Math.min(400, m.width * .4);
    evidence.homeIcon = { status: "NOT_APPLIED" };
    evidence.sidebar = { status: "UNRESOLVED" };
    const sidebars = [...document.querySelectorAll('[data-app-action-sidebar-scroll]')].filter(node => {
      const r = node.getBoundingClientRect();
      return visible(node) && r.width >= 160 && r.width <= 360 && r.right <= m.left + 2;
    });
    if (sidebars.length === 1) {
      const sidebar = sidebars[0];
      evidence.sidebar.before = snapshot(sidebar);
      patch(sidebar, { "background-color": "rgba(233,222,208,.72)", "backdrop-filter": "blur(14px) saturate(90%)" });
      evidence.sidebar.status = "APPLIED";
      evidence.sidebar.after = snapshot(sidebar);
    }
    // ponytail: fixed L1 composition for wide lab windows; narrow windows keep native layout.
    if (headline && safeScreenshot() && m.width >= 800) {
      patch(headline, { width: `${islandWidth}px`, "max-width": `${islandWidth}px`,
        height: "auto", "font-size": "24px", "line-height": "1.4", "text-align": "left",
        "justify-content": "flex-start" });
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      const h = headline.getBoundingClientRect();
      patch(headline, { translate: `${m.left + 28 - h.left}px ${m.top + 150 - h.top}px` });
      evidence.headline.layout = "L1_LEFT_COLUMN";
      evidence.headline.after = snapshot(headline);
      // Verified native _0r anchor. Individual translate preserves native hover/rotation transform.
      const icons = [...main.querySelectorAll('[data-testid="home-icon"]')].filter(node => visible(node)
        && node.parentElement === headline.parentElement && node.getAttribute("aria-hidden") === "true");
      if (icons.length === 1) {
        const icon = icons[0], r = icon.getBoundingClientRect();
        evidence.homeIcon.before = snapshot(icon);
        patch(icon, { translate: `${m.left + 28 - r.left}px ${m.top + 72 - r.top}px`, color: "#f4f1ec" });
        evidence.homeIcon = { ...evidence.homeIcon, status: "APPLIED", after: snapshot(icon) };
      }
    }
    if (safeScreenshot() && headline) {
      const h = headline.getBoundingClientRect();
      const top = h.bottom + 18, bottom = Math.min(composerSurface.getBoundingClientRect().top - 48, ...contextSurfaces.map(node => node.getBoundingClientRect().top)) - 18;
      const width = evidence.headline.layout === "L1_LEFT_COLUMN" ? islandWidth : Math.min(460, m.width * .55);
      evidence.island.layout = { headlineRect: rect(headline), composerRect: rect(composerSurface), top, bottom, width, availableHeight: bottom - top, requiredHeight: 118 };
      if (bottom - top >= 118 && width >= 280) {
        sample = document.createElement("section");
        sample.id = "codex-d4-content-sample";
        sample.setAttribute("aria-hidden", "true");
        sample.style.cssText = `position:fixed;box-sizing:border-box;pointer-events:none;z-index:10;left:${m.left + 28}px;top:${top}px;width:${width}px;height:118px;padding:16px 20px;border-radius:16px;background:rgba(34,27,22,.48);backdrop-filter:blur(14px) saturate(105%);color:#f4f1ec;border:1px solid rgba(247,226,199,.12);box-shadow:inset 0 1px 0 rgba(255,241,222,.14),inset 0 -1px 0 rgba(0,0,0,.18),0 6px 20px rgba(0,0,0,.12);font:14px/1.55 system-ui;`;
        for (const [tag, text] of [["small", "D4 · LOCAL MATERIAL SAMPLE"], ["p", "玻璃承载信息，背景保留呼吸。"], ["code", "const stage = 'L1'; // local sample"]]) {
          const child = document.createElement(tag);
          child.appendChild(document.createTextNode(text));
          child.style.cssText = tag === "p" ? "margin:5px 0" : tag === "small" ? "font-size:10px;letter-spacing:.08em;color:#d8cec1" : "font-size:12px;color:#b8e4c9";
          sample.appendChild(child);
        }
        document.body.appendChild(sample);
        evidence.island = { ...evidence.island, mode: "LOCAL_SAMPLE_NOT_NATIVE_MESSAGE", rect: rect(sample) };
      } else evidence.island.mode = "SKIPPED_INSUFFICIENT_SPACE";
    } else evidence.island.mode = "SKIPPED_PRIVATE_OR_NO_HEADLINE";
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    evidence.horizontalOverflow = document.documentElement.scrollWidth > document.documentElement.clientWidth;
    evidence.visualAcceptance = "PENDING_USER_REVIEW";
    evidence.pendingChecks = [
      ["headline", evidence.headline.status === "MATCHED"],
      ["composer", evidence.composer.status === "APPLIED"],
      ["composerContext", evidence.composerContext.status === "APPLIED"],
      ["contentSample", evidence.island.mode === "LOCAL_SAMPLE_NOT_NATIVE_MESSAGE"],
      ["topStrip", evidence.topStrip.status === "DECORATIVE_BACKGROUND_CLEARED_NEEDS_VISUAL_REVIEW"],
      ["sidebar", evidence.sidebar.status === "APPLIED"],
      ["homeIcon", evidence.homeIcon.status === "APPLIED"],
    ].filter(([, passed]) => !passed).map(([name]) => name);
    return evidence;
  }
  function boundaries() {
    return [...changed.map(item => item.node), sample].filter(Boolean);
  }
  function nativeCandidates() {
    const main = document.querySelector(MAIN);
    if (!main) return [];
    // Store sD marks final assistant blocks; turn wrappers also contain user/tool content.
    return [...main.querySelectorAll('[data-local-conversation-final-assistant="true"]')].filter(node => {
      const r = node.getBoundingClientRect();
      let left = Math.max(0, r.left), right = Math.min(innerWidth, r.right);
      let top = Math.max(0, r.top), bottom = Math.min(innerHeight, r.bottom);
      for (let parent = node.parentElement; parent; parent = parent.parentElement) {
        const s = getComputedStyle(parent), p = parent.getBoundingClientRect();
        if (s.display === "none" || s.visibility === "hidden" || Number(s.opacity) === 0) return false;
        if (s.overflowX !== "visible") { left = Math.max(left, p.left); right = Math.min(right, p.right); }
        if (s.overflowY !== "visible") { top = Math.max(top, p.top); bottom = Math.min(bottom, p.bottom); }
      }
      return visible(node) && node.closest(turns) && !node.closest(COMPOSER)
        && right - left > 2 && bottom - top > 2 && Number(getComputedStyle(node).opacity) > 0
        && !node.closest('[aria-hidden="true"],[inert]')
        && !node.querySelector('iframe,canvas,[data-mcp-app-expanded],[contenteditable="true"],textarea');
    });
  }
  function applyNativeContent() {
    if (nativeTarget) return nativeTarget.isConnected ? nativeEvidence : { status: "TARGET_DETACHED" };
    const candidates = nativeCandidates();
    const target = candidates.at(-1);
    if (!target) return { status: "NOT_FOUND", candidateCount: candidates.length };
    const before = snapshot(target);
    patch(target, { "background-color": "transparent", "background-image": "none", "backdrop-filter": "none",
      "border-color": "transparent", "box-shadow": "none",
      color: "#f4f1ec", "--color-text": "#f4f1ec", "--color-text-secondary": "#d8cec1",
      "--color-text-tertiary": "#bfb3a4", "--color-token-text-primary": "#f4f1ec", "--color-token-text-secondary": "#d8cec1" });
    nativeTarget = target;
    if (theme) patch(target, themeStyle('card'));
    nativeEvidence = { status: "APPLIED", mode: "ONE_VISIBLE_FINAL_ASSISTANT", candidateCount: candidates.length,
      before, after: snapshot(target), geometryUnchanged: JSON.stringify(before.rect) === JSON.stringify(rect(target)),
      screenshot: "DISABLED_CONTENT_REVIEW", visualAcceptance: "PENDING_USER_REVIEW" };
    return nativeEvidence;
  }
  function restoreEntry({ node, before }) {
    let restored = true;
    for (const [name, old] of before) {
      if (old.value) node.style.setProperty(name, old.value, old.priority);
      else node.style.removeProperty(name);
      restored &&= node.style.getPropertyValue(name) === old.value && node.style.getPropertyPriority(name) === old.priority;
    }
    return restored;
  }
  function refreshNativeContent() {
    refreshNativeSurfaces();
    const next = nativeCandidates().at(-1);
    if (nativeTarget && next !== nativeTarget) {
      const index = changed.findIndex(item => item.node === nativeTarget);
      if (index >= 0) nativeRestored = restoreEntry(changed.splice(index, 1)[0]) && nativeRestored;
      nativeTarget = null;
      nativeEvidence = null;
      nativeSwitches++;
    }
    return { ...applyNativeContent(), tracking: "ONE_VISIBLE_BLOCK", switches: nativeSwitches, previousTargetsRestored: nativeRestored };
  }
  function scheduleNativeRefresh() {
    if (!nativeObserver || nativeFrame) return;
    nativeFrame = requestAnimationFrame(() => { nativeFrame = 0; refreshNativeContent(); });
  }
  function startNativeContentTracking() {
    if (!nativeObserver) {
      nativeObserver = new MutationObserver(scheduleNativeRefresh);
      // Observe structural/style changes without reading content. A stable target is not patched again,
      // so notifications from our own style writes settle after one extra refresh.
      nativeObserver.observe(document.body, { childList: true, subtree: true, characterData: true,
        attributes: true, attributeFilter: ["data-local-conversation-final-assistant", "aria-hidden", "inert", "hidden", "class", "style"] });
      window.addEventListener("scroll", scheduleNativeRefresh, true);
      window.addEventListener("resize", scheduleNativeRefresh);
    }
    return refreshNativeContent();
  }
  function cleanup() {
    nativeObserver?.disconnect();
    nativeObserver = null;
    cancelAnimationFrame(nativeFrame);
    nativeFrame = 0;
    window.removeEventListener("scroll", scheduleNativeRefresh, true);
    window.removeEventListener("resize", scheduleNativeRefresh);
    const sampleId = sample?.id;
    sample?.remove();
    let restored = nativeRestored;
    for (const entry of changed.reverse()) restored = restoreEntry(entry) && restored;
    changed.length = 0;
    delete window.__codexD4Glass;
    return { restored, sampleRemoved: !sampleId || !document.getElementById(sampleId) };
  }
  window.__codexD4Glass = { safeScreenshot, apply, applyNativeContent, startNativeContentTracking, refreshNativeContent, setTheme, removeDiagnosticSample, boundaries, cleanup };
  return true;
})();
