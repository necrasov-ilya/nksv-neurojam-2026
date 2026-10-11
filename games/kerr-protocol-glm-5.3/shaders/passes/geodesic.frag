#version 300 es
// ============================================================================
// Backward null-geodesic raymarcher in Kerr spacetime (Boyer-Lindquist,
// Hamiltonian RK4). Per pixel: integrate the photon's null geodesic from the
// camera, accumulate volumetric jet / nebula / disk-glow along the curved path,
// terminate on horizon capture, disk absorption, or sky escape.
// ============================================================================
precision highp float;
#include "shaders/lib/common.glsl"
#include "shaders/lib/noise.glsl"
#include "shaders/lib/kerr.glsl"
#include "shaders/lib/blackbody.glsl"
#include "shaders/lib/camera.glsl"
#include "shaders/lib/disk.glsl"
#include "shaders/lib/sky.glsl"
#include "shaders/lib/jet.glsl"

uniform sampler2D uBlueNoise;
uniform int uMaxSteps;
uniform float uStepScale;
uniform float uDebugDir;   // 1: output initial local ray direction

in vec2 vUV;
layout(location = 0) out vec4 oColor;
layout(location = 1) out vec4 oData;   // steps, path length, event, doppler g
layout(location = 2) out vec4 oData2;  // disk: r_hit, phi_hit, T_obs, g
layout(location = 3) out vec4 oData3;  // reference dir (escape/chord) + deflection angle

// Adaptive affine step: coarse far away, fine near the horizon/photon sphere,
// and fine near the equatorial plane where the disk must be caught.
float stepSize(float r, float cosTh, float rPlus_, float rout) {
  float h = uStepScale * r;
  h = min(h, 3.5);
  // Beyond the jet (|z| < 90) the field is weak and nothing is sampled:
  // grow the step superlinearly so wrap-around escapers do not burn the
  // step budget on empty space.
  if (r > 95.0) h *= 1.0 + (r - 95.0) * 0.15;
  if (r < 5.0) h = min(h, 0.085 + 0.05 * r);          // photon sphere refinement
  if (r < rout && abs(cosTh) < 0.05) h = min(h, 0.30); // plane-crossing accuracy
  return max(h, 0.0025);
}

// Local ray direction in quasi-cartesian frame (BL -> cartesian Jacobian on the
// flow velocity) - used both at sky escape and for rays that run out of step
// budget far from the horizon.
vec3 escapeDir(vec4 x, vec4 p, float a) {
  vec4 dx4, dp4;
  rhsFlow(dx4, dp4, x, p, a);
  float r0 = x.y, th0 = x.z, ph0 = x.w;
  float st = sin(th0), ct = cos(th0);
  float R0 = sqrt(r0 * r0 + a * a);
  vec3 v = vec3(dx4.y, dx4.z, dx4.w);
  return normalize(vec3(
    (r0 / R0) * st * cos(ph0) * v.x + R0 * ct * cos(ph0) * v.y - R0 * st * sin(ph0) * v.z,
    (r0 / R0) * st * sin(ph0) * v.x + R0 * ct * sin(ph0) * v.y + R0 * st * cos(ph0) * v.z,
    ct * v.x - r0 * st * v.y));
}

void main() {
  float a = uSpin;
  float rp = rPlus(a);
  float rin = uDiskInner;
  float rout = uDiskOuter;
  // ---- camera: local orthonormal tetrad, screen ray -> covariant momentum ----
  vec4 e0, e1, e2, e3;
  tetrad(e0, e1, e2, e3, uCam.x, uCam.y, a);
  vec2 n = ndc(gl_FragCoord.xy + uJitter - 0.5);
  vec3 dLocal = screenDir(n, uCam.w);
  if (uDebugDir > 1.5 && uDebugDir < 2.5) {
    oColor = vec4(uSpin, uDiskInner, uDiskOuter, uDiskTmax);
    oData = vec4(uDiskBright, uTime, uFeatureToggles.x, uCam.x);
    oData2 = vec4(0, 0, 0, 1);
    oData3 = vec4(0, 0, 1, 0);
    return;
  }
  if (uDebugDir > 0.5 && uDebugDir < 1.5) {
    oColor = vec4(dLocal * 0.5 + 0.5, 1.0);
    oData = vec4(0, 0, 9, 1);
    oData3 = vec4(0, 0, 1, 0);
    return;
  }
  vec4 p = -e0 + dLocal.x * e1 + dLocal.y * e2 + dLocal.z * e3; // p_t = -1 (E_cam = 1)
  vec4 x = vec4(0.0, uCam.x, uCam.y, uCam.z);
  // Straight (unlensed) direction of this pixel in eye coordinates. The
  // angle between it and where the photon ACTUALLY went is the deflection
  // delta - the TAA pass uses it to decide whether its camera-matrix
  // reprojection of history is trustworthy for this pixel (it assumes
  // straight rays; error grows like delta x camera motion).
  vec3 d0EC = screenDirEC(ndc(gl_FragCoord.xy + uJitter - 0.5), uCam.w);
  oData3 = vec4(d0EC, 0.0);

  vec3 radiance = vec3(0.0);
  float event = 2.0;      // default: captured / unresolved
  float gFac = 1.0;
  float hitR = 0.0, hitPhi = 0.0, hitT = 0.0;
  float pathLen = 0.0;
  int steps = 0;
  float prevCos = cos(x.z);
  float bn = texelFetch(uBlueNoise, ivec2(gl_FragCoord.xy) & 31, 0).r;
  float nebPhase = float(uFrame & 15) * 0.0617 + bn * 0.5;   // deterministic jitter
  // Emission-absorption integrator, marched FRONT-TO-BACK away from the camera:
  // each sample's emission is attenuated by the transmittance of everything
  // between it and the camera, and extinguishes what lies beyond. The horizon
  // is a perfect absorber, so captured rays carry only near-side emission -
  // the shadow stays a true void instead of a fog bank.
  float T = 1.0;
  float hCtrl = 1e9;      // adaptive angular-advance budget (see loop)
  float polarZ = 0.0;     // last step was inside the polar stiff zone

  for (int i = 0; i < 2048; i++) {
    if (i >= uMaxSteps) break;
    float r = x.y;
    float h = stepSize(r, cos(x.z), rp, rout);
    // Adaptive controller on the ANGULAR advance: near the spin axis the
    // azimuthal rate ~ 1/sin^2(theta) diverges, and a fixed step garbles phi
    // (zipper artifacts down the pole meridian). Bound |d theta|,|d phi| per
    // step using the previous step's advance - no extra RHS evaluations.
    // Applied ONLY inside the polar zone: elsewhere the smooth theta dynamics
    // are already resolved at the base step and shrinking h would exhaust the
    // step budget (renders as black unresolved regions).
    {
      // Predictive cap near the spin axis: dphi/dlambda ~ p_phi / sin^2(theta)
      // diverges, so bound the step by the angular rate BEFORE taking it (the
      // reactive hCtrl alone reacts one step too late and rays plunge wrongly).
      float cz = cos(x.z);
      polarZ = 0.0;
      if (1.0 - cz * cz < 0.36) {
        polarZ = 1.0;
        float gtt, gtp, gpp, grr, gth;
        ginv(gtt, gtp, gpp, grr, gth, x.y, x.z, a);
        float phidot = abs(gtp * p.x + gpp * p.w);
        float thdot = abs(gth * p.z);
        h = min(h, 0.10 / max(phidot, 1e-4));
        h = min(h, hCtrl);
        // never let one step consume the whole remaining polar angle: the pole
        // must be approached, not jumped - RK4 midpoints inside a polar
        // crossing see unbounded dphi/dtheta and destroy p_theta.
        float thRem = cz > 0.0 ? x.z : (PI - x.z);
        if (thdot > 1e-6) h = min(h, 0.15 * thRem / thdot);
      }
    }
    vec4 xPrev = x, pPrev = p;
    float zPre = x.z, phPre = x.w;
    rk4Step(x, p, h, a);
    steps++;
    {
      float dth = abs(x.z - zPre), dph = abs(x.w - phPre);
      float err = max(dth, dph);
      hCtrl = h * clamp(0.45 / max(err, 1e-4), 0.18, 1.35);
    }
    // pole wrap: theta out of (0, pi) mirrors phi by pi
    if (x.z < 0.0)      { x.z = -x.z; x.w += PI; }
    else if (x.z > PI)  { x.z = 2.0 * PI - x.z; x.w += PI; }
    r = x.y;
    if (!(r * r > 0.0)) { event = 2.0; break; }             // NaN guard
    if (r < rp + 0.04)  { event = 2.0; pathLen += h; break; } // horizon capture
    float c = cos(x.z);
    // ---- disk plane crossing (bisection refinement) ----
    if (uFeatureToggles.x > 0.5 && prevCos * c < 0.0 && r > rin - 0.35 && r < rout + 2.5) {
      vec4 xa = xPrev, pa = pPrev;      // state just before crossing
      vec4 xb = x, pb = p;              // state just after
      float ha = h;
      for (int k = 0; k < 6; k++) {
        vec4 xm = xa, pm = pa;
        rk4Step(xm, pm, ha * 0.5, a);
        if (cos(xm.z) * cos(xa.z) < 0.0) { xb = xm; pb = pm; ha *= 0.5; }
        else { xa = xm; pa = pm; ha -= ha * 0.5; }
      }
      float rc = 0.5 * (xa.y + xb.y);
      float phc = 0.5 * (xa.w + xb.w);
      // ray tilt vs disk normal from the flow velocity (limb factor)
      vec4 dx4, dp4;
      rhsFlow(dx4, dp4, xa, pa, a);
      float stc = sin(xa.z), ctc = cos(xa.z);
      float vz = ctc * dx4.y - xa.y * stc * dx4.z;
      float speed = length(vec3(dx4.y, xa.y * dx4.z, xa.y * stc * dx4.w));
      float dirZ = abs(vz) / max(speed, 1e-6);
      float gg;
      vec3 de = diskEmission(rc, phc, pa, a, dirZ, gg);
      float TobsHit = gg * diskTem(rc);
      if (rc > rin && rc < rout && dot(de, de) > 1e-8) {
        gFac = gg;
        hitR = rc; hitPhi = phc; hitT = TobsHit;
        radiance += de * T;
        event = 1.0;
        vec3 hitPos = blToCart(rc, xa.z, phc, a);
        pathLen = distance(hitPos, camPosEC(uCam));
        // reference direction = straight chord camera->hit; deflection = angle
        // vs the unlensed pixel direction (large for the lensed arch images)
        vec3 chord = (hitPos - camPosEC(uCam)) / max(pathLen, 1e-4);
        oData3 = vec4(chord, acos(clamp(dot(d0EC, chord), -1.0, 1.0)));
        break;
      }
    }
    prevCos = c;
    // ---- volumetrics along the geodesic (emission + extinction) ----
    if (T > 0.02) {
      vec3 posC = blToCart(r, x.z, x.w, a);
      float kappa = 0.0;
      if (uFeatureToggles.y > 0.5 && r < 90.0 && r > rin * 0.5) {
        vec4 dx4, dp4;
        rhsFlow(dx4, dp4, x, p, a);
        // Proper BL -> cartesian Jacobian on the flow velocity. A crude
        // (rdot, thdot, phdot)-as-cartesian mapping puts the AZIMUTHAL rate in
        // the z slot, so the jet's z-beaming flips sign across the projected
        // axis and the beam splits into bright/dim halves.
        float st0 = sin(x.z), ct0 = cos(x.z), R0 = sqrt(r * r + a * a);
        vec3 v0 = vec3(dx4.y, dx4.z, dx4.w);
        vec3 rd = normalize(vec3(
          (r / R0) * st0 * cos(x.w) * v0.x + R0 * ct0 * cos(x.w) * v0.y - R0 * st0 * sin(x.w) * v0.z,
          (r / R0) * st0 * sin(x.w) * v0.x + R0 * ct0 * sin(x.w) * v0.y + R0 * st0 * cos(x.w) * v0.z,
          ct0 * v0.x - r * st0 * v0.y));
        // The jet column (width ~1-3 M) is NARROWER than the adaptive step far
        // from the hole: a single sample per segment strides straight over it
        // and the emission integral becomes step-size dependent (prints as a
        // hard seam where neighbouring rays take different step sizes). Split
        // the segment into sub-steps whenever it grazes the column.
        vec3 posPrev = blToCart(xPrev.y, xPrev.z, xPrev.w, a);
        vec3 seg = posC - posPrev;
        vec3 mid = 0.5 * (posC + posPrev);
        if (length(mid.xy) < 10.0) {   // chord can graze the column: sub-step
          for (int k = 1; k <= 4; k++) {
            vec3 sp = posPrev + seg * (float(k) - 0.5) * 0.25;
            float zk = abs(sp.z);
            if (length(sp.xy) < 1.6 * jetWidth(zk) + 1.0) {
              radiance += jetEmission(sp, h * 0.25, rd, a) * T;
              kappa += jetDensity(sp, a) * 0.020 * 0.25;
            }
          }
        } else {
          radiance += jetEmission(posC, h, rd, a) * T;
          kappa += jetDensity(posC, a) * 0.020;
        }
      }
      if (uFeatureToggles.z > 0.5 && r > 6.0 && (steps & 1) == 0) {
        radiance += nebulaVolume(posC + vec3(nebPhase), h * 2.0) * T;
        kappa += 0.0;   // backdrop-grade: optically thin by design
      }
      if (uFeatureToggles.x > 0.5 && r > rin * 0.9 && r < rout + 2.0) {
        float zc = r * c;
        if (abs(zc) < 1.1) {
          vec4 dg = diskGlow(r, zc, x.w, a, h);
          radiance += dg.rgb * T;
          kappa += dg.a;
        }
      }
      T *= exp(-kappa * h);
    }
    pathLen += h;
    if (r > 140.0) {                                      // escaped to the sky
      vec3 dir = escapeDir(x, p, a);
      oData3 = vec4(dir, acos(clamp(dot(d0EC, dir), -1.0, 1.0)));
      if (uDebugDir > 2.5 && uDebugDir < 3.5) { oColor = vec4(dir, 1.0); oData = vec4(0, 0, 9, 1); return; }
      if (uDebugDir > 3.5) {
        float chiDeg = degrees(acos(clamp(dot(dir, uTestStarDir), -1.0, 1.0)));
        oColor = vec4(chiDeg / 180.0, 0.0, 0.0, 1.0);
        oData = vec4(0, 0, 9, 1);
        return;
      }
      radiance += skyRadiance(dir) * T;
      event = 0.0;
      pathLen = 1e5;
      break;
    }
  }
  // Step budget exhausted far from the horizon (near-pole rays take tiny
  // adaptive steps): this is NOT a capture. Finish the ray against the sky with
  // its current direction so unresolved pixels read as sky, not black beads.

  if (!finite3(radiance)) { radiance = vec3(0.0); event = 2.0; }
  oColor = vec4(max(radiance, vec3(0.0)), 1.0);
  oData = vec4(float(steps), pathLen, event, gFac);
  oData2 = vec4(hitR, hitPhi, hitT, gFac);
}
