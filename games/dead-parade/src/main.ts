// DEAD PARADE — integrated entry: sim + view + UI + audio + input wiring.
import { Clock } from 'three';
import { GameView } from './rendering/GameView';
import { Simulation } from './game/Simulation';
import { UI } from './ui/UI';
import { AudioSys } from './audio/Audio';
import { Input } from './core/Input';
import { Settings } from './core/Settings';
import type { Zone } from './core/model';
import { baseModifiers, UPGRADES } from './game/upgrades';
import type { Modifiers } from './game/upgrades';

const canvas = document.querySelector<HTMLCanvasElement>('#gameCanvas')!;
const move = { x: 0, z: 0 };
const view = new GameView(canvas);
const input = new Input();
input.attach(canvas);
const settings = new Settings();
const audio = new AudioSys();

type Mode = 'MENU' | 'PLAYING';
let mode: Mode = 'MENU';
let endlessMode = false;
let sim: Simulation | null = null;
let ui: UI | null = null;

function modifiersWithLoadout(): Modifiers & { startMutation: string } {
  if (!ui) return baseModifiers() as Modifiers & { startMutation: string };
  return ui.getModifiers();
}

function startRun(endless = false): void {
  endlessMode = endless;
  const mods = modifiersWithLoadout();
  if (ui) mods.startMutation = ui.startingMutation;
  sim = new Simulation((index: number): Zone => view.zone(index), endless);
  sim.reset(mods);
  mode = 'PLAYING';
  input.setEnabled(true);
  ui?.show('PLAYING');
  audio.reset();
  void audio.unlock().then(() => audio.configure(settings.data));
}

function toMenu(): void {
  mode = 'MENU';
  sim = null;
  ui?.show('MAIN_MENU');
}

function choose(id: string): void {
  sim?.chooseUpgrade(id);
  input.clearFrame();
  if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
  ui?.show('PLAYING');
}

ui = new UI({
  start: (endless = false) => startRun(endless),
  menu: toMenu,
  loadout: () => { mode = 'MENU'; ui!.show('LOADOUT'); },
  resume: () => ui!.show('PLAYING'),
  pause: () => ui!.show('PAUSED'),
  settingsChanged: () => {
    const s = ui!.settings;
    settings.data = { ...settings.data, ...s };
    settings.save();
    audio.configure({ master: s.master, music: s.music, sfx: s.sfx });
    view.setQuality(s.shadows, s.quality);
  },
  previewItem: id => view.previewItem(id),
});

audio.configure({ master: settings.data.master, music: settings.data.music, sfx: settings.data.sfx });
view.setQuality(settings.data.shadows !== 'low', settings.data.hordeQuality);
view.zone(0);
ui.show('MAIN_MENU');

function pausePlaying(): void {
  if (mode === 'PLAYING' && ui && ui.screen === 'PLAYING') ui.show('PAUSED');
  if (document.pointerLockElement) document.exitPointerLock();
}

window.addEventListener('keydown', event => {
  if (ui?.screen === 'LEVEL_UP') {
    if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(event.code)) {
      event.preventDefault();
      const cards = Array.from(document.querySelectorAll<HTMLButtonElement>('#luCards button'));
      const current = cards.indexOf(document.activeElement as HTMLButtonElement);
      const direction = event.code === 'ArrowUp' || event.code === 'ArrowLeft' ? -1 : 1;
      cards[(Math.max(0, current) + direction + cards.length) % cards.length]?.focus();
      return;
    }
    const number = /^(?:Digit|Numpad)([123])$/.exec(event.code);
    if (number) {
      event.preventDefault();
      if (!event.repeat) document.querySelectorAll<HTMLButtonElement>('#luCards button')[Number(number[1]) - 1]?.click();
    }
    return;
  }
  if (event.code === 'Tab') { event.preventDefault(); if (mode === 'PLAYING') ui?.toggleBuild(); }
  if (event.code === 'Escape' && mode === 'PLAYING') {
    if (ui?.screen === 'PLAYING') { ui.show('PAUSED'); }
    else if (ui?.screen === 'PAUSED') { ui.show('PLAYING'); }
    else if (ui?.screen === 'SETTINGS' || ui?.screen === 'HOWTO') { ui.show('PAUSED'); }
  }
  if (mode !== 'PLAYING' || !sim || ui?.screen !== 'PLAYING') return;
  if (event.code === 'KeyQ' && sim.snapshot.pendingLevel === false) { controls.surge = true; }
  if (event.code === 'KeyE') { controls.ability = true; }
  if (event.code === 'Space') { controls.dash = true; }
  if (event.code === 'Digit1') { controls.select = 1; ui.selectAbility(1); }
  if (event.code === 'Digit2') { controls.select = 2; ui.selectAbility(2); }
  if (event.code === 'Digit3') { controls.select = 3; ui.selectAbility(3); }
  if (event.code === 'Digit4') { controls.select = 4; ui.selectAbility(4); }
});

const controls = { x: 0, z: 0, yaw: 0, sprint: false, dash: false, surge: false, ability: false, select: 0 };
function readMovement(): void {
  const m = input.moveVec();
  controls.x = m.x; controls.z = m.z;
}

window.addEventListener('keyup', event => {
  if (event.code === 'Space') void event;
});

canvas.addEventListener('mousedown', () => {
  if (mode === 'PLAYING' && ui?.screen === 'PLAYING') void canvas.requestPointerLock();
});

window.addEventListener('blur', () => { if (mode === 'PLAYING') pausePlaying(); });
window.addEventListener('resize', () => view.resize());

const clock = new Clock();
let last = performance.now();

function frame(now: number): void {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, Math.max(0, (now - last) / 1000));
  last = now;

  if (mode === 'MENU') {
    view.update(undefined, dt, ui?.screen === 'LOADOUT' ? 'loadout' : 'menu');
    input.clearFrame();
    return;
  }

  if (!sim) return;
  const s = sim.snapshot;

  const playing = ui?.screen === 'PLAYING';
  if (playing) {
    cameraLook();
    readMovement();
    controls.yaw = view.cameraRig.yaw;
    sim.update(dt, controls);
    controls.dash = controls.surge = controls.ability = false;
    controls.select = 0;
    if (s.pendingLevel) showLevelUp();
  } else {
    sim.update(0, controls);
  }

  view.update(s, dt, 'playing');
  if (ui) {
    ui.update(s);
    for (const effect of s.effects) audio.effect(effect, s);
    s.effects.length = 0;
    if (s.notices.length) { for (const text of s.notices) ui.toast(text); s.notices.length = 0; }
    if (s.won && !endlessMode) { mode = 'MENU'; ui.end(s, true); sim = null; input.setEnabled(false); return; }
    if (s.lost) { mode = 'MENU'; ui.end(s, false); sim = null; input.setEnabled(false); return; }
  }
  input.clearFrame();
  audio.update(dt, s, playing);
}

function showLevelUp(): void {
  const owned = new Map<string, number>();
  for (const id of sim!.snapshot.upgrades) owned.set(id, (owned.get(id) ?? 0) + 1);
  const shuffled = UPGRADES.filter(upgrade => (owned.get(upgrade.id) ?? 0) < upgrade.maxRank);
  if (!shuffled.length) { sim!.snapshot.pendingLevel = false; return; }
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  ui!.levelUp(shuffled.slice(0, 3), choose);
  input.clearFrame();
}

function cameraLook(): void {
  view.cameraRig.rotate(input.getMouseDx(), input.getMouseDy(), settings.data.sensitivity);
  const m = input.moveVec();
  move.x = m.x; move.z = m.z;
  controls.x = move.x; controls.z = move.z;
  controls.sprint = input.isDown('ShiftLeft') || input.isDown('ShiftRight');
}

input.setEnabled(true);
requestAnimationFrame(frame);

