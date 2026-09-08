(() => {
  "use strict";

  const config = window.SKIN_CONFIG;
  const visualState = window.VisualState;
  const host = window.previewHost;
  const root = host.nodes.root;
  const body = host.nodes.body;
  const layerA = host.nodes.skinLayerA;
  const layerB = host.nodes.skinLayerB;
  const loaded = new Map();
  const anchors = config.visualTokens;
  const mainlineCrossfade = config.mainline.backgroundTransition;
  const lockedExCrossfade = config.ex.enterTransition.staggeredCrossfade;
  let currentLevel = config.slider.min;
  let targetLevel = currentLevel;
  let exActive = false;
  let exSourceState = visualState.getLevelState(currentLevel);
  let currentDisplayedSource = null;
  let lastSegment = "";
  let lastAppliedState = null;
  let transitionFrame = 0;
  let transitionResolve = null;
  let transitionPromise = Promise.resolve();
  let transitionSerial = 0;
  let activeTransition = null;
  let activeLayer = layerA;
  let inactiveLayer = layerB;
  const transitionLog = [];
  const stableMotion = Object.freeze({ motionOffsetX: 0, motionOffsetY: 0, motionScale: 1 });
  const transientMotion = Object.freeze({
    startupEnd: 80 / mainlineCrossfade.duration,
    completionEnd: 300 / mainlineCrossfade.duration,
    startupCompletion: 0.16,
    up: Object.freeze({
      incoming: Object.freeze({ motionOffsetX: 14, motionOffsetY: 4, motionScale: 0.997 }),
      outgoing: Object.freeze({ motionOffsetX: -7, motionOffsetY: -3, motionScale: 1 }),
    }),
    down: Object.freeze({
      incoming: Object.freeze({ motionOffsetX: -12, motionOffsetY: -4, motionScale: 0.997 }),
      outgoing: Object.freeze({ motionOffsetX: 7, motionOffsetY: 3, motionScale: 1 }),
    }),
  });
  let lastMotionState = {
    transitionId: null,
    direction: "none",
    progress: 1,
    motionProgress: 1,
    phase: "stable",
    incoming: { ...stableMotion },
    outgoing: { ...stableMotion },
  };

  const smoothStep = (value) => {
    const t = visualState.clamp(value);
    return t * t * (3 - 2 * t);
  };

  const easeOutCubic = (value) => {
    const t = visualState.clamp(value);
    return 1 - ((1 - t) ** 3);
  };

  const layerName = (layer) => layer === layerA ? "A" : "B";

  function recordTransition(transitionId, fromLevel, toLevel, event, detail = {}) {
    const entry = {
      timestamp: Number(performance.now().toFixed(3)),
      transitionId,
      fromLevel,
      toLevel,
      event,
      ...detail,
    };
    transitionLog.push(entry);
    if (transitionLog.length > 500) transitionLog.splice(0, transitionLog.length - 500);
    if (typeof console !== "undefined" && typeof console.debug === "function") {
      console.debug("[mainline-transition]", JSON.stringify(entry));
    }
    return entry;
  }

  function preload(asset) {
    if (asset.available === false) {
      loaded.set(asset.id, { ok: false, status: "missing", path: asset.path, required: asset.required, skipped: true });
      return Promise.resolve(null);
    }
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => {
        loaded.set(asset.id, { ok: true, status: "ready", path: asset.path, required: asset.required, width: image.naturalWidth, height: image.naturalHeight });
        resolve(image);
      };
      image.onerror = () => {
        loaded.set(asset.id, { ok: false, status: "missing", path: asset.path, required: asset.required });
        if (asset.required) reject(new Error(`无法加载 ${asset.path}`));
        else resolve(null);
      };
      image.src = asset.path;
    });
  }

  function setLayerMaterial(layer, material) {
    layer.style.setProperty("--skin-brightness", material.brightness);
    layer.style.setProperty("--skin-saturation", material.saturation);
  }

  function setLayerMotion(layer, motion = stableMotion) {
    layer.style.setProperty("--skin-motion-x", `${motion.motionOffsetX.toFixed(3)}px`);
    layer.style.setProperty("--skin-motion-y", `${motion.motionOffsetY.toFixed(3)}px`);
    layer.style.setProperty("--skin-motion-scale", motion.motionScale.toFixed(6));
  }

  function getMotionProgress(progress) {
    const t = visualState.clamp(Number(progress));
    if (t <= transientMotion.startupEnd) {
      return transientMotion.startupCompletion * smoothStep(t / transientMotion.startupEnd);
    }
    if (t >= transientMotion.completionEnd) return 1;
    const mainProgress = (t - transientMotion.startupEnd)
      / (transientMotion.completionEnd - transientMotion.startupEnd);
    return transientMotion.startupCompletion
      + (1 - transientMotion.startupCompletion) * easeOutCubic(mainProgress);
  }

  function getMainlineMotionState(fromLevel, toLevel, progress) {
    const direction = Number(toLevel) > Number(fromLevel) ? "up" : "down";
    const definition = transientMotion[direction];
    const motionProgress = getMotionProgress(progress);
    const incomingRemaining = 1 - motionProgress;
    const scaledMotion = (value, amount) => (value * amount) || 0;
    return {
      direction,
      progress: visualState.clamp(Number(progress)),
      motionProgress,
      incoming: {
        motionOffsetX: scaledMotion(definition.incoming.motionOffsetX, incomingRemaining),
        motionOffsetY: scaledMotion(definition.incoming.motionOffsetY, incomingRemaining),
        motionScale: definition.incoming.motionScale
          + (1 - definition.incoming.motionScale) * motionProgress,
      },
      outgoing: {
        motionOffsetX: scaledMotion(definition.outgoing.motionOffsetX, motionProgress),
        motionOffsetY: scaledMotion(definition.outgoing.motionOffsetY, motionProgress),
        motionScale: 1,
      },
    };
  }

  function publishMotionState(state) {
    lastMotionState = {
      ...state,
      incoming: { ...state.incoming },
      outgoing: { ...state.outgoing },
    };
    host.events.emit("mainlinemotionchange", lastMotionState);
    return lastMotionState;
  }

  function applyTransitionMotion(transition, progress) {
    const state = getMainlineMotionState(
      transition.fromState.levelIndex,
      transition.toState.levelIndex,
      progress,
    );
    setLayerMotion(transition.incomingLayer, state.incoming);
    setLayerMotion(transition.outgoingLayer, state.outgoing);
    return publishMotionState({
      transitionId: transition.id,
      ...state,
      phase: state.motionProgress >= 1 ? "motion-complete" : "moving",
    });
  }

  function publishStableMotion(transition) {
    return publishMotionState({
      transitionId: transition?.id || null,
      direction: transition
        ? (transition.toState.levelIndex > transition.fromState.levelIndex ? "up" : "down")
        : "none",
      progress: 1,
      motionProgress: 1,
      phase: "stable",
      incoming: { ...stableMotion },
      outgoing: { ...stableMotion },
    });
  }

  function setLayer(layer, source, material) {
    const sourceId = source.slotId || source.assetAnchor;
    if (layer.dataset.anchor !== sourceId) {
      layer.style.backgroundImage = `url("${source.image}")`;
      layer.dataset.anchor = sourceId;
    }
    const background = source.background;
    layer.style.setProperty("--skin-x", background.positionX);
    layer.style.setProperty("--skin-y", background.positionY);
    layer.style.setProperty("--skin-translate-x", background.translateX || 0);
    layer.style.setProperty("--skin-translate-y", background.translateY || 0);
    layer.style.setProperty("--skin-scale", background.scale);
    layer.style.backgroundSize = `auto ${background.size}%`;
    setLayerMaterial(layer, material);
  }

  function setStableLayerPair(nextActiveLayer) {
    activeLayer = nextActiveLayer;
    inactiveLayer = activeLayer === layerA ? layerB : layerA;
    activeLayer.classList.add("is-visible");
    inactiveLayer.classList.remove("is-visible");
  }

  function prepareHiddenLayer(layer, source, material) {
    layer.style.transition = "none";
    setLayerOpacity(layer, 0);
    setLayerMotion(layer);
    setLayer(layer, source, material);
  }

  function cleanupHiddenLayer(layer) {
    layer.style.transition = "none";
    layer.classList.remove("is-visible", "is-ambient");
    setLayerOpacity(layer, 0);
    setLayerMotion(layer);
  }

  const levelSource = (state) => ({ slotId: state.imageSlotId, image: state.image, background: state.background });
  const levelAssetReady = (state) => Boolean(loaded.get(state.imageSlotId)?.ok);

  function applyVisualState(tokens, meta = {}) {
    const { material, palette } = tokens;
    const opacityProperties = {
      sidebarOpacity: "--sidebar-opacity",
      contentOpacity: "--content-opacity",
      cardOpacity: "--card-opacity",
      inputOpacity: "--input-opacity",
      topbarOpacity: "--topbar-opacity",
      modelSelectorOpacity: "--model-selector-opacity",
    };
    Object.entries(opacityProperties).forEach(([key, property]) => {
      root.style.setProperty(property, material[key].toFixed(3));
    });
    root.style.setProperty("--backdrop-blur", `${material.backdropBlur.toFixed(1)}px`);
    root.style.setProperty("--skin-tint", material.warmTint.toFixed(3));
    root.style.setProperty("--skin-vignette", material.vignette.toFixed(3));
    root.style.setProperty("--tint-rgb", palette.baseBackground);
    root.style.setProperty("--accent-rgb", palette.accentColor);
    root.style.setProperty("--accent", `rgb(${palette.accentColor})`);
    root.style.setProperty("--surface-topbar-rgb", palette.topbarTint);
    root.style.setProperty("--surface-sidebar-rgb", palette.sidebarTint);
    root.style.setProperty("--surface-content-rgb", palette.contentTint);
    root.style.setProperty("--surface-card-rgb", palette.cardTint);
    root.style.setProperty("--surface-input-rgb", palette.inputTint);
    root.style.setProperty("--surface-model-rgb", palette.modelTint);
    root.style.setProperty("--text-primary", `rgb(${palette.textPrimary})`);
    root.style.setProperty("--text-secondary", `rgba(${palette.textSecondary}, ${palette.textSecondaryAlpha.toFixed(3)})`);
    root.style.setProperty("--text-muted", `rgba(${palette.textMuted}, ${palette.textMutedAlpha.toFixed(3)})`);
    root.style.setProperty("--hairline", `rgba(${palette.borderColor}, ${palette.borderAlpha.toFixed(3)})`);
    body.dataset.theme = tokens.id;
    lastAppliedState = { ...meta, tokens };
    host.events.emit("visualstatechange", lastAppliedState);
  }

  function setLayerOpacity(layer, opacity, blur = 0) {
    layer.style.opacity = String(visualState.clamp(opacity));
    layer.style.setProperty("--skin-exit-blur", `${Math.max(0, blur).toFixed(2)}px`);
  }

  function getStaggeredState(progress, curve) {
    const t = visualState.clamp(Number(progress));
    const outgoingFast = smoothStep(t / curve.outgoingFastFadeEnd);
    const outgoingTail = smoothStep(
      (t - curve.outgoingFastFadeEnd) / (curve.outgoingFadeOutEnd - curve.outgoingFastFadeEnd),
    );
    const outgoingOpacity = t <= curve.outgoingFastFadeEnd
      ? 1 - (1 - curve.outgoingFastFadeOpacity) * outgoingFast
      : curve.outgoingFastFadeOpacity * (1 - outgoingTail);
    const incomingFirst = smoothStep(
      (t - curve.incomingDelayProgress) / (curve.incomingFirstFadeEnd - curve.incomingDelayProgress),
    );
    const incomingTail = smoothStep(
      (t - curve.incomingFirstFadeEnd) / (curve.incomingFadeInEnd - curve.incomingFirstFadeEnd),
    );
    const incomingOpacity = t <= curve.incomingFirstFadeEnd
      ? curve.incomingFirstFadeOpacity * incomingFirst
      : curve.incomingFirstFadeOpacity + (1 - curve.incomingFirstFadeOpacity) * incomingTail;
    const blurIn = smoothStep(
      (t - curve.outgoingBlurInStart) / (curve.outgoingBlurInEnd - curve.outgoingBlurInStart),
    );
    const blurOut = 1 - smoothStep(
      (t - curve.outgoingBlurOutStart) / (curve.outgoingBlurOutEnd - curve.outgoingBlurOutStart),
    );
    return {
      outgoingOpacity: visualState.clamp(outgoingOpacity),
      incomingOpacity: visualState.clamp(incomingOpacity),
      outgoingBlur: curve.outgoingBlurPeak * blurIn * blurOut,
    };
  }

  function getMainlineBackgroundState(progress) {
    return getStaggeredState(progress, mainlineCrossfade);
  }

  function getExBackgroundState(progress) {
    return getStaggeredState(progress, {
      incomingDelayProgress: lockedExCrossfade.exDelayProgress,
      outgoingFastFadeEnd: lockedExCrossfade.commandFastFadeEnd,
      outgoingFastFadeOpacity: lockedExCrossfade.commandFastFadeOpacity,
      outgoingFadeOutEnd: lockedExCrossfade.commandFadeOutEnd,
      incomingFirstFadeEnd: lockedExCrossfade.exFirstFadeEnd,
      incomingFirstFadeOpacity: lockedExCrossfade.exFirstFadeOpacity,
      incomingFadeInEnd: lockedExCrossfade.exFadeInEnd,
      outgoingBlurPeak: lockedExCrossfade.commandBlurPeak,
      outgoingBlurInStart: lockedExCrossfade.commandBlurInStart,
      outgoingBlurInEnd: lockedExCrossfade.commandBlurInEnd,
      outgoingBlurOutStart: lockedExCrossfade.commandBlurOutStart,
      outgoingBlurOutEnd: lockedExCrossfade.commandBlurOutEnd,
    });
  }

  function stabilizeLevel(value, options = {}) {
    const state = visualState.getLevelState(value);
    const assetReady = levelAssetReady(state);
    const stableLayer = options.layer || activeLayer;
    const hiddenLayer = stableLayer === layerA ? layerB : layerA;
    currentLevel = state.levelIndex;
    targetLevel = currentLevel;
    exActive = false;
    if (assetReady) {
      currentDisplayedSource = levelSource(state);
      if (stableLayer.dataset.anchor !== currentDisplayedSource.slotId) {
        prepareHiddenLayer(stableLayer, currentDisplayedSource, state.tokens.material);
      } else {
        setLayerMaterial(stableLayer, state.tokens.material);
      }
    } else {
      setLayerMaterial(stableLayer, state.tokens.material);
    }
    setLayerOpacity(stableLayer, 1);
    cleanupHiddenLayer(hiddenLayer);
    setStableLayerPair(stableLayer);
    body.dataset.levelAssetStatus = assetReady ? "ready" : "missing";
    lastSegment = `level:${state.levelId}:${assetReady ? "ready" : "asset-missing"}`;
    applyVisualState(state.tokens, {
      mode: "level-stable",
      levelIndex: state.levelIndex,
      levelId: state.levelId,
      imageSlot: state.imageSlotId,
      imagePath: state.image,
      imageStatus: assetReady ? "ready" : "missing",
      displayedImageSlot: currentDisplayedSource?.slotId || null,
    });
    return { ...state, imageStatus: assetReady ? "ready" : "missing", displayedImageSlot: currentDisplayedSource?.slotId || null };
  }

  function cancelLevelTransition() {
    if (!activeTransition || !transitionResolve) return null;
    const transition = activeTransition;
    cancelAnimationFrame(transitionFrame);
    const resolve = transitionResolve;
    transitionResolve = null;
    activeTransition = null;
    setLayerMotion(transition.incomingLayer || transition.outgoingLayer);
    const settled = stabilizeLevel(transition.toState.levelIndex, {
      instant: true,
      layer: transition.incomingLayer || transition.outgoingLayer,
    });
    recordTransition(transition.id, transition.fromState.levelIndex, transition.toState.levelIndex, "SETTLE", { cancelled: true });
    recordTransition(transition.id, transition.fromState.levelIndex, transition.toState.levelIndex, "CLEANUP", {
      cancelled: true,
      activeLayer: layerName(activeLayer),
    });
    recordTransition(transition.id, transition.fromState.levelIndex, transition.toState.levelIndex, "END", { cancelled: true });
    publishStableMotion(transition);
    resolve({ ...settled, cancelled: true });
    return settled;
  }

  function animateLevelTransition(transition, duration, render) {
    transitionPromise = new Promise((resolve) => {
      transitionResolve = resolve;
      transition.resolve = resolve;
      transition.promise = transitionPromise;
      activeTransition = transition;
      const startedAt = performance.now();
      const tick = (now) => {
        if (!activeTransition || activeTransition.id !== transition.id) return;
        const progress = visualState.clamp((now - startedAt) / duration);
        render(progress);
        if (progress < 1) {
          transitionFrame = requestAnimationFrame(tick);
        } else {
          transitionResolve = null;
          activeTransition = null;
          recordTransition(transition.id, transition.fromState.levelIndex, transition.toState.levelIndex, "SETTLE");
          const settled = stabilizeLevel(transition.toState.levelIndex, {
            instant: true,
            layer: transition.incomingLayer || transition.outgoingLayer,
          });
          recordTransition(transition.id, transition.fromState.levelIndex, transition.toState.levelIndex, "CLEANUP", {
            activeLayer: layerName(activeLayer),
          });
          recordTransition(transition.id, transition.fromState.levelIndex, transition.toState.levelIndex, "END");
          publishStableMotion(transition);
          resolve(settled);
        }
      };
      transitionFrame = requestAnimationFrame(tick);
    });
    return transitionPromise;
  }

  function setLevel(value, options = {}) {
    const nextLevel = visualState.normalizeLevelIndex(value);
    if (activeTransition && nextLevel === targetLevel) return transitionPromise;
    if (!activeTransition && nextLevel === currentLevel) {
      return Promise.resolve({ ...visualState.getLevelState(currentLevel), ignored: true });
    }
    cancelLevelTransition();
    const fromState = visualState.getLevelState(currentLevel);
    const toState = visualState.getLevelState(nextLevel);
    const transitionId = ++transitionSerial;
    targetLevel = nextLevel;
    recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "REQUEST");
    recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "START");
    if (options.instant) {
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, `BACKGROUND_${layerName(activeLayer)}_SET`, { role: "active" });
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "UI_START");
      const settled = stabilizeLevel(nextLevel, { instant: true });
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "SETTLE", { instant: true });
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "CLEANUP", { instant: true, activeLayer: layerName(activeLayer) });
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "END", { instant: true });
      return Promise.resolve(settled);
    }

    const targetAssetReady = levelAssetReady(toState);
    const sameBackground = !targetAssetReady || currentDisplayedSource?.image === toState.image;
    const duration = Math.max(1, Number(options.duration || (
      sameBackground ? config.mainline.sameBackgroundDuration : mainlineCrossfade.duration
    )));
    lastSegment = `${fromState.levelId}:${toState.levelId}`;

    if (sameBackground) {
      const transition = {
        id: transitionId,
        fromState,
        toState,
        outgoingLayer: activeLayer,
        incomingLayer: null,
      };
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, `BACKGROUND_${layerName(activeLayer)}_SET`, { role: "retained" });
      recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "UI_START");
      return animateLevelTransition(transition, duration, (progress) => {
        const visualProgress = smoothStep(progress);
        const tokens = visualState.interpolateVisualTokens(fromState.tokens, toState.tokens, visualProgress);
        setLayerMaterial(activeLayer, tokens.material);
        setLayerOpacity(activeLayer, 1);
        setLayerOpacity(inactiveLayer, 0);
        applyVisualState(tokens, {
          mode: "level-material-transition",
          fromLevel: fromState.levelIndex,
          toLevel: toState.levelIndex,
          imageSlot: toState.imageSlotId,
          imageStatus: targetAssetReady ? "ready" : "missing",
          displayedImageSlot: currentDisplayedSource?.slotId || null,
          progress: visualProgress,
        });
      });
    }

    const outgoingLayer = activeLayer;
    const incomingLayer = inactiveLayer;
    outgoingLayer.style.transition = "none";
    setLayer(outgoingLayer, currentDisplayedSource, fromState.tokens.material);
    prepareHiddenLayer(incomingLayer, levelSource(toState), fromState.tokens.material);
    recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, `BACKGROUND_${layerName(outgoingLayer)}_SET`, { role: "outgoing" });
    recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, `BACKGROUND_${layerName(incomingLayer)}_SET`, { role: "incoming" });
    recordTransition(transitionId, fromState.levelIndex, toState.levelIndex, "UI_START");
    const transition = { id: transitionId, fromState, toState, outgoingLayer, incomingLayer };
    applyTransitionMotion(transition, 0);
    return animateLevelTransition(transition, duration, (progress) => {
      const visualProgress = smoothStep(progress);
      const tokens = visualState.interpolateVisualTokens(fromState.tokens, toState.tokens, visualProgress);
      const backgroundState = getMainlineBackgroundState(progress);
      setLayerMaterial(outgoingLayer, tokens.material);
      setLayerMaterial(incomingLayer, tokens.material);
      setLayerOpacity(outgoingLayer, backgroundState.outgoingOpacity, backgroundState.outgoingBlur);
      setLayerOpacity(incomingLayer, backgroundState.incomingOpacity);
      const motionState = applyTransitionMotion(transition, progress);
      applyVisualState(tokens, {
        mode: "level-background-transition",
        fromLevel: fromState.levelIndex,
        toLevel: toState.levelIndex,
        fromImageSlot: currentDisplayedSource.slotId,
        toImageSlot: toState.imageSlotId,
        progress: visualProgress,
        backgroundProgress: progress,
        backgroundState,
        motionState,
      });
    });
  }

  function prepareExTransition(levelValue = currentLevel) {
    cancelLevelTransition();
    exSourceState = { ...stabilizeLevel(levelValue, { instant: true, layer: layerA }), displaySource: currentDisplayedSource };
    return exSourceState;
  }

  function setPelicanRevealMask(dissolveProgress, revealX, revealY, enabled) {
    const dissolve = visualState.clamp(Number(dissolveProgress));
    if (!enabled || dissolve >= 0.999) {
      layerB.classList.remove("is-pelican-reveal");
      body.dataset.pelicanReveal = enabled ? "complete" : "soft-crossfade";
      return;
    }
    const x = visualState.clamp(Number(revealX) - 0.055, -0.2, 1.2);
    const y = visualState.clamp(Number(revealY) + 0.035, -0.2, 1.2);
    layerB.style.setProperty("--pelican-reveal-x", `${(x * 100).toFixed(2)}%`);
    layerB.style.setProperty("--pelican-reveal-y", `${(y * 100).toFixed(2)}%`);
    layerB.style.setProperty("--pelican-reveal-rx", `${(3 + 147 * dissolve).toFixed(2)}vw`);
    layerB.style.setProperty("--pelican-reveal-ry", `${(2 + 118 * dissolve).toFixed(2)}vh`);
    layerB.classList.add("is-pelican-reveal");
    body.dataset.pelicanReveal = "masked";
  }

  function preparePelicanExTransition(levelValue = currentLevel, maskEnabled = true) {
    const sourceState = prepareExTransition(levelValue);
    prepareHiddenLayer(layerB, anchors.ex, sourceState.tokens.material);
    setPelicanRevealMask(0, 0.5, 0.5, maskEnabled);
    body.dataset.pelicanTransition = "prepared";
    return sourceState;
  }

  function renderPelicanExProgress({
    dissolveProgress = 0,
    revealX = 0.5,
    revealY = 0.5,
    maskEnabled = true,
    phase = "entry",
  } = {}) {
    const dissolve = visualState.clamp(Number(dissolveProgress));
    const from = exSourceState;
    const tokens = visualState.interpolateVisualTokens(from.tokens, anchors.ex, dissolve);
    const l6Fade = smoothStep((dissolve - 0.38) / 0.62);
    const l6Blur = 3 * Math.sin(Math.PI * dissolve);
    exActive = dissolve > 0;
    lastSegment = `${from.levelId}:pelican:freedom`;
    setLayerMaterial(layerA, tokens.material);
    setLayerMaterial(layerB, tokens.material);
    setLayerOpacity(layerA, 1 - l6Fade, l6Blur);
    setLayerOpacity(layerB, maskEnabled ? (dissolve > 0 ? 1 : 0) : dissolve);
    setPelicanRevealMask(dissolve, revealX, revealY, maskEnabled);
    applyVisualState(tokens, {
      mode: "pelican-ex-transition",
      sourceLevel: from.levelIndex,
      sourceLevelId: from.levelId,
      sourceImageSlot: from.imageSlotId,
      displayedImageSlot: from.displaySource?.slotId || null,
      targetImageSlot: anchors.ex.assetAnchor,
      progress: dissolve,
      dissolveProgress: dissolve,
      revealX,
      revealY,
      maskEnabled,
      phase,
    });
    return { sourceLevel: from.levelIndex, progress: dissolve, dissolveProgress: dissolve, maskEnabled, tokens };
  }

  function finishPelicanExEnter() {
    setLayerOpacity(layerA, 0);
    setLayerOpacity(layerB, 1);
    layerB.classList.remove("is-pelican-reveal");
    body.dataset.pelicanReveal = "complete";
    body.dataset.pelicanTransition = "ambient";
    exActive = true;
    lastSegment = `${exSourceState.levelId}:pelican:freedom:stable`;
    applyVisualState(anchors.ex, {
      mode: "ex-stable",
      sourceLevel: exSourceState.levelIndex,
      sourceLevelId: exSourceState.levelId,
      imageSlot: anchors.ex.assetAnchor,
      progress: 1,
      via: "pelican-occlusion",
    });
    return { sourceLevel: exSourceState.levelIndex, progress: 1, tokens: anchors.ex };
  }

  function abortPelicanExTransition() {
    layerB.classList.remove("is-pelican-reveal");
    body.dataset.pelicanReveal = "aborted";
    body.dataset.pelicanTransition = "idle";
    setLayerOpacity(layerB, 0);
    return stabilizeLevel(exSourceState.levelIndex, { instant: true, layer: layerA });
  }

  function renderExProgress(backgroundProgress, visualProgress = backgroundProgress) {
    const backgroundT = visualState.clamp(Number(backgroundProgress));
    const visualT = visualState.clamp(Number(visualProgress));
    const from = exSourceState;
    const to = anchors.ex;
    exActive = backgroundT > 0 || visualT > 0;
    root.style.setProperty("--skin-duration", "1ms");
    root.style.setProperty("--skin-filter-duration", "1ms");
    const tokens = visualState.interpolateVisualTokens(from.tokens, to, visualT);
    const backgroundState = getExBackgroundState(backgroundT);
    setLayer(layerA, from.displaySource, tokens.material);
    setLayer(layerB, to, tokens.material);
    lastSegment = `${from.levelId}:freedom`;
    setLayerOpacity(layerA, backgroundState.outgoingOpacity, backgroundState.outgoingBlur);
    setLayerOpacity(layerB, backgroundState.incomingOpacity);
    applyVisualState(tokens, {
      mode: "ex-transition",
      sourceLevel: from.levelIndex,
      sourceLevelId: from.levelId,
      sourceImageSlot: from.imageSlotId,
      sourceImageStatus: from.imageStatus,
      displayedImageSlot: from.displaySource?.slotId || null,
      backgroundProgress: backgroundT,
      progress: visualT,
      backgroundState,
    });
    return { sourceLevel: from.levelIndex, backgroundProgress: backgroundT, progress: visualT, backgroundState, tokens };
  }

  function finishExExit() {
    layerB.classList.remove("is-pelican-reveal");
    body.dataset.pelicanTransition = "idle";
    return stabilizeLevel(exSourceState.levelIndex, { instant: true, layer: layerA });
  }

  function renderEx(active) {
    if (active) prepareExTransition(currentLevel);
    return active ? renderExProgress(1, 1) : finishExExit();
  }

  async function init() {
    const list = [
      ...config.levels.map((level) => level.imageSlot),
      { id: "image-ex", path: anchors.ex.image, required: true, available: true },
    ];
    const results = await Promise.allSettled(list.map(preload));
    const errors = results.filter((result) => result.status === "rejected");
    if (errors.length) throw new Error(errors.map((item) => item.reason.message).join("; "));
    stabilizeLevel(config.slider.min, { instant: true });
    layerA.classList.add("is-visible");
    return Object.fromEntries(loaded);
  }

  function diagnostics() {
    return {
      ready: [...loaded.values()].filter((item) => item.required).every((item) => item.ok),
      loaded: Object.fromEntries(loaded),
      currentLevel,
      targetLevel,
      previousLevel: exSourceState.levelIndex,
      currentImageSlot: currentDisplayedSource?.slotId || null,
      currentAssetStatus: body.dataset.levelAssetStatus,
      exActive,
      lastSegment,
      lastAppliedState,
      transitionRunning: Boolean(transitionResolve),
      activeTransitionId: activeTransition?.id || null,
      activeLayer: layerName(activeLayer),
      lastMotionState: {
        ...lastMotionState,
        incoming: { ...lastMotionState.incoming },
        outgoing: { ...lastMotionState.outgoing },
      },
      visibleLayers: [activeLayer, inactiveLayer].map((layer) => ({
        layer: layerName(layer),
        anchor: layer.dataset.anchor,
        opacity: Number(layer.style.opacity || 0),
        filter: layer.style.values?.["--skin-exit-blur"] || layer.style.getPropertyValue?.("--skin-exit-blur") || "0px",
        transform: layer.style.transform || "",
        backgroundPosition: layer.style.backgroundPosition || "",
        backgroundSize: layer.style.backgroundSize || "",
        stablePositionX: layer.style.values?.["--skin-x"] || layer.style.getPropertyValue?.("--skin-x") || "",
        stablePositionY: layer.style.values?.["--skin-y"] || layer.style.getPropertyValue?.("--skin-y") || "",
        stableTranslateX: layer.style.values?.["--skin-translate-x"] || layer.style.getPropertyValue?.("--skin-translate-x") || "0",
        stableTranslateY: layer.style.values?.["--skin-translate-y"] || layer.style.getPropertyValue?.("--skin-translate-y") || "0",
        stableScale: layer.style.values?.["--skin-scale"] || layer.style.getPropertyValue?.("--skin-scale") || "",
        motionOffsetX: layer.style.values?.["--skin-motion-x"] || layer.style.getPropertyValue?.("--skin-motion-x") || "0px",
        motionOffsetY: layer.style.values?.["--skin-motion-y"] || layer.style.getPropertyValue?.("--skin-motion-y") || "0px",
        motionScale: layer.style.values?.["--skin-motion-scale"] || layer.style.getPropertyValue?.("--skin-motion-scale") || "1",
      })),
      transitionLog: transitionLog.map((entry) => ({ ...entry })),
    };
  }

  window.skinEngine = {
    init,
    setLevel,
    prepareExTransition,
    preparePelicanExTransition,
    renderEx,
    renderExProgress,
    renderPelicanExProgress,
    finishPelicanExEnter,
    abortPelicanExTransition,
    finishExExit,
    getLevelState: visualState.getLevelState,
    getMainlineBackgroundState,
    getMainlineMotionState,
    getExBackgroundState,
    whenLevelSettled: () => transitionPromise,
    getTransitionLog: () => transitionLog.map((entry) => ({ ...entry })),
    clearTransitionLog: () => { transitionLog.length = 0; },
    diagnostics,
  };
})();
