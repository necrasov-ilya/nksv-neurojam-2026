#version 300 es
// Bloom upsample: 3x3 tent filter from the coarser level, added onto the current
// level's downsampled image (progressive mip summation).
precision highp float;
#include "shaders/lib/common.glsl"
uniform sampler2D uSrc;
uniform sampler2D uDst;
uniform vec2 uSrcRes;
in vec2 vUV;
out vec4 oColor;
void main() {
  vec2 tx = 1.0 / uSrcRes;
  vec3 s = texture(uSrc, vUV).rgb * 4.0;
  s += texture(uSrc, vUV + vec2(-tx.x, 0.0)).rgb * 2.0;
  s += texture(uSrc, vUV + vec2( tx.x, 0.0)).rgb * 2.0;
  s += texture(uSrc, vUV + vec2(0.0, -tx.y)).rgb * 2.0;
  s += texture(uSrc, vUV + vec2(0.0,  tx.y)).rgb * 2.0;
  s += texture(uSrc, vUV + vec2(-tx.x, -tx.y)).rgb;
  s += texture(uSrc, vUV + vec2( tx.x, -tx.y)).rgb;
  s += texture(uSrc, vUV + vec2(-tx.x,  tx.y)).rgb;
  s += texture(uSrc, vUV + vec2( tx.x,  tx.y)).rgb;
  s /= 16.0;
  vec3 d = texture(uDst, vUV).rgb;
  oColor = vec4(d + s, 1.0);
}
