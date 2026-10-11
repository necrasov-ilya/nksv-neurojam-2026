#version 300 es
// Bloom downsample (Kawase dual-filter style). First level applies a soft-knee
// brightness threshold. Energy preserved by normalized weights.
precision highp float;
#include "shaders/lib/common.glsl"
uniform sampler2D uSrc;
uniform vec2 uSrcRes;
uniform float uPrefilter;
uniform float uThreshold;
in vec2 vUV;
out vec4 oColor;
void main() {
  vec2 tx = 1.0 / uSrcRes;
  vec3 c = texture(uSrc, vUV).rgb * 4.0;
  c += texture(uSrc, vUV + vec2(-1.0, -1.0) * tx).rgb;
  c += texture(uSrc, vUV + vec2( 1.0, -1.0) * tx).rgb;
  c += texture(uSrc, vUV + vec2(-1.0,  1.0) * tx).rgb;
  c += texture(uSrc, vUV + vec2( 1.0,  1.0) * tx).rgb;
  c /= 8.0;
  if (uPrefilter > 0.5) {
    const float knee = 0.55;
    float l = max(max(c.r, c.g), c.b);
    float soft = clamp(l - uThreshold + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee);
    float w = max(soft, l - uThreshold) / max(l, 1e-5);
    c *= max(w, 0.0);
  }
  oColor = vec4(c, 1.0);
}
