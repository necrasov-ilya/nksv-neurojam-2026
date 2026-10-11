#version 300 es
// Orbit plot: two mirrored rays (d_phi = +0.06 / -0.06) traced from the camera,
// drawn in the cartesian x-z plane. Should be exact mirror images at a=0.
precision highp float;
#include "shaders/lib/common.glsl"
#include "shaders/lib/kerr.glsl"
#include "shaders/lib/camera.glsl"
uniform float uTraceScale;
in vec2 vUV;
out vec4 oColor;
vec3 pathColor(vec4 x) {
  float xx = x.y * sin(x.z) * cos(x.w);
  float zz = x.y * cos(x.z);
  return vec3(xx, zz, 0.0);
}
void main() {
  float a = uSpin;
  vec2 p_screen = (vUV * 2.0 - 1.0) * 14.0;   // x in [-14,14] M, z same
  vec3 col = vec3(0.015, 0.02, 0.035);
  // horizon disk
  float rr = length(p_screen);
  col = mix(col, vec3(0.25, 0.05, 0.05), smoothstep(rPlus(a) + 0.15, rPlus(a) - 0.05, rr));
  // photon sphere ring
  col += vec3(0.25, 0.2, 0.05) * exp(-abs(rr - (1.0 + sqrt(2.0))) * 2.0) * 0.5;
  // trace two rays
  for (int ray = 0; ray < 2; ray++) {
    float sgn = ray == 0 ? 1.0 : -1.0;
    vec4 e0, e1, e2, e3;
    tetrad(e0, e1, e2, e3, uCam.x, uCam.y, a);
    vec3 dLocal = normalize(vec3(-1.0, 0.0, sgn * 0.24));
    vec4 p = -e0 + dLocal.x * e1 + dLocal.y * e2 + dLocal.z * e3;
    vec4 x = vec4(0.0, uCam.x, uCam.y, 0.0);
    vec3 c1 = ray == 0 ? vec3(0.15, 0.85, 1.0) : vec3(1.0, 0.55, 0.15);
    vec3 prev = vec3(x.y * sin(x.z), x.y * cos(x.z), 0.0);
    for (int i = 0; i < 400; i++) {
      float h = clamp(uTraceScale * x.y, 0.0025, 3.5);
      if (x.y < 5.0) h = min(h, 0.10);
      rk4Step(x, p, h, a);
      if (x.z < 0.0) { x.z = -x.z; x.w += PI; }
      else if (x.z > PI) { x.z = 2.0 * PI - x.z; x.w += PI; }
      vec3 cur = vec3(x.y * sin(x.z) * cos(x.w), x.y * cos(x.z), 0.0);
      // segment prev->cur distance to p_screen
      vec2 a2 = prev.xy, b2 = cur.xy, pp = p_screen;
      vec2 ab = b2 - a2;
      float t = clamp(dot(pp - a2, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
      float d = length(pp - (a2 + t * ab));
      col += c1 * exp(-d * d * 90.0) * 0.6;
      prev = cur;
      if (x.y < rPlus(a) + 0.02 || x.y > 200.0) break;
    }
  }
  oColor = vec4(col, 1.0);
}
