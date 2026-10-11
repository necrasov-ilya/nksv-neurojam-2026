#version 300 es
// Final composite: exposure -> ACES -> grade (chromatic aberration, vignette,
// grain, dither) -> sRGB 8-bit. Presented at full canvas resolution.
precision highp float;
#include "shaders/lib/common.glsl"
#include "shaders/lib/noise.glsl"
uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform sampler2D uStreak;
uniform sampler2D uBlueNoise;
uniform vec2 uCanvasRes;
uniform float uExposure;
uniform float uGrain;
uniform vec4 uCompToggles;   // bloom, streak, CA, vignette
in vec2 vUV;
out vec4 oColor;

vec3 sampleScene(vec2 uv) {
  vec3 c = texture(uScene, uv).rgb;
  if (uCompToggles.x > 0.5) c += texture(uBloom, uv).rgb * 0.030;
  if (uCompToggles.y > 0.5) {
    // Anamorphic flare attaches to lit pixels: where the scene itself is
    // black (the shadow void) the lens streak is extinguished too, so the
    // void stays a true void instead of wearing a blue shelf.
    vec3 s = texture(uStreak, uv).rgb * 0.045;
    c += s * smoothstep(0.0, 0.06, max(max(c.r, c.g), c.b));
  }
  return c;
}
void main() {
  vec2 uv = vUV;
  vec2 d = uv - 0.5;
  float r2 = dot(d, d);
  vec3 col;
  if (uCompToggles.z > 0.5) {
    vec2 off = d * r2 * 0.0045;
    col = vec3(sampleScene(uv + off).r, sampleScene(uv).g, sampleScene(uv - off).b);
  } else {
    col = sampleScene(uv);
  }
  col *= uExposure;
  // ACES in the shadows/mids; extended-Reinhard shoulder blended in for the
  // hot limb (ACES alone flattens everything above ~8 HDR to the same white
  // and the Doppler limb loses all of its turbulent texture).
  {
    vec3 a = acesFilm(col);
    vec3 shoulder = col * (1.0 + col / 2304.0) / (1.0 + col);
    float w = smoothstep(0.8, 4.0, luma(col)) * 0.85;
    col = mix(a, shoulder * 0.97, w);
  }
  // gentle saturation lift (ACES desaturates; restore a little)
  float l = luma(col);
  col = clamp(mix(vec3(l), col, 1.08), 0.0, 1.0);
  if (uCompToggles.w > 0.5) col *= 1.0 - 0.34 * pow(r2 * 2.4, 1.4);
  // film grain: deterministic blue-noise driven, stronger in shadows - but it
  // FADES TO ZERO in the deep void: the shadow must stay the only true black
  // on screen, not a field of dancing speckles.
  float bn = texelFetch(uBlueNoise, ivec2(gl_FragCoord.xy) & 31, 0).r;
  float bn2 = texelFetch(uBlueNoise, (ivec2(gl_FragCoord.xy) + ivec2(17)) & 31, 0).r;
  float g = (bn + bn2 - 1.0);
  col += g * uGrain * (1.0 - 0.6 * l) * smoothstep(0.0, 0.012, l) * 0.045;
  col = srgbEncode(clamp(col, 0.0, 1.0));
  // triangular dither before the 8-bit write (also void-gated)
  col += (bn + bn2 - 1.0) / 255.0 * smoothstep(0.0, 0.004, l);
  oColor = vec4(col, 1.0);
}
