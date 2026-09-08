(() => {
  "use strict";

  const config = window.SKIN_CONFIG;
  const anchors = config.visualTokens;

  const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));
  const lerpNumber = (from, to, progress) => from + (to - from) * progress;
  const lerpOpacity = (from, to, progress) => clamp(lerpNumber(from, to, progress));
  const clone = (value) => JSON.parse(JSON.stringify(value));
  const normalizeLevelIndex = (value) => {
    const numeric = Math.round(Number(value));
    return clamp(Number.isFinite(numeric) ? numeric : config.slider.min, config.slider.min, config.levels.length);
  };
  const resolveAnchor = (anchorId) => anchors[config.anchorAliases[String(anchorId)]];

  const parseRgb = (value) => String(value).split(",").map((channel) => Number(channel.trim()));
  const srgbToLinear = (channel) => {
    const value = channel / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  };
  const linearToSrgb = (channel) => {
    const value = channel <= 0.0031308
      ? channel * 12.92
      : 1.055 * channel ** (1 / 2.4) - 0.055;
    return Math.round(clamp(value) * 255);
  };
  const lerpColor = (from, to, progress) => {
    const fromRgb = parseRgb(from).map(srgbToLinear);
    const toRgb = parseRgb(to).map(srgbToLinear);
    return fromRgb
      .map((channel, index) => linearToSrgb(lerpNumber(channel, toRgb[index], progress)))
      .join(", ");
  };

  const interpolateObject = (from, to, progress, colorKeys = []) => {
    const result = {};
    Object.keys(from).forEach((key) => {
      if (colorKeys.includes(key)) {
        result[key] = lerpColor(from[key], to[key], progress);
      } else if (typeof from[key] === "number" && typeof to[key] === "number") {
        result[key] = key.toLowerCase().includes("opacity") || key.toLowerCase().includes("alpha")
          ? lerpOpacity(from[key], to[key], progress)
          : lerpNumber(from[key], to[key], progress);
      } else {
        result[key] = progress < 0.5 ? from[key] : to[key];
      }
    });
    return result;
  };

  const paletteColorKeys = [
    "baseBackground", "sidebarTint", "contentTint", "cardTint", "inputTint", "topbarTint",
    "modelTint", "borderColor", "textPrimary", "textSecondary", "textMuted", "accentColor",
  ];

  const interpolateVisualTokens = (from, to, progress) => {
    const t = clamp(progress);
    if (t === 0) return clone(from);
    if (t === 1) return clone(to);
    return {
      id: `${from.id}-${to.id}`,
      assetAnchor: t < 0.5 ? from.assetAnchor : to.assetAnchor,
      label: t < 0.5 ? from.label : to.label,
      shortLabel: t < 0.5 ? from.shortLabel : to.shortLabel,
      image: t < 0.5 ? from.image : to.image,
      background: interpolateObject(from.background, to.background, t),
      material: interpolateObject(from.material, to.material, t),
      palette: interpolateObject(from.palette, to.palette, t, paletteColorKeys),
    };
  };

  function resolveLevelTokens(level) {
    const spec = level.visualState;
    const base = spec.anchor
      ? clone(resolveAnchor(spec.anchor))
      : interpolateVisualTokens(resolveAnchor(spec.from), resolveAnchor(spec.to), spec.progress);
    const adjustments = level.tokenAdjustments;
    if (!adjustments) return base;
    return {
      ...base,
      ...clone(adjustments),
      background: { ...base.background, ...clone(adjustments.background || {}) },
      material: { ...base.material, ...clone(adjustments.material || {}) },
      palette: { ...base.palette, ...clone(adjustments.palette || {}) },
    };
  }

  function getLevelState(value) {
    const levelIndex = normalizeLevelIndex(value);
    const level = config.levels[levelIndex - 1];
    const tokens = resolveLevelTokens(level);
    return {
      levelIndex,
      levelId: level.id,
      displayLabel: level.displayLabel,
      narrativeLabel: level.narrativeLabel,
      imageSlot: clone(level.imageSlot),
      imageSlotId: level.imageSlot.id,
      image: level.imageSlot.path,
      background: clone(level.backgroundState || tokens.background),
      tokens,
    };
  }

  function interpolateLevelStates(fromValue, toValue, progress) {
    const from = getLevelState(fromValue);
    const to = getLevelState(toValue);
    const t = clamp(progress);
    return {
      fromLevel: from.levelIndex,
      toLevel: to.levelIndex,
      progress: t,
      tokens: interpolateVisualTokens(from.tokens, to.tokens, t),
    };
  }

  window.VisualState = Object.freeze({
    clamp,
    lerpNumber,
    lerpOpacity,
    lerpColor,
    interpolateVisualTokens,
    normalizeLevelIndex,
    resolveAnchor,
    resolveLevelTokens,
    getLevelState,
    interpolateLevelStates,
    getExState: () => clone(config.ex.state),
  });
})();
