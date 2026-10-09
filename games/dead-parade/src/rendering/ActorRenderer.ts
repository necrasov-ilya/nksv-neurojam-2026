import * as THREE from 'three';
import type { Actor, ActorKind } from '../core/model';

interface Skin { skin: number; shirt: number; pants: number; accent: number; scale: number; width: number; }
const SKINS: Record<ActorKind, Skin> = {
  leader: { skin: 0xa4c16c, shirt: 0x294d4a, pants: 0x26373c, accent: 0xe15c44, scale: 1.25, width: 1 },
  walker: { skin: 0x92b96f, shirt: 0x59766b, pants: 0x344956, accent: 0xd5ba74, scale: 1, width: 1 },
  runner: { skin: 0xa4d57a, shirt: 0xc29541, pants: 0x385556, accent: 0xffd566, scale: 0.95, width: 0.78 },
  brute: { skin: 0x779d72, shirt: 0x544c6f, pants: 0x353b51, accent: 0xcaa6f0, scale: 1.52, width: 1.5 },
  bomber: { skin: 0xd5bf6a, shirt: 0xa45037, pants: 0x584336, accent: 0xff9a40, scale: 1.12, width: 1.35 },
  spitter: { skin: 0x85c688, shirt: 0x406962, pants: 0x35534c, accent: 0x9aff70, scale: 1.08, width: 0.95 },
  civilian: { skin: 0xd4aa84, shirt: 0xb57760, pants: 0x394758, accent: 0xe4c58b, scale: 1, width: 0.94 },
  athlete: { skin: 0xb98666, shirt: 0xc4b462, pants: 0x325d62, accent: 0xf3dfad, scale: 1.05, width: 0.87 },
  heavyCivilian: { skin: 0xc39777, shirt: 0x809ea0, pants: 0x48546b, accent: 0xdccc9b, scale: 1.08, width: 1.3 },
  worker: { skin: 0xd0a076, shirt: 0xbf913c, pants: 0x4d6369, accent: 0xffd85a, scale: 1.03, width: 1.08 },
  medic: { skin: 0xd5b199, shirt: 0xd5d4b4, pants: 0x517c76, accent: 0xe55c47, scale: 1, width: 0.9 },
  guard: { skin: 0xc7a080, shirt: 0x547288, pants: 0x364a61, accent: 0xe5c365, scale: 1.05, width: 1 },
  rifleman: { skin: 0xc5a27d, shirt: 0x657766, pants: 0x40564c, accent: 0xd9b57c, scale: 1.08, width: 1.05 },
  shotgunner: { skin: 0xb89073, shirt: 0x705e53, pants: 0x394952, accent: 0xee985c, scale: 1.12, width: 1.15 },
  grenadier: { skin: 0xc1a386, shirt: 0x637145, pants: 0x475643, accent: 0xeaa446, scale: 1.1, width: 1.12 },
  riot: { skin: 0xaf9480, shirt: 0x3b5769, pants: 0x2b4051, accent: 0x9ac8d9, scale: 1.13, width: 1.13 },
  heavy: { skin: 0xb09d86, shirt: 0x3e565c, pants: 0x293f47, accent: 0xe7c270, scale: 1.35, width: 1.4 },
  flamer: { skin: 0xc59a7d, shirt: 0x8a4a2c, pants: 0x4a3a2c, accent: 0xff7a2a, scale: 1.14, width: 1.18 },
  sniper: { skin: 0xc2a184, shirt: 0x4c5a44, pants: 0x37452f, accent: 0xd8ffd2, scale: 1.02, width: 0.88 },
  drone: { skin: 0x9aa8ad, shirt: 0x6d7b80, pants: 0x3f4b50, accent: 0x7ff2ff, scale: 0.72, width: 0.8 },
  sapper: { skin: 0xbd9776, shirt: 0x7d6a3a, pants: 0x4c4433, accent: 0xffd23f, scale: 1.1, width: 1.05 },
};
type PartShape = 'box' | 'head' | 'orb' | 'glow';

/** Four body draw calls, growable for the complete simulation population, never view-filtered. */
export class ActorRenderer {
  readonly root = new THREE.Group();
  private capacity = 0;
  private readonly meshes = {} as Record<PartShape, THREE.InstancedMesh>;
  private readonly counts: Record<PartShape, number> = { box: 0, head: 0, orb: 0, glow: 0 };
  private readonly geometries: Record<PartShape, THREE.BufferGeometry> = {
    box: new THREE.BoxGeometry(1, 1, 1), head: new THREE.IcosahedronGeometry(0.5, 1), orb: new THREE.SphereGeometry(0.5, 7, 5), glow: new THREE.SphereGeometry(0.5, 6, 4),
  };
  private readonly solid = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.85, flatShading: true });
  private readonly glow = new THREE.MeshBasicMaterial({ color: 0xffffff });
  private readonly base = new THREE.Object3D();
  private readonly part = new THREE.Object3D();
  private readonly matrix = new THREE.Matrix4();
  private readonly color = new THREE.Color();
  private readonly up = new THREE.Vector3(0, 1, 0);
  private readonly direction = new THREE.Vector3();
  private readonly rootQuat = new THREE.Quaternion();
  private readonly leanQuat = new THREE.Quaternion();
  private readonly axisX = new THREE.Vector3(1, 0, 0);
  private readonly axisY = new THREE.Vector3(0, 1, 0);
  private highlight = '';

  constructor() { this.reserve(64); }

  private reserve(actors: number): void {
    if (actors <= this.capacity) return;
    this.capacity = Math.max(64, THREE.MathUtils.ceilPowerOfTwo(actors));
    for (const shape of Object.keys(this.meshes) as PartShape[]) { this.meshes[shape].removeFromParent(); this.meshes[shape].dispose(); }
    for (const shape of Object.keys(this.counts) as PartShape[]) {
      const mesh = new THREE.InstancedMesh(this.geometries[shape], shape === 'glow' ? this.glow : this.solid, this.capacity * (shape === 'box' ? 48 : 12));
      mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage); mesh.frustumCulled = false; mesh.castShadow = shape !== 'glow'; mesh.receiveShadow = true;
      this.meshes[shape] = mesh; this.root.add(mesh);
    }
  }

  private piece(shape: PartShape, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: number, rx = 0, rz = 0): void {
    this.part.position.set(x, y, z); this.part.scale.set(sx, sy, sz); this.part.rotation.set(rx, 0, rz); this.part.updateMatrix();
    this.matrix.multiplyMatrices(this.base.matrix, this.part.matrix);
    const i = this.counts[shape]++; this.meshes[shape].setMatrixAt(i, this.matrix); this.meshes[shape].setColorAt(i, this.color.setHex(color));
  }

  private limb(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, width: number, color: number): void {
    this.direction.set(x2 - x1, y2 - y1, z2 - z1);
    this.part.position.set((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2);
    this.part.scale.set(width, this.direction.length() + width * 0.2, width);
    this.part.quaternion.setFromUnitVectors(this.up, this.direction.normalize()); this.part.updateMatrix();
    this.matrix.multiplyMatrices(this.base.matrix, this.part.matrix);
    const i = this.counts.box++; this.meshes.box.setMatrixAt(i, this.matrix); this.meshes.box.setColorAt(i, this.color.setHex(color));
  }

  update(actors: readonly Actor[], time: number, camera: THREE.Camera, quality: string, preview = ''): void {
    this.reserve(actors.length + 1); this.highlight = preview;
    this.counts.box = this.counts.head = this.counts.orb = this.counts.glow = 0;
    for (let i = 0; i < actors.length; i++) {
      const actor = actors[i];
      const dx = actor.x - camera.position.x, dz = actor.z - camera.position.z;
      const detail = actor.kind === 'leader' || dx * dx + dz * dz < (quality === 'low' ? 650 : 1800);
      this.actor(actor, time, detail);
    }
    for (const shape of Object.keys(this.counts) as PartShape[]) {
      const mesh = this.meshes[shape]; mesh.count = this.counts[shape]; mesh.instanceMatrix.needsUpdate = true;
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    }
  }

  private actor(actor: Actor, time: number, detail: boolean): void {
    const s = SKINS[actor.kind], leader = actor.kind === 'leader';
    const zombie = leader || actor.kind === 'walker' || actor.kind === 'runner' || actor.kind === 'brute' || actor.kind === 'bomber' || actor.kind === 'spitter' || actor.infected;
    const armed = actor.kind === 'guard' || actor.kind === 'rifleman' || actor.kind === 'shotgunner' || actor.kind === 'grenadier' || actor.kind === 'riot' || actor.kind === 'heavy' || actor.kind === 'flamer' || actor.kind === 'sniper' || actor.kind === 'sapper';
    const dead = actor.state === 'dead' || actor.state === 'down';
    const rising = actor.state === 'infected' || actor.state === 'rising';
    const speed = Math.min(1, Math.hypot(actor.vx, actor.vz) / 2.5);
    const phase = detail ? actor.anim * (actor.kind === 'runner' ? 13 : 8) + actor.id * 1.71 : Math.floor(time * 5) * 1.4 + actor.id;
    const stride = Math.sin(phase) * (0.035 + speed * 0.47);
    const attack = actor.attack > 0 ? Math.sin(Math.min(1, actor.attack * 4) * Math.PI) : 0;
    const bob = Math.abs(Math.cos(phase)) * 0.07 * speed;
    const lean = dead ? -1.48 : rising ? -1.2 * Math.max(0, Math.min(1, actor.timer)) : actor.state === 'lock' || actor.kind === 'drone' ? 0 : (zombie ? 0.12 : -0.035) + attack * 0.3;
    this.base.position.set(actor.x, actor.y + (dead ? 0.22 : bob), actor.z);
    this.rootQuat.setFromAxisAngle(this.axisY, actor.angle); this.leanQuat.setFromAxisAngle(this.axisX, lean); this.base.quaternion.copy(this.rootQuat).multiply(this.leanQuat);
    this.base.scale.set(s.scale, s.scale, s.scale); this.base.updateMatrix();
    const w = s.width, skin = actor.infected ? 0x93b46e : s.skin;
    const pulse = this.highlight && leader ? 0xffd06a : s.accent;
    if (actor.kind === 'drone') {
      // A suspended camera pod and four animated rotors, never a tiny humanoid.
      this.piece('box', 0, 1.2, 0, 1.1, .4, .85, s.shirt);
      this.piece('head', 0, .9, .35, .6, .55, .65, s.pants);
      this.piece('glow', 0, .95, .69, .28, .2, .12, dead ? 0x273b3d : s.accent);
      for (let i = 0; i < 4; i++) {
        const x = i % 2 ? .95 : -.95, z = i < 2 ? -.8 : .8;
        this.limb(0, 1.25, 0, x, 1.25, z, .14, s.pants);
        this.piece('orb', x, 1.3, z, .38, .25, .38, s.shirt);
        const spin = dead ? 0 : time * 35 + i;
        this.limb(x + Math.sin(spin) * .5, 1.45, z + Math.cos(spin) * .5, x - Math.sin(spin) * .5, 1.45, z - Math.cos(spin) * .5, .085, s.accent);
      }
      this.piece('box', 0, .8, .9, .18, .17, .6, s.pants);
      return;
    }
    for (const side of [-1, 1]) {
      const step = stride * side;
      const hipX = side * 0.19 * w;
      this.limb(hipX, 0.95, 0, hipX, 0.55, step * 0.62, 0.21 * w, s.pants);
      this.limb(hipX, 0.55, step * 0.62, hipX, 0.15 + Math.max(0, step) * 0.22, step, 0.17 * w, s.pants);
      this.piece('box', hipX, 0.095 + Math.max(0, step) * 0.22, step + 0.095, 0.23 * w, 0.17, 0.4, leader && /sole|sneaker/.test(this.highlight) ? pulse : 0x233332);
    }
    this.piece('box', 0, 1.15, 0, 0.67 * w, 0.69, 0.38 * w, s.shirt, 0.035);
    this.piece('box', 0, 0.94, 0, 0.66 * w, 0.12, 0.4 * w, 0x223b3e);
    this.piece('box', 0, 0.95, 0.22 * w, 0.11, 0.1, 0.035, s.accent);
    if (actor.kind === 'brute' || actor.kind === 'heavy' || actor.kind === 'heavyCivilian') this.piece('head', 0, 1.13, 0.13, 0.95 * w, 0.85, 0.57, s.shirt);
    for (const side of [-1, 1]) {
      const shoulder = side * 0.43 * w;
      const elbowZ = armed ? 0.25 : zombie ? 0.28 - stride * side * 0.3 : -stride * side * 0.5;
      const handZ = armed ? 0.55 : zombie ? 0.52 + attack * 0.33 - stride * side * 0.3 : -stride * side;
      const elbowY = zombie ? 1.17 + attack * 0.1 : armed ? 1.13 : 0.99;
      const handY = armed ? 1.25 : zombie ? 1.12 + attack * 0.2 : 0.68;
      this.limb(shoulder, 1.4, 0, shoulder * 1.14, elbowY, elbowZ, 0.24 * w, s.shirt);
      this.limb(shoulder * 1.14, elbowY, elbowZ, shoulder * 0.91, handY, handZ, 0.16 * w, skin);
      this.piece('head', shoulder * 0.91, handY, handZ, 0.2 * w, 0.22 * w, 0.23 * w, skin);
    }
    this.piece('box', 0, 1.59, 0.08, 0.24, 0.24, 0.24, skin);
    this.piece('head', 0, 1.93, 0.075, leader ? 0.79 : 0.6, leader ? 0.83 : 0.69, leader ? 0.7 : 0.59, skin, -0.08);
    this.piece('box', 0, 1.7 - attack * 0.08, 0.27 + attack * 0.1, leader ? 0.52 : 0.39, 0.2, 0.34, skin, attack * 0.35);
    if (detail) {
      this.piece('box', 0, 1.775, 0.405, leader ? 0.45 : 0.3, 0.09 + attack * 0.12, 0.045, 0x352d28);
      this.piece('box', 0.035, 1.81, 0.431, 0.29, 0.055, 0.03, 0xeee2b3);
      for (const side of [-1, 1]) {
        this.piece('orb', side * (leader ? 0.2 : 0.145), 2.015, leader ? 0.39 : 0.34, leader ? 0.25 : 0.145, leader ? 0.28 : 0.16, leader ? 0.2 : 0.11, zombie ? 0xeae9b1 : 0xefdab7);
        this.piece('glow', side * (leader ? 0.2 : 0.145), 2.01, leader ? 0.492 : 0.399, leader ? 0.08 : 0.057, leader ? 0.09 : 0.062, 0.045, zombie ? 0xcbe66c : 0x2d3b3c);
        this.piece('head', side * (leader ? 0.4 : 0.31), 1.94, 0.06, 0.16, 0.23, 0.16, skin);
        this.piece('box', side * 0.16, 2.13, 0.34, 0.22, 0.055, 0.08, 0x405a3d, 0, side * -0.19);
      }
      this.piece('head', 0.02, 1.9, 0.41, 0.13, 0.19, 0.17, skin);
      this.piece('box', -0.12, 2.21, -0.05, 0.42, 0.1, 0.36, zombie ? 0x354a39 : 0x534337, 0, -0.2);
      this.piece('box', -0.22, 2.15, -0.12, 0.13, 0.24, 0.35, zombie ? 0x354a39 : 0x534337);
    } else {
      this.piece('glow', 0, 2, 0.355, 0.35, 0.075, 0.04, zombie ? 0xdce9a0 : 0x302e2b);
    }
    if (leader) {
      this.piece('box', -0.12, 1.41, 0.23, 0.22, 0.3, 0.055, 0xe2d6ac, 0, -0.35);
      this.piece('box', 0.12, 1.41, 0.23, 0.22, 0.3, 0.055, 0xe2d6ac, 0, 0.35);
      this.piece('box', 0, 1.19, 0.285, 0.13, 0.47, 0.06, pulse, 0.15, Math.sin(time * 3) * 0.1);
      this.piece('head', 0, 1.44, 0.285, 0.17, 0.15, 0.1, pulse);
      for (let i = 0; i < 3; i++) this.piece('box', -0.22 + i * 0.18, 0.88, -0.1, 0.17, 0.26, 0.2, s.shirt, 0, (i - 1) * 0.15);
      this.piece('box', 0.22, 1.37, 0.229, 0.15, 0.025, 0.04, 0xe4d2a5);
      if (/rib|spine|bone|femur|marrow/.test(this.highlight)) for (let i = 0; i < 4; i++) this.piece('glow', 0, 1.07 + i * 0.13, -0.25, 0.24, 0.09, 0.12, pulse);
      if (/gland|brain|heart|lung|cortex/.test(this.highlight)) this.piece('glow', 0.2, 1.33, 0.31, 0.28, 0.26, 0.13, 0xe87985);
      if (/horn|tooth|amulet/.test(this.highlight)) this.piece('glow', 0, 1.18, 0.34, 0.23, 0.24, 0.12, pulse);
    }
    if (armed) {
      this.piece('head', 0, 2.18, 0.055, 0.67, 0.31, 0.68, s.shirt);
      this.piece('box', 0, 2.13, 0.34, 0.65, 0.06, 0.22, s.shirt);
      this.piece('box', 0, 1.27, 0.24 * w, 0.49 * w, 0.4, 0.12, 0x283f40);
      this.piece('box', 0.28, 1.25, 0.71, 0.12, 0.17, actor.kind === 'guard' ? 0.39 : 0.87, 0x233236, -0.05);
      this.piece('box', 0.28, 1.1, 0.52, 0.1, 0.21, 0.14, 0x273b3d, -0.24);
      if (actor.kind === 'riot') {
        this.piece('box', -0.35, 1.02, 0.65, 0.67, 1.25, 0.12, 0x456978);
        this.piece('box', -0.35, 1.35, 0.719, 0.46, 0.19, 0.025, 0x82bbc1);
        this.piece('box', -0.35, 0.8, 0.719, 0.48, 0.11, 0.025, 0xd1d0b1);
      }
      if (actor.kind === 'grenadier') for (let i = 0; i < 3; i++) this.piece('orb', -0.2 + i * 0.18, 1.24, 0.35, 0.13, 0.2, 0.14, s.accent);
    }
    if (actor.kind === 'flamer') {
      for (const side of [-1, 1]) {
        this.piece('orb', side * .25, 1.35, -.4, .4, 1.15, .48, s.accent);
        this.piece('box', side * .25, 1.35, -.66, .28, .14, .08, 0x302e2b);
      }
      this.piece('box', 0, 1.91, .43, .48, .3, .28, 0x302e2b);
      this.piece('box', 0, 2.06, .44, .48, .1, .08, s.accent);
      this.piece('box', .28, 1.25, 1.15, .3, .3, .45, s.accent);
      this.limb(.3, 1, -.4, .46, 1.1, .7, .15, 0x302e2b);
      if (!dead && !rising && actor.attack > 0) for (let i = 0; i < 5; i++) this.piece('glow', .28, 1.25, 1.7 + i * 1.9, .6 + i * .85, .6 + i * .26, 2.3, i % 2 ? 0xffa42c : 0xff5724);
    }
    if (actor.kind === 'sniper') {
      this.piece('head', 0, 2.03, -.04, .85, .9, .8, s.shirt);
      this.piece('box', 0, 1.88, .39, .48, .13, .08, 0x233236);
      this.piece('box', 0, 1.15, -.3, .95, 1.3, .12, s.shirt, -.12);
      this.piece('box', .28, 1.25, 1.28, .095, .1, 1.65, 0x233236);
      this.piece('box', .28, 1.46, .87, .18, .18, .5, 0x233236);
      this.piece('glow', .28, 1.46, 1.13, .13, .13, .025, s.accent);
      if (!dead && actor.state === 'lock') this.piece('box', .28, 1.25, 23, .035, .035, 42, 0xff413d);
    }
    if (actor.kind === 'sapper') {
      this.piece('box', 0, 1.32, -.4, .86, .95, .47, s.accent);
      this.piece('box', -.37, 2, -.42, .055, 1.1, .055, 0x233236);
      this.piece('glow', -.37, 2.55, -.42, .14, .14, .14, actor.state === 'deploy' ? 0xff413d : s.accent);
      this.piece('box', .28, 1.3, 1, .42, .4, .85, 0x4c4433);
      this.piece('box', .28, 1.3, 1.44, .3, .28, .035, 0x171f23);
      for (const side of [-1, 1]) this.piece('box', side * .53, 1.48, 0, .32, .35, .57, s.accent);
      this.piece('box', 0, 2, .42, .53, .28, .1, 0x233236);
    }
    if (actor.kind === 'worker') { this.piece('head', 0, 2.23, 0.075, 0.66, 0.32, 0.68, s.accent); this.piece('box', 0, 2.16, 0.09, 0.71, 0.07, 0.73, s.accent); }
    if (actor.kind === 'medic') { this.piece('box', 0, 1.27, 0.225, 0.1, 0.31, 0.045, s.accent); this.piece('box', 0, 1.27, 0.23, 0.28, 0.1, 0.045, s.accent); }
    if (actor.kind === 'bomber') {
      this.piece('glow', 0, 1.12, 0.29, 0.68, 0.7, 0.35, s.accent);
      for (const side of [-1, 1]) this.piece('glow', side * 0.38, 1.52, 0, 0.23, 0.24, 0.25, 0xffc35c);
    }
    if (actor.kind === 'spitter') { this.piece('glow', 0, 1.67, 0.33, 0.47, 0.43, 0.36, s.accent); this.piece('head', 0, 1.39, -0.28, 0.67, 0.9, 0.49, 0x688e45); }
    if (actor.kind === 'brute') for (const side of [-1, 1]) this.piece('head', side * 0.63, 1.45, 0, 0.55, 0.48, 0.55, s.accent);
  }
}
