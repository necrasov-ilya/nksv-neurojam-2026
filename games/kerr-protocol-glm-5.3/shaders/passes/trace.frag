#version 300 es
// Debug oscilloscope: single center ray, plots r(lambda) across the screen.
precision highp float;
#include "shaders/lib/common.glsl"
#include "shaders/lib/kerr.glsl"
#include "shaders/lib/camera.glsl"
uniform int uTraceSteps;
uniform float uStepScale;
uniform vec2 uCanvasRes2;
uniform vec3 uTraceDir;
uniform int uTraceN;
uniform int uTraceDual;
uniform int uTraceProbe;   // 1: output first-eval dp (dp_r, dp_th) for A and B
in vec2 vUV;
out vec4 oColor;
void main() {
  float a = uSpin;
  vec4 e0, e1, e2, e3;
  tetrad(e0, e1, e2, e3, uCam.x, uCam.y, a);
  vec3 dLocal = normalize(uTraceDir);
  vec4 p = -e0 + dLocal.x * e1 + dLocal.y * e2 + dLocal.z * e3;
  vec4 x = vec4(0.0, uCam.x, uCam.y, uCam.z);
  vec4 pB = p; vec4 xB = x;
  pB.w = -pB.w;                     // mirrored ray: p_phi -> -p_phi
  bool dual = uTraceDual > 0;
  if (uTraceProbe > 0 && dual) {    // first RHS evaluation at the identical initial state
    vec4 dxA, dpA, dxB2, dpB2;
    rhsFlow(dxA, dpA, x, p, a);
    rhsFlow(dxB2, dpB2, xB, pB, a);
    oColor = vec4(dpA.y, dpB2.y, dpA.z, dpB2.z);
    return;
  }
  float k = vUV.x * float(uTraceN);
  int steps = int(k);
  float target = 0.0;
  for (int i = 0; i < 4096; i++) {
    if (i >= steps) break;
    float h = clamp(uStepScale * x.y, 0.0025, 3.5);
    if (!dual || x.y > 0.0) rk4Step(x, p, h, a);
    if (dual) rk4Step(xB, pB, h, a);
    if (x.z < 0.0) { x.z = -x.z; x.w += PI; }
    else if (x.z > PI) { x.z = 2.0 * PI - x.z; x.w += PI; }
    if (dual) {
      if (xB.z < 0.0) { xB.z = -xB.z; xB.w += PI; }
      else if (xB.z > PI) { xB.z = 2.0 * PI - xB.z; xB.w += PI; }
    }
    if (x.y < rPlus(a) + 0.05) { target = 1.0; break; }   // captured -> bottom
  }
  // data column at left edge: final r, captured flag, p_phi, steps — exact readback
  if (vUV.x > 1.0 - 3.0 / uCanvasRes2.x) {
    if (dual) oColor = vec4(x.y, xB.y, p.y, pB.y);
    else oColor = vec4(x.y / 200.0, (x.z - 1.5) / 2.0 + 0.5, clamp(p.y * 0.25 + 0.5, 0.0, 1.0), clamp(p.w * 0.5 + 0.5, 0.0, 1.0));
    return;
  }
  // plot r: 140 M full scale, log-ish compression for near hole
  float rPlot = clamp((x.y - 0.5) / 139.5, 0.0, 1.0);
  float y = target > 0.5 ? 0.02 : rPlot;
  vec3 col = vec3(0.02, 0.03, 0.05);
  float d = abs(vUV.y - y);
  col += vec3(0.2, 1.0, 0.4) * exp(-d * d * 4e4);
  // reference lines: horizon 1.4/140, photon sphere 3/140, camera 60/140
  for (float rr = 1.5; rr < 140.0; rr += 1.0) {
    float yr = clamp((rr - 0.5) / 139.5, 0.0, 1.0);
    col += vec3(0.12, 0.12, 0.2) * exp(-abs(vUV.y - yr) * 1500.0);
  }
  oColor = vec4(col, 1.0);
}
