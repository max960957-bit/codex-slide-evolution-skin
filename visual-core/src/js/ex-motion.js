(() => {
  "use strict";

  const config = window.SKIN_CONFIG.ex;
  const host = window.previewHost;
  const root = host.nodes.root;
  const body = host.nodes.body;
  const exLayer = host.nodes.skinLayerB;
  const tintLayer = host.nodes.skinTint;
  const lightLayer = host.nodes.ambientLight;
  const settings = {
    transitionEnabled: config.enterTransition.enabled,
    transitionDuration: config.enterTransition.duration,
    ambientEnabled: config.ambientMotion.enabled,
    ambientDuration: config.ambientMotion.cycleDuration,
    ambientIntensity: config.ambientMotion.intensity,
    debugMultiplier: 1,
    warmLightDemoEnabled: false,
    respectReducedMotion: config.ambientMotion.reducedMotionRespect,
  };
  let phase = "mainline";
  let motionProgress = 0;
  let previousLevel = window.SKIN_CONFIG.slider.min;
  let animationFrame = 0;
  let activePromise = Promise.resolve();
  let activeResolve = null;
  let routeSerial = 0;

  const clamp = window.VisualState.clamp;
  const smoothStep = (value) => {
    const t = clamp(value);
    return t * t * (3 - 2 * t);
  };
  const reducedMotionActive = () => settings.respectReducedMotion && host.reducedMotion.matches();

  function transitionProgress(progress) {
    return {
      visual: smoothStep((progress - 0.12) / 0.76),
      background: clamp(progress),
    };
  }

  function applyProgress(progress) {
    motionProgress = clamp(progress);
    const staged = transitionProgress(motionProgress);
    window.skinEngine.renderExProgress(staged.background, staged.visual);
  }

  function updateAmbientStyle() {
    const formalIntensity = clamp(settings.ambientIntensity, 0, 1.5);
    const intensity = formalIntensity * settings.debugMultiplier;
    root.style.setProperty("--ambient-duration", `${settings.ambientDuration}ms`);
    root.style.setProperty("--ambient-x-peak", `${(3 * intensity).toFixed(2)}px`);
    root.style.setProperty("--ambient-y-peak", `${(-2 * intensity).toFixed(2)}px`);
    root.style.setProperty("--ambient-scale-peak", (1 + 0.003 * intensity).toFixed(4));
    root.style.setProperty("--ambient-brightness-peak", (0.02 * intensity).toFixed(3));
    root.style.setProperty("--ambient-tint-peak", (0.03 * intensity).toFixed(3));
    root.style.setProperty("--ambient-light-duration", `${config.diagnostics.warmLightDemo.cycleDuration}ms`);
    root.style.setProperty("--ambient-light-opacity", config.diagnostics.warmLightDemo.opacity.toFixed(3));
    body.dataset.ambientDebugBoost = settings.debugMultiplier > 1 ? "true" : "false";
    body.dataset.ambientLightDemo = settings.warmLightDemoEnabled ? "true" : "false";
  }

  function stopAmbient() {
    body.classList.remove("ex-ambient-active");
    exLayer.classList.remove("is-ambient");
    tintLayer.classList.remove("is-ambient");
    lightLayer.classList.remove("is-active");
  }

  function startAmbient() {
    stopAmbient();
    updateAmbientStyle();
    if (reducedMotionActive() || phase !== "ambient") return;
    let active = false;
    if (settings.ambientEnabled) {
      exLayer.classList.add("is-ambient");
      tintLayer.classList.add("is-ambient");
      active = true;
    }
    if (settings.warmLightDemoEnabled) {
      lightLayer.classList.add("is-active");
      active = true;
    }
    if (active) body.classList.add("ex-ambient-active");
    else body.classList.remove("ex-ambient-active");
  }

  function resetDiagnostics() {
    settings.debugMultiplier = 1;
    settings.warmLightDemoEnabled = false;
    updateAmbientStyle();
  }

  function setPhase(nextPhase) {
    phase = nextPhase;
    body.dataset.exMotionState = phase;
    host.events.emit("exmotionchange", getState());
  }

  function finish(target) {
    applyProgress(target);
    if (target === 1) {
      setPhase("ambient");
      startAmbient();
    } else {
      stopAmbient();
      resetDiagnostics();
      window.skinEngine.finishExExit();
      setPhase("mainline");
    }
  }

  function animateTo(target) {
    cancelAnimationFrame(animationFrame);
    if (activeResolve) {
      activeResolve({ ...getState(), cancelled: true });
      activeResolve = null;
    }
    stopAmbient();
    const from = motionProgress;
    const distance = Math.abs(target - from);
    if (distance <= 0.000001 && ((target === 1 && phase === "ambient") || (target === 0 && phase === "mainline"))) {
      return Promise.resolve(getState());
    }
    const duration = settings.transitionDuration * distance;
    const instant = !settings.transitionEnabled || reducedMotionActive() || duration <= 1;
    setPhase(target > from ? "entering" : "exiting");
    if (instant) {
      finish(target);
      return Promise.resolve(getState());
    }

    activePromise = new Promise((resolve) => {
      activeResolve = resolve;
      const startedAt = performance.now();
      const tick = (now) => {
        const elapsed = now - startedAt;
        const local = clamp(elapsed / duration);
        applyProgress(from + (target - from) * local);
        if (local < 1) {
          animationFrame = requestAnimationFrame(tick);
        } else {
          finish(target);
          const settle = activeResolve;
          activeResolve = null;
          settle?.(getState());
        }
      };
      animationFrame = requestAnimationFrame(tick);
    });
    return activePromise;
  }

  function configure(partial = {}) {
    Object.entries(partial).forEach(([key, value]) => {
      if (Object.prototype.hasOwnProperty.call(settings, key)) settings[key] = value;
    });
    settings.transitionDuration = Math.max(0, Number(settings.transitionDuration));
    settings.ambientDuration = Math.max(1000, Number(settings.ambientDuration));
    settings.ambientIntensity = clamp(Number(settings.ambientIntensity), 0, 1.5);
    settings.debugMultiplier = clamp(Number(settings.debugMultiplier), 1, config.diagnostics.ambientTestMultiplier);
    settings.warmLightDemoEnabled = Boolean(settings.warmLightDemoEnabled);
    updateAmbientStyle();
    if (phase === "ambient") startAmbient();
    host.events.emit("exmotionchange", getState());
    return getState();
  }

  function handleVisibility() {
    if (!config.ambientMotion.pauseWhenHidden) return;
    body.dataset.ambientPaused = host.visibility.isHidden() ? "true" : "false";
  }

  function getState() {
    return {
      phase,
      previousLevel,
      levelIndex: previousLevel,
      progress: motionProgress,
      reducedMotion: reducedMotionActive(),
      settings: { ...settings },
    };
  }

  function enter(levelIndex = previousLevel) {
    if (phase === "entering") return activePromise;
    if (phase === "ambient") return Promise.resolve(getState());
    const routeId = ++routeSerial;
    if (phase === "mainline") {
      previousLevel = window.VisualState.normalizeLevelIndex(levelIndex);
      const usePelican = previousLevel === 6
        && window.pelicanTransition
        && window.pelicanTransition.canRun();
      if (usePelican) {
        stopAmbient();
        setPhase("entering");
        window.exVideoBackground?.prepareForTransition?.();
        activePromise = window.pelicanTransition.enter({ activeLevel: previousLevel }).then((result) => {
          if (routeId !== routeSerial) return getState();
          if (!result.completed) {
            window.skinEngine.prepareExTransition(previousLevel);
            return animateTo(1);
          }
          motionProgress = 1;
          setPhase("ambient");
          startAmbient();
          return { ...getState(), pelican: result };
        });
        return activePromise;
      }
      window.skinEngine.prepareExTransition(previousLevel);
    }
    return animateTo(1);
  }

  function exit() {
    routeSerial += 1;
    window.pelicanTransition?.cancel();
    return animateTo(0);
  }

  host.visibility.onChange(handleVisibility);
  host.reducedMotion.onChange(() => {
    if (reducedMotionActive() && (phase === "entering" || phase === "exiting")) {
      finish(phase === "entering" ? 1 : 0);
    } else if (phase === "ambient") {
      startAmbient();
    }
  });
  handleVisibility();
  updateAmbientStyle();

  window.exMotion = {
    enter,
    exit,
    toggle: (active) => animateTo(active ? 1 : 0),
    configure,
    getState,
    startAmbient,
    stopAmbient,
    resetDiagnostics,
    whenSettled: () => activePromise,
  };
})();
