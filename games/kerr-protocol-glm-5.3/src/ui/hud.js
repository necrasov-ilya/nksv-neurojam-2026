// Instrument-grade HUD: status, physics panel (computed numbers + formulas),
// custom sliders, hint, debug overlay. DOM, monospace, tabular numbers.
import { deg, fmt } from '../mathx.js';

const sph3 = Math.sqrt(3);
export function physicsNumbers(spin, camR) {
  const a = spin;
  const rplus = 1 + Math.sqrt(Math.max(0, 1 - a * a));
  const z1 = 1 + Math.cbrt(1 - a * a) * (Math.cbrt(1 + a) + Math.cbrt(1 - a));
  const z2 = Math.sqrt(3 * a * a + z1 * z1);
  const risco = 3 + z2 - Math.sqrt((3 - z1) * (3 + z1 + 2 * z2));
  const rphPro = 2 * (1 + Math.cos((2 / 3) * Math.acos(-a)));
  const rphRet = 2 * (1 + Math.cos((2 / 3) * Math.acos(a)));
  const bph = (r) => Math.abs(a) < 1e-6 ? 3 * sph3
    : Math.abs(-(r * r * r - 3 * r * r + a * a * r + a * a) / (a * (r - 1)));
  const bPro = bph(rphPro), bRet = bph(rphRet);
  const thShadow = Math.asin(Math.min(1, bPro / Math.max(camR, bPro + 1e-3)));
  const tIsco = 2 * Math.PI * (Math.pow(risco, 1.5) + a);
  return { rplus, risco, rphPro, rphRet, bPro, bRet, thShadow, tIsco };
}

export class Hud {
  constructor(params, camera) {
    this.params = params; this.camera = camera;
    this.el = {
      status: document.getElementById('status'),
      physics: document.getElementById('physics'),
      hint: document.getElementById('hint'),
      debug: document.getElementById('debug'),
      toast: document.getElementById('toast'),
    };
    this.hintShown = true;
    this.sliders = [];
    this.buildSliders();
    this.el.hint.innerHTML =
      '<b>drag</b> orbit &nbsp;·&nbsp; <b>wheel</b> dolly &nbsp;·&nbsp; ' +
      '<b>1–5</b> shots &nbsp;·&nbsp; <b>C</b> cinematic loop &nbsp;·&nbsp; <b>P</b> still ' +
      '&nbsp;·&nbsp; <b>G</b> quality &nbsp;·&nbsp; <b>J</b> jet &nbsp;·&nbsp; ' +
      '<b>T</b> self-test &nbsp;·&nbsp; <b>H</b> hide HUD';
    this.toastTimer = 0;
  }
  buildSliders() {
    const mk = (label, min, max, get, set, fmtFn) => {
      const row = document.createElement('div');
      row.className = 'slider-row';
      const lab = document.createElement('span'); lab.className = 'slider-label'; lab.textContent = label;
      const track = document.createElement('div'); track.className = 'track';
      const knob = document.createElement('div'); knob.className = 'knob';
      track.appendChild(knob);
      const val = document.createElement('span'); val.className = 'slider-val';
      row.append(lab, track, val);
      this.el.status.appendChild(row);
      const update = () => {
        const t = (get() - min) / (max - min);
        knob.style.left = `${(t * 127).toFixed(1)}px`;
        val.textContent = fmtFn(get());
      };
      const apply = (e) => {
        const rect = track.getBoundingClientRect();
        const t = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width));
        set(min + t * (max - min));
        update();
      };
      let drag = false;
      track.addEventListener('pointerdown', (e) => { drag = true; track.setPointerCapture(e.pointerId); apply(e); });
      track.addEventListener('pointermove', (e) => { if (drag) apply(e); });
      track.addEventListener('pointerup', () => { drag = false; });
      this.sliders.push(update);
      update();
    };
    const P = this.params;
    mk('spin a', 0, 0.999, () => P.p.spin, (v) => P.set('spin', Math.round(v * 1000) / 1000), (v) => v.toFixed(3));
    mk('inclination', 5, 175, () => this.camera.tt / deg, (v) => this.camera.setInclination(v), (v) => v.toFixed(1) + '°');
    mk('exposure EV', -2, 2, () => Math.log2(P.p.exposure), (v) => P.set('exposure', Math.pow(2, v)), (v) => (v >= 0 ? '+' : '') + v.toFixed(2));
    mk('disk bright', 0.1, 3, () => P.p.diskBright, (v) => P.set('diskBright', v), (v) => v.toFixed(2));
    mk('nebula', 0, 3, () => P.p.nebulaBright, (v) => P.set('nebulaBright', v), (v) => v.toFixed(2));
    const tgl = (label, get, set) => {
      const row = document.createElement('div');
      row.className = 'slider-row';
      const lab = document.createElement('span'); lab.className = 'slider-label'; lab.textContent = label;
      const btn = document.createElement('span'); btn.className = 'toggle';
      const upd = () => { btn.textContent = get() ? '[ on ]' : '[ off ]'; btn.classList.toggle('on', get()); };
      btn.addEventListener('pointerdown', (e) => { e.stopPropagation(); set(!get()); upd(); });
      row.append(lab, btn);
      this.el.status.appendChild(row);
      upd();
    };
    tgl('jet', () => P.p.jetOn, (v) => P.set('jetOn', v));
  }
  toast(msg) {
    const t = this.el.toast;
    t.textContent = msg;
    t.hidden = false;
    t.style.opacity = '1';
    this.toastTimer = performance.now() + 1400;
  }
  dismissHint() {
    this.el.hint.style.display = 'none';
  }
  update(ctx) {
    // called ~10 Hz. ctx: {fps, ms, p50, p95, renderer, params, camera, stats, scene}
    if (this.toastTimer && performance.now() > this.toastTimer) {
      this.el.toast.style.opacity = '0'; this.toastTimer = 0;
    }
    for (const s of this.sliders) s();
    const P = this.params.p, R = ctx.renderer, cam = ctx.camera;
    const ph = physicsNumbers(P.spin, cam.sr.x);
    const lines = [
      `KERR  a=${P.spin.toFixed(3)}   M=1  G=c=1`,
      `incl ${fmt(cam.st.x / deg, 1)}°  r ${fmt(cam.sr.x, 1)} M  fov ${fmt(cam.sf.x, 0)}°`,
      `ISCO ${ph.risco.toFixed(3)} M   r+ ${ph.rplus.toFixed(3)} M`,
      `shadow θ ${fmt(ph.thShadow / deg, 3)}°   scale ${R.scale.toFixed(2)}`,
      `samples ${R.samples}   exp ${fmt(P.exposure, 2)}`,
    ];
    this.el.status.firstChild && this.el.status.childNodes.forEach(() => {});
    // replace only the plain text nodes, keep sliders
    let textIdx = 0;
    const textBlock = document.createElement('div');
    textBlock.textContent = lines.join('\n');
    if (!this._textPlaced) { this.el.status.prepend(textBlock); this._textPlaced = true; }
    else this.el.status.firstChild.textContent = lines.join('\n');
    const f = (sym, name, val, formula) => `${sym} ${name.padEnd(9)} ${val}\n    ${formula}`;
    this.el.physics.textContent = [
      '— KERR PHYSICS —',
      f('r+', 'horizon', ph.rplus.toFixed(4) + ' M', '1+sqrt(1-a²)'),
      f('r_isco', 'ISCO', ph.risco.toFixed(4) + ' M', '3+Z2-sqrt((3-Z1)(3+Z1+2Z2))'),
      f('r_ph-', 'phot pro', ph.rphPro.toFixed(4) + ' M', '2(1+cos(2/3 arccos(-a)))'),
      f('r_ph+', 'phot ret', ph.rphRet.toFixed(4) + ' M', '2(1+cos(2/3 arccos(+a)))'),
      f('b_ph-', 'b_crit p', ph.bPro.toFixed(4) + ' M', P.spin === 0 ? '3√3 M' : '|-(r³-3r²+a²r+a²)/(a(r-1))|'),
      f('b_ph+', 'b_crit r', ph.bRet.toFixed(4) + ' M', ''),
      f('T_isco', 'period', ph.tIsco.toFixed(2) + ' M/c', '2π(r^(3/2)+a)'),
      f('θ_sh', 'shadow', (ph.thShadow / deg).toFixed(3) + '°', 'asin(b_ph-/r_cam)'),
      f('g-', 'doppler min', ctx.stats.gMin.toFixed(3), 'min E_cam/E_em on screen'),
      f('g+', 'doppler max', ctx.stats.gMax.toFixed(3), 'max E_cam/E_em on screen'),
      f('steps', 'avg/max', `${ctx.stats.avgSteps.toFixed(0)}/${ctx.stats.maxSteps.toFixed(0)}`, 'geodesic RK4 steps'),
    ].join('\n');
    if (this.debugOn) {
      this.el.debug.hidden = false;
      this.el.debug.textContent = [
        `${ctx.fps.toFixed(0)} fps   ${ctx.ms.toFixed(1)} ms`,
        `frame p50 ${ctx.p50.toFixed(1)} ms   p95 ${ctx.p95.toFixed(1)} ms`,
        `render scale ${R.scale.toFixed(3)}  internal ${R.iw}x${R.ih}`,
        `steps avg ${ctx.stats.avgSteps.toFixed(0)}  max ${ctx.stats.maxSteps}`,
        `samples ${R.samples}  frame ${R.frame}`,
        `bloom ${this.params.q.bloomLevels} lvl  quality ${this.params.q.name}`,
      ].join('\n');
    } else this.el.debug.hidden = true;
  }
}
