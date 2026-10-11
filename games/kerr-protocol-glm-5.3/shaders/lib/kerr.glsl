// Kerr metric, Boyer-Lindquist coordinates (t, r, theta, phi), M=1, signature (-,+,+,+).
// Inverse metric + ANALYTIC partial derivatives (verified against sympy + finite
// differences to 1.6e-5). Hamiltonian flow H = 1/2 g^{ab} p_a p_b, RK4.
uniform float uSpin;

struct Geom { float S, D, A, c, s; };

Geom geom(float r, float th, float a) {
  float c = cos(th), s = sin(th);
  float S = r * r + a * a * c * c;
  float D = r * r - 2.0 * r + a * a;
  float A = (r * r + a * a) * (r * r + a * a) - a * a * D * s * s;
  return Geom(S, D, A, c, s);
}
// Inverse metric components.
void ginv(out float gtt, out float gtp, out float gpp, out float grr, out float gth, float r, float th, float a) {
  Geom g = geom(r, th, a);
  float den = g.S * g.D;
  gtt  = -g.A / den;
  gtp  = -2.0 * a * r / den;
  gpp  = (r * r - 2.0 * r + a * a * g.c * g.c) / (g.s * g.s * den);
  grr  = g.D / g.S;
  gth  = 1.0 / g.S;
}
// d/dr and d/dtheta of the inverse metric components.
void dginv(out float dtt_r, out float dtp_r, out float dpp_r, out float drr_r, out float doo_r,
           out float dtt_t, out float dtp_t, out float dpp_t, out float drr_t, out float doo_t,
           float r, float th, float a) {
  float c = cos(th), s = sin(th), c2 = c * c, s2 = s * s;
  float S = r * r + a * a * c2;
  float dS_r = 2.0 * r, dS_t = -2.0 * a * a * s * c;
  float D = r * r - 2.0 * r + a * a;
  float dD_r = 2.0 * r - 2.0;
  float A = (r * r + a * a) * (r * r + a * a) - a * a * D * s2;
  float dA_r = 4.0 * r * (r * r + a * a) - a * a * s2 * dD_r;
  float dA_t = -2.0 * a * a * D * s * c;
  float den = S * D;
  float dden_r = dS_r * D + S * dD_r;
  float dden_t = dS_t * D;
  float inv2 = 1.0 / (den * den);
  dtt_r = -(dA_r * den - A * dden_r) * inv2;
  dtt_t = -(dA_t * den - A * dden_t) * inv2;
  dtp_r = -(2.0 * a * den - 2.0 * a * r * dden_r) * inv2;
  dtp_t = (2.0 * a * r * dden_t) * inv2;
  float N = r * r - 2.0 * r + a * a * c2;
  float dN_r = dD_r, dN_t = -2.0 * a * a * s * c;
  dpp_r = dN_r / (s2 * den) - N * dden_r / (s2 * den * den);
  dpp_t = dN_t / (s2 * den) - N * dden_t / (s2 * den * den) - 2.0 * N * c / (s2 * s * den);
  drr_r = (dD_r * S - D * dS_r) / (S * S);
  drr_t = -D * dS_t / (S * S);
  doo_r = -dS_r / (S * S);
  doo_t = -dS_t / (S * S);
}
// Hamiltonian RHS. x = (t, r, th, ph), p = (p_t, p_r, p_th, p_ph), both covariant p.
void rhsFlow(inout vec4 dx, inout vec4 dp, vec4 x, vec4 p, float a) {
  float r = x.y, th = x.z;
  float gtt, gtp, gpp, grr, gth;
  ginv(gtt, gtp, gpp, grr, gth, r, th, a);
  float pt = p.x, pr = p.y, pth = p.z, pp = p.w;
  dx = vec4(gtt * pt + gtp * pp, grr * pr, gth * pth, gtp * pt + gpp * pp);
  float dtt_r, dtp_r, dpp_r, drr_r, doo_r, dtt_t, dtp_t, dpp_t, drr_t, doo_t;
  dginv(dtt_r, dtp_r, dpp_r, drr_r, doo_r, dtt_t, dtp_t, dpp_t, drr_t, doo_t, r, th, a);
  dp = vec4(0.0,
    -0.5 * (dtt_r * pt * pt + 2.0 * dtp_r * pt * pp + dpp_r * pp * pp + drr_r * pr * pr + doo_r * pth * pth),
    -0.5 * (dtt_t * pt * pt + 2.0 * dtp_t * pt * pp + dpp_t * pp * pp + drr_t * pr * pr + doo_t * pth * pth),
    0.0);
}
// One RK4 step of the geodesic flow.
void rk4Step(inout vec4 x, inout vec4 p, float h, float a) {
  vec4 k1x, k1p, k2x, k2p, k3x, k3p, k4x, k4p;
  rhsFlow(k1x, k1p, x, p, a);
  rhsFlow(k2x, k2p, x + 0.5 * h * k1x, p + 0.5 * h * k1p, a);
  rhsFlow(k3x, k3p, x + 0.5 * h * k2x, p + 0.5 * h * k2p, a);
  rhsFlow(k4x, k4p, x + h * k3x, p + h * k3p, a);
  x += (h / 6.0) * (k1x + 2.0 * k2x + 2.0 * k3x + k4x);
  p += (h / 6.0) * (k1p + 2.0 * k2p + 2.0 * k3p + k4p);
}
// Covariant metric components.
void gcov(out float gtt, out float gtp, out float gpp, out float grr, out float gth, float r, float th, float a) {
  Geom g = geom(r, th, a);
  gtt = -(1.0 - 2.0 * r / g.S);
  gtp = -2.0 * a * r * g.s * g.s / g.S;
  gpp = g.A * g.s * g.s / g.S;
  grr = g.S / g.D;
  gth = g.S;
}
// Static-observer orthonormal tetrad at (r, th): contravariant BL components,
// Gram-Schmidt of the coordinate basis. Returns covariant tetrad vectors e_(a)_mu
// (e0 = observer timelike, e1 = radial, e2 = polar, e3 = azimuthal).
void tetrad(out vec4 e0, out vec4 e1, out vec4 e2, out vec4 e3, float r, float th, float a) {
  float gtt, gtp, gpp, grr, gth;
  gcov(gtt, gtp, gpp, grr, gth, r, th, a);
  e0 = vec4(1.0 / sqrt(-gtt), 0.0, 0.0, 0.0);
  e1 = vec4(0.0, sqrt(1.0 / grr), 0.0, 0.0);
  e2 = vec4(0.0, 0.0, sqrt(1.0 / gth), 0.0);
  // v = d/dphi, orthogonalize against e0 (g(e0,e0) = -1): v' = v + g(v,e0) e0.
  vec4 v = vec4(0.0, 0.0, 0.0, 1.0);
  float gve0 = gtp * v.w * e0.x;             // g(v, e0) = g_tp v^phi e0^t
  vec4 vortho = v + gve0 * e0;
  // metric norm of vortho:
  float vt = vortho.x, vr = vortho.y, vth = vortho.z, vp = vortho.w;
  float n2 = gtt * vt * vt + 2.0 * gtp * vt * vp + gpp * vp * vp + grr * vr * vr + gth * vth * vth;
  e3 = vortho / sqrt(n2);
  // covariant tetrad: e_(a)_mu = g_{mu nu} e_(a)^nu
  vec4 c0 = vec4(gtt * e0.x + gtp * e0.w, 0.0, 0.0, gtp * e0.x + gpp * e0.w);
  vec4 c1 = vec4(0.0, grr * e1.y, 0.0, 0.0);
  vec4 c2 = vec4(0.0, 0.0, gth * e2.z, 0.0);
  vec4 c3 = vec4(gtt * e3.x + gtp * e3.w, 0.0, 0.0, gtp * e3.x + gpp * e3.w);
  e0 = c0; e1 = c1; e2 = c2; e3 = c3;
}
// Horizons and derived radii.
float rPlus(float a) { return 1.0 + sqrt(max(0.0, 1.0 - a * a)); }
float rIsco(float a) {
  float z1 = 1.0 + pow(max(0.0, 1.0 - a * a), 1.0 / 3.0) * (pow(1.0 + a, 1.0 / 3.0) + pow(1.0 - a, 1.0 / 3.0));
  float z2 = sqrt(3.0 * a * a + z1 * z1);
  return 3.0 + z2 - sqrt((3.0 - z1) * (3.0 + z1 + 2.0 * z2)); // prograde
}
// Keplerian angular velocity (prograde), coordinate time.
float omegaKep(float r, float a) { return 1.0 / (r * sqrt(r) + a); }
// Boyer-Lindquist -> quasi-cartesian position (for noise/volumes).
vec3 blToCart(float r, float th, float ph, float a) {
  float R = sqrt(r * r + a * a);
  float s = sin(th), c = cos(th);
  return vec3(R * s * cos(ph), R * s * sin(ph), r * c);
}
