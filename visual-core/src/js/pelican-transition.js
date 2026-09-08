(() => {
  "use strict";

  const host = window.previewHost;
  const overlay = host.nodes.pelicanOverlay;
  const image = host.nodes.pelicanImage;
  const edgeSoftener = host.nodes.pelicanEdgeSoftener;
  const edgeErode = host.nodes.pelicanEdgeErode;
  const edgeTint = host.nodes.pelicanEdgeTint;
  const clamp = window.VisualState.clamp;
  const defaults = Object.freeze({
    assetPath: "assets/transitions/pelican_occlusion.png",
    duration: 1120,
    reducedDuration: 300,
    path: Object.freeze([
      Object.freeze({ x: -0.12, y: 0.72 }),
      Object.freeze({ x: 0.12, y: 0.64 }),
      Object.freeze({ x: 0.46, y: 0.36 }),
      Object.freeze({ x: 1.10, y: -0.06 }),
    ]),
    exitOffset: Object.freeze({ x: 0.18, y: -0.16 }),
    entryEnd: 100,
    approachEnd: 380,
    occlusionPeak: 500,
    occlusionEnd: 620,
    handoffEnd: 740,
    exitEnd: 1090,
    maxScale: 1.21,
    maxBlur: 1.8,
    dissolveStart: 470,
    dissolveEnd: 740,
    fadeOutStart: 960,
    respectReducedMotion: true,
  });
  const settings = {
    ...defaults,
    path: defaults.path.map((point) => ({ ...point })),
  };
  const log = [];
  let transitionSerial = 0;
  let animationFrame = 0;
  let activeTransition = null;
  let activePromise = Promise.resolve();
  let activeResolve = null;
  let assetStatus = "loading";
  let assetReady = false;
  let maskSupported = false;
  let initPromise = null;
  let lastState = {
    transitionId: null,
    phase: "idle",
    elapsedMs: 0,
    progress: 0,
    pelicanX: 0,
    pelicanY: 0,
    scale: 0.28,
    rotate: -7,
    blur: 0,
    opacity: 0,
    exitX: 0,
    exitY: 0,
    edgeFeather: 0.55,
    edgeTintStrength: 0.035,
    currentTint: "rgb(116, 129, 159)",
    offscreenStatus: "onscreen",
    dissolveProgress: 0,
    activeLevel: 6,
    targetLevel: "EX",
    assetReady: false,
    maskSupported: false,
    fallback: null,
  };

  const smoothStep = (value) => {
    const t = clamp(value);
    return t * t * (3 - 2 * t);
  };
  const lerp = (from, to, progress) => from + (to - from) * clamp(progress);
  const segment = (time, start, end) => clamp((time - start) / Math.max(1, end - start));

  function colorBetween(from, to, progress) {
    const t = clamp(progress);
    const channels = from.map((value, index) => Math.round(lerp(value, to[index], t)));
    return `rgb(${channels.join(", ")})`;
  }

  function pathVelocityAt(time) {
    if (time < 380) return 1;
    if (time < 430) return lerp(1, 0.30, smoothStep(segment(time, 380, 430)));
    if (time < 550) return 0.30;
    if (time < 620) return lerp(0.30, 1.05, smoothStep(segment(time, 550, 620)));
    if (time < 740) return lerp(1.05, 1.18, smoothStep(segment(time, 620, 740)));
    return 1.18;
  }

  const pathTiming = (() => {
    const cumulative = [0];
    let distance = 0;
    for (let time = 1; time <= defaults.exitEnd; time += 1) {
      distance += pathVelocityAt(time - 0.5);
      cumulative.push(distance);
    }
    return { cumulative, distance };
  })();

  function pathProgressAt(time) {
    const clampedTime = clamp(time / defaults.exitEnd) * defaults.exitEnd;
    const lower = Math.floor(clampedTime);
    const upper = Math.min(defaults.exitEnd, lower + 1);
    const fraction = clampedTime - lower;
    return lerp(pathTiming.cumulative[lower], pathTiming.cumulative[upper], fraction) / pathTiming.distance;
  }

  function record(transitionId, event, detail = {}) {
    const entry = {
      timestamp: Number(performance.now().toFixed(3)),
      transitionId,
      event,
      ...detail,
    };
    log.push(entry);
    if (log.length > 300) log.splice(0, log.length - 300);
    console.debug?.("[pelican-transition]", JSON.stringify(entry));
    return entry;
  }

  function supportsMask() {
    if (typeof CSS === "undefined" || typeof CSS.supports !== "function") return false;
    const value = "radial-gradient(ellipse at center, #000 0%, transparent 100%)";
    return CSS.supports("mask-image", value) || CSS.supports("-webkit-mask-image", value);
  }

  function publish(state) {
    lastState = { ...state };
    host.events.emit("pelicantransitionchange", { ...lastState });
    return lastState;
  }

  function bezierPoint(progress, viewport) {
    const [p0, p1, p2, p3] = settings.path;
    const t = clamp(progress);
    const inverse = 1 - t;
    const x = (inverse ** 3) * p0.x
      + 3 * (inverse ** 2) * t * p1.x
      + 3 * inverse * (t ** 2) * p2.x
      + (t ** 3) * p3.x;
    const y = (inverse ** 3) * p0.y
      + 3 * (inverse ** 2) * t * p1.y
      + 3 * inverse * (t ** 2) * p2.y
      + (t ** 3) * p3.y;
    return { normalizedX: x, normalizedY: y, x: x * viewport.width, y: y * viewport.height };
  }

  function phaseAt(time) {
    if (time < settings.entryEnd) return "entry";
    if (time < settings.approachEnd) return "approach";
    if (time < settings.occlusionEnd) return "maximum-occlusion";
    if (time < settings.handoffEnd) return "handoff";
    if (time < settings.exitEnd) return "exit";
    return "cleanup";
  }

  function computeFrame(progress, viewport) {
    const referenceTime = clamp(progress) * defaults.duration;
    const pathProgress = pathProgressAt(referenceTime);
    const point = bezierPoint(pathProgress, viewport);
    const exitProgress = smoothStep(segment(referenceTime, settings.occlusionEnd, settings.exitEnd));
    const exitX = settings.exitOffset.x * viewport.width * exitProgress;
    const exitY = settings.exitOffset.y * viewport.height * exitProgress;
    point.x += exitX;
    point.y += exitY;
    point.normalizedX += settings.exitOffset.x * exitProgress;
    point.normalizedY += settings.exitOffset.y * exitProgress;
    let scale;
    let rotate;
    if (referenceTime < settings.entryEnd) {
      const t = smoothStep(segment(referenceTime, 0, settings.entryEnd));
      scale = lerp(0.28, 0.38, t);
      rotate = lerp(-7, -5, t);
    } else if (referenceTime < settings.approachEnd) {
      const t = smoothStep(segment(referenceTime, settings.entryEnd, settings.approachEnd));
      scale = lerp(0.38, 0.95, t);
      rotate = lerp(-5, -1, t);
    } else if (referenceTime < settings.occlusionPeak) {
      const t = smoothStep(segment(referenceTime, settings.approachEnd, settings.occlusionPeak));
      scale = lerp(0.95, settings.maxScale, t);
      rotate = lerp(-1, 2, t);
    } else if (referenceTime < settings.occlusionEnd) {
      const t = smoothStep(segment(referenceTime, settings.occlusionPeak, settings.occlusionEnd));
      scale = lerp(settings.maxScale, 1.12, t);
      rotate = lerp(2, 3, t);
    } else {
      const t = smoothStep(segment(referenceTime, settings.occlusionEnd, settings.exitEnd));
      scale = lerp(1.12, 0.60, t);
      rotate = lerp(3, 7, t);
    }
    const entryOpacity = smoothStep(segment(referenceTime, 0, settings.entryEnd));
    const exitOpacity = 1 - smoothStep(segment(referenceTime, settings.fadeOutStart, settings.exitEnd));
    const opacity = Math.min(entryOpacity, exitOpacity);
    const blurIn = smoothStep(segment(referenceTime, settings.approachEnd, 490));
    const blurOut = 1 - smoothStep(segment(referenceTime, 490, settings.occlusionEnd));
    const exitBlur = lerp(0.4, 0.7, segment(referenceTime, settings.occlusionEnd, settings.exitEnd));
    const blur = referenceTime < settings.occlusionEnd
      ? settings.maxBlur * blurIn * blurOut
      : exitBlur;
    const dissolveProgress = smoothStep(segment(referenceTime, settings.dissolveStart, settings.dissolveEnd));
    let edgeFeather;
    if (referenceTime < settings.approachEnd) {
      edgeFeather = lerp(0.55, 0.80, smoothStep(segment(referenceTime, 0, settings.approachEnd)));
    } else if (referenceTime < settings.occlusionPeak) {
      edgeFeather = lerp(0.80, 1.25, smoothStep(segment(referenceTime, settings.approachEnd, settings.occlusionPeak)));
    } else if (referenceTime < settings.occlusionEnd) {
      edgeFeather = lerp(1.25, 1.35, smoothStep(segment(referenceTime, settings.occlusionPeak, settings.occlusionEnd)));
    } else {
      edgeFeather = lerp(1.35, 1.75, exitProgress);
    }
    const tintProgress = smoothStep(segment(referenceTime, settings.dissolveStart, settings.dissolveEnd));
    const edgeTintStrength = lerp(0.035, 0.055, tintProgress);
    const currentTint = colorBetween([116, 129, 159], [178, 166, 137], tintProgress);
    const renderedWidth = Math.min(viewport.width * 0.74, 1680) * scale;
    const renderedHeight = renderedWidth * (941 / 1672);
    const bounds = {
      left: point.x - renderedWidth * 0.35,
      right: point.x + renderedWidth * 0.65,
      top: point.y - renderedHeight * 0.55,
      bottom: point.y + renderedHeight * 0.45,
    };
    const offscreenStatus = bounds.left >= viewport.width
      ? "offscreen-right"
      : (bounds.bottom <= 0 ? "offscreen-top" : "onscreen");
    return {
      phase: phaseAt(referenceTime),
      progress: clamp(progress),
      pelicanX: point.x,
      pelicanY: point.y,
      normalizedX: point.normalizedX,
      normalizedY: point.normalizedY,
      pathProgress,
      scale,
      rotate,
      blur,
      opacity,
      exitX,
      exitY,
      edgeFeather,
      edgeTintStrength,
      currentTint,
      offscreenStatus,
      dissolveProgress,
    };
  }

  function applyPelican(frame) {
    image.style.transform = `translate3d(${frame.pelicanX.toFixed(2)}px, ${frame.pelicanY.toFixed(2)}px, 0) translate3d(-35%, -55%, 0) scale(${frame.scale.toFixed(4)}) rotate(${frame.rotate.toFixed(3)}deg)`;
    image.style.opacity = frame.opacity.toFixed(4);
    const localFeather = Math.min(2, frame.edgeFeather);
    edgeSoftener?.setAttribute("stdDeviation", localFeather.toFixed(3));
    edgeErode?.setAttribute("radius", (localFeather * 0.85).toFixed(3));
    edgeTint?.setAttribute("flood-color", frame.currentTint);
    edgeTint?.setAttribute("flood-opacity", frame.edgeTintStrength.toFixed(4));
    image.style.filter = `url("#pelicanEdgeBlend") blur(${frame.blur.toFixed(3)}px)`;
  }

  function cleanupOverlay() {
    overlay.hidden = true;
    overlay.dataset.active = "false";
    image.style.opacity = "0";
    image.style.transform = "none";
    image.style.filter = "blur(0px)";
    image.style.willChange = "auto";
  }

  function settle(transition, result) {
    cancelAnimationFrame(animationFrame);
    cleanupOverlay();
    record(transition.id, "SETTLE", result);
    record(transition.id, "CLEANUP", { overlayHidden: true });
    record(transition.id, "END", result);
    activeTransition = null;
    const resolve = activeResolve;
    activeResolve = null;
    resolve?.(result);
  }

  function fail(transition, error) {
    try {
      window.skinEngine.abortPelicanExTransition();
    } catch (_) {
      cleanupOverlay();
    }
    const message = error instanceof Error ? error.message : String(error);
    publish({ ...lastState, phase: "fallback", fallback: "runtime-error", runtimeError: message });
    settle(transition, { completed: false, fallback: "runtime-error", runtimeError: message });
  }

  function runTimeline(transition, reduced) {
    const duration = reduced ? settings.reducedDuration : settings.duration;
    const viewport = host.getViewport();
    transition.startedAt = performance.now();
    transition.reduced = reduced;
    transition.maskEnabled = !reduced && maskSupported;
    window.skinEngine.preparePelicanExTransition(transition.activeLevel, transition.maskEnabled);
    if (!reduced) {
      overlay.hidden = false;
      overlay.dataset.active = "true";
      image.style.willChange = "transform, opacity, filter";
    }

    const tick = (now) => {
      if (!activeTransition || activeTransition.id !== transition.id) return;
      try {
        const elapsedMs = Math.min(duration, Math.max(0, now - transition.startedAt));
        const progress = clamp(elapsedMs / duration);
        const frame = reduced
          ? {
            phase: "reduced-dissolve",
            progress,
            pelicanX: 0,
            pelicanY: 0,
            normalizedX: 0.5,
            normalizedY: 0.5,
            scale: 1,
            rotate: 0,
            blur: 0,
            opacity: 0,
            exitX: 0,
            exitY: 0,
            edgeFeather: 0,
            edgeTintStrength: 0,
            currentTint: "transparent",
            offscreenStatus: "not-applicable",
            dissolveProgress: smoothStep(progress),
          }
          : computeFrame(progress, viewport);
        if (!reduced) applyPelican(frame);
        window.skinEngine.renderPelicanExProgress({
          dissolveProgress: frame.dissolveProgress,
          revealX: frame.normalizedX,
          revealY: frame.normalizedY,
          maskEnabled: transition.maskEnabled,
          phase: frame.phase,
        });
        publish({
          transitionId: transition.id,
          phase: frame.phase,
          elapsedMs,
          progress,
          pelicanX: frame.pelicanX,
          pelicanY: frame.pelicanY,
          scale: frame.scale,
          rotate: frame.rotate,
          blur: frame.blur,
          opacity: frame.opacity,
          exitX: frame.exitX,
          exitY: frame.exitY,
          edgeFeather: frame.edgeFeather,
          edgeTintStrength: frame.edgeTintStrength,
          currentTint: frame.currentTint,
          offscreenStatus: frame.offscreenStatus,
          dissolveProgress: frame.dissolveProgress,
          activeLevel: transition.activeLevel,
          targetLevel: "EX",
          assetReady,
          maskSupported,
          fallback: reduced ? "reduced-motion" : (maskSupported ? null : "mask-soft-crossfade"),
        });
        if (progress < 1) {
          animationFrame = requestAnimationFrame(tick);
        } else {
          window.skinEngine.finishPelicanExEnter();
          settle(transition, {
            completed: true,
            reduced,
            maskEnabled: transition.maskEnabled,
          });
        }
      } catch (error) {
        fail(transition, error);
      }
    };
    animationFrame = requestAnimationFrame(tick);
  }

  function init() {
    if (initPromise) return initPromise;
    maskSupported = supportsMask();
    initPromise = new Promise((resolve) => {
      image.onload = () => {
        assetReady = true;
        assetStatus = "ready";
        publish({ ...lastState, assetReady: true, maskSupported });
        resolve(true);
      };
      image.onerror = () => {
        assetReady = false;
        assetStatus = "missing";
        publish({ ...lastState, assetReady: false, maskSupported, fallback: "asset-missing" });
        resolve(false);
      };
      image.src = settings.assetPath;
    });
    return initPromise;
  }

  function enter({ activeLevel = 6 } = {}) {
    if (activeTransition) return activePromise;
    const reduced = settings.respectReducedMotion && host.reducedMotion.matches();
    if (!assetReady && !reduced) {
      publish({ ...lastState, phase: "fallback", assetReady: false, fallback: "asset-missing" });
      return Promise.resolve({ completed: false, fallback: "asset-missing" });
    }
    const transition = { id: ++transitionSerial, activeLevel };
    activeTransition = transition;
    record(transition.id, "REQUEST", { activeLevel, targetLevel: "EX" });
    record(transition.id, "START", { activeLevel, targetLevel: "EX", reduced });
    activePromise = new Promise((resolve) => {
      activeResolve = resolve;
      runTimeline(transition, reduced);
    });
    return activePromise;
  }

  function cancel() {
    if (!activeTransition) return false;
    const transition = activeTransition;
    cancelAnimationFrame(animationFrame);
    window.skinEngine.abortPelicanExTransition();
    publish({ ...lastState, phase: "cancelled", opacity: 0 });
    settle(transition, { completed: false, cancelled: true });
    return true;
  }

  function configure(partial = {}) {
    if (Number.isFinite(Number(partial.duration))) settings.duration = Math.max(850, Number(partial.duration));
    if (Number.isFinite(Number(partial.maxScale))) settings.maxScale = clamp(Number(partial.maxScale), 1.18, 1.30);
    if (Number.isFinite(Number(partial.maxBlur))) settings.maxBlur = clamp(Number(partial.maxBlur), 0, 2);
    if (Number.isFinite(Number(partial.dissolveStart))) settings.dissolveStart = clamp(Number(partial.dissolveStart), 350, 650);
    if (Number.isFinite(Number(partial.dissolveEnd))) settings.dissolveEnd = clamp(Number(partial.dissolveEnd), settings.dissolveStart + 80, 850);
    if (typeof partial.respectReducedMotion === "boolean") settings.respectReducedMotion = partial.respectReducedMotion;
    if (Array.isArray(partial.path) && partial.path.length === 4) {
      settings.path = partial.path.map((point, index) => ({
        x: Number.isFinite(Number(point.x)) ? Number(point.x) : settings.path[index].x,
        y: Number.isFinite(Number(point.y)) ? Number(point.y) : settings.path[index].y,
      }));
    }
    return getState();
  }

  function getState() {
    return {
      ...lastState,
      assetPath: settings.assetPath,
      assetStatus,
      assetReady,
      maskSupported,
      active: Boolean(activeTransition),
      settings: {
        ...settings,
        path: settings.path.map((point) => ({ ...point })),
      },
    };
  }

  host.reducedMotion.onChange(() => {
    if (activeTransition && settings.respectReducedMotion && host.reducedMotion.matches()) cancel();
  });
  cleanupOverlay();

  window.pelicanTransition = {
    init,
    enter,
    cancel,
    configure,
    computeFrame,
    canRun: () => assetReady || (settings.respectReducedMotion && host.reducedMotion.matches()),
    getState,
    getLog: () => log.map((entry) => ({ ...entry })),
    clearLog: () => { log.length = 0; },
    whenSettled: () => activePromise,
  };
})();
