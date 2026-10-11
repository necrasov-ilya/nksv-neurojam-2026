// Orbit camera in Boyer-Lindquist coordinates: (r, theta=inclination, phi).
// Critically damped springs on every axis -> no snap cuts, no linear lerps.
import { springStep, clamp } from './mathx.js';
import { deg } from './mathx.js';
const OMEGA = 3.0; // spring stiffness (~2 s transitions)
export class Camera {
  constructor() {
    this.sr = { x: 26, v: 0 };     // radius, M
    this.st = { x: 81 * deg, v: 0 }; // inclination (from +spin axis)
    this.sp = { x: -35 * deg, v: 0 }; // azimuth
    this.sf = { x: 58, v: 0 };     // fov, degrees
    this.tr = this.sr.x; this.tt = this.st.x; this.tp = this.sp.x; this.tf = this.sf.x;
    this.orbit = null;             // cinematic override (fn(t) -> {r,th,ph,fov})
    this.velocity = 0;             // max |dx/dt| of params, for TAA motion gating
    this.dragging = false;         // pointer drag in progress (settled must be false)
  }
  target(r, th, ph, fov) {
    this.tr = r; this.tt = th; this.tp = ph; this.tf = fov ?? this.tf;
  }
  orbitDolly(dr) { this.tr = clamp(this.tr * Math.exp(dr * 0.0012), 2.2, 90); this.sr.x = clamp(this.sr.x, 2.2, 90); }
  // Drag tracks the pointer directly (state and target move together, spring
  // follows at zero lag). AZIMUTH IS FREE: it must never be clamped to a
  // half-circle - clamping it made the state snap to the boundary mid-drag and
  // the spring whip it back ("fails to turn / shudders"). Keep it bounded by
  // wrapping STATE and TARGET through 2*pi together, so the spring error stays
  // on the shortest arc.
  orbitDrag(dx, dy) {
    this.tp -= dx * 0.005;
    this.tt = clamp(this.tt - dy * 0.005, 0.05, Math.PI - 0.05);
    this.st.x = clamp(this.st.x, 0.05, Math.PI - 0.05);
    this.sp.x = this.tp;   // direct tracking; springs see zero error
    if (this.sp.x > Math.PI) { this.sp.x -= 2 * Math.PI; this.tp -= 2 * Math.PI; }
    else if (this.sp.x < -Math.PI) { this.sp.x += 2 * Math.PI; this.tp += 2 * Math.PI; }
  }
  setInclination(degrees) { this.tt = clamp(degrees * deg, 0.05, Math.PI - 0.05); this.st.x = this.tt; }
  update(dt) {
    if (this.orbit) {
      const c = this.orbit(this.orbit.t);
      this.orbit.t += dt;
      this.tr = c.r; this.tt = c.th; this.tp = c.ph; this.tf = c.fov;
    }
    const d0 = Math.abs(this.sr.x - this.tr) + 2 * Math.abs(this.st.x - this.tt)
      + 2 * Math.abs(this.sp.x - this.tp) + 0.4 * Math.abs(this.sf.x - this.tf);
    springStep(this.sr, this.tr, OMEGA, dt);
    springStep(this.st, this.tt, OMEGA, dt);
    springStep(this.sp, this.tp, OMEGA, dt);
    springStep(this.sf, this.tf, OMEGA * 0.8, dt);
    this.velocity = d0;
    const moved = Math.abs(this.sr.dx) + Math.abs(this.st.dx) + Math.abs(this.sp.dx) > 1e-4;
    this.settled = !moved && !this.orbit && !this.dragging;
  }
  get state() {
    return { r: this.sr.x, th: this.st.x, ph: this.sp.x, fov: this.sf.x };
  }
}
// Five composed shots (r, inclination°, azimuth°, fov°).
export const SHOTS = [
  { name: 'HERO',        r: 23.5, inc: 81.0, az: -38, fov: 56, exp: 1.00 },
  { name: 'EDGE-ON',     r: 21.0, inc: 86.5, az: 12,  fov: 55, exp: 0.74 },
  { name: 'HIGH',        r: 28.0, inc: 46.0, az: 55,  fov: 52, exp: 1.00, jet: 2.0 },
  { name: 'PHOTON RING', r: 8.6,  inc: 83.5, az: -20, fov: 44, exp: 0.38 },
  { name: 'JET',         r: 40.0, inc: 55.0, az: 10,  fov: 54, exp: 0.95, jet: 16.0 },
];
// Seamless 30 s loop: integer numbers of cycles per period for exact closure.
export function cinematicOrbit(t) {
  const T = 30, w = 2 * Math.PI / T, u = (t % T) / T * 2 * Math.PI;
  const az0 = -0.60;
  return {
    r:  24.5 + 3.6 * Math.sin(u),                    // 1 cycle
    th: (81.5 + 3.8 * Math.sin(2 * u + 1.1)) * deg,  // 2 cycles
    ph: az0 + u,                                     // 1 turn
    fov: 57 + 2.5 * Math.sin(u + 1.6),
  };
}
