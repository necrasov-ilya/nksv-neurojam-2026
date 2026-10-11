// Blackbody chromaticity: linear-sRGB normalized to unit luminance, as a
// degree-9 polynomial in u = log10(T/K), fitted to exact Planck spectra through
// CIE 1931 XYZ -> sRGB (400 samples, 800K..40000K, max err < 1e-3).
// Bolometric scaling is applied separately as T^4.
vec3 blackbodyRGB(float T) {
  float u = clamp(log2(max(T, 500.0)) * 0.30102999566, 2.9, 4.61); // log10, clamp 800..40000K
  // r(u)
  float r = -1.694118e-01; r = r * u + 5.256859e+00; r = r * u - 7.082192e+01; r = r * u + 5.391608e+02;
  r = r * u - 2.519677e+03; r = r * u + 7.292016e+03; r = r * u - 1.224751e+04; r = r * u + 9.132570e+03;
  r = r * u + 2.147898e+03; r = r * u - 5.637722e+03;
  // g(u)
  float g = 1.483784e-02; g = g * u - 4.632840e-01; g = g * u + 6.207899e+00; g = g * u - 4.591267e+01;
  g = g * u + 1.979687e+02; g = g * u - 4.588871e+02; g = g * u + 2.744677e+02; g = g * u + 1.250792e+03;
  g = g * u - 3.039230e+03; g = g * u + 2.154640e+03;
  // b(u)
  float b = 3.518688e-01; b = b * u - 1.089013e+01; b = b * u + 1.470478e+02; b = b * u - 1.132809e+03;
  b = b * u + 5.458395e+03; b = b * u - 1.692641e+04; b = b * u + 3.334516e+04; b = b * u - 3.928187e+04;
  b = b * u + 2.378136e+04; b = b * u - 4.728795e+03;
  return max(vec3(r, g, b), vec3(0.0));
}
