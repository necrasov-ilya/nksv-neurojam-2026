// Render graph: geodesic (HDR, MRT, adaptive scale) -> TAA -> bloom chain ->
// anamorphic streaks -> composite (ACES, grade, grain, dither). All hand-written GLSL.
import { Program } from '../gl/program.js';
import { loadShaderSource } from '../gl/shaderlib.js';
import { RT, MRT, bindDefaultFB, drawFullscreen } from '../gl/targets.js';
import { makeBlueNoise, r2 } from '../prng.js';
import { clamp } from '../mathx.js';

const VERT = 'shaders/passes/fullscreen.vert';

export class Renderer {
  constructor(gl, canvas, params) {
    this.gl = gl; this.canvas = canvas; this.params = params;
    this.scale = 0.6;
    this.frame = 0;
    this.traceDir = [-1.0, 0.0, 0.24];
    this.samples = 0;        // accumulated TAA samples since reset
    this.historyValid = false;
    this.stats = { avgSteps: 0, maxSteps: 0, gMin: 1, gMax: 1 };
    this._statPool = new Float32Array(512 * 512 * 4);
    this.needResize = true;
    this.timerPool = []; this.timerResults = {};
  }
  async init() {
    const gl = this.gl;
    const sources = {};
    const names = ['geodesic', 'taa', 'bloom_down', 'bloom_up', 'streak', 'composite'];
    const qp = new URLSearchParams(location.search); if (qp.has('trace')) names.push('trace'); if (qp.has('trace2')) names.push('trace2');
    for (const n of names) sources[n] = await loadShaderSource(`shaders/passes/${n}.frag`);
    const vert = await loadShaderSource(VERT);
    this.progs = {};
    for (const n of names) this.progs[n] = new Program(gl, n, vert, sources[n]);
    // blue noise tile
    const bn = makeBlueNoise(32);
    this.bnTex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, this.bnTex);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, bn.size, bn.size, 0, gl.RED, gl.UNSIGNED_BYTE, bn.data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  }
  resize(canvasW, canvasH) {
    this.canvasW = canvasW; this.canvasH = canvasH;
    this.needResize = true;
  }
  rebuildTargets() {
    const gl = this.gl;
    const q = this.params.q;
    const w = Math.max(64, Math.round(this.canvasW * this.scale * q.maxScale / this.params.q.maxScale));
    // internal res = canvas * scale (scale already bounded by quality maxScale)
    const iw = Math.max(64, Math.round(this.canvasW * this.scale));
    const ih = Math.max(64, Math.round(this.canvasH * this.scale));
    this.iw = iw; this.ih = ih;
    for (const t of this.targets || []) t.dispose();
    this.mrt = new MRT(gl, iw, ih);
    this.accum = [new RT(gl, iw, ih, { float: true, linear: true }), new RT(gl, iw, ih, { float: true, linear: true })];
    this.accumIdx = 0;
    // bloom chain
    this.bloomA = []; this.bloomB = [];
    let bw = iw >> 1, bh = ih >> 1;
    const levels = Math.min(q.bloomLevels, 7);
    for (let i = 0; i < levels && bw >= 8 && bh >= 8; i++) {
      this.bloomA.push(new RT(gl, bw, bh, { float: true, linear: true }));
      this.bloomB.push(new RT(gl, bw, bh, { float: true, linear: true }));
      bw >>= 1; bh >>= 1;
    }
    this.streakA = new RT(gl, Math.max(8, iw >> 1), Math.max(8, ih >> 1), { float: true, linear: true });
    this.streakB = new RT(gl, Math.max(8, iw >> 1), Math.max(8, ih >> 1), { float: true, linear: true });
    this.targets = [this.mrt, ...this.accum, ...this.bloomA, ...this.bloomB, this.streakA, this.streakB];
    this.historyValid = false;
    this.samples = 0;
    this.needResize = false;
  }
  resetHistory() { this.historyValid = false; this.samples = 0; }
  setCommon(p, s, extra) {
    const gl = this.gl;
    p.f1('uSpin', s.spin)
      .v4('uCam', s.camR, s.camTh, s.camPh, s.camFov)
      .v4('uPrevCam', s.prevR, s.prevTh, s.prevPh, s.prevFov)
      .v2('uRes', this.iw, this.ih)
      .v2('uJitter', s.jitter[0], s.jitter[1])
      .v2('uPrevJitter', s.prevJitter[0], s.prevJitter[1])
      .f1('uTime', s.time)
      .f1('uAspect', this.iw / this.ih)
      .f1('uDiskInner', s.diskInner)
      .f1('uDiskOuter', s.diskOuter)
      .f1('uDiskBright', s.diskBright)
      .f1('uDiskTmax', 14000.0)
      .f1('uNebulaBright', s.nebulaBright)
      .f1('uJetBright', s.jetMul ?? 1.0)
      .i1('uFrame', this.frame)
      .i1('uMaxSteps', this.maxSteps)
      .f1('uStepScale', s.stepScale)
      .v4('uFeatureToggles', s.diskOn, s.jetOn, s.nebulaOn, s.starsOn)
      .f1('uMotionPx', s.motionPx || 0)
      .f1('uTestGradientSky', s.testGradientSky)
      .f1('uTestStarOn', s.testStarOn)
      .f1('uDebugDir', s.debugDir || 0)
      .v3('uTestStarDir', s.testStarDir[0], s.testStarDir[1], s.testStarDir[2]);
    p.tex('uBlueNoise', 7, this.bnTex);
  }
  render(state, dtMs) {
    this.lastState = state;
    const gl = this.gl;
    const q = this.params.q;
    if (this.traceDirReq) { this.traceDir = this.traceDirReq; this.traceDirReq = null; }
    if (this.traceNReq != null) { this.traceN = this.traceNReq; this.traceNReq = null; }
    if (this.progs.trace && this.traceDual) {
      // dual-march debug: render into the float MRT so we can read exact values
      if (!this.mrt) this.rebuildTargets();
      const t = this.mrt;
      gl.bindFramebuffer(gl.FRAMEBUFFER, t.fbo);
      gl.viewport(0, 0, t.w, t.h);
      const pT = this.progs.trace.use();
      this.setCommon(pT, state);
      pT.v3('uTraceDir', this.traceDir[0], this.traceDir[1], this.traceDir[2]);
      pT.i1('uTraceN', this.traceN == null ? q.steps : this.traceN);
      pT.i1('uTraceDual', 1);
      pT.i1('uTraceProbe', this.traceProbe ? 1 : 0);
      pT.v2('uCanvasRes2', t.w, t.h);
      pT.f1('uStepScale', state.stepScale);
      drawFullscreen(gl);
      this.frame++;
      return;
    }
    if (this.progs.trace) {
      bindDefaultFB(gl, this.canvasW, this.canvasH);
      const pT = this.progs.trace.use();
      this.setCommon(pT, state);
      pT.i1('uTraceSteps', q.steps);
      pT.v3('uTraceDir', this.traceDir[0], this.traceDir[1], this.traceDir[2]);
      pT.i1('uTraceN', this.traceN == null ? q.steps : this.traceN);
      pT.i1('uTraceDual', this.traceDual ? 1 : 0);
      pT.f1('uStepScaleP', 1.0);
      pT.v2('uCanvasRes2', this.canvasW, this.canvasH);
      pT.f1('uStepScale', state.stepScale);
      drawFullscreen(gl);
      this.frame++;
      return;
    }
    if (this.progs.trace2) {
      bindDefaultFB(gl, this.canvasW, this.canvasH);
      const pT = this.progs.trace2.use();
      this.setCommon(pT, state);
      pT.f1('uTraceScale', state.stepScale);
      drawFullscreen(gl);
      this.frame++;
      return;
    }
    this.maxSteps = state.maxSteps || q.steps;
    if (this.needResize || this.iw !== Math.round(this.canvasW * this.scale)) this.rebuildTargets();
    const prevIdx = this.accumIdx;
    const cur = this.accum[this.accumIdx];
    const hist = this.accum[1 - this.accumIdx];
    // ---- pass 1: geodesic -> MRT ----
    this.mrt.bind();
    const pGeo = this.progs.geodesic.use();
    this.setCommon(pGeo, state);
    pGeo.f1('uExposureNorm', state.exposure); // pass through for pre-normalization only
    drawFullscreen(gl);
    // ---- pass 2: temporal accumulation ----
    cur.bind();
    const pTaa = this.progs.taa.use();
    this.setCommon(pTaa, state);
    // Blend weight, graded by camera motion (screen px of rotation/frame).
    // Large flings throw the history away entirely; gentle motion keeps a
    // strong far-field blend and lets the deflection term reject the rest.
    const mp = state.motionPx || 0;
    if (mp > 34 && this.historyValid) { this.historyValid = false; this.samples = 0; }
    const blend = 0.94 - 0.24 * Math.min(1, Math.max(0, (mp - 1.5) / 10));
    pTaa.f1('uBlendMax', this.historyValid ? blend : 0.0);
    pTaa.tex('uScene', 0, this.mrt.colorTex);
    pTaa.tex('uData', 1, this.mrt.dataTex);
    pTaa.tex('uData3', 3, this.mrt.data3Tex);
    pTaa.tex('uHistory', 2, hist.tex);
    drawFullscreen(gl);
    this.accumIdx = 1 - this.accumIdx;
    this.historyValid = true;
    // `samples` means STATIC accumulation: any real motion restarts it, so
    // "converged" is never reported for an orbiting camera.
    this.samples = mp < 2 ? Math.min(this.samples + 1, 4096) : 0;
    const composed = this.accum[1 - this.accumIdx]; // just-written frame
    // ---- pass 3: bloom chain ----
    const bloomTex = this.bloomChain(composed);
    // ---- pass 4: anamorphic streaks ----
    this.streakPass(bloomTex);
    // ---- pass 5: composite to screen (or to presentRT for verification) ----
    if (this.presentRT) this.presentRT.bind();
    else bindDefaultFB(gl, this.canvasW, this.canvasH);
    const pComp = this.progs.composite.use();
    this.setCommon(pComp, state);
    pComp.tex('uScene', 0, composed.tex);
    pComp.tex('uBloom', 1, bloomTex);
    pComp.tex('uStreak', 2, this.streakA.tex);
    pComp.f1('uExposure', state.exposure);
    pComp.v2('uCanvasRes', this.canvasW, this.canvasH);
    pComp.f1('uGrain', state.grain);
    pComp.v4('uCompToggles', state.bloomOn ? 1 : 0, state.streakOn ? 1 : 0, state.caOn ? 1 : 0, state.vignetteOn ? 1 : 0);
    drawFullscreen(gl);
    this.frame++;
    // step statistics every 12 frames (small readback region of data plane)
    if (this.frame % 12 === 1) this.gatherStats();
  }
  bloomChain(src) {
    const gl = this.gl;
    const pDown = this.progs.bloom_down.use();
    let input = src.tex;
    for (let i = 0; i < this.bloomA.length; i++) {
      const b = this.bloomA[i];
      b.bind();
      pDown.tex('uSrc', 0, input);
      pDown.v2('uSrcRes', i === 0 ? this.iw : this.bloomA[i - 1].w, i === 0 ? this.ih : this.bloomA[i - 1].h);
      pDown.f1('uPrefilter', i === 0 ? 1.0 : 0.0);
      pDown.f1('uThreshold', 3.5);
      drawFullscreen(gl);
      input = b.tex;
    }
    const pUp = this.progs.bloom_up.use();
    for (let i = this.bloomA.length - 1; i > 0; i--) {
      const srcB = this.bloomA[i], dstA = this.bloomA[i - 1], dst = this.bloomB[i - 1];
      dst.bind();
      pUp.tex('uSrc', 0, srcB.tex);
      pUp.tex('uDst', 1, dstA.tex);
      pUp.v2('uSrcRes', srcB.w, srcB.h);
      drawFullscreen(gl);
    }
    this.bloomFinal = this.bloomB[0];
    return this.bloomFinal.tex;
  }
  streakPass(bloomTex) {
    const gl = this.gl;
    const pS = this.progs.streak.use();
    // two horizontal blurs of decreasing radius, accumulated
    pS.tex('uSrc', 0, bloomTex);
    this.streakB.bind();
    pS.f1('uPass', 0.0);
    drawFullscreen(gl);
    this.streakA.bind();
    pS.tex('uSrc', 0, this.streakB.tex);
    pS.f1('uPass', 1.0);
    drawFullscreen(gl);
  }
  gatherStats() {
    const gl = this.gl;
    const w = Math.min(512, this.mrt.w), h = Math.min(512, this.mrt.h);
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.mrt.fbo);
    gl.readBuffer(gl.COLOR_ATTACHMENT1);
    const buf = this._statPool;
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, buf);
    gl.readBuffer(gl.COLOR_ATTACHMENT0);
    let sum = 0, n = 0, mx = 0;
    let gmin = 1e9, gmax = -1e9;
    for (let i = 0; i < w * h; i++) {
      const steps = buf[i * 4];
      if (steps > 0) { sum += steps; n++; if (steps > mx) mx = steps; }
      const ev = buf[i * 4 + 2];
      if (ev > 0.5 && ev < 1.5) {
        const g = buf[i * 4 + 3];
        if (g > 0.01 && Number.isFinite(g)) { if (g < gmin) gmin = g; if (g > gmax) gmax = g; }
      }
    }
    if (n > 0) { this.stats.avgSteps = sum / n; this.stats.maxSteps = mx; }
    if (gmin < 1e9) { this.stats.gMin = gmin; this.stats.gMax = gmax; }
  }
  // Adaptive render scale. The old rule compared the RAW frame interval to
  // fixed 16.5/12.5 ms thresholds - but a healthy vsynced frame IS ~16.7 ms
  // (idle GPU, waiting for the compositor), which read as "overloaded", so the
  // scale ratcheted to its 0.35 floor and vsync capping never let it climb
  // back. The interval must be judged against the DISPLAY's own period:
  // estimate refresh as the fastest frame in the window, then compare the
  // median: hitting every vsync = headroom (climb), missing half of them =
  // overload (drop, with a cooldown so one spike cannot oscillate it).
  adaptScale(frameMs) {
    const q = this.params.q;
    if (frameMs < 2 || frameMs > 400 || this.frame < 12) return;
    if (!this._dtRing) this._dtRing = new Float32Array(64);   // allocated once
    this._dtRing[this.frame & 63] = frameMs;
    if (this._cooldown > 0) this._cooldown--;
    // --- motion ladder: sustained camera motion boosts resolution ---
    // Deflection-gated history means the hole's neighbourhood shows the raw
    // per-frame sample while orbiting; at a low scale that sample is mush, so
    // while the camera actually moves, render at >= 0.85 (quality permitting).
    const mp = (this.lastState && this.lastState.motionPx) || 0;
    // --- motion ladder: sustained camera motion boosts resolution ---
    // Deflection-gated history means the hole's neighbourhood shows the raw
    // per-frame sample while orbiting; at a low scale that sample is mush, so
    // while the camera actually moves, render at >= 0.85 (quality permitting).
    // Trigger on a short EMA of motion so bursty pointer steps (one 45 px
    // event, several idle frames, repeat) count as motion too.
    this._emaMotion = (this._emaMotion || 0) * 0.8 + Math.min(mp, 60) * 0.2;
    if (this._emaMotion > 1.2) {
      this._motionSince = (this._motionSince || 0) + 1;
      if (this._motionSince === 12) {
        const target = Math.min(q.maxScale, this._motionCap || 1, Math.max(this.scale, 0.85));
        if (target > this.scale + 0.02) { this.scale = target; this.needResize = true; }
      }
    } else {
      this._motionSince = 0;
    }
    // While moving, still watch for a hopeless GPU (missing >2x the display
    // period): step DOWN once and cap the boost so it cannot oscillate.
    if (mp > 2 && (this.frame & 31) === 0 && this._dtRing) {
      const w2 = [];
      for (let i = 0; i < 64; i++) if (this._dtRing[i] > 2) w2.push(this._dtRing[i]);
      if (w2.length >= 32) {
        w2.sort((a, b) => a - b);
        const r2 = Math.max(4, w2[Math.floor(w2.length * 0.1)]), m2 = w2[w2.length >> 1];
        if (m2 > r2 * 2.2 && this.scale > 0.5) {
          this._motionCap = Math.max(0.55, this.scale - 1 / 8);
          this.scale = this._motionCap;
          this.needResize = true;
          this._motionSince = 0;
        }
      }
      return; // judge the budget when the picture is static, not mid-drag
    }
    // --- static budget: wide hysteresis, rare steps ---
    // Every rescale rebuilds targets and throws away TAA convergence, so the
    // ladder must be deliberate: drop decisively (-10%, long cooldown), climb
    // only after several consecutive clean evaluations (+1/16).
    if ((this.frame & 63) !== 0) return;
    const win = [];
    for (let i = 0; i < 64; i++) if (this._dtRing[i] > 2) win.push(this._dtRing[i]);
    if (win.length < 32) return;
    win.sort((a, b) => a - b);
    // refresh estimate: 10th percentile, not the minimum — one early-firing
    // rAF callback (back-to-back dispatch after a stall) would otherwise
    // shrink the assumed refresh period and make healthy frames read as
    // overload. p10 rides through a handful of glitch frames.
    const refresh = Math.max(4, win[Math.floor(win.length * 0.1)]);
    const p50 = win[win.length >> 1];
    if (this._cooldown > 0) { this._cooldown--; return; }
    let s = this.scale;
    if (p50 > refresh * 1.45) {
      s = Math.max(0.5, s * 0.9);
      this._cooldown = 3;             // 3 evaluation periods (~3 s at 60 Hz)
      this._clean = 0;
    } else if (p50 < refresh * 1.06 && s < q.maxScale) {
      if (++this._clean >= 3) {
        s = Math.min(q.maxScale, s + 1 / 16);
        this._clean = 0;
        this._cooldown = 1;
        if (s >= 0.8) this._motionCap = 1;   // machine proved it: restore the motion boost
      }
    } else {
      this._clean = 0;
    }
    s = Math.round(s * 96) / 96;
    if (Math.abs(s - this.scale) > 1e-4) {
      this.scale = s;
      this.needResize = true;
    }
  }
}
