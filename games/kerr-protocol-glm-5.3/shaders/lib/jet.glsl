uniform float uJetBright;
// Relativistic jet along the spin axis: volumetric, sampled along the geodesic
// with matched emission + extinction (see geodesic.frag integrator). Helical
// structure, internal-shock knots, synchrotron tint, mildly-relativistic
// Doppler beaming (I ~ g^{2.2}, synchrotron power-law alpha ~ 0.6 -> 3+alpha
// scaled down for the frequency-integrated band).
// Geometry: a collimated core (half-width ~ 0.8 M at the base, opening to
// ~2.5 M by z = 60 M) - narrow enough that it reads as a SEARCHLIGHT column,
// not a fog bank. Extinction is matched to the emissivity so the line-of-sight
// integral saturates at a bounded surface brightness (optically-thick core).
float jetWidth(float z) { return 0.50 + 0.55 * pow(0.8 + abs(z), 0.45); }
float jetDensity(vec3 pos, float a) {
  float z = abs(pos.z);
  if (z > 90.0) return 0.0;
  float rho = length(pos.xy);
  float w = 0.50 + 0.55 * pow(0.8 + z, 0.45);
  float profile = exp(-pow(rho / w, 3.0));
  return profile * (1.0 / (1.0 + pow(z / 26.0, 1.15)));
}
vec3 jetEmission(vec3 pos, float h, vec3 rayDir, float a) {
  float z = abs(pos.z);
  float rho = length(pos.xy);
  float w = 0.50 + 0.55 * pow(0.8 + z, 0.45);
  float profile = exp(-pow(rho / w, 3.0));
  if (profile < 0.004 || z > 90.0) return vec3(0.0);
  // Longitudinal emissivity: real jets stay bright for thousands of r_s; a
  // steep (z/16)^1.8 collapse left only a diffuse glow past z~32. Flat out to
  // the gate at r<90 (softened by a taper so the integration cutoff does not
  // print a hard edge), with the knots carrying the longitudinal contrast.
  float fall = 0.95 / (1.0 + pow(z / 26.0, 1.15));
  fall *= smoothstep(1.5, 5.0, z) * mix(0.22, 1.0, smoothstep(2.5, 7.0, z));   // dark launch collar
  fall *= smoothstep(88.0, 55.0, z);
  float ph = atan(pos.y, pos.x);
    // azimuth is degenerate on the axis: fade the helix out near rho=0 or the
  // per-step atan noise reads as a beaded column through the shadow
  float helix = mix(1.0, 0.70 + 0.30 * sin(2.0 * ph - 1.15 * z + uTime * 1.35),
                    smoothstep(0.18, 0.65, rho / w));
  // Longitudinal plasma structure: quasi-stationary density clumps along the
  // spine (periodic in phi so no branch cut through the column).
  float clump = 0.72 + 0.55 * fbm2(vec2(z * 0.5, 0.0) + 0.35 * vec2(cos(ph), sin(ph)), 2);
  float knot = 1.0;
  // Quasi-stationary internal-shock ladder (Herbig-Haro style): three knots
  // at fixed altitudes with slow secular drift, so a still frame always shows
  // the beaded structure instead of hoping the sweep is in view.
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float kz = 4.0 + 4.0 * fk + 1.6 * sin(uTime * 0.21 + fk * 2.1);
    float dz = (z - kz) / 1.3;
    knot += 5.5 * exp(-dz * dz) * (0.8 + 0.2 * sin(uTime * 0.5 + fk));
  }
  // beaming: emitter velocity beta * z-hat; photon flies toward the camera
  // along -rayDir, so cos(emission, v) = -dot(zHat, rayDir).
  float beta = 0.72;
  float gam = 1.0 / sqrt(1.0 - beta * beta);
  float dop = 1.0 / (gam * (1.0 - beta * (-rayDir.z)));
  float dens = profile * fall * helix * knot * clump;
  vec3 col = mix(vec3(0.50, 0.66, 1.25), vec3(0.72, 0.82, 1.30), clamp(profile, 0.0, 1.0));
  return col * dens * pow(dop, 2.2) * 0.010 * uJetBright * h * (uFeatureToggles.y);
}
