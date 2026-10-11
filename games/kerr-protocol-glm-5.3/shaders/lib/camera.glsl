// Camera uniforms shared by every pass. Boyer-Lindquist orbit camera.
// uCam = (r, theta, phi, fovRad). Screen basis in the local orthonormal frame:
// forward = -e_r, up = -e_theta (toward +spin axis), right = +e_phi.
uniform vec4 uCam;
uniform vec4 uPrevCam;
uniform vec2 uRes;
uniform vec2 uJitter;      // sub-pixel jitter of this frame (pixels)
uniform vec2 uPrevJitter;
uniform float uAspect;
uniform float uTime;
uniform int uFrame;

vec2 ndc(vec2 fragCoord) { return (fragCoord / uRes) * 2.0 - 1.0; }
float tanHalfFov(float fov) { return tan(0.5 * fov); }
// Local-frame direction components (d_r, d_th, d_ph), unit norm.
vec3 screenDir(vec2 n, float fov) {
  float t = tanHalfFov(fov);
  return normalize(vec3(-1.0, -n.y * t, n.x * t * uAspect));
}
// Euclidean approximations (TAA reprojection / volumes).
vec3 camPosEC(vec4 cam) {
  float s = sin(cam.y), c = cos(cam.y);
  return vec3(cam.x * s * cos(cam.z), cam.x * s * sin(cam.z), cam.x * c);
}
void camFrameEC(vec4 cam, out vec3 fwd, out vec3 right, out vec3 up) {
  vec3 pos = camPosEC(cam);
  vec3 rh = normalize(pos);
  fwd = -rh;
  right = normalize(cross(vec3(0.0, 0.0, 1.0), rh) + vec3(1e-6, 0.0, 0.0));
  up = cross(right, fwd);
}
// Project a world direction into previous-frame screen UV. Returns uv and hit z.
vec2 dirToPrevUV(vec3 d, out float z) {
  vec3 fwd, right, up;
  camFrameEC(uPrevCam, fwd, right, up);
  z = dot(d, fwd);
  float t = tanHalfFov(uPrevCam.w);
  return vec2(dot(d, right) / max(z, 1e-4) / (t * uAspect), dot(d, up) / max(z, 1e-4) / t) * 0.5 + 0.5;
}
vec3 screenDirEC(vec2 n, float fov) {
  vec3 fwd, right, up;
  camFrameEC(uCam, fwd, right, up);
  float t = tanHalfFov(fov);
  return normalize(fwd + right * (n.x * t * uAspect) + up * (n.y * t));
}
