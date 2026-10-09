// Procedural color system + texture helpers for the whole game.
// One palette, one voice: 1950s future seen through a dirty lens.

import * as THREE from "three";

export const Pal = {
  turquoise: 0x7ba3a0,
  turquoiseDark: 0x4f7c79,
  cream: 0xd8cdb4,
  creamDark: 0xbca989,
  mustard: 0xc9a22f,
  mustardDark: 0xa37d1f,
  fadedRed: 0xa03e2d,
  fadedRedLight: 0xc0553a,
  petrol: 0x2f5d50,
  petrolLight: 0x3f7a68,
  asphalt: 0x383b40,
  asphaltDark: 0x2c2f34,
  concrete: 0x8d8a83,
  concreteDark: 0x6f6c66,
  zombie: 0x8fbf3f,
  zombieDark: 0x5f8a2c,
  emergency: 0xd23c2f,
  emergencyLight: 0xff5030,
  windowWarm: 0xffc87a,
  windowCold: 0xaecdff,
  neonTurquoise: 0x41e0d6,
  neonRed: 0xff4433,
  neonYellow: 0xffd54a,
  skin: 0x9fb48a, // sickly zombie skin
  skinDead: 0x7d9a66,
  blood: 0x6e1d20,
  shadowWrap: 0x141518,
  fog: 0x8fa3a8,
};


export function mix(a: number, b: number, t: number): number {
  const ca = new THREE.Color(a);
  const cb = new THREE.Color(b);
  const out = new THREE.Color().lerpColors(ca, cb, t);
  return out.getHex();
}

/** 4x4 checker canvas for tileable grime variations. */
export function noiseCanvas(w: number, h: number, base: number, amp: number): THREE.CanvasTexture {
  const cv = document.createElement("canvas");
  cv.width = w;
  cv.height = h;
  const g = cv.getContext("2d");
  if (!g) throw new Error('Canvas 2D is required for procedural textures');
  const img = g.createImageData(w, h);
  // deterministic pseudo-rng (stable across runs)
  let s = 1234567;
  const nr = () => {
    s = Math.imul(s ^ (s >>> 15), s | 1);
    s ^= Math.imul(s ^ (s >>> 7), s | 61);
    return ((s ^ (s >>> 14)) >>> 0) / 4294967296;
  };
  const cb = new THREE.Color(base);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const t = 1 + (nr() - 0.5) * 2 * amp;
      const c = cb.clone().multiplyScalar(Math.min(t, 1.6));
      const idx = (y * w + x) * 4;
      img.data[idx] = Math.round(c.r * 255);
      img.data[idx + 1] = Math.round(c.g * 255);
      img.data[idx + 2] = Math.round(c.b * 255);
      img.data[idx + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

/** Retro sign texture: bold distressed uppercase text on a panel. */
export function signCanvas(
  text: string,
  fg: number,
  bg: number,
  w = 512,
  h = 192,
): THREE.CanvasTexture {
  const cv = document.createElement("canvas");
  cv.width = w;
  cv.height = h;
  const g = cv.getContext("2d");
  if (!g) throw new Error('Canvas 2D is required for signage');
  const bgc = new THREE.Color(bg);
  g.fillStyle = `rgb(${Math.round(bgc.r * 255)},${Math.round(bgc.g * 255)},${Math.round(bgc.b * 255)})`;
  g.fillRect(0, 0, w, h);
  // border like a neon frame
  const fgc = new THREE.Color(fg);
  g.strokeStyle = `rgb(${Math.round(fgc.r * 255)},${Math.round(fgc.g * 255)},${Math.round(fgc.b * 255)})`;
  g.lineWidth = 10;
  g.strokeRect(4, 4, w - 8, h - 8);
  g.fillStyle = g.strokeStyle;
  g.font = `bold ${Math.round(h * 0.52)}px "Arial Black", "Impact", sans-serif`;
  g.textAlign = "center";
  g.textBaseline = "middle";
  g.fillText(text, w / 2, h / 2 + 8);
  // distressed streaks
  let s = 99;
  const nr = () => {
    s = Math.imul(s ^ (s >>> 15), s | 1);
    s ^= Math.imul(s ^ (s >>> 7), s | 61);
    return ((s ^ (s >>> 14)) >>> 0) / 4294967296;
  };
  for (let i = 0; i < 26; i++) {
    g.fillStyle = `rgba(0,0,0,${0.04 + nr() * 0.1})`;
    g.fillRect(nr() * w, nr() * h, w * (0.05 + nr() * 0.2), 3 + nr() * 7);
  }
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

export const hex = (v: number) => new THREE.Color(v);