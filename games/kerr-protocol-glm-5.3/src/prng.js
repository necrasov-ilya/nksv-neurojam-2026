// Deterministic PRNG (mulberry32) + blue noise tile. No Math.random in the render path.
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
// Integer hash for spatial noise (used for deterministic star/noise seeds in JS only).
export function hash2i(x, y) {
  let h = (x * 374761393 + y * 668265263) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return (h ^ (h >>> 16)) >>> 0;
}
// R2 low-discrepancy sequence: jitter frame n -> deterministic sub-pixel offsets.
export function r2(n) {
  return [
    (0.5 + 0.7548776662466927 * n) % 1,
    (0.5 + 0.5698402909980532 * n) % 1,
  ];
}
// Compact void-and-cluster blue noise on a N x N torus (deterministic).
export function makeBlueNoise(n = 32) {
  const N = n, M = N * N;
  const sigma = 1.9, half = 4;
  const pre = [];
  for (let j = -half; j <= half; j++) for (let i = -half; i <= half; i++) {
    pre.push(Math.exp(-((i * i + j * j) / (2 * sigma * sigma))));
  }
  const energy = new Float32Array(M);
  const add = (x, y, s) => {
    const cx = Math.floor(x), cy = Math.floor(y), fx = x - cx, fy = y - cy;
    for (let j = -half; j <= half + 1; j++) for (let i = -half; i <= half + 1; i++) {
      const w = (pre[(j + half) * (2 * half + 1) + (i + half)] || 0);
      if (w === 0) continue;
      const bx = (cx + i + N) % N, by = (cy + j + N) % N;
      const ddx = Math.abs(i + 0.5 - fx), ddy = Math.abs(j + 0.5 - fy);
      if (ddx > half || ddy > half) continue;
      energy[by * N + bx] += s * w;
    }
  };
  const rand = mulberry32(0x9E3779B9);
  // Initial white noise pattern: keep ~10% darkest ranks as prototypes.
  const initial = [];
  for (let i = 0; i < M; i++) initial.push(rand());
  initial.sort((a, b) => a - b);
  const lim = initial[Math.floor(M * 0.1)];
  const used = new Uint8Array(M);
  let count = 0;
  for (let i = 0; i < M; i++) if (rand() < 0.5 && count < M * 0.1) { used[i] = 1; count++; }
  for (let i = 0; i < M; i++) if (used[i]) add(i % N, Math.floor(i / N), 1);
  const rank = new Uint8Array(M);
  for (let k = 0; k < M; k++) {
    // tightest cluster
    let best = -1, bestE = Infinity;
    for (let i = 0; i < M; i++) if (!used[i] && energy[i] > 0 && energy[i] < bestE) { bestE = energy[i]; best = i; }
    if (best < 0) for (let i = 0; i < M; i++) if (!used[i]) { best = i; break; }
    used[best] = 1; rank[best] = k; add(best % N, Math.floor(best / N), 1);
  }
  // convert ranks to [0,255], energy-spread check omitted for compactness
  const out = new Uint8Array(M);
  for (let i = 0; i < M; i++) out[i] = Math.round(255 * rank[i] / (M - 1));
  return { data: out, size: N };
}
