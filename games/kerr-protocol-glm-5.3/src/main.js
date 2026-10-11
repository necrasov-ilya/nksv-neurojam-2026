// KERR — relativistic black hole renderer. Raw WebGL2, zero runtime dependencies.
import { createGL, initResize } from './gl/context.js';
import { Renderer } from './render/renderer.js';
import { Params } from './params.js';
import { Camera, SHOTS, cinematicOrbit } from './camera.js';
import { Input } from './input.js';
import { Hud } from './ui/hud.js';
import { SelfTest } from './selftest.js';
import { deg, clamp } from './mathx.js';

const qs = new URLSearchParams(location.search);
const canvas = document.getElementById('gl');
const fatal = (msg) => {
  const el = document.getElementById('fatal');
  el.hidden = false;
  el.textContent = msg;
  throw new Error(msg);
};
const { gl, error } = createGL(canvas);
if (error) fatal(error);
gl.getExtension('OES_texture_float_linear');

const params = new Params((key) => {
  renderer && renderer.resetHistory();
  hud && hud.toast(`${key} → ${typeof params.p[key] === 'number' ? params.p[key].toFixed(2) : params.p[key]}`);
});
if (qs.has('dpr')) window.devicePixelRatio = parseFloat(qs.get('dpr'));

const camera = new Camera();
const hud = new Hud(params, camera);
const renderer = new Renderer(gl, canvas, params);

const state = {
  spin: params.p.spin,
  camR: 0, camTh: 0, camPh: 0, camFov: 0,
  prevR: 0, prevTh: 0, prevPh: 0, prevFov: 0,
  jitter: [0.5, 0.5], prevJitter: [0.5, 0.5],
  time: 0, exposure: params.p.exposure, diskBright: 1, nebulaBright: 1, jetMul: 1,
  diskInner: 6, diskOuter: 15,
  diskOn: true, jetOn: true, nebulaOn: true, starsOn: true,
  testGradientSky: 0, testStarOn: 0, testStarDir: [0, 0, -1],
  cameraMoving: false, maxSteps: 0, stepScale: 0.034, debugDir: 0,
  testActive: false, spinOverride: null,
  grain: 1, bloomOn: true, streakOn: true, caOn: true, vignetteOn: true,
};
let sceneTime = 0;
let stillMode = null;      // {target} accumulation counter
let testEnv = null;        // self-test overrides

async function boot() {
  await renderer.init();
  const resizeCtl = initResize(canvas, gl, (w, h) => {
    if (w === -1) { hud.toast('WebGL context lost — recovering…'); return; }
    if (w === -2) { renderer.needResize = true; hud.toast('WebGL context restored.'); return; }
    renderer.resize(w, h);
  });
  window.addEventListener('keydown', (e) => {
    if (e.key === '`') { hud.debugOn = !hud.debugOn; }
  });
  const input = new Input(canvas, {
    orbitDrag: (dx, dy) => { camera.orbit = null; camera.orbitFn = null; camera.dragging = true; camera.orbitDrag(dx, dy); },
    dragEnd: () => { camera.dragging = false; },
    dolly: (d) => { camera.orbit = null; camera.orbitDolly(d); },
    dismissHint: () => hud.dismissHint(),
    key: async (k, e) => {
      if (k >= '1' && k <= '5') {
        const s = SHOTS[parseInt(k) - 1];
        camera.orbit = null;
        camera.target(s.r, s.inc * deg, s.az * deg, s.fov);
        state.expMul = s.exp ?? 1;          // per-shot exposure grade
        state.jetMul = s.jet ?? 1;          // per-shot jet gain
        camera.settled = false;
        hud.toast(`SHOT ${parseInt(k)} — ${s.name}`);
      } else if (k === 'c') {
        if (camera.orbitFn) { camera.orbitFn = null; hud.toast('auto-orbit off'); }
        else { camera.orbitFn = cinematicOrbit; camera.orbitT = 0; hud.toast('CINEMATIC ORBIT — 30 s loop'); }
      } else if (k === 'p') {
        startStill();
      } else if (k === 't') {
        hud.toast('SELF-TEST RUNNING');
        await runSelfTest();
      } else if (k === 'h') {
        const hudEl = document.getElementById('hud');
        hudEl.style.display = hudEl.style.display === 'none' ? '' : 'none';
      } else if (k === 'g') {
        params.set('quality', (params.p.quality + 1) % 4);
        hud.toast(`quality ${params.q.name}`);
      } else if (k === 'j') {
        params.set('jetOn', !params.p.jetOn);
      }
    },
  });
  // camera orbit hookup (cinematicOrbit assigned through camera.orbit = {t})
  const origUpdate = camera.update.bind(camera);
  camera.update = (dt) => {
    if (camera.orbitFn) {
      const c = camera.orbitFn(camera.orbitT += dt);
      camera.target(c.r, c.th, c.ph, c.fov);
    }
    origUpdate(dt);
  };
  testEnv = makeTestEnv();
  if (qs.has('autotest')) setTimeout(() => runSelfTest(), 400);
  requestAnimationFrame(loop);
}

// ---- still capture (P) ----
function startStill() {
  stillMode = { frames: 0, target: 96, oldScale: renderer.scale, oldQuality: params.p.quality };
  renderer.scale = 1.0;                 // stills are ALWAYS full resolution
  params.set('quality', 3);             // and full integration budget (ULTRA)
  renderer.needResize = true;
  hud.toast('ACCUMULATING STILL…');
}
function finishStill() {
  canvas.toBlob((blob) => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `kerr-still-${Date.now()}.png`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  }, 'image/png');
  renderer.scale = stillMode.oldScale;
  params.set('quality', stillMode.oldQuality);
  renderer.needResize = true;
  stillMode = null;
  hud.toast('STILL SAVED');
}

// ---- self-test environment ----
function makeTestEnv() {
  let framesLeft = 0, resolve = null;
  const env = {
    gl, renderer, params, camera,
    renderFrames: (n, cfg) => new Promise((res) => {
      applyTestConfig(cfg);
      framesLeft = n; resolve = res; env.resolve = res;
    }),
  };
  env._tick = () => { if (framesLeft > 0 && --framesLeft === 0) { const r = resolve; resolve = null; env.resolve = null; clearTestConfig(); r(); } };
  return env;
}
function applyTestConfig(cfg) {
  camera.orbit = null; camera.orbitFn = null;
  state.testActive = true;
  state.spinOverride = cfg.spin;
  state.spin = cfg.spin;
  const s = camera.state;
  const fovDeg = cfg.fov / deg;
  camera.target(cfg.camR, cfg.camInc, 0, fovDeg);
  camera.sr.x = cfg.camR; camera.sr.v = 0;
  camera.st.x = cfg.camInc; camera.st.v = 0;
  camera.sp.x = 0; camera.sp.v = 0;
  camera.sf.x = fovDeg; camera.sf.v = 0;
  camera.tr = cfg.camR; camera.tt = cfg.camInc; camera.tp = 0; camera.tf = fovDeg;
  state.diskOn = !!cfg.disk; state.jetOn = !!cfg.jet;
  state.nebulaOn = !!cfg.nebula; state.starsOn = !!cfg.stars;
  state.testGradientSky = cfg.gradientSky ? 1 : 0;
  state.testStarOn = cfg.testStar ? 1 : 0;
  if (cfg.testStar) {
    // Beacon sky direction: beta_s = angular offset from the view center
    // (the hole), measured in the equatorial plane. beta_s = 0 -> directly
    // behind the hole (classic on-axis Einstein ring geometry). Camera
    // azimuth is 0 in tests, so view center = -x_hat, right = +y_hat.
    const beta = cfg.testStarAngle ?? 0;
    state.testStarDir = [-Math.cos(beta), Math.sin(beta), 0];
  }
  state.fixedTime = cfg.fixedTime ?? null;
  renderer.frame = cfg.cold ? 0 : renderer.frame;
  camera.settled = true;
  renderer.resetHistory();
  renderer.scale = Math.min(renderer.scale, 0.75); // stable test conditions
  renderer.needResize = true;
}
function clearTestConfig() {
  state.fixedTime = null;
  state.testGradientSky = 0; state.testStarOn = 0;
  state.diskOn = true; state.jetOn = params.p.jetOn;
  state.nebulaOn = true; state.starsOn = true;
  state.spin = params.p.spin;
  state.testActive = false; state.spinOverride = null;
  renderer.resetHistory();
}
async function runSelfTest() {
  const st = new SelfTest(testEnv);
  await st.run();
}

// ---- main loop ----
let last = performance.now();
const times = [];
let hudT = 0;
function loop(now) {
  requestAnimationFrame(loop);
  const dtMs = Math.min(now - last, 100);
  last = now;
  if (document.hidden) return;
  const testing = testEnv && testEnv.resolve;
  if (!testing) {
    camera.update(dtMs / 1000);
    sceneTime += dtMs / 1000;
  }
  // build per-frame state
  const cs = camera.state;
  state.prevR = state.camR; state.prevTh = state.camTh; state.prevPh = state.camPh; state.prevFov = state.camFov;
  state.camR = cs.r; state.camTh = cs.th; state.camPh = cs.ph; state.camFov = cs.fov * deg;
  state.spin = state.testActive ? state.spinOverride : params.p.spin;
  const a = state.spin;
  const z1 = 1 + Math.cbrt(1 - a * a) * (Math.cbrt(1 + a) + Math.cbrt(1 - a));
  const z2 = Math.sqrt(3 * a * a + z1 * z1);
  state.diskInner = Math.max(1.25, 3 + z2 - Math.sqrt((3 - z1) * (3 + z1 + 2 * z2)));
  state.diskOuter = 15;
  if (!state.testActive) {
    state.exposure = params.p.exposure * (state.expMul ?? 1);
    state.diskBright = params.p.diskBright;
    state.nebulaBright = params.p.nebulaBright;
  }
  if (!testing && !state.testActive) state.jetOn = params.p.jetOn;
  state.maxSteps = params.q.steps;
  state.stepScale = params.q.stepScale;
  state.time = state.fixedTime !== null && state.fixedTime !== undefined ? state.fixedTime : sceneTime;
  state.cameraMoving = !camera.settled;
  // Camera motion this frame, expressed in SCREEN PIXELS of rotation at the
  // current focal length. This - not "settled" - drives TAA motion gating:
  // a drag that moves state and target together never disturbed `settled`,
  // so the old check let 0.94-weight history blend while the camera spun.
  {
    const dph = Math.atan2(Math.sin(state.camPh - state.prevPh), Math.cos(state.camPh - state.prevPh));
    const dAng = Math.abs(dph) * Math.sin(state.camTh) + Math.abs(state.camTh - state.prevTh);
    const dFov = Math.abs(state.camFov - state.prevFov) / state.camFov;
    const dR = Math.abs(state.camR - state.prevR);
    const focal = (renderer.ih || 800) * 0.5 / Math.tan(state.camFov * 0.5);
    state.motionPx = (dAng + 0.55 * dFov + dR * 8 / (state.camR * state.camR)) * focal;
  }
  // deterministic jitter sequence (R2), index by frame — ping-pong between two
  // preallocated pairs (F1: no per-frame allocation, and prevJitter must not
  // alias the live one)
  if (!state._jitA) { state._jitA = [0.5, 0.5]; state._jitB = [0.5, 0.5]; }
  const j = (renderer.frame & 1) ? state._jitB : state._jitA;
  j[0] = (0.5 + 0.7548776662466927 * renderer.frame) % 1;
  j[1] = (0.5 + 0.5698402909980532 * renderer.frame) % 1;
  state.prevJitter = (renderer.frame & 1) ? state._jitA : state._jitB;
  state.jitter = j;
  try {
    renderer.render(state, dtMs);
  } catch (err) {
    fatal('Render error: ' + err.message);
  }
  if (stillMode) {
    if (++stillMode.frames >= stillMode.target) finishStill();
  } else if (!testing) {
    renderer.adaptScale(dtMs);
  }
  if (testEnv && testEnv.resolve) testEnv._tick();
  // stats + HUD
  times.push(dtMs);
  if (times.length > 240) times.shift();
  hudT += dtMs;
  if (hudT > 100) {
    hudT = 0;
    const sorted = times.slice().sort((x, y) => x - y);
    const p50 = sorted[Math.floor(sorted.length * 0.5)] || 0;
    const p95 = sorted[Math.floor(sorted.length * 0.95)] || 0;
    hud.update({
      fps: 1000 / Math.max(1, dtMs), ms: dtMs, p50, p95,
      renderer, params, camera, stats: renderer.stats,
    });
    window.__perf = { p50, p95 };
  }
  // automation frame state — one persistent object, mutated in place (F1)
  const F = window.__frame || (window.__frame = {});
  F.n = renderer.frame; F.samples = renderer.samples; F.scale = renderer.scale;
  F.iw = renderer.iw; F.ih = renderer.ih; F.settled = !!camera.settled; F.still = !!stillMode;
  F.stats = renderer.stats; F.p50 = (window.__perf || {}).p50 || 0; F.p95 = (window.__perf || {}).p95 || 0;
}

// automation hooks
window.__setPreset = (i) => {
  const s = SHOTS[i];
  camera.orbit = null; camera.orbitFn = null;
  camera.target(s.r, s.inc * deg, s.az * deg, s.fov);
  state.expMul = s.exp ?? 1;
  state.jetMul = s.jet ?? 1;
  camera.settled = false;
};
window.__setParam = (k, v) => params.set(k, v);
window.__setFeat = (k, v) => { state[k] = v; };
window.__setComp = (k, v) => { state[k] = v; };
window.__orbit = (on) => {
  camera.orbitFn = on ? cinematicOrbit : null;
  camera.orbitT = 0;
};
window.__runTests = runSelfTest;
window.__applyCfg = applyTestConfig;
window.__setDebug = (v) => { state.debugDir = v; };
window.__gl = gl; window.__R = renderer; window.__cam = camera;
window.__rendererProbe = () => {
  const gl0 = gl, R = renderer;
  const w = R.iw, h = R.ih;
  const buf = new Float32Array(w * h * 4);
  gl0.bindFramebuffer(gl0.FRAMEBUFFER, R.mrt.fbo);
  gl0.readPixels(0, 0, w, h, gl0.RGBA, gl0.FLOAT, buf);
  const lum = (x, y) => { const i = (y * w + x) * 4; return (buf[i]*0.2126 + buf[i+1]*0.7152 + buf[i+2]*0.0722).toFixed(4); };
  const row = [];
  const y = Math.floor(h / 2);
  for (let x = 0; x < w; x += Math.max(1, Math.floor(w / 40))) row.push(`${x}:${lum(x, y)}`);
  const dat = new Float32Array(w * h * 4);
  gl0.readBuffer(gl0.COLOR_ATTACHMENT1);
  gl0.readPixels(0, 0, w, h, gl0.RGBA, gl0.FLOAT, dat);
  const ev = (x, y2) => { const i = (y2 * w + x) * 4; return `ev${dat[i+2].toFixed(0)}/s${dat[i].toFixed(0)}`; };
  const evrow = [];
  for (let x = 0; x < w; x += Math.max(1, Math.floor(w / 20))) evrow.push(`${x}:${ev(x, y)}`);
  // coarse ASCII map of events: '.' sky, '#' captured, '?' other
  const CW = 64, CH = 36;
  let map = '';
  for (let my = 0; my < CH; my++) {
    let line = '';
    for (let mx = 0; mx < CW; mx++) {
      const x = Math.floor((mx + 0.5) / CW * w), y2 = Math.floor((my + 0.5) / CH * h);
      const e = dat[(y2 * w + x) * 4 + 2];
      line += e < 0.5 ? '.' : (e < 1.5 ? 'D' : (e < 2.5 ? '#' : '?'));
    }
    map += line + '\n';
  }
  return `res ${w}x${h}\nrow: ${row.join(' ')}\nevents: ${evrow.join(' ')}\nmap(. sky # captured):\n${map}`;
};

boot().catch((err) => fatal('Boot failed: ' + err.message));
