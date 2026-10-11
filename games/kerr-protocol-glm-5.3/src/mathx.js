export const clamp = (x, a, b) => (x < a ? a : x > b ? b : x);
export const lerp = (a, b, t) => a + (b - a) * t;
export const deg = Math.PI / 180;
// Critical damping spring toward target; advances state {x, v} by dt.
export function springStep(s, target, omega, dt) {
  const t = Math.min(dt, 1 / 20);
  const n1 = 1.0 / (1.0 + 2.0 * omega * t);
  const n2 = t * omega * omega * n1;
  const n3 = (2.0 * n2) / (t * (1.0 + 2.0 * omega * t));
  const d = target - s.x;
  const nv = (s.v + n2 * d) / (1.0 + 2.0 * omega * t);
  s.x += t * nv;
  s.v = nv;
  s.dx = d;
  return s;
}
export function fmt(x, digits = 2) {
  if (!Number.isFinite(x)) return '—';
  return x.toFixed(digits);
}
export function isPowerOfTwo(x) { return (x & (x - 1)) === 0; }
