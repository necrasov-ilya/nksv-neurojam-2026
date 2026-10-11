// Shared constants and helpers. Units: geometric, M = G = c = 1.
const float PI = 3.14159265358979;

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
bool finit(float x) { return x == x && abs(x) < 1e20; }
bool finite3(vec3 c) { return finit(c.x) && finit(c.y) && finit(c.z); }

// ACES filmic fit (Narkowicz 2015), linear in -> linear out.
vec3 acesFilm(vec3 x) {
  const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}
vec3 srgbEncode(vec3 c) {
  return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055,
             step(vec3(0.0031308), c));
}
