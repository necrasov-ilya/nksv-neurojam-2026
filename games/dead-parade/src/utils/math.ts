// Shared math helpers — durable utility contract used across all systems.
// These are kept as exported named functions because dozens of call sites
// depend on identical, lockstep behavior (angles, damping, clamping).

export const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const damp = (a: number, b: number, l: number, dt: number) =>
  lerp(a, b, 1 - Math.exp(-l * dt));

export function lerpAngle(a: number, b: number, t: number): number {
  let d = (b - a) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}

export function dampAngle(a: number, b: number, l: number, dt: number): number {
  return lerpAngle(a, b, 1 - Math.exp(-l * dt));
}

export const dist2 = (ax: number, az: number, bx: number, bz: number) => {
  const dx = ax - bx;
  const dz = az - bz;
  return Math.sqrt(dx * dx + dz * dz);
};

// Squared distance (cheap ordering).
export const dist2sq = (ax: number, az: number, bx: number, bz: number) => {
  const dx = ax - bx;
  const dz = az - bz;
  return dx * dx + dz * dz;
};

export function normalizeAngle(a: number): number {
  while (a > Math.PI) a -= Math.PI * 2;
  while (a < -Math.PI) a += Math.PI * 2;
  return a;
}