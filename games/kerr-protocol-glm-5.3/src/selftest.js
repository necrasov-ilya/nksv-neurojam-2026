// Self-test suite T1..T8 + T9 default-frame presentation check.
// All checks are MEASUREMENTS: readPixels on real framebuffers.
import { deg } from './mathx.js';

const SPH3 = Math.sqrt(3);
export class SelfTest {
  constructor(env) { this.env = env; }   // env: {gl, renderer, params, camera, renderFrames, setTestState}
  log(name, pass, msg) {
    const line = `${pass ? 'PASS' : 'FAIL'}  ${name}  ${msg}`;
    console.log(line);
    this.results.push({ name, pass, msg });
  }
  async run() {
    this.results = [];
    const t0 = performance.now();
    console.log('%cKERR self-test — measurements from readPixels', 'font-weight:bold');
    await this.t1(); await this.t2(); await this.t3(); await this.t4();
    await this.t5(); await this.t6(); await this.t7(); await this.t8();
    await this.t9();
    await this.t10();
    const pass = this.results.filter(r => r.pass).length;
    console.log(`%cdone: ${pass}/${this.results.length} passed in ${((performance.now() - t0) / 1000).toFixed(1)}s`, 'font-weight:bold');
    window.__tests = { results: this.results, passed: pass, total: this.results.length, done: true };
    return this.results;
  }
  readAccum() {
    const R = this.env.renderer;
    const gl = this.env.gl;
    const w = R.iw, h = R.ih;
    const buf = new Float32Array(w * h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, R.accum[1 - R.accumIdx].fbo);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, buf);
    return { buf, w, h };
  }
  readRaw() {   // pre-TAA geodesic output (current frame)
    const R = this.env.renderer;
    const gl = this.env.gl;
    const w = R.iw, h = R.ih;
    const buf = new Float32Array(w * h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, R.mrt.fbo);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, buf);
    return { buf, w, h };
  }
  readData(attachment = 1) {
    const R = this.env.renderer;
    const gl = this.env.gl;
    const w = R.iw, h = R.ih;
    const buf = new Float32Array(w * h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, R.mrt.fbo);
    gl.readBuffer(gl.COLOR_ATTACHMENT0 + attachment);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, buf);
    gl.readBuffer(gl.COLOR_ATTACHMENT0);
    return { buf, w, h };
  }
  async t1() {
    const { renderFrames } = this.env;
    await renderFrames(28, {
      spin: 0, camR: 60, camInc: 90, fov: 10 * deg,
      disk: false, jet: false, nebula: false, stars: false, gradientSky: true, fixedTime: 0,
    });
    const { buf, w, h } = this.readData(1);      // event buffer
    const cy = Math.floor(h / 2);
    const captured = (x) => buf[(cy * w + x) * 4 + 2] > 1.5;
    let xl = -1, xr = -1;
    for (let x = 0; x < w; x++) if (captured(x)) { xl = x; break; }
    for (let x = w - 1; x >= 0; x--) if (captured(x)) { xr = x; break; }
    // captured span is [xl, xr]; sub-pixel by luminance is overkill; use span center/edges
    const t = Math.tan(5 * deg), aspect = w / h;
    const ndc = (x) => (x / w) * 2 - 1;
    const bAt = (x) => {
      const ang = Math.atan(Math.abs(ndc(x)) * t * aspect);
      return 60 * Math.sin(ang) / Math.sqrt(1 - 2 / 60);   // Synge correction
    };
    const bL = bAt(xl), bR = bAt(xr);
    const b = 0.5 * (bL + bR);
    const asym = Math.abs(bL - bR) / b;
    const rel = Math.abs(b - 3 * SPH3) / (3 * SPH3);
    this.log('T1 shadow radius', rel < 0.03 && asym < 0.02,
      `b=${b.toFixed(4)} M (L ${bL.toFixed(3)} / R ${bR.toFixed(3)}, asym ${(asym * 100).toFixed(1)}%) vs 3√3=${(3 * SPH3).toFixed(4)} M  (rel ${(rel * 100).toFixed(2)}%)`);
  }
  async t2() {
    const { renderFrames } = this.env;
    const mad = async (spin) => {
      await renderFrames(28, {
        spin, camR: 30, camInc: 90, fov: 50 * deg,
        disk: false, jet: false, nebula: false, stars: false, gradientSky: true, fixedTime: 0,
      });
      const { buf, w, h } = this.readRaw();
      let acc = 0, mean = 0, n = 0;
      const lum = (x, y) => { const i = (y * w + x) * 4; return buf[i] * 0.2126 + buf[i + 1] * 0.7152 + buf[i + 2] * 0.0722; };
      for (let y = 0; y < h; y += 3) for (let x = 0; x < w; x += 3) { mean += lum(x, y); n++; }
      mean /= n;
      for (let y = 0; y < h; y += 3) for (let x = 0; x < w; x += 3) acc += Math.abs(lum(x, y) - lum(w - 1 - x, y));
      return { mad: acc / n / mean, mean };
    };
    const s0 = await mad(0.0);
    const s09 = await mad(0.9);
    const ok = s0.mad < 0.01 && s09.mad > 0.02 && s09.mad > 5 * s0.mad;
    this.log('T2 symmetry/frame-drag', ok,
      `mirror MAD a=0: ${(s0.mad * 100).toFixed(3)}%  a=0.9: ${(s09.mad * 100).toFixed(2)}% (ratio ${(s09.mad / Math.max(s0.mad, 1e-9)).toFixed(0)}x)`);
  }
  async t3() {
    const { renderFrames } = this.env;
    await renderFrames(28, {
      spin: 0.9, camR: 20, camInc: 81 * deg, fov: 56 * deg,
      disk: true, jet: false, nebula: false, stars: false, gradientSky: false, fixedTime: 3.0,
    });
    const { buf, w, h } = this.readAccum();
    const { buf: dat } = this.readData();
    const lumaOf = (i) => buf[i] * 0.2126 + buf[i + 1] * 0.7152 + buf[i + 2] * 0.0722;
    let lL = 0, rL = 0, ln = 0, rn = 0;
    let lR = 0, lG = 0, lB = 0, rR = 0, rG = 0, rB = 0;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const p = (y * w + x) * 4;
      if (dat[p + 2] < 0.5 || dat[p + 2] > 1.5) continue;   // disk pixels only
      const l = lumaOf(p);
      if (x < w / 2) { lL += l; ln++; lR += buf[p]; lG += buf[p + 1]; lB += buf[p + 2]; }
      else { rL += l; rn++; rR += buf[p]; rG += buf[p + 1]; rB += buf[p + 2]; }
    }
    const ml = lL / Math.max(ln, 1), mr = rL / Math.max(rn, 1);
    const ratio = Math.max(ml, mr) / Math.max(Math.min(ml, mr), 1e-6);
    // CCT proxy: blue/red ratio of the brighter vs dimmer half
    const brB = (lB / Math.max(lR, 1e-6)), rB2 = (rB / Math.max(rR, 1e-6));
    const brightBlue = ml > mr ? brB : rB2;
    const dimBlue = ml > mr ? rB2 : brB;
    const ok = ratio >= 2.0 && brightBlue > dimBlue;
    this.log('T3 Doppler asymmetry', ok,
      `approach/recede luminance ratio = ${ratio.toFixed(2)} (>=2), B/R bright ${(brightBlue).toFixed(3)} vs dim ${(dimBlue).toFixed(3)}`);
  }
  async t4() {
    const { renderFrames } = this.env;
    const innerEdge = async (spin) => {
      await renderFrames(24, {
        spin, camR: 22, camInc: 80 * deg, fov: 55 * deg,
        disk: true, jet: false, nebula: false, stars: false, gradientSky: false, fixedTime: 5.0,
      });
      const ev = this.readData(1), d2 = this.readData(2);
      const { w, h } = ev;
      let rmin = 1e9, count = 0;
      for (let y = 0; y < h; y += 2) for (let x = 0; x < w; x += 2) {
        const p = (y * w + x) * 4;
        if (ev.buf[p + 2] > 0.5 && ev.buf[p + 2] < 1.5) { rmin = Math.min(rmin, d2.buf[p]); count++; }
      }
      return { rmin, count };
    };
    const A = await innerEdge(0.0);
    const B = await innerEdge(0.9);
    const z1 = 1 + Math.cbrt(1 - 0.81) * (Math.cbrt(1.9) + Math.cbrt(0.1));
    const z2 = Math.sqrt(3 * 0.81 + z1 * z1);
    const risco09 = 3 + z2 - Math.sqrt((3 - z1) * (3 + z1 + 2 * z2));
    const theo = risco09 / 6;
    const meas = B.rmin / A.rmin;
    const rel = Math.abs(meas - theo) / theo;
    this.log('T4 ISCO tracking', rel < 0.10,
      `inner edge r: a=0 ${A.rmin.toFixed(3)} M, a=0.9 ${B.rmin.toFixed(3)} M, ratio ${meas.toFixed(3)} vs ISCO ratio ${theo.toFixed(3)} (${(rel * 100).toFixed(1)}%)`);
  }
  async t5() {
    const { renderFrames } = this.env;
    await renderFrames(24, {
      spin: 0.5, camR: 22, camInc: 78 * deg, fov: 55 * deg,
      disk: true, jet: false, nebula: false, stars: false, gradientSky: false, fixedTime: 5.0,
    });
    const acc = this.readAccum();
    const ev = this.readData(1);
    const dat = this.readData(2);
    const z1 = 1 + Math.cbrt(1 - 0.25) * (Math.cbrt(1.5) + Math.cbrt(0.5));
    const z2 = Math.sqrt(3 * 0.25 + z1 * z1);
    const rin = 3 + z2 - Math.sqrt((3 - z1) * (3 + z1 + 2 * z2));
    // three radial bands INSIDE the disk (outer radius 15 M): inner rim,
    // mid, outer lanes - CCT must decrease monotonically outward
    const bands = [[rin + 0.2, rin * 1.5], [rin * 1.9, rin * 2.7], [rin * 3.0, rin * 3.5]];
    const out = [];
    for (const [lo, hi] of bands) {
      let r = 0, g = 0, b = 0, n = 0;
      for (let y = 0; y < acc.h; y += 2) for (let x = 0; x < acc.w; x += 2) {
        const p = (y * acc.w + x) * 4;
        const rh = dat.buf[p];
        if (ev.buf[p + 2] > 0.5 && ev.buf[p + 2] < 1.5 && rh >= lo && rh < hi) {
          r += acc.buf[p]; g += acc.buf[p + 1]; b += acc.buf[p + 2]; n++;
        }
      }
      if (n < 8) { out.push(null); continue; }
      out.push({ r: r / n, g: g / n, b: b / n, n, rm: (lo + hi) / 2 });
    }
    // chromaticity of each band
    const M = [[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]];
    const xy = (rgb) => {
      const X = 0.4124 * rgb[0] + 0.3576 * rgb[1] + 0.1805 * rgb[2];
      const Y = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
      const Z = 0.0193 * rgb[0] + 0.1192 * rgb[1] + 0.9505 * rgb[2];
      const s = X + Y + Z;
      return [X / s, Y / s];
    };
    const CCT = (p) => {
      const n = (p[0] - 0.3320) / (0.1858 - p[1]);
      return 449 * n ** 3 + 3525 * n ** 2 + 6823.3 * n + 5520.33;
    };
    const ccts = [];
    let locusMax = 0;
    for (const band of out) {
      if (!band) { ccts.push(NaN); continue; }
      const p = xy([band.r, band.g, band.b]);
      // best-fit temperature on our own fitted Planck locus (same polynomial as the shader)
      let best = 1e9, bestT = NaN;
      for (let T = 1200; T <= 30000; T += 50) {
        const q = xy(bbJS(T));
        const d = Math.hypot(q[0] - p[0], q[1] - p[1]);
        if (d < best) { best = d; bestT = T; }
      }
      locusMax = Math.max(locusMax, best);
      ccts.push(bestT);
    }
    const valid = ccts.filter((c) => Number.isFinite(c));
    // McCamy is only valid to ~25000 K; use its iso-temperature line slope n for ordering
    const mono = ccts.length === 3 && ccts.every(Number.isFinite) && ccts[0] > ccts[1] && ccts[1] > ccts[2];
    const ok = mono && locusMax < 0.02 && out.every((b) => b);
    this.log('T5 blackbody sanity', ok,
      `locus CCT @ r≈${out.map((b) => (b ? b.rm.toFixed(1) : '?')).join(',')}: ${ccts.map((c) => c.toFixed(0)).join(' > ')} K (decreasing), max locus dist ${locusMax.toFixed(4)} (<0.02)`);
  }
  async t6() {
    const { renderFrames } = this.env;
    const hash = async () => {
      await renderFrames(8, {
        spin: 0.7, camR: 18, camInc: 80 * deg, fov: 56 * deg,
        disk: true, jet: true, nebula: true, stars: true, gradientSky: false, fixedTime: 12.345, cold: true,
      });
      const { buf } = this.readAccum();
      if (!SelfTest._fb) SelfTest._fb = new ArrayBuffer(4);
      const f32 = new Float32Array(SelfTest._fb), u32 = new Uint32Array(SelfTest._fb);
      let h = 2166136261;
      for (let i = 0; i < buf.length; i += 16) {
        f32[0] = buf[i];
        h ^= u32[0]; h = Math.imul(h, 16777619);
      }
      return h >>> 0;
    };
    const h1 = await hash();
    const h2 = await hash();
    this.log('T6 determinism', h1 === h2, `pixel hash ${h1.toString(16)} vs ${h2.toString(16)}`);
  }
  async t7() {
    const { renderFrames } = this.env;
    await renderFrames(4, {
      spin: 0.9, camR: 15, camInc: 76 * deg, fov: 56 * deg,
      disk: true, jet: true, nebula: true, stars: true, gradientSky: false, fixedTime: 7.7,
    });
    const { buf } = this.readAccum();
    let bad = 0;
    for (let i = 0; i < buf.length; i++) if (!Number.isFinite(buf[i])) bad++;
    this.log('T7 no NaN/Inf', bad === 0, `${bad} non-finite values in HDR target (tolerance 0)`);
  }
  // T9: the DEFAULT presented frame (default view, default parameters, full
  // composite: bloom, streak, ACES, grade) must have a black shadow and a sane
  // luminance histogram. Guards against "self-tests pass but the screen is a
  // milky sheet" regressions between the geodesic image and the display.
  async t9() {
    const { gl, renderer: R, camera } = this.env;
    // restore the boot default view exactly
    camera.orbit = null; camera.orbitFn = null;
    camera.target(26, 81 * deg, -35 * deg, 58);
    camera.sr.x = 26; camera.sr.v = 0;
    camera.st.x = 81 * deg; camera.st.v = 0;
    camera.sp.x = -35 * deg; camera.sp.v = 0;
    camera.sf.x = 58; camera.sf.v = 0;
    camera.tr = 26; camera.tt = 81 * deg; camera.tp = -35 * deg; camera.tf = 58;
    camera.settled = true;
    R.scale = 0.75; R.needResize = true; R.adaptScale = R.adaptScale; // stable test scale
    await this.waitFrames(30);                                  // TAA convergence
    // composite into a readable LDR target for one frame
    const { RT } = await import('./gl/targets.js');
    const rt = new RT(gl, R.canvasW, R.canvasH, {});
    R.presentRT = rt;
    await this.waitFrames(1);
    R.presentRT = null;
    const W = rt.w, H = rt.h;
    const px = new Uint8Array(W * H * 4);
    rt.bind();
    gl.readPixels(0, 0, W, H, gl.RGBA, gl.UNSIGNED_BYTE, px);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    rt.dispose();
    // captured-pixel mask from the geodesic data plane (same static view)
    const w = R.iw, h = R.ih;
    const ev = new Float32Array(w * h * 4);
    gl.bindFramebuffer(gl.FRAMEBUFFER, R.mrt.fbo);
    gl.readBuffer(gl.COLOR_ATTACHMENT1);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.FLOAT, ev);
    gl.readBuffer(gl.COLOR_ATTACHMENT0);
    // erode the captured mask by 3 px: the shadow's rim pixels legitimately
    // mix in ring/disk light (bloom, CA, TAA jitter, the 0.75-scale bilinear
    // upscale smears ~2 px inward). The VOID is the interior - measured there,
    // any pixel above threshold is a genuine leak. 3 px clears the filter halo.
    const cap0 = new Uint8Array(w * h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) cap0[y * w + x] = ev[(y * w + x) * 4 + 2] > 1.5 ? 1 : 0;
    const cap = new Uint8Array(w * h);
    const er = 3;
    for (let y = er; y < h - er; y++) for (let x = er; x < w - er; x++) {
      let m = 1;
      for (let dy = -er; dy <= er && m; dy++) for (let dx = -er; dx <= er && m; dx++) m = cap0[(y + dy) * w + x + dx];
      cap[y * w + x] = m;
    }
    let vn = 0, vsum = 0, vmax = 0, vHot = 0;
    for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      if (cap[i]) {
        const cx = Math.min(W - 1, Math.round(x / w * W));
        const cy = Math.min(H - 1, Math.round(y / h * H));  // both buffers are GL-oriented
        const q = (cy * W + cx) * 4;
        const l = 0.2126 * px[q] + 0.7152 * px[q + 1] + 0.0722 * px[q + 2];
        vn++; vsum += l; if (l > vmax) vmax = l; if (l > 24) vHot++;
      }
    }
    const vmean = vsum / Math.max(vn, 1);
    // full-frame histogram sanity
    let n = 0, sum = 0, hot = 0, dark = 0;
    const hist = new Array(32).fill(0);
    for (let q = 0; q < W * H; q++) {
      const l = 0.2126 * px[q * 4] + 0.7152 * px[q * 4 + 1] + 0.0722 * px[q * 4 + 2];
      n++; sum += l; if (l > 250) hot++; if (l < 10) dark++;
      hist[Math.min(31, l / 8 | 0)]++;
    }
    const mean = sum / n;
    const okVoid = vn > 2000 && vmean < 12 && vHot / vn < 0.01;
    // graded cinematic frame: luminance carried by disk + lensed sky; the
    // milky-frame guard is the deep-shadow FLOOR (a washed frame has no true
    // dark lanes left), not a large dark fraction.
    const okHist = mean > 25 && mean < 110 && hot / n < 0.12 && dark / n > 0.05;
    this.log('T9 default frame', okVoid && okHist,
      `shadow: mean ${vmean.toFixed(1)}/255, max ${vmax.toFixed(0)}, ${(100 * vHot / vn).toFixed(1)}% >24 (n=${vn}); ` +
      `frame: mean ${mean.toFixed(0)}, ${(100 * hot / n).toFixed(1)}% blown, ${(100 * dark / n).toFixed(0)}% deep-shadow`);
  }
  async waitFrames(n) {
    await new Promise((res) => {
      const n0 = window.__frame ? window.__frame.n : 0;
      const iv = setInterval(() => {
        if (window.__frame && window.__frame.n >= n0 + n) { clearInterval(iv); res(); }
      }, 16);
    });
  }
  // T10 — camera motion stability. Reproduces the videographer's drag test:
  // a fast scripted orbit must (a) actually rotate the camera by what was
  // commanded (an azimuth clamp once snapped it back), (b) reset the TAA
  // sample counter while moving (a counter that kept climbing meant history
  // was being blended through rotation), (c) not let the background strip
  // change GROW across the drag, (d) decay quickly once the drag stops, and
  // (e) never pin the render scale at its floor.
  async t10() {
    const { gl, renderer: R, camera } = this.env;
    camera.orbit = null; camera.orbitFn = null;
    camera.target(26, 81 * deg, -35 * deg, 58);
    camera.sr.x = 26; camera.st.x = 81 * deg; camera.sp.x = -35 * deg; camera.sf.x = 58;
    camera.tr = 26; camera.tt = 81 * deg; camera.tp = -35 * deg; camera.tf = 58;
    camera.settled = true;
    await this.waitFrames(40);
    const scale0 = R.scale;
    const ph0 = camera.state.ph;
    // ---- per-frame capture of a sky-only strip of the PRESENTED frame ----
    // Composite is pinned to a readable RT for the whole test and sampled from
    // a rAF callback (registered after the app's loop, so the frame is already
    // presented) - polling with setInterval skipped frames on fast hosts.
    const { RT } = await import('./gl/targets.js');
    const rt = new RT(gl, R.canvasW, R.canvasH, {});
    const H = R.canvasH, W = R.canvasW;
    const y0 = Math.round(H * 0.04), y1 = Math.round(H * 0.14);
    const sw = W, sh = y1 - y0;
    const buf = new Uint8Array(sw * sh * 4);
    const frames = [];
    let capOn = true;
    R.presentRT = rt;
    const capRAF = () => {
      if (!capOn) return;
      gl.bindFramebuffer(gl.FRAMEBUFFER, rt.fbo);
      gl.readPixels(0, y0, sw, sh, gl.RGBA, gl.UNSIGNED_BYTE, buf);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      const lum = new Float32Array(sw * sh);
      for (let i = 0; i < sw * sh; i++)
        lum[i] = 0.2126 * buf[i * 4] + 0.7152 * buf[i * 4 + 1] + 0.0722 * buf[i * 4 + 2];
      const f = window.__frame;
      frames.push({ n: f.n, lum, samples: f.samples, scale: f.scale });
      requestAnimationFrame(capRAF);
    };
    requestAnimationFrame(capRAF);
    // ---- scripted fast drag: 10 steps x 60 px, 120 ms apart ----
    const cv = document.getElementById('gl');
    const fire = (type, x, y) => cv.dispatchEvent(new PointerEvent(type, {
      pointerId: 7, clientX: x, clientY: y, bubbles: true, isPrimary: true,
    }));
    fire('pointerdown', 640, 400);
    for (let i = 1; i <= 10; i++) {
      fire('pointermove', 640 - 60 * i, 400);
      await new Promise((r) => setTimeout(r, 120));
    }
    fire('pointerup', 640 - 600, 400);
    const stopIdx = frames.length;
    await this.waitFrames(40);                     // decay window
    // ---- recovery window for the render scale ----
    const minScale = { v: 1 };
    let scaleEnd = R.scale;
    for (let k = 0; k < 260; k += 10) {
      await this.waitFrames(10);
      minScale.v = Math.min(minScale.v, R.scale);
      scaleEnd = R.scale;
      if (scaleEnd >= this.env.params.q.maxScale - 0.02 || scaleEnd >= scale0 - 0.06) break;
    }
    capOn = false;
    R.presentRT = null;
    rt.dispose();
    // ---- metrics ----
    const dphi = Math.atan2(Math.sin(camera.state.ph - ph0), Math.cos(camera.state.ph - ph0));
    const commanded = 10 * 60 * 0.005;
    const diffs = [];
    for (let i = 1; i < frames.length; i++) {
      const a = frames[i - 1], b = frames[i];
      if (b.n - a.n !== 1 || Math.abs(b.scale - a.scale) > 1e-6) { diffs.push(NaN); continue; }
      let s = 0;
      for (let k = 0; k < b.lum.length; k++) s += Math.abs(b.lum[k] - a.lum[k]);
      diffs.push(s / b.lum.length);
    }
    const motion = diffs.slice(0, stopIdx - 1).filter((d) => Number.isFinite(d));
    const post = diffs.slice(stopIdx - 1).filter((d) => Number.isFinite(d));
    const mPeak = Math.max(...motion, 0);
    // rotation frames only: pointer steps land in single frames, the rest of
    // the drag window is idle - measuring idle frames proves nothing.
    const rotFrames = motion.filter((d) => d > Math.max(4.0, 0.15 * mPeak));
    const half = Math.ceil(rotFrames.length / 2);
    const head = Math.max(...rotFrames.slice(0, half), 0);
    const tail = Math.max(...rotFrames.slice(half), 0);
    const noGrow = rotFrames.length >= 3 && tail <= 1.35 * head + 2.0;
    // decay: post-stop diffs must fall below 30% of the drag peak quickly and
    // settle to a crawl (frame-counted, so the check is fps-independent).
    let i8 = post.findIndex((d) => d <= Math.max(3.0, 0.3 * mPeak));
    let iSettle = -1, run = 0;
    for (let i = 0; i < post.length; i++) {
      run = post[i] <= 3.5 ? run + 1 : 0;
      if (run >= 4) { iSettle = i - 3; break; }
    }
    const samplesDuringMotion = Math.min(...frames.slice(0, stopIdx).map((f) => f.samples), 9999);
    const scaleFloorOk = minScale.v >= 0.49;
    const recoverOk = scaleEnd >= Math.min(scale0 - 0.06, this.env.params.q.maxScale - 0.02) || scaleEnd >= scale0;
    const turnOk = Math.abs(Math.abs(dphi) - commanded) < 0.15 * commanded;
    const ok = turnOk && noGrow && i8 >= 0 && i8 <= 8 && iSettle >= 0 && iSettle <= 20
      && samplesDuringMotion <= 3 && scaleFloorOk && recoverOk;
    this.log('T10 camera motion', ok,
      `turn ${(dphi * 180 / Math.PI).toFixed(1)}°/${(commanded * 180 / Math.PI).toFixed(0)}°; ` +
      `drag ΔL head→tail ${head.toFixed(1)}→${tail.toFixed(1)} (no-grow ${noGrow}); ` +
      `post-stop decay ≤30% peak in ${i8 < 0 ? '>' + post.length : i8 + 1}f, settled in ${iSettle < 0 ? '>' + post.length : iSettle + 1}f; ` +
      `samples during motion min ${samplesDuringMotion}; scale ${scale0.toFixed(2)}→${scaleEnd.toFixed(2)} (floor ${minScale.v.toFixed(2)})`);
  }
  async t8() {
    // Gravitational lensing of background point sources vs the numpy ground
    // truth in proto/lens_gt.py (independent float64 RK4 twin, same camera:
    // a=0.4, r0=25, inc=90deg, fov=26deg). A source at angular offset beta_s
    // from the view center must appear at the predicted image-plane NDC
    // position (u*, phi*) - pushed outward toward the Einstein radius and to
    // the far side. On-axis source (beta_s=0): the ring only resolves in the
    // sector the ground truth says it does (frame-dragging asymmetry).
    const { renderFrames } = this.env;
    const base = {
      spin: 0.4, camR: 25, camInc: 90 * deg, fov: 26 * deg,
      disk: false, jet: false, nebula: false, stars: false, gradientSky: false,
      testStar: true, fixedTime: 0,
    };
    const errs = [];
    const detail = [];
    // (beta_s, u*, phi*) from proto/lens_gt.py — numpy float64 twin of the same
    // camera + integrator. u* there is stored as horizontal NDC of the aspect
    // 1.6 field scan (ring_scan.py ASPECT=1.6). The COMPARISON unit here is
    // vertical half-FOV: u_v = hypot(ndc_x * aspect, ndc_y) with the aspect
    // MEASURED from the readback, which is the same physical angle at every
    // window size — a fraction of the frame is not. The GT is converted into
    // that unit once (u_gt_v = u_gt * GT_ASPECT); for this table phi=180deg
    // (equatorial source, inc=90 camera) so the vertical component is zero and
    // the scalar conversion is exact. Tolerance 0.02 in the GT's unit = 0.032
    // in the vertical unit: the SAME physical angle, not a loosening.
    const GT_ASPECT = 1.6;
    const TOL_U = 0.02 * GT_ASPECT;
    const tanHalf = Math.tan(base.fov / 2);
    const GT = [
      { b: 35 * deg, u: 0.7850, ph: 180.00 },
      { b: 50 * deg, u: 0.6900, ph: 180.00 },
      { b: 65 * deg, u: 0.6275, ph: 180.00 },
      { b: 80 * deg, u: 0.5850, ph: 180.00 },
    ];
    for (const g of GT) {
      await renderFrames(3, { ...base, testStarAngle: g.b });
      const { buf, w, h } = this.readRaw();
      const aspect = w / h;                 // measured — never assumed
      const cx = (w - 1) / 2, cy = (h - 1) / 2;
      const lum = (x, y) => { const p = (y * w + x) * 4; return buf[p] + buf[p + 1] + buf[p + 2]; };
      let peak = 0, px = 0, py = 0;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        const l = lum(x, y);
        if (l > peak) { peak = l; px = x; py = y; }
      }
      // centroid in a window around the dominant image only; the window is
      // square in PIXELS (= square in the vertical unit), so it does not
      // stretch with the aspect.
      const rw = Math.round(0.12 * cy);
      let sw = 0, sx = 0, sy = 0;
      for (let y = Math.max(0, py - rw); y < Math.min(h, py + rw); y++)
        for (let x = Math.max(0, px - rw); x < Math.min(w, px + rw); x++) {
          const l = lum(x, y);
          if (l > Math.max(0.4, 0.25 * peak)) { sw += l; sx += l * x; sy += l * y; }
        }
      if (sw <= 0) { errs.push(9); detail.push(`b=${(g.b / deg).toFixed(0)}: no image`); continue; }
      const nxc = (sx / sw) / cx - 1, nyc = (sy / sw) / cy - 1;
      const um = Math.hypot(nxc * aspect, nyc);      // vertical half-FOV units
      const ugt = g.u * GT_ASPECT;                   // GT in the same unit
      const angM = Math.atan(um * tanHalf) / deg;    // sky angle from center
      const angG = Math.atan(ugt * tanHalf) / deg;
      const du = um - ugt;
      let dph = Math.atan2(nyc, nxc * aspect) / deg; // physical azimuth
      dph = Math.min(Math.abs(dph - g.ph), 360 - Math.abs(dph - g.ph));
      errs.push(Math.max(Math.abs(du) / TOL_U, dph / 3.0));
      const phDeg = ((Math.atan2(nyc, nxc * aspect) / deg) + 360) % 360;
      detail.push(`b=${(g.b / deg).toFixed(0)}: u ${um.toFixed(3)} vs ${ugt.toFixed(3)} vNDC (${(du >= 0 ? '+' : '')}${(du * 1000).toFixed(0)}e-3), ${angM.toFixed(2)}° vs ${angG.toFixed(2)}° on sky, phi ${phDeg.toFixed(1)} vs ${g.ph}`);
    }
    // ---- on-axis Einstein ring: bright only in the ground-truth sector ----
    // The ring is ~1 px wide, so measure the TAA-CONVERGED accumulation
    // (24 jittered frames): that is the render's true area-averaged ring
    // brightness, not a single sub-pixel lottery sample.
    // The ring is ~1 px wide: measure the area average over the jittered RAW
    // frames. (The TAA accumulation clamps sub-pixel HDR spikes to the local
    // neighborhood, so the accum cannot represent a sub-pixel ring even when
    // every jittered frame renders it at the ground-truth radius.)
    await renderFrames(24, { ...base, testStarAngle: 0 });
    const run = this.readRaw();
    const w = run.w, h = run.h;
    const frames = [run.buf];
    for (let k = 0; k < 7; k++) {
      await renderFrames(1, { ...base, testStarAngle: 0, cold: false });
      frames.push(this.readRaw().buf);
    }
    const NF = frames.length;
    const buf = frames[0];
    const { buf: ev } = this.readData(1);
    const cx = (w - 1) / 2, cy = (h - 1) / 2;
    const lum = (x, y) => {
      let s = 0;
      for (let k = 0; k < NF; k++) { const p = (y * w + x) * 4; s += frames[k][p] + frames[k][p + 1] + frames[k][p + 2]; }
      return s / NF;
    };
    const isCap = (x, y) => ev[(y * w + x) * 4 + 2] > 1.5;
    // rim radius in the ground-truth sector (image azimuth ~180deg)
    const rimAt = (phDeg) => {
      const ph = phDeg * deg; let rb = 0;
      const dxr = Math.cos(ph), dyr = Math.sin(ph) * (h / w);
      for (let t = 1; t < h; t++) {
        const x = Math.round(cx + dxr * t), y = Math.round(cy + dyr * t);
        if (x < 1 || y < 1 || x >= w - 1 || y >= h - 1) break;
        if (isCap(x, y)) rb = Math.max(rb, t);
      }
      return rb;
    };
    const rb = rimAt(180);
    // ring window: just outside the rim (ground truth: u_peak/u_rim ~ 1.006,
    // resolvable band < 0.03 wide), same azimuth sector; compare against the
    // anti-sector (image azimuth ~0) which must stay dark.
    const sectorMax = (phDeg) => {
      const ph = phDeg * deg; let mx = 0;
      for (let dp = -8; dp <= 8; dp += 2) {
        const p2 = ph + dp * deg;
        const dxr = Math.cos(p2), dyr = Math.sin(p2) * (h / w);
        for (let t = Math.max(1, rb - 3); t < rb + 0.05 * rb + 6; t++) {
          const x = Math.round(cx + dxr * t), y = Math.round(cy + dyr * t);
          if (x < 1 || y < 1 || x >= w - 1 || y >= h - 1) continue;
          mx = Math.max(mx, lum(x, y));
        }
      }
      return mx;
    };
    const sky = 0.019;
    const ringL = sectorMax(180), antiL = sectorMax(0);
    const okRing = ringL > 12 * sky && antiL < 5 * sky;
    detail.push(`ring sector ${ringL.toFixed(2)} (${(ringL / sky).toFixed(0)}x sky), anti-sector ${antiL.toFixed(2)}`);
    const ok = errs.every((e) => e <= 1.0) && okRing;
    this.log('T8 lensing vs numpy GT', ok, detail.join('; '));
  }
}
// JS twin of the shader's blackbody polynomial (for locus checks).
export function bbJS(T) {
  const u = Math.min(4.61, Math.max(2.9, Math.log10(Math.max(T, 500))));
  const cr = [-1.694118e-01, 5.256859e+00, -7.082192e+01, 5.391608e+02, -2.519677e+03, 7.292016e+03, -1.224751e+04, 9.132570e+03, 2.147898e+03, -5.637722e+03];
  const cg = [1.483784e-02, -4.632840e-01, 6.207899e+00, -4.591267e+01, 1.979687e+02, -4.588871e+02, 2.744677e+02, 1.250792e+03, -3.039230e+03, 2.154640e+03];
  const cb = [3.518688e-01, -1.089013e+01, 1.470478e+02, -1.132809e+03, 5.458395e+03, -1.692641e+04, 3.334516e+04, -3.928187e+04, 2.378136e+04, -4.728795e+03];
  const ev = (c) => c.reduce((a, v) => a * u + v, 0);
  return [Math.max(0, ev(cr)), Math.max(0, ev(cg)), Math.max(0, ev(cb))];
}
