// Lensed sky: procedural star field with PSF + diffraction spikes, volumetric
// nebula backdrop, deterministic. Sampled at the END of each integrated geodesic.
uniform vec4 uFeatureToggles;   // x disk, y jet, z nebula, w stars
uniform float uNebulaBright;
uniform float uTestGradientSky;
uniform float uTestStarOn;
uniform vec3 uTestStarDir;

vec2 octaEncode(vec3 d) {
  d /= (abs(d.x) + abs(d.y) + abs(d.z));
  vec2 e = d.xy;
  if (d.z < 0.0) e = (1.0 - abs(d.yx)) * vec2(d.x >= 0.0 ? 1.0 : -1.0, d.y >= 0.0 ? 1.0 : -1.0);
  return e;
}
vec3 octaDecode(vec2 e) {
  vec3 d = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
  if (d.z < 0.0) d.xy = (1.0 - abs(d.yx)) * vec2(e.x >= 0.0 ? 1.0 : -1.0, e.y >= 0.0 ? 1.0 : -1.0);
  return normalize(d);
}
// Point spread function of a star: gaussian core + halo + 4 diffraction spikes.
float starPSF(float chord, float sigma) {
  // Compact PSF: every component decays well inside one grid cell so the 3x3
  // sampling window never clips it (clipped halos read as square tiles).
  float core = exp(-(chord * chord) / (sigma * sigma));
  float halo = 0.05 * exp(-chord / (3.2 * sigma));
  halo *= smoothstep(6.5 * sigma, 3.0 * sigma, chord);
  return core + halo;
}
float starSpikes(vec3 d, vec3 sd, float chord, float sigma) {
  if (chord > 6.0 * sigma) return 0.0;
  vec3 t1 = normalize(cross(sd, vec3(0.21, 0.17, 0.96)));
  vec3 t2 = cross(sd, t1);
  vec3 v = d - sd * dot(d, sd);
  float u1 = dot(v, t1), u2 = dot(v, t2);
  float s = exp(-pow(u1 / (2.2 * sigma), 2.0)) * max(0.0, 1.0 - abs(u2) / (4.4 * sigma))
          + exp(-pow(u2 / (2.2 * sigma), 2.0)) * max(0.0, 1.0 - abs(u1) / (4.4 * sigma));
  return 0.16 * s;
}
vec3 starLayer(vec3 d) {
  const float GRID = 170.0;
  vec2 o = octaEncode(d);
  vec2 g = o * GRID;
  vec2 base = floor(g);
  vec3 acc = vec3(0.0);
  float sigma = 0.0016;   // ~4 px core at default fov - pinpoints, not blobs
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 cell = base + vec2(float(i), float(j));
      float h0 = hash2(cell);
      if (h0 > 0.30) continue;
      vec2 sc = (cell + vec2(0.2 + 0.6 * hash2(cell + 7.3), 0.2 + 0.6 * hash2(cell + 3.1))) / GRID;
      vec3 sd = octaDecode(sc);              // sc is already in [-1,1] octa space
      float chord = length(d - sd);
      float h1 = hash2(cell + 11.7);
      float h2 = hash2(cell + 29.3);
      float h3 = hash2(cell + 47.9);
      float flux = 0.9 * pow(1.0 - h1, 6.0) + 0.03;     // magnitude ladder: few bright, many faint
      if (h2 > 0.988) flux *= 30.0;                       // rare bright stars
      float T = 2700.0 + 11000.0 * pow(h3, 2.5);
      float psf = starPSF(chord, sigma);
      acc += blackbodyRGB(T) * flux * (psf + starSpikes(d, sd, chord, sigma) * step(0.988, h2));
    }
  }
  return acc;
}
// Nebula bed: deep 3D FBM, two-tone by density, galactic band. Direction-based
// (infinitely far layer) - lensed by construction.
vec3 nebulaBackdrop(vec3 d) {
  vec3 dir = d * 2.6;
  float w = fbm3(dir * 0.55 + vec3(2.0, 5.0, 8.0), 3);
  float n = fbm3(dir + 1.8 * w, 4);
  float band = exp(-pow(dot(d, normalize(vec3(0.28, 0.42, 0.86))), 2.0) * 5.0);
  float dens = pow(max(n - 0.13 - 0.24 * band, 0.0), 1.45) * (1.0 + 1.5 * band);
  float hue = fbm3(dir * 0.7 + 31.0, 2);
  vec3 c1 = vec3(0.070, 0.082, 0.160);
  vec3 c2 = vec3(0.200, 0.115, 0.240);
  vec3 c3 = vec3(0.060, 0.155, 0.165);
  vec3 col = mix(mix(c1, c2, hue), c3, pow(max(n - 0.42, 0.0) * 2.0, 1.5));
  return col * dens * 2.6;
}
// Mid-field volumetric nebula, sampled ALONG the geodesic (positions are the
// actual curved ray positions, so the near-hole volume is lensed).
vec3 nebulaVolume(vec3 pos, float h) {
  float n = fbm3(pos * 0.115 + vec3(4.0, 9.0, 1.0), 3);
  float dens = pow(max(n - 0.32, 0.0), 1.7) * 1.9;
  float hue = fbm3(pos * 0.06 + 17.0, 2);
  vec3 col = mix(vec3(0.10, 0.13, 0.30), vec3(0.32, 0.16, 0.30), hue);
  return col * dens * 0.0018 * h;
}
vec3 skyRadiance(vec3 d) {
  if (uTestGradientSky > 0.5) {
    return mix(vec3(0.045, 0.052, 0.085), vec3(0.34, 0.36, 0.43), d.z * 0.5 + 0.5);
  }
  vec3 c = vec3(0.011, 0.013, 0.024);
  if (uTestStarOn > 0.5) {
    float chord = length(d - uTestStarDir);
    c += vec3(1.0, 0.98, 0.95) * 90.0 * starPSF(chord, 0.020);   // wide beacon: ring must be samplable
  }
  if (uFeatureToggles.w > 0.5) c += starLayer(d) * 1.35;
  if (uFeatureToggles.z > 0.5) c += nebulaBackdrop(d) * uNebulaBright;
  return c;
}
