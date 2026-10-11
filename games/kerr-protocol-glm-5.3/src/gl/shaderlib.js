// Shader loader with recursive #include resolution and a line map for
// readable compile errors: errors report origin file : line.
const cache = new Map(); // path -> {lines, includes}
async function fetchShader(path) {
  if (cache.has(path)) return cache.get(path);
  const res = await fetch(path);
  if (!res.ok) throw new Error(`shader fetch failed: ${path} (${res.status})`);
  const text = await res.text();
  const entry = { text };
  cache.set(path, entry);
  return entry;
}
export async function loadShaderSource(path, stack = []) {
  if (stack.includes(path)) throw new Error(`shader include cycle: ${stack.concat(path).join(' -> ')}`);
  const entry = await fetchShader(path);
  const outLines = [];
  const map = []; // {file, line}
  const rawLines = entry.text.split('\n');
  for (let i = 0; i < rawLines.length; i++) {
    const m = rawLines[i].match(/^\s*#include\s+"([^"]+)"/);
    if (m) {
      const inc = m[1];
      const sub = await loadShaderSource(inc.startsWith('.') ? inc : inc, stack.concat(path));
      for (let k = 0; k < sub.lines.length; k++) {
        outLines.push(sub.lines[k]);
        map.push(sub.map[k]);
      }
    } else {
      outLines.push(rawLines[i]);
      map.push({ file: path, line: i + 1 });
    }
  }
  return { lines: outLines, map };
}
export function mapShaderError(infoLog, map) {
  return infoLog.split('\n').map((line) => {
    const m = line.match(/^ERROR:\s*\d+:(\d+):\s*(.*)$/);
    if (!m) return line;
    const ln = parseInt(m[1], 10);
    const src = map[ln - 1] || { file: '?', line: ln };
    return `ERROR ${src.file}:${src.line}: ${m[2]}`;
  }).join('\n');
}
