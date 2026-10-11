// WebGL2 context creation, extension gates, resize, context loss.
export function createGL(canvas) {
  const gl = canvas.getContext('webgl2', {
    alpha: false, antialias: false, depth: false, stencil: false,
    preserveDrawingBuffer: true, powerPreference: 'high-performance',
    desynchronized: false,
  });
  if (!gl) return { gl: null, error: 'WebGL2 is not available in this browser.' };
  const extColorFloat = gl.getExtension('EXT_color_buffer_float');
  const extFloatLinear = gl.getExtension('OES_texture_float_linear'); // optional
  const extTimer = gl.getExtension('EXT_disjoint_timer_query_webgl2'); // optional
  if (!extColorFloat) {
    return { gl, error: 'Required extension EXT_color_buffer_float is missing — ' +
      'HDR render targets cannot be created. Try a recent Chrome/Firefox/Safari with hardware acceleration on.' };
  }
  return { gl, error: null, extTimer };
}

export function initResize(canvas, gl, onResize) {
  let lost = false;
  const apply = () => {
    if (lost) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.max(2, Math.round(canvas.clientWidth * dpr));
    const h = Math.max(2, Math.round(canvas.clientHeight * dpr));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w; canvas.height = h;
      onResize(w, h);
    }
  };
  canvas.addEventListener('webglcontextlost', (e) => { e.preventDefault(); lost = true; onResize(-1, -1); });
  canvas.addEventListener('webglcontextrestored', () => { lost = false; apply(); onResize(-2, -2); });
  window.addEventListener('resize', apply);
  apply();
  return { apply, get lost() { return lost; } };
}
