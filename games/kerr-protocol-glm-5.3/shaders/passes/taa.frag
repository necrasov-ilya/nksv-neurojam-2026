#version 300 es
// Temporal accumulation with reprojection (direction for sky, world point for
// geometry), 3x3 neighborhood clamp, motion gating. History resets upstream.
precision highp float;
#include "shaders/lib/common.glsl"
#include "shaders/lib/camera.glsl"

uniform sampler2D uScene;
uniform sampler2D uData;
uniform sampler2D uData3;    // reference dir + deflection angle (radians)
uniform sampler2D uHistory;
uniform float uBlendMax;
uniform float uMotionPx;     // camera rotation this frame, in screen pixels

in vec2 vUV;
out vec4 oColor;

void main() {
  ivec2 px = ivec2(gl_FragCoord.xy);
  vec3 scene = texelFetch(uScene, px, 0).rgb;
  vec4 data = texelFetch(uData, px, 0);      // steps, pathLen, event, g
  if (uBlendMax <= 0.0) { oColor = vec4(scene, 1.0); return; }
  vec2 n = ndc(gl_FragCoord.xy + uJitter - 0.5);
  vec3 dir = screenDirEC(n, uCam.w);
  vec2 prevUV;
  bool valid;
  if (data.z < 0.5) {                        // sky: reproject the direction
    float z;
    prevUV = dirToPrevUV(dir, z);
    valid = z > 0.0;
  } else {                                   // geometry: reproject the world point
    vec3 pos = camPosEC(uCam) + dir * data.y;
    vec3 rel = pos - camPosEC(uPrevCam);
    vec3 fwd, right, up;
    camFrameEC(uPrevCam, fwd, right, up);
    float zf = dot(rel, fwd);
    float t = tanHalfFov(uPrevCam.w);
    prevUV = vec2(dot(rel, right) / (t * uAspect), dot(rel, up) / t) / max(zf, 1e-3) * 0.5 + 0.5;
    valid = zf > 0.0;
  }
  valid = valid && all(greaterThan(prevUV, vec2(0.001))) && all(lessThan(prevUV, vec2(0.999)));
  // 3x3 neighborhood bounds (variance-style clamp keeps detail, kills ghosting)
  vec3 mn = scene, mx = scene, m1 = scene, m2 = scene * scene;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec3 c = texelFetch(uScene, clamp(px + ivec2(i, j), ivec2(0), ivec2(uRes) - 1), 0).rgb;
      mn = min(mn, c); mx = max(mx, c);
      m1 += c; m2 += c * c;
    }
  }
  vec3 mu = m1 / 9.0;
  vec3 sigma = sqrt(max(m2 / 9.0 - mu * mu, vec3(0.0)));
  // Static camera: loosen the clamp. A hard 3x3 variance clamp erases
  // legitimate sub-pixel HDR detail (photon-ring samples, star cores) the
  // instant a jittered frame misses them; ghosting protection only matters
  // while the camera moves, where uBlendMax is low.
  float settled = smoothstep(0.7, 0.94, uBlendMax);
  float k = mix(1.6, 3.2, settled);
  vec3 slack = mix(vec3(0.002), vec3(0.02) + 0.5 * mu, settled);
  mn = max(mn, mu - k * sigma - slack);
  mx = min(mx, mu + k * sigma + slack);
  vec3 outc = scene;
  if (valid) {
    vec2 hUV = prevUV + (uPrevJitter - uJitter) / uRes;
    vec3 hist = texture(uHistory, hUV).rgb;
    if (all(lessThan(hist, vec3(1e9)))) {
      // The reprojection above assumes STRAIGHT rays. Near the hole the photon
      // bent by delta, so the image of a sky/disk feature moves with the local
      // magnification (~ 1 + delta), not with the camera matrix: the history
      // lands delta * (camera motion) pixels off. While the camera rotates,
      // scale each pixel's history weight down by that expected error - the
      // lensed background keeps accumulating (delta is micro out there), the
      // photon-ring neighbourhood falls back to its honest per-frame sample.
      float defl = texelFetch(uData3, px, 0).w;
      float errPx = defl * uMotionPx;
      float mfac = smoothstep(0.6, 3.0, uMotionPx);
      float rej = mfac * smoothstep(0.3, 1.2, errPx);
      // Full rejection leaves the photon-ring zone as a raw per-frame sample:
      // honest, but at reduced scale it stair-steps. Keep a CLAMPED sliver of
      // history (neighborhood bounds hold it near the local mean, so it acts
      // as a temporal denoise, not a ghost) and let convergence take over the
      // instant rotation stops.
      float w = uBlendMax * (1.0 - rej * 0.75);
      hist = clamp(hist, mn, mx);
      outc = mix(scene, hist, w);
    }
  }
  if (!finite3(outc)) outc = scene;
  oColor = vec4(outc, 1.0);
}
