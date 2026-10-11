// Program wrapper: compile with mapped errors, cache uniform locations.
import { mapShaderError } from './shaderlib.js';
export class Program {
  constructor(gl, name, vertEntry, fragEntry) {
    this.gl = gl; this.name = name;
    this.uniforms = new Map();
    this.vert = compile(gl, gl.VERTEX_SHADER, name, vertEntry);
    this.frag = compile(gl, gl.FRAGMENT_SHADER, name, fragEntry);
    this.prog = gl.createProgram();
    gl.attachShader(this.prog, this.vert);
    gl.attachShader(this.prog, this.frag);
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw new Error(`link failed [${name}]:\n${gl.getProgramInfoLog(this.prog)}`);
    }
  }
  use() { this.gl.useProgram(this.prog); return this; }
  uni(name) {
    let loc = this.uniforms.get(name);
    if (loc === undefined) {
      loc = this.gl.getUniformLocation(this.prog, name);
      this.uniforms.set(name, loc);
    }
    return loc;
  }
  f1(n, x) { const l = this.uni(n); if (l) this.gl.uniform1f(l, x); return this; }
  i1(n, x) { const l = this.uni(n); if (l) this.gl.uniform1i(l, x); return this; }
  v2(n, x, y) { const l = this.uni(n); if (l) this.gl.uniform2f(l, x, y); return this; }
  v3(n, x, y, z) { const l = this.uni(n); if (l) this.gl.uniform3f(l, x, y, z); return this; }
  v4(n, x, y, z, w) { const l = this.uni(n); if (l) this.gl.uniform4f(l, x, y, z, w); return this; }
  tex(n, unit, texture, sampler) {
    const gl = this.gl;
    gl.activeTexture(gl.TEXTURE0 + unit);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    const l = this.uni(n); if (l) gl.uniform1i(l, unit);
    return this;
  }
  dispose() {
    const gl = this.gl;
    gl.deleteShader(this.vert); gl.deleteShader(this.frag); gl.deleteProgram(this.prog);
  }
}
function compile(gl, type, name, entry) {
  const sh = gl.createShader(type);
  gl.shaderSource(sh, entry.lines.join('\n'));
  gl.compileShader(sh);
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(sh);
    throw new Error(`compile failed [${name}]:\n${mapShaderError(log, entry.map)}`);
  }
  return sh;
}
