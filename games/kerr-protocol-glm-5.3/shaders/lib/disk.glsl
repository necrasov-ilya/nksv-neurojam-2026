// Optically thick, geometrically thin Keplerian disk in the equatorial plane.
// Color: Shakura-Sunyaev T(r) -> Planck -> CIE -> sRGB (fitted), Doppler shifted
// in energy space: T_obs = g * T_em with g = E_cam/E_em, and I ~ T_obs^4 (g^4).
uniform float uDiskInner;
uniform float uDiskOuter;
uniform float uDiskBright;
uniform float uDiskTmax;

// Turbulent surface density in the co-rotating frame; differential rotation
// shears the pattern into trailing spirals automatically (phi' = phi - Omega t).
float diskTurbulence(float r, float ph, float a, float t) {
  // Pattern advection is deliberately sub-Keplerian in CLOCK terms: the TAA
  // accumulates ~17 frames, so a full-omega pattern would smear its own fine
  // filaments into milk during settling. 0.35x keeps the shear legible over
  // seconds of viewing while the accumulated frame stays sharp.
  float om = omegaKep(r, a) * 0.35;
  // Differential rotation: inner annuli lap the outer ones, so any passive
  // pattern shears into a trailing log-spiral, phi -> phi - k*ln(r/r_in)
  // (this is the accumulated shear of many orbits - the same k the live
  // advection would build up over t ~ k/omega). Pitch k=2.2 reads as clear
  // trailing spiral arms at every instant, including still frames.
  float spiral = 2.2 * log(max(r / uDiskInner, 1.0));
  float phi1 = ph - om * t * 1.0 - spiral;
  float phi2 = ph - om * t * 0.83 - spiral * 1.18;  // second layer: different pitch
  // Periodic in phi: noise domain is a circle in the flow frame, so the
  // pattern has NO branch cut at phi = +/- pi (a raw-phi domain prints a
  // vertical comb through the far-side image).
  vec2 p1 = vec2(r * 2.6, 0.0) + (2.0 + r * 0.55) * vec2(cos(phi1), sin(phi1));
  vec2 p2 = vec2(r * 6.5, 0.0) + (4.0 + r * 1.3) * vec2(cos(phi2), sin(phi2));
  // Third layer at high azimuthal wavenumber: edge-on views see the disk as a
  // foreshortened sheet where only fine PHI-structure survives as texture -
  // this prints as azimuthal filaments sheared along the flow instead of milk.
  float phi3 = ph - om * t * 1.19 - spiral * 0.76;
  // Anisotropic fine layer: strongly compressed radially (r*9), long along the
  // flow -> prints as thin sheared filaments instead of isotropic blotches.
  vec2 p3 = vec2(r * 9.0, 0.0) + (7.0 + r * 2.2) * vec2(cos(phi3), sin(phi3));
  float q = fbm2(p1 * 0.55 + vec2(3.1, 7.7), 3);
  float n1 = fbm2(p1 + 2.4 * q + vec2(0.0, t * 0.0), 4);
  float n2 = fbm2(p2, 3);
  float n3 = fbm2(p3 + vec2(9.4, 1.2), 3);
  n3 = n3 * n3 * (3.0 - 2.0 * n3);            // contrast stretch -> fibrous streaks
  // Ridged component: thin bright threads (magnetic flux-tube look) riding the
  // same anisotropic domain - these give the disk its hair-thin strand structure.
  float ridge = 1.0 - abs(2.0 * fbm2(p3 * 1.7 + vec2(5.5, 4.8), 3) - 1.0);
  ridge *= ridge;
  // Grand-design m=2 trailing spiral density wave on the same sheared phase:
  // two arms whose contrast grows inward (where the shear is fastest). This is
  // the modal structure the turbulence decorates, not a painted texture.
  float arm = pow(0.5 + 0.5 * cos(2.0 * (ph - om * t * 0.9) - spiral * 2.0), 1.6);
  arm = mix(1.0, 0.86 + 0.28 * arm, smoothstep(uDiskInner * 1.05, uDiskInner * 2.4, r) * 0.9);  // A/B softer
  return clamp((0.10 + 1.30 * n1 + 0.30 * n2 + 0.85 * n3 + 0.95 * ridge) * arm, 0.0, 2.4);
}
// Five orbiting hot spots / flares. Same lensing, beaming and redshift as the rest.
float diskHotspots(float r, float ph, float a, float t) {
  float acc = 0.0;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float rr = mix(uDiskInner * 1.15, uDiskOuter * 0.62, 0.12 + 0.2 * fi);
    float om = omegaKep(rr, a);
    float p0 = 2.399 * fi + 0.9;
    float dph = atan(sin(ph - (p0 + om * t)), cos(ph - (p0 + om * t)));
    float pulse = 0.5 + 0.5 * sin(t * (0.5 + 0.13 * fi) + 3.0 * fi);
    float d = length(vec2(log(r / rr) * 3.5, dph * rr * 0.9));
    acc += (0.55 + 1.9 * pulse) * exp(-d * d * 2.2);
  }
  return acc;
}
// Disk temperature profile. Shakura-Sunyaev normalization fixes the PEAK
// (uDiskTmax at r_peak = 1.36 r_in, where SS f(x) reaches 0.0567). The SS
// shape itself, T ~ f^(1/4), is nearly FLAT in colour space - under 25%
// temperature variation between 6 and 15 M - so the disk would read one
// white regardless of radius. The radial COLOUR gradient therefore uses the
// irradiated-envelope steepening T ~ (r_peak / r)^1.6: white-blue ISCO,
// warm white mid-disk, amber, deep-orange outer lanes. Emission still
// scales as T_obs^4 with T_obs = g*T_em (Doppler g^4 beaming, D2/D3).
float diskTem(float r) {
  float rPeak = uDiskInner * 1.36;
  return uDiskTmax * pow(rPeak / max(r, 0.5 * uDiskInner), 1.6);
}
// Brightness temperature: the DISSIPATION profile (SS flux, T ~ f^(1/4)) is
// much flatter than the colour gradient above. Amplitude follows dissipation
// (so the outer lanes stay luminous), colour follows the steep gradient (so
// the disk reads white-blue -> amber -> deep orange). The Doppler factor g
// enters BOTH as a multiplicative shift; amplitude therefore scales as g^4
// exactly (D2/D3), while the spectrum hardens with g as it must.
float diskTemAmp(float r) {
  float x = uDiskInner / r;
  float f = x * x * x * max(0.0, 1.0 - sqrt(x));
  float tSS = uDiskTmax * pow(max(f / 0.056652, 0.0), 0.25);
  float rPeak = uDiskInner * 1.36;
  return max(tSS, uDiskTmax * 0.64 * pow(rPeak / max(r, 0.5 * uDiskInner), 0.42));
}
// Full disk surface brightness at a plane crossing. dirZ: |cos| of ray vs disk normal.
vec3 diskEmission(float r, float ph, vec4 p, float a, float dirZ, out float gOut) {
  float gtt, gtp, gpp, grr, gth;
  gcov(gtt, gtp, gpp, grr, gth, r, 1.5707963, a);
  float om = omegaKep(r, a);
  float ut = 1.0 / sqrt(-(gtt + 2.0 * om * gtp + om * om * gpp));
  // Backward-traced p is past-directed (p_t > 0): the physical photon is k = -p,
  // so E_em = -k.u = +p.u = u^t (p_t + Omega p_phi) > 0 for any real hit.
  float Eem = (p.x + om * p.w) * ut;
  float g = 1.0 / max(Eem, 0.05);                   // Doppler + gravitational shift
  gOut = g;
  float Tcol = g * diskTem(r);             // observed COLOUR temperature
  float Tamp = g * diskTemAmp(r);          // observed BRIGHTNESS temperature
  float dens = diskTurbulence(r, ph, a, uTime);
  float hot = diskHotspots(r, ph, a, uTime);
  float edgeIn = smoothstep(uDiskInner, uDiskInner * 1.06, r);
  float edgeOut = 1.0 - smoothstep(uDiskOuter * 0.58, uDiskOuter * 1.02, r);
  // Limb factor: modest foreshortening only. A geometrically THIN photosphere
  // radiates with nearly angle-independent specific intensity (limb darkening
  // is a thick stellar-atmosphere effect); a deep 0.55 floor penalises exactly
  // the tangential crossings that build the photon ring and the lensed arch.
  float limb = 0.74 + 0.26 * dirZ;
  float I = edgeIn * edgeOut * limb * (dens + hot) * pow(Tamp * (1.0 / 12000.0), 4.0);
  return blackbodyRGB(Tcol) * I * 1.6 * uDiskBright;
}
// Thin atmosphere hugging the plane (scale height hint, D4). Solved as an
// emission-absorption medium with MATCHED opacity: the source function is the
// local blackbody, so the line-of-sight integral saturates at bounded surface
// brightness instead of fogging without limit (an edge-on camera embedded in
// the atmosphere must see a glowing sheet, not an unbounded blue haze).
vec4 diskGlow(float r, float z, float ph, float a, float h) {
  float H = 0.055 + 0.028 * r;              // thin atmosphere, D4 scale height
  float Tem = diskTem(r);
  float dens = 0.35 + 0.65 * fbm2(vec2(r * 3.1, 0.0) + 2.0 * vec2(cos(ph), sin(ph)), 2);
  // The atmosphere exists only where the disk does. Inside the ISCO the flow
  // plunges and the thin atmosphere is gone - the shadow interior must be a
  // true void (rays that cross the plane outside the ISCO hit the opaque
  // surface instead, so this edge is exactly what captured rays sample).
  float edgeIn = smoothstep(uDiskInner * 1.05, uDiskInner * 1.50, r);
  float edgeOut = 1.0 - smoothstep(uDiskOuter * 0.6, uDiskOuter, r);
  float s = edgeIn * edgeOut * dens * 0.022 * uDiskBright * 9.0 / (1.0 + r * 0.30);
  // The corona is a CHROMOSPHERE: it lives ABOVE the opaque disk body
  // (half-thickness 0.12 M, enforced as an absorber in geodesic.frag), not at
  // the midplane. Rays that skim the plane itself at disk radii are inside the
  // disk body and terminate on its surface; the vacuum carve below means the
  // corona cannot paint captured rays that dive almost-parallel to the plane.
  float g = s * exp(-pow(abs(z) / H, 2.4)) * smoothstep(0.12, 0.34, abs(z));
  // Opacity 10x the emission coefficient: the line-of-sight integral saturates
  // at bb/10 (an optically thin corona), so grazing views see a bounded whisper
  // of atmosphere instead of a milky sheet burying the disk surface.
  return vec4(blackbodyRGB(Tem) * g * h, 10.0 * g);
}
