(() => {
  "use strict";

  const config = window.SKIN_CONFIG.ex.videoBackground;
  const host = window.previewHost;
  let video = host.nodes.exVideo;
  const standby = video.cloneNode(false);
  standby.removeAttribute('id');
  video.parentElement.appendChild(standby);
  const videos = [video, standby];
  let loopFrame = 0, incoming = null, incomingReady = false, loopCount = 0;
  const overlap = 0.7;
  let requested = false;
  let sourcesReady = false;
  let prepared = false;
  let playbackFailed = false;

  function reducedMotionActive() {
    return config.reducedMotionFallback && host.reducedMotion.matches();
  }

  function prepare() {
    if (prepared) return sourcesReady;
    prepared = true;
    video.muted = Boolean(config.muted);
    video.loop = false;
    video.autoplay = false;
    video.playsInline = Boolean(config.playsInline);
    video.preload = "auto";
    video.poster = config.poster;
    if (!config.enabled) return false;
    for (const [type, src] of Object.entries(config.sources)) {
      if (!src) continue;
      const source = host.createElement("source");
      source.src = src;
      source.type = `video/${type}`;
      video.appendChild(source);
      sourcesReady = true;
    }
    standby.muted = true; standby.loop = false; standby.autoplay = false; standby.playsInline = true;
    standby.poster = config.poster;
    for (const source of video.querySelectorAll('source')) standby.appendChild(source.cloneNode());
    for (const item of videos) { item.style.transition = 'none'; if (sourcesReady) item.load(); }
    return sourcesReady;
  }

  function followLoop() {
    loopFrame = 0;
    if (!requested || reducedMotionActive() || host.visibility.isHidden()) return;
    const remaining = video.duration - video.currentTime;
    if (config.loop && Number.isFinite(remaining) && remaining <= overlap && !incoming) {
      incoming = videos.find(item => item !== video);
      const next = incoming;
      next.currentTime = 0; next.style.zIndex = '2'; video.style.zIndex = '1';
      next.style.opacity = '0'; next.classList.add('is-active');
      next.play().then(() => { if (incoming === next) incomingReady = true; }, () => { playbackFailed = true; pause(); });
    }
    if (incoming && incomingReady) {
      // The outgoing video stays opaque underneath: no dimming to the poster between cycles.
      const mix = Math.min(1, incoming.currentTime / overlap);
      incoming.style.opacity = String(mix * mix * (3 - 2 * mix));
      if (mix >= 1) {
        const old = video; video = incoming; incoming = null; incomingReady = false;
        old.pause(); old.classList.remove('is-active'); old.style.opacity = '0';
        video.style.opacity = '1'; loopCount++;
      }
    }
    loopFrame = requestAnimationFrame(followLoop);
  }

  function pause() {
    host.nodes.body.dataset.exVideoPlaying = 'false';
    cancelAnimationFrame(loopFrame); loopFrame = 0;
    if (incoming) { incoming.pause(); incoming = null; incomingReady = false; }
    for (const item of videos) { item.pause(); item.classList.remove('is-active'); item.style.opacity = '0'; }
  }

  async function playIfAllowed(visible = true) {
    if (!requested || !config.enabled || !sourcesReady || reducedMotionActive() || host.visibility.isHidden()) {
      pause();
      return false;
    }
    video.classList.toggle("is-active", visible);
    host.nodes.body.dataset.exVideoPlaying = String(visible);
    video.style.opacity = visible ? '1' : '0';
    if (video.ended) video.currentTime = 0;
    try {
      await video.play();
      playbackFailed = false;
      if (!loopFrame) loopFrame = requestAnimationFrame(followLoop);
      return true;
    } catch (_) {
      playbackFailed = true;
      pause();
      return false;
    }
  }

  function activate() {
    requested = true;
    return playIfAllowed();
  }

  function prepareForTransition() {
    requested = true;
    return playIfAllowed(true);
  }

  function deactivate() {
    requested = false;
    pause();
  }

  host.visibility.onChange(() => {
    if (!config.pauseWhenHidden) return;
    if (host.visibility.isHidden()) pause();
    else playIfAllowed();
  });
  host.reducedMotion.onChange(playIfAllowed);
  video.addEventListener("error", () => {
    playbackFailed = true;
    pause();
  });
  video.addEventListener("loadeddata", () => {
    playbackFailed = false;
  });
  host.events.on("exmotionchange", (event) => {
    if (event.detail.phase === "ambient") activate();
    else if (event.detail.phase === "mainline") deactivate();
  });

  prepare();
  window.exVideoBackground = {
    activate,
    prepareForTransition,
    deactivate,
    getState: () => ({
      requested,
      sourcesReady,
      playing: !video.paused,
      readyState: video.readyState,
      playbackFailed,
      reducedMotion: reducedMotionActive(),
      loopCount,
      crossfading: incoming !== null,
    }),
  };
})();
