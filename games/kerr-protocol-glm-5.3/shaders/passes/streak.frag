#version 300 es
// Anamorphic diffraction glare: horizontal streak on the brightest features.
// Two passes: (0) threshold + long horizontal blur, (1) wider blur accumulated.
precision highp float;
#include "shaders/lib/common.glsl"
uniform sampler2D uSrc;
uniform float uPass;
in vec2 vUV;
out vec4 oColor;
void main() {
  if (uPass < 0.5) {
    // Gate each tap on its OWN luminance: only genuinely hot cores flare, and
    // the reach is short enough that the streak hugs its source instead of
    // painting a blue shelf across the shadow void.
    const int N = 16;
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = -N; i <= N; i++) {
      float fi = float(i) / float(N);
      float w = exp(-fi * fi * 3.0);
      vec3 c = texture(uSrc, vUV + vec2(fi * 0.045, 0.0)).rgb;
      c *= smoothstep(24.0, 48.0, max(max(c.r, c.g), c.b));
      acc += c * w;
      wsum += w;
    }
    oColor = vec4(acc / wsum * vec3(0.80, 0.88, 1.15), 1.0);
  } else {
    const int N = 24;
    vec3 acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = -N; i <= N; i++) {
      float fi = float(i) / float(N);
      float w = exp(-fi * fi * 2.0);
      acc += texture(uSrc, vUV + vec2(fi * 0.10, 0.0)).rgb * w;
      wsum += w;
    }
    oColor = vec4(acc / wsum, 1.0);
  }
}
