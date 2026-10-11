// Deterministic hashing + value noise + FBM. No randomness at runtime.
// NOTE: float->uint of negatives is undefined in GLSL; route through int() first.
uint uhash1(uint x) {
  x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; x ^= x >> 16;
  return x;
}
float hash2(vec2 p) {
  ivec2 ip = ivec2(floor(p));
  uint h = uhash1(uint(ip.x) * 374761393u ^ uint(ip.y) * 668265263u);
  return float(h) * (1.0 / 4294967296.0);
}
float hash3(vec3 p) {
  ivec3 ip = ivec3(floor(p));
  uint h = uhash1(uint(ip.x) * 374761393u ^ uint(ip.y) * 668265263u ^ uint(ip.z) * 1274126177u);
  return float(h) * (1.0 / 4294967296.0);
}
float vnoise3(vec3 x) {
  vec3 i = floor(x), f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  float n000 = hash3(i), n100 = hash3(i + vec3(1, 0, 0));
  float n010 = hash3(i + vec3(0, 1, 0)), n110 = hash3(i + vec3(1, 1, 0));
  float n001 = hash3(i + vec3(0, 0, 1)), n101 = hash3(i + vec3(1, 0, 1));
  float n011 = hash3(i + vec3(0, 1, 1)), n111 = hash3(i + vec3(1, 1, 1));
  return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
             mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}
float fbm3(vec3 p, int oct) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 6; i++) {
    if (i >= oct) break;
    s += a * vnoise3(p);
    p = p * 2.03 + vec3(11.3, 7.7, 5.1);
    a *= 0.5;
  }
  return s;
}
float vnoise2(vec2 x) {
  vec2 i = floor(x), f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
             mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p, int oct) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 5; i++) {
    if (i >= oct) break;
    s += a * vnoise2(p);
    p = p * 2.11 + vec2(9.4, 3.7);
    a *= 0.5;
  }
  return s;
}
