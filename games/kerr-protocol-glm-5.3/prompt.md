# KERR PROTOCOL — a relativistic black hole, hand-written in GLSL (benchmark prompt v1)

You are an autonomous senior graphics programmer and demoscene-grade shader
author who also knows general relativity well enough to integrate null
geodesics correctly. No engine, no framework, no library is going to help you
here: every photon on screen is bent by math you wrote. Work until the image
is finished and beautiful, not described.

Build a real-time, interactive, cinematic rendering of a spinning
(Kerr) black hole with an accretion disk, a relativistic jet and a lensed
sky — running in a browser tab, in raw WebGL2, with zero runtime
dependencies.

Two things are the product, everything else serves them:

1. **THE PICTURE.** This will be judged from a 30-second screen capture.
   Every frame of that capture must look like a frame from a film with a
   nine-figure budget — deep blacks, molten highlights, real film response,
   no banding, no mush. The bar is a viewer asking "wait, this is running in
   a browser tab, in one shader?" A technically correct render that looks
   like a physics homework plot is a FAILED build.
2. **THE PHYSICS.** The light must actually be bent: null geodesics
   integrated in curved spacetime, per pixel, per frame. A screen-space
   "warp the background UVs around a circle" fake is an instant fail — the
   self-test (section 9) is built to catch exactly that. A beautiful lie is
   a failed build.

Both, or nothing. If you find yourself trading one away, you have taken a
wrong turn — go back and find the version where both hold.

## 0. HARD CONSTRAINTS

- C1. **Zero runtime dependencies.** No three.js, no glMatrix, no bundler,
  no npm package in the shipped product, no CDN script. `index.html` + your
  own ES modules + your own `.glsl` files, served by any static file server
  (`python3 -m http.server <port>` must be enough to see the whole thing).
  Test/dev tooling (Playwright for screenshots, a screenshot script) may be
  installed as devDependencies — it is not part of the product and must
  never be required to view it.
- C2. **Raw WebGL2, by hand**: context creation and loss handling, a single
  fullscreen triangle (not a quad), framebuffers, float render targets,
  program compilation with readable error reporting, uniform location
  caching, resize. All of it yours. Requires WebGL2 +
  `EXT_color_buffer_float`; if unavailable, fail loudly with a readable
  on-screen message — never render garbage.
- C3. **A real codebase, not a monolith**: ES modules, one module per system
  (gl context, program cache, render graph / passes, camera, input,
  parameters, hud, selftest, math). Shaders live in separate `.glsl` files
  loaded by `fetch` and assembled by your own `#include` resolver with
  correct line numbers in compile errors. Shader source pasted into JS
  template literals, or one 2000-line file, is a defect.
- C4. Deterministic: a single seeded PRNG and deterministic noise — no
  `Math.random()` anywhere in the render path. Same time + same camera +
  same parameters = same pixels (T6).
- C5. Zero console errors or warnings from your own code, zero shader
  compile/link warnings, no TODOs, no dead keys, no `alert()`.
- C6. 60 FPS at 1080p on a mainstream desktop GPU in the default shot, held
  by adaptive internal render scale (C7) — never by making the picture look
  cheap.
- C7. The heavy geodesic pass renders to an internal target whose scale
  adapts to measured frame time; presentation is always at full canvas
  resolution. When the camera is still, temporal accumulation (R2) must
  visibly converge to a cleaner, sharper, denoised frame. This is where the
  "expensive" look comes from — treat it as a feature, not an optimization.
- C8. Every animation eased or spring-damped. A visible linear lerp is a
  defect; a snap cut in a camera move is a defect.

## 1. THE SHOT

A supermassive Kerr black hole, seen from close enough that the disk fills
the frame. The camera sits well outside, near the equatorial plane but
tilted a little above it (~78-84 degrees inclination) — the angle where the
lensing is at its most spectacular: the far side of the disk is bent up and
over the shadow into a luminous arch, the underside is bent up from below,
and the two nearly close into a ring around an absolute void.

In the frame: the shadow (a true black, the darkest thing on screen), the
photon ring hugging it, the disk arching over and under, a thin bright
inner edge near the ISCO, a relativistic jet climbing out along the spin
axis, and behind everything a lensed sky — stars smeared into arcs, a deep
volumetric nebula wrapping around the hole.

CRITICAL: the luminance of the frame is carried by the disk and the lensed
sky. The shadow must read as a *hole in the image*, not as dark gray. If a
screenshot reads as "gray soup with a bright ring", the exposure, the
tonemapping or the nebula density is wrong, and that is a top-priority bug,
not a taste question.

## 2. THE PHYSICS — light must actually be bent (G)

- G1. **Null geodesic integration in Kerr geometry**, per pixel, marching
  backwards from the camera. Boyer-Lindquist or Kerr-Schild coordinates —
  your call, but justify it in the report and handle its singularities.
  RK4 or RKF45 with adaptive step size. Spin `a` is a live parameter in
  [0, 0.999]; at `a = 0` the code must reduce to Schwarzschild exactly.
- G2. Rays terminate in exactly three ways: captured by the horizon, escaped
  to the sky, or absorbed by the disk. Robust termination — no infinite
  loops, no NaN, a hard step cap with a graceful (and visibly correct)
  fallback.
- G3. **The shadow.** At `a = 0` it is a circle whose impact parameter is
  `b_crit = 3*sqrt(3) M ~ 5.196 M`. At high spin it must visibly flatten on
  the prograde side into the classic D-shape. This is measured by T1/T2 —
  it is the strongest single piece of evidence that the physics is real.
- G4. **The photon ring.** The n=1 higher-order image must be visible as a
  thin, bright, sharp ring hugging the shadow — the disk seen from behind
  and underneath, wrapped around the hole. Getting n=2 is a bonus. If the
  top of the disk arcs over the shadow while the underside arcs below it,
  and a razor-thin ring separates both from the void, you have it right.
- G5. **Frame dragging.** With `a > 0` the lensed sky and the inner disk
  visibly shear in the direction of rotation, and the shadow becomes
  asymmetric. Moving spin from 0 to 0.9 must change the picture in an
  obvious, physically correct way — not merely tint it.
- G6. **Doppler beaming and gravitational redshift.** Compute the photon
  energy shift from the actual four-velocity of the emitting disk element
  (Keplerian orbit at that radius) and the camera. The approaching side must
  be dramatically brighter and bluer; the receding side dimmer and redder;
  light climbing out of the well loses energy. State in the report whether
  you used delta^3 or delta^4 for surface brightness and why.

## 3. THE DISK (D)

- D1. Geometrically thin, optically thick, spanning ISCO to ~20-25 M. The
  ISCO depends on spin (6 M at a=0, ~1.24 M at a=0.998) — when the user
  changes spin, the inner edge must move accordingly (T4).
- D2. **Color from physics, not from a palette.** Temperature profile
  `T ~ r^(-3/4)` (Shakura-Sunyaev), converted through an actual blackbody
  spectrum -> CIE -> sRGB. The white-blue inner edge and deep orange outer
  disk must fall out of the Planck curve, not out of a hand-drawn gradient
  texture. Combine with the Doppler shift from G6 in energy space, not by
  tinting pixels afterwards.
- D3. **Turbulence and shear.** Differential Keplerian rotation: the inner
  rings orbit visibly faster than the outer ones and shear structure into
  spirals. Density and temperature detail from domain-warped FBM evaluated
  in the co-rotating frame — no visible tiling, no noise "crawl", no
  static texture stapled to a rotating disk.
- D4. Vertical structure: thin, but not a zero-thickness plane. A small
  scale height with self-shadowing hint, so the near edge occults and the
  far side glows through.
- D5. A few hot spots / flares orbiting with the flow, so the eye has
  motion to track. They obey the same lensing, beaming and redshift as
  everything else.

## 4. JET AND SKY (J)

- J1. **Relativistic jet** along the spin axis: raymarched volumetric,
  synchrotron-blue and dense at the base, fainter and cooler with distance,
  with helical structure from frame dragging and brighter internal-shock
  knots travelling outward. Lensed like everything else.
- J2. **Procedural star field, no textures**: a plausible distribution of
  stellar magnitudes and color temperatures, rendered with a real point
  spread function and subtle diffraction spikes, fully lensed — stars near
  the shadow smear into arcs, and a star directly behind the hole forms an
  Einstein ring (T8).
- J3. **Volumetric nebula bed**: 3D FBM, colored by density and by the
  light it receives, so the background is a place and not a black void. It
  must be lensed along the ray as well, and it must never turn into gray
  mush — it is the thing that gives the frame depth.
- J4. Everything in J1-J3 is sampled ALONG the integrated geodesic. Warping
  a background in screen space instead of along the ray is a hard failure.

## 5. RENDER GRAPH — the passes (R)

At least these, all hand-written GLSL, all in HDR (RGBA16F):

- R1. **Geodesic pass** -> HDR at adaptive scale, with blue-noise jittered
  sub-pixel offsets that change every frame.
- R2. **Temporal accumulation**: reprojection with the previous frame's
  camera matrices, exponential history blend, neighborhood clamping and
  rejection to kill ghosting. Still camera -> a converged, razor-sharp,
  noise-free frame. Moving camera -> no smear trails. History resets on any
  parameter change.
- R3. **Bloom**: a mip chain (>=5 levels) of downsamples and upsamples,
  energy-preserving, soft-knee threshold. The disk must bleed light like
  film without collapsing into a white blob.
- R4. **Anamorphic streaks / diffraction glare** on the brightest features,
  as a separate pass. Subtle and cinematic — not a lens-flare sprite.
- R5. **Composite**: filmic tonemapping (ACES or AgX — say which),
  exposure control, gentle chromatic aberration toward the frame edges,
  vignette, film grain, and dithering before the 8-bit write. Banding
  anywhere — nebula, shadow rim, jet — is a defect.
- R6. Every pass individually toggleable at runtime for debugging and for
  the report; NaN/Inf must never reach the composite (guard and prove it in
  T7).

## 6. CAMERA AND CINEMATOGRAPHY (V)

- V1. Damped orbit + dolly on mouse and wheel, keyboard fly, critically
  damped everywhere, no jitter, no gimbal flip at the poles.
- V2. **Five named shot presets on keys 1-5**, each a real composition, not
  a random viewpoint: (1) the wide hero shot, (2) razor edge-on through the
  disk plane, (3) high angle looking down on disk and jet, (4) photon-ring
  closeup, (5) jet base looking along the axis. Transitions are eased
  cinematic moves of about two seconds. Each of the five must be a frame you
  would publish.
- V3. `C` = **cinematic auto-orbit**: a slow, perfectly smooth, seamlessly
  looping 30-second camera move designed to be screen-recorded. It must
  never clip through the disk, never lose the composition, and it must end
  exactly where it began. This is the shot that will be published — treat it
  as the deliverable it is.
- V4. `P` = **high-quality still**: freeze, accumulate N supersampled frames
  at full resolution, save a PNG. This is the frame people will screenshot.
- V5. Optional bonus, only after everything else works: a near-horizon
  flythrough preset.

## 7. HUD AND CONTROLS (U)

- U1. Instrument-grade minimal HUD, monospace, tabular numbers, no default
  browser widgets, no rounded dashboard cliches: spin `a`, inclination,
  ISCO radius, shadow angular radius, exposure, disk temperature range,
  render scale, accumulated samples. Numbers animate, never teleport.
- U2. A live parameter panel — spin, inclination, exposure, disk
  brightness, jet on/off, quality. Every parameter changes the picture
  immediately and correctly and resets the accumulator.
- U3. A controls hint that dismisses on first input; `H` hides the entire
  HUD for clean recording.
- U4. Backquote (`) debug overlay: FPS, frame ms p50/p95, render scale,
  average and max ray steps, accumulated samples, and per-pass GPU timings
  if `EXT_disjoint_timer_query_webgl2` is available.
- U5. A physics panel that shows the derived numbers with the formula
  behind each: horizon radius, `b_crit`, ISCO, orbital period at ISCO,
  the Doppler factor extremes currently on screen. This is a teaching
  instrument as much as a picture — and every number must be computed, never
  typed in.

## 8. PERFORMANCE (F)

- F1. Zero per-frame allocations in JS; uniform locations cached; no shader
  recompiles at runtime except on a quality change.
- F2. Adaptive ray stepping: coarse far from the hole, fine near the photon
  sphere. Report average and max steps per frame.
- F3. devicePixelRatio clamped, correct resize (recreate targets, reset
  accumulation), tab-visibility pause with clean resume.
- F4. Quality presets low / medium / high / ultra affecting steps, render
  scale, bloom levels and jet samples; `G` cycles them. Ultra is allowed to
  drop below 60 FPS; high must hold it.

## 9. SELF-TEST (T key) — this is what makes the build trustworthy

Log PASS/FAIL per check to the console with the measured values on failure.
These are MEASUREMENTS taken with `readPixels` on the real framebuffer, not
assertions about your own code:

- T1. **Shadow radius**: at `a = 0`, disk and jet disabled, measure the
  shadow's radius in pixels, convert using the current camera distance and
  FOV, and assert it matches `b_crit = 5.196 M` within 3%.
- T2. **Symmetry and frame dragging**: at `a = 0` with the camera in the
  equatorial plane and only the sky enabled, the frame must be mirror
  symmetric about the vertical axis (mean absolute difference < 1%). At
  `a = 0.9` the same measurement must fail by a wide margin. Report both
  numbers — together they are the proof that the metric is really in there.
- T3. **Doppler asymmetry**: with the disk on, the mean luminance of the
  approaching half is at least 2x the receding half, and its mean color
  temperature is higher. Report the ratio.
- T4. **ISCO tracking**: measure the inner disk edge radius in pixels at
  `a = 0` and at `a = 0.9`; assert the ratio matches the ISCO formula within
  10%.
- T5. **Blackbody sanity**: sample disk pixels at three radii; assert
  monotone cooling outward and that each hue sits on the Planck locus for
  `T(r)` — no invented palette.
- T6. **Determinism**: render the frame at `t = 12.345 s` twice from a cold
  accumulator; assert the pixel hashes are identical.
- T7. **No NaN/Inf**: scan the HDR target for non-finite values. Zero
  tolerance.
- T8. **Einstein ring**: enable a debug mode with a single test star placed
  exactly behind the hole; assert the bright pixels form a closed, thin,
  radially symmetric ring around the shadow rather than a point. This is the
  check that a screen-space fake cannot pass.
- T9. **Performance**: on the default shot at 1080p, p95 frame time under
  16.7 ms; report p50/p95 for all five presets.

Making a check pass by special-casing the test, loosening a tolerance, or
disabling the feature it measures is a failure of the entire build. If a
check fails, the physics or the renderer is wrong — fix that.

## 10. KNOWN PITFALLS — do not fail on these (K)

- K1. The screen-space fake (warping background UVs around a disc) is an
  instant fail; T2 and T8 exist to catch it.
- K2. Numerical blowup near the horizon: adaptive step, termination radius,
  guards. Boyer-Lindquist is singular at the horizon — handle it properly or
  work in Kerr-Schild.
- K3. Float precision at large radii — keep everything in units of M and
  avoid catastrophic cancellation in the conserved quantities.
- K4. Banding: dither before the 8-bit write, jitter volumetric sample
  offsets with blue noise, never quantize the nebula.
- K5. TAA ghosting on the fast-moving inner disk: neighborhood clamp, and do
  not accumulate under camera motion.
- K6. Additive blowout: the disk becomes a white sheet without proper HDR
  and tonemapping. Solve it with exposure and the tonemapper, not by
  dimming the disk.
- K7. `EXT_color_buffer_float` missing -> say so on screen; never silently
  fall back to 8-bit targets.
- K8. After every optimization, re-check the hero frame with your eyes (the
  `look` tool). A faster build that looks worse is a regression, and it will
  be judged as one.
- K9. Ports 5173-5211, 4000, 8642 and 8652 are occupied on this machine.
  Pick a free port and print it.

## 11. PROCESS AND ACCEPTANCE

Ship a minimal correct core first: fullscreen triangle, Schwarzschild
geodesics, lensed star field, shadow. Verify T1 and T2 immediately —
everything else hangs off the physics being real. Then iterate in priority
order:

disk with blackbody + Doppler (sections 2-3) -> photon ring quality (G4) ->
temporal accumulation, bloom, tonemap and grade (R2/R3/R5) -> nebula and jet
(J1/J3) -> Kerr spin and frame dragging (G5) -> camera presets and the
cinematic orbit (V) -> HUD and physics panel (U) -> quality presets.

If you have to cut, cut from the bottom: the near-horizon flythrough (V5),
per-pass GPU timers (U4), the n=2 image (G4), jet knot detail, the ultra
preset. Nothing in sections 2, 3, 5 or 9 is sacrificable. Downgrading a
hand-written pass to something cheaper counts as a cut and goes to the same
place at the bottom of the queue.

You are a NON-VISION model: you cannot judge this image by reading your own
code, and the accessibility tree tells you nothing about a shader. Use the
`look` tool relentlessly — drive the page with Playwright, save frames to
`shots/`, and interrogate them like a VFX supervisor: does the shadow read
as a true void or as gray? is there banding in the nebula? does the photon
ring read as a thin sharp line? does the disk look like film or like a
gradient? is the approaching side obviously brighter? would a person stop
scrolling for this frame? Check every preset, and check before and after
every visual change. Capture the browser console and fix everything from
your own code. If you cannot see the page at all, say so explicitly and
self-review against every requirement ID. Do not stop at a plan.

All C/G/D/J/R/V/U/F/T/K requirements are individually checkable — they are
your definition of done.

Finish with a short report:
1. Project layout (one line per module) and the exact command to serve it.
2. Full control scheme.
3. The physics: coordinates, integrator, step strategy, average steps per
   ray, the beaming exponent you chose and why, and every formula behind the
   numbers in the physics panel.
4. Requirement IDs fully met / partially met / cut.
5. The self-test table: every T check with its measured value.
6. p50/p95 frame times for all five presets at 1080p.
7. The main trade-offs you consciously took and why.
