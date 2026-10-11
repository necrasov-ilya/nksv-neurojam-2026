/* Injected only into staged launch HTML, before the unmodified game scripts. */
(() => {
  'use strict';
  const root = new URL('./', document.currentScript.src);
  const gameBase = new URL('./', location.href);
  const rawNow = performance.now.bind(performance);
  const rawDateNow = Date.now.bind(Date);
  const nativeRAF = window.requestAnimationFrame.bind(window);
  const nativeCancelRAF = window.cancelAnimationFrame.bind(window);
  const nativeTimeout = window.setTimeout.bind(window);
  const nativeClearTimeout = window.clearTimeout.bind(window);
  const contexts = new Set();
  const media = new Set();
  const playingMedia = new Set();
  const pressed = new Map();
  const rafs = new Map();
  const timers = new Map();
  let nextID = 1;
  let paused = false;
  let muted = false;
  let pauseStart = 0;
  let pausedMillis = 0;
  let capturePending = false;
  const send = (type, value) => parent.postMessage({kind: 'latent-frame', type, value}, location.origin);
  const logicalNow = () => rawNow() - pausedMillis - (paused ? rawNow() - pauseStart : 0);
  Object.defineProperty(performance, 'now', {value: logicalNow, configurable: true});
  Date.now = () => rawDateNow() - pausedMillis - (paused ? rawNow() - pauseStart : 0);

  // CEF is off-screen: the Godot window owns cursor confinement and relative input.
  // Browser builds retain the browser's original Pointer Lock implementation.
  const embedded = Boolean(new URLSearchParams(parent.location.search).get('token'));
  let lockedElement = null;
  let lockRequest = 0;
  let pendingLock = null;
  if (embedded) {
    Object.defineProperty(document, 'pointerLockElement', {configurable: true, get: () => lockedElement});
    Element.prototype.requestPointerLock = function() {
      if (paused || pendingLock) return Promise.reject(new DOMException('Среда не активна', 'InvalidStateError'));
      return new Promise((resolve, reject) => {
        pendingLock = {element: this, request: ++lockRequest, resolve, reject};
        send('pointer-lock-request', {request: lockRequest, locked: true});
      });
    };
    document.exitPointerLock = () => {
      if (pendingLock) {
        pendingLock.reject(new DOMException('Захват отменён', 'AbortError'));
        pendingLock = null;
      }
      if (lockedElement) {
        lockedElement = null;
        document.dispatchEvent(new Event('pointerlockchange'));
      }
      send('pointer-lock-request', {request: ++lockRequest, locked: false});
    };
  }
  function acceptPointerLock(value) {
    if (!embedded || !pendingLock || value.request !== pendingLock.request) return;
    const request = pendingLock;
    pendingLock = null;
    if (value.locked && !paused) {
      lockedElement = request.element;
      document.dispatchEvent(new Event('pointerlockchange'));
      request.resolve();
    } else {
      document.dispatchEvent(new Event('pointerlockerror'));
      request.reject(new DOMException('Окно не захватило мышь', 'NotAllowedError'));
    }
  }
  function relativeMouse(delta) {
    if (!embedded || paused || !lockedElement) return;
    const bounds = lockedElement.getBoundingClientRect();
    const event = new MouseEvent('mousemove', {bubbles: true, clientX: bounds.x + bounds.width / 2, clientY: bounds.y + bounds.height / 2});
    Object.defineProperties(event, {movementX: {value: delta[0]}, movementY: {value: delta[1]}});
    lockedElement.dispatchEvent(event);
  }

  function localize(value) {
    if (typeof value !== 'string') return value;
    const cdn = 'https://cdn.jsdelivr.net/npm/three@0.170.0/';
    if (value.startsWith(cdn)) return new URL('vendor/three/' + value.slice(cdn.length), root).href;
    if (value.startsWith('/games/')) {
      const parts = value.split('/');
      return new URL(parts.slice(3).join('/'), gameBase).href;
    }
    if (value.startsWith('/') && !value.startsWith('//')) return new URL(value.slice(1), gameBase).href;
    return value;
  }
  const nativeFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    if (typeof input === 'string') input = localize(input);
    else if (input instanceof URL) input = new URL(localize(input.href));
    else if (input instanceof Request && localize(input.url) !== input.url) input = new Request(localize(input.url), input);
    return nativeFetch(input, init);
  };
  const xhrOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url, ...rest) {return xhrOpen.call(this, method, localize(url), ...rest);};
  const imageSource = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
  Object.defineProperty(HTMLImageElement.prototype, 'src', {...imageSource, set(value) {imageSource.set.call(this, localize(value));}});

  function capture() {
    if (!capturePending) return;
    const candidates = [...document.querySelectorAll('canvas')].filter(canvas => canvas.width > 32 && canvas.height > 32);
    candidates.sort((a, b) => b.width * b.height - a.width * a.height);
    if (!candidates.length) return;
    capturePending = false;
    try {
      const source = candidates[0];
      const canvas = document.createElement('canvas');
      const scale = Math.min(480 / source.width, 320 / source.height, 1);
      canvas.width = Math.max(1, Math.round(source.width * scale));
      canvas.height = Math.max(1, Math.round(source.height * scale));
      canvas.getContext('2d').drawImage(source, 0, 0, canvas.width, canvas.height);
      send('snapshot', canvas.toDataURL('image/jpeg', 0.78));
    } catch (error) {send('snapshot-error', 'Снимок недоступен: ' + error.message);}
  }
  function scheduleRAF(id, record) {
    record.native = nativeRAF(() => {
      record.native = null;
      if (paused || !rafs.has(id)) return;
      rafs.delete(id);
      try {record.callback(logicalNow());} finally {capture();}
    });
  }
  window.requestAnimationFrame = callback => {
    const id = nextID++;
    const record = {callback, native: null};
    rafs.set(id, record);
    if (!paused) scheduleRAF(id, record);
    return id;
  };
  window.cancelAnimationFrame = id => {
    const record = rafs.get(id);
    if (record?.native !== null && record?.native !== undefined) nativeCancelRAF(record.native);
    rafs.delete(id);
  };
  function scheduleTimer(id, record) {
    record.native = nativeTimeout(() => {
      record.native = null;
      if (paused || !timers.has(id)) return;
      if (!record.interval) timers.delete(id);
      try {record.callback(...record.args);} finally {
        if (record.interval && timers.has(id)) {
          record.deadline = logicalNow() + record.delay;
          scheduleTimer(id, record);
        }
      }
    }, Math.max(0, record.deadline - logicalNow()));
  }
  function timer(callback, delay, args, interval) {
    const id = nextID++;
    delay = Math.max(interval ? 1 : 0, Number(delay) || 0);
    const record = {callback: typeof callback === 'function' ? callback : new Function(String(callback)), delay, args, interval, deadline: logicalNow() + delay, native: null};
    timers.set(id, record);
    if (!paused) scheduleTimer(id, record);
    return id;
  }
  window.setTimeout = (callback, delay, ...args) => timer(callback, delay, args, false);
  window.setInterval = (callback, delay, ...args) => timer(callback, delay, args, true);
  window.clearTimeout = window.clearInterval = id => {
    const record = timers.get(id);
    if (record?.native !== null && record?.native !== undefined) nativeClearTimeout(record.native);
    timers.delete(id);
  };

  const gains = new WeakMap();
  if (window.AudioNode) {
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function(destination, ...ports) {
      const gain = gains.get(this.context);
      if (gain && destination === this.context.destination) destination = gain;
      return connect.call(this, destination, ...ports);
    };
    for (const name of ['AudioContext', 'webkitAudioContext']) {
      const Native = window[name];
      if (!Native) continue;
      function Wrapped(...args) {
        const context = new Native(...args);
        const gain = context.createGain();
        connect.call(gain, context.destination);
        gains.set(context, gain);
        gain.gain.value = muted || paused ? 0 : 1;
        contexts.add(context);
        if (paused) context.suspend().catch(() => {});
        return context;
      }
      Wrapped.prototype = Native.prototype;
      Object.setPrototypeOf(Wrapped, Native);
      window[name] = Wrapped;
    }
  }
  function updateAudio() {
    for (const context of contexts) {
      const gain = gains.get(context);
      if (gain) gain.gain.value = muted || paused ? 0 : 1;
    }
    for (const item of media) item.muted = muted;
  }
  document.addEventListener('play', event => {
    if (!(event.target instanceof HTMLMediaElement)) return;
    media.add(event.target);
    event.target.muted = muted;
    if (paused) {playingMedia.add(event.target); event.target.pause();}
  }, true);

  function setPaused(value) {
    value = Boolean(value);
    if (value === paused) return;
    if (value) {
      for (const [code, original] of pressed) {
        const release = new KeyboardEvent('keyup', {key: original.key, code, bubbles: true});
        Object.defineProperty(release, 'latentSynthetic', {value: true});
        window.dispatchEvent(release);
        document.dispatchEvent(new KeyboardEvent('keyup', {key: original.key, code, bubbles: true}));
      }
      pressed.clear();
      pauseStart = rawNow();
      paused = true;
      document.exitPointerLock?.();
      for (const record of rafs.values()) {if (record.native !== null) nativeCancelRAF(record.native); record.native = null;}
      for (const record of timers.values()) {if (record.native !== null) nativeClearTimeout(record.native); record.native = null;}
      for (const context of contexts) if (context.state !== 'closed') context.suspend().catch(() => {});
      for (const item of media) if (!item.paused) {playingMedia.add(item); item.pause();}
    } else {
      pausedMillis += rawNow() - pauseStart;
      paused = false;
      for (const [id, record] of rafs) scheduleRAF(id, record);
      for (const [id, record] of timers) scheduleTimer(id, record);
      for (const context of contexts) if (context.state !== 'closed') context.resume().catch(() => {});
      for (const item of playingMedia) if (!item.ended) item.play().catch(() => {});
      playingMedia.clear();
    }
    updateAudio();
  }
  window.addEventListener('keydown', event => {
    if (event.latentSynthetic) return;
    if (event.code === 'Escape' || event.code === 'F8') {
      event.preventDefault(); event.stopImmediatePropagation();
      if (!event.repeat) send(event.code === 'Escape' ? 'pause' : 'snapshot-key');
    } else if (paused) {event.preventDefault(); event.stopImmediatePropagation();}
    else pressed.set(event.code, {key: event.key});
  }, true);
  window.addEventListener('keyup', event => {
    if (event.latentSynthetic) return;
    pressed.delete(event.code);
    if (paused || event.code === 'Escape' || event.code === 'F8') {event.preventDefault(); event.stopImmediatePropagation();}
  }, true);
  for (const name of ['mousedown', 'mouseup', 'mousemove', 'touchstart', 'touchmove', 'touchend']) {
    window.addEventListener(name, event => {if (paused) {event.preventDefault(); event.stopImmediatePropagation();}}, {capture: true, passive: false});
  }
  document.addEventListener('pointerlockchange', () => {if (!document.pointerLockElement && !paused) send('pause');});
  window.addEventListener('message', event => {
    if (event.source !== parent || event.origin !== location.origin || event.data?.kind !== 'latent-host') return;
    const {type, value} = event.data;
    if (type === 'init') {muted = Boolean(value.muted); setPaused(value.paused); updateAudio();}
    else if (type === 'pause') setPaused(value);
    else if (type === 'mute') {muted = Boolean(value); updateAudio();}
    else if (type === 'pointer-lock') acceptPointerLock(value);
    else if (type === 'mouse-motion') relativeMouse(value);
    else if (type === 'snapshot') {
      if (paused) {send('snapshot-error', 'Для снимка продолжи стенд и нажми F8.'); return;}
      capturePending = true;
      nativeTimeout(() => {if (capturePending) {capturePending = false; send('snapshot-error', 'Кадр ещё не отрисован. Повтори снимок после загрузки среды.');}}, 5000);
    }
  });
  window.addEventListener('error', event => {if (event.message) send('error', event.message);});
  window.addEventListener('unhandledrejection', event => send('error', String(event.reason?.message || event.reason)));
  send('ready');
})();
