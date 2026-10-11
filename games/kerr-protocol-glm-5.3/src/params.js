// Live parameter registry + quality presets. Changing anything resets TAA history.
export const QUALITY = [
  { name: 'low',    steps: 220, stepScale: 0.062, maxScale: 0.55, nebula: 1.0, bloomLevels: 4 },
  { name: 'medium', steps: 300, stepScale: 0.048, maxScale: 0.70, nebula: 1.0, bloomLevels: 5 },
  { name: 'high',   steps: 400, stepScale: 0.034, maxScale: 0.85, nebula: 1.0, bloomLevels: 3 },
  { name: 'ultra',  steps: 560, stepScale: 0.024, maxScale: 1.00, nebula: 1.0, bloomLevels: 4 },
];
const def = () => ({
  spin: 0.9,
  fov: 58,
  exposure: 1.0,
  diskBright: 1.0,
  jetOn: true,
  quality: 2,          // index into QUALITY
  starDensity: 1.0,
  nebulaBright: 1.0,
});
export class Params {
  constructor(onChange) {
    this.p = def();
    this.onChange = onChange; // called with (key) whenever a value is set
  }
  set(key, value) {
    if (this.p[key] === value) return;
    this.p[key] = value;
    this.onChange(key);
  }
  get q() { return QUALITY[this.p.quality]; }
}
