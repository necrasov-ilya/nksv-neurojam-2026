import * as THREE from 'three';
import type { Barrier, Zone } from '../core/model';
import { districtDef } from '../game/districts';
import { Pal, noiseCanvas, signCanvas } from './Palette';

type Piece = { matrix: THREE.Matrix4; color: number };
type Shape = 'box' | 'round' | 'pole' | 'glow';

const seasons = [
  { ground: 0x426c4a, road: 0x334846, pavement: 0x899483, foliage: 0x36824b, tips: 0x91b855, roof: 0x71836c, wall: 0x76967b, sky: 0x83adb1, sun: 0xffecc2, fog: 0.0105 },
  { ground: 0x8b804a, road: 0x655746, pavement: 0xb9aa82, foliage: 0x677b3b, tips: 0xaaa04f, roof: 0xb0a07b, wall: 0xbc9a65, sky: 0xc4ad85, sun: 0xffc17e, fog: 0.011 },
  { ground: 0x76583c, road: 0x443e3b, pavement: 0x988675, foliage: 0xa54e29, tips: 0xd59b39, roof: 0x876850, wall: 0x9b795c, sky: 0x9c9590, sun: 0xffd0a1, fog: 0.013 },
  { ground: 0xc4d9dc, road: 0x6c8791, pavement: 0xb4cdd4, foliage: 0x527b7c, tips: 0xe3edef, roof: 0xe1e9e8, wall: 0x809dad, sky: 0x9fbbc9, sun: 0xcce8ff, fog: 0.016 },
] as const;
const biomeSeasons = [0, 1, 2, 2, 0, 3, 2, 3, 1, 2, 1, 2, 0, 3, 1];

/** Zone geometry and collision originate together; decorative trim never blocks actors. */
export class CityWorld {
  readonly root = new THREE.Group();
  readonly obstacles: THREE.Object3D[] = [];
  readonly data: Zone;
  readonly exitMarker: THREE.Group;
  readonly atmosphere: typeof seasons[number];
  private readonly archetype: number;
  private readonly pieces: Record<Shape, Piece[]> = { box: [], round: [], pole: [], glow: [] };
  private readonly dummy = new THREE.Object3D();
  private readonly barrierViews = new Map<number, { root: THREE.Group; slats: THREE.Mesh[]; lamp: THREE.Mesh }>();
  private readonly textures: THREE.Texture[] = [];
  private weatherMaterial?: THREE.ShaderMaterial;
  private seed: number;

  constructor(readonly index: number) {
    const def = districtDef(index);
    this.seed = def.seed;
    this.archetype = index < 5 ? index : 5 + (index - 5) % 10;
    this.atmosphere = seasons[biomeSeasons[def.biome] ?? 0];
    this.data = { index, boxes: [], barriers: [], shelters: [], spawn: { x: 0, z: 45 }, exit: { x: 0, z: -48 }, biome: def.biome, weather: def.weather };
    this.ground();
    const archetype = this.archetype;
    const signTable = [
      ['MOONLIGHT DINER', 'SUNSET HOMES', 'GOOD DAY MART', 'RADIO REPAIR', 'PALM PHARMACY', 'LAST CALL'],
      ['STARDUST MOTEL', 'RECORD ROOM', 'ATOMIC LAUNDRY', 'THE ORBIT', 'FRESH FARE', 'NIGHT OWL'],
      ['PRECINCT 09', 'CIVIL DEFENSE', 'CITY RECORDS', 'POLICE GARAGE', 'COURTHOUSE', 'SAFE ZONE'],
      ['NOVA CHEMICAL', 'LOADING BAY 04', 'UNION WORKS', 'PRESSURE CO.', 'NIGHT SHIFT', 'DANGER'],
      ['EVAC TERMINAL', 'TICKET OFFICE', 'GATE B', 'LAST DEPARTURE', 'TRANSIT AUTH.', 'NO RETURN'],
      ['FROSTLINE MOTEL', 'SKI & SURVIVAL', 'GLACIER GAS', 'WINTER RECORDS', 'SNOWPLOW CO.', 'COLD STORAGE'],
      ['ASH TOBACCO', 'BURN BAR', 'CINDER CAFE', 'CHARCOAL CO.', 'SMOKE SIGNALS', 'FIREWATCH'],
      ['PERMAFROST BANK', 'ICY DONUTS', 'POLAR PLUMBING', 'FROSTBIT FASHION', 'COLD CUTS', 'THAW & GO'],
      ['MIRAGE MOTEL', 'SUNSHINE SOLAR', 'DESERT DINER', 'OASIS OIL', 'TAN LINES', 'HEAT INDEX'],
      ['EMBER ORCHARDS', 'CIDER CELLAR', 'SMOKEHOUSE 12', 'FLAMEBROIL', 'CAMP SUPPLY', 'BURN BAN'],
      ['OCTANE STATION', 'PUMP 66', 'LUBE & TUNE', 'DIESEL DEN', 'TIRE TIME', 'NO SMOKING'],
      ['HARVEST HALL', 'GRAIN & GROAN', 'CIDER PRESS', 'SILO SUPPLY', 'SCARECROW CO.', 'PUMPKIN PATCH'],
      ['OVERGROWTH FLORAL', 'VINE DINER', 'GREENHOUSE 9', 'COMPOST CO.', 'RAINFOREST FM', 'WEED WACKERS'],
      ['CRYO STORAGE', 'ICE DELIVERY', 'FROSTBITE FX', 'DEEP FREEZE', 'COLD CHAIN', 'ABSOLUTE ZERO'],
      ['FOUNDRY 7', 'SCRAP KING', 'MAGMA MFG', 'RED HOT WELDING', 'ALLOY & ANVIL', 'MELTDOWN'],
    ][archetype];
    const names = signTable;
    for (const side of [-1, 1]) {
      for (let block = 0; block < 4; block++) {
        // Building footprints leave a continuous central avenue and generous side passages.
        const endless = archetype >= 5;
        const open = archetype === 6 || archetype === 9 || archetype === 11 || archetype === 12;
        if (endless && open && block % 2 === (side > 0 ? 1 : 0)) continue;
        const z = 34 - block * 25 + (endless ? (this.rand() - 0.5) * 4 : 0);
        const w = endless ? 12 + this.rand() * 5 : 19;
        const d = endless ? (open ? 12 : 15) + this.rand() * 5 : 19;
        const h = archetype === 0 ? 5 + this.rand() * 3 : open || archetype === 8 || archetype === 10 ? 4.8 + this.rand() * 3 : archetype === 3 || archetype === 14 ? 8 + this.rand() * 5 : 9 + this.rand() * 9;
        const x = side * (endless ? 19 + w / 2 + this.rand() * 2 : 25.5);
        this.building(x, z, w, h, d, names[(block + (side > 0 ? 2 : 0)) % names.length], side, block);
      }
    }
    for (let i = 0; i < 12; i++) {
      const side = i % 2 ? -1 : 1;
      const z = 45 - Math.floor(i / 2) * 18;
      this.lamp(side * 11.9, z, side);
      if (i % 3 !== 1 && Math.abs(z + 5 - 8) > 4 && Math.abs(z + 5 + 31) > 4) this.tree(side * 14, z + 5, archetype === 3 || archetype === 14 ? 0.65 : 1);
      if (i % 2 === 0 && archetype !== 9 && archetype !== 11 && archetype !== 12) this.car(side * (9.8 + (archetype >= 5 ? this.rand() : 0)), z - 7, i % 4 === 0 ? Pal.turquoise : Pal.fadedRed, archetype === 2 || archetype === 4);
      this.add('box', side * 12.4, 0.5, z + 2, 0.55, 1, 0.6, Pal.mustardDark);
      this.add('box', side * 12.4, 1.03, z + 2, 0.7, 0.1, 0.75, Pal.petrol);
      this.add('box', side * 13.2, 0.62, z - 3, 0.7, 0.16, 2.1, Pal.creamDark);
      for (const dz of [-0.75, 0.75]) this.add('pole', side * 13.2, 0.3, z - 3 + dz, 0.09, 0.6, 0.09, Pal.shadowWrap);
    }
    if (archetype === 3 || archetype === 14) this.factory();
    if (archetype === 4) this.terminal();
    if (archetype >= 5) this.sectorProps();
    this.shelters(def.shelters);
    for (let i = 0; i < def.barricadeLines; i++) {
      this.barrier({ id: 100 + i, x: 0, z: def.barricadeLines === 3 ? 18 - i * 27 : i === 0 ? -12 : -39, hx: 7.6, hz: 0.65, hp: archetype === 4 ? 1100 : 420 + Math.min(index, 24) * 130, maxHp: archetype === 4 ? 1100 : 420 + Math.min(index, 24) * 130, kind: archetype === 4 && i === 1 ? 'gate' : archetype > 1 ? 'police' : 'wood', open: false });
    }
    this.exitMarker = this.marker(index >= 5 ? 'INFECTION SPREADS' : 'NEXT DISTRICT', 0, -48, Pal.neonTurquoise);
    this.root.add(this.exitMarker);
    this.flush();
    this.createWeather();
  }

  private rand(): number {
    this.seed = Math.imul(1664525, this.seed) + 1013904223 | 0;
    return (this.seed >>> 0) / 4294967296;
  }

  private add(shape: Shape, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: number, rx = 0, ry = 0, rz = 0): void {
    this.dummy.position.set(x, y, z); this.dummy.scale.set(sx, sy, sz); this.dummy.rotation.set(rx, ry, rz); this.dummy.updateMatrix();
    this.pieces[shape].push({ matrix: this.dummy.matrix.clone(), color });
  }

  private ground(): void {
    const tex = noiseCanvas(128, 128, 0x849597, 0.12); tex.wrapS = tex.wrapT = THREE.RepeatWrapping; tex.repeat.set(30, 40); this.textures.push(tex);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(300, 300), new THREE.MeshStandardMaterial({ color: this.atmosphere.ground, map: tex, roughness: 1 }));
    ground.rotation.x = -Math.PI / 2; ground.position.y = -0.05; ground.receiveShadow = true; this.root.add(ground);
    this.add('box', 0, -0.025, 0, 19, 0.04, 124, this.atmosphere.road);
    for (const side of [-1, 1]) {
      this.add('box', side * 12.6, 0.055, 0, 6.2, 0.13, 122, this.atmosphere.pavement);
      this.add('box', side * 9.65, 0.13, 0, 0.3, 0.26, 122, Pal.creamDark);
      for (let z = -59; z < 60; z += 4) this.add('box', side * 12.6, 0.125, z, 6.1, 0.014, 0.055, 0x3f5353);
      this.add('box', side * 40, 0.8, 0, 1, 1.6, 120, 0x385554);
      this.data.boxes.push({ x: side * 40, z: 0, hx: 0.5, hz: 60 });
    }
    for (let z = -57; z < 60; z += 7) {
      this.add('box', -0.2, 0.007, z, 0.1, 0.025, 3, Pal.mustard);
      this.add('box', 0.2, 0.007, z, 0.1, 0.025, 3, Pal.mustard);
    }
    for (const z of [21.5, -3.5, -28.5]) {
      this.add('box', 0, 0.002, z, 80, 0.025, 4, this.atmosphere.road);
      for (let x = -7; x <= 7; x += 2) this.add('box', x, 0.025, z + 2.5, 1.1, 0.025, 2.7, 0xa6ad98);
    }
    this.data.boxes.push({ x: 0, z: 60, hx: 40, hz: 0.5 }, { x: 0, z: -60, hx: 40, hz: 0.5 });
    this.add('box', 0, 0.5, 60, 80, 1, 1, Pal.petrol);
    this.add('box', 0, 0.5, -60, 80, 1, 1, Pal.petrol);
    // Surface scatter has no collision: snowdrifts, dry grass, leaves or fresh spring growth.
    for (let i = 0; i < 100; i++) {
      const side = i % 2 ? -1 : 1, x = side * (10.3 + this.rand() * 7.5), z = (this.rand() - 0.5) * 114;
      this.add('box', x, 0.145, z, 0.3 + this.rand() * 1.4, 0.03, 0.2 + this.rand() * 0.8, this.atmosphere.tips, 0, this.rand() * Math.PI);
    }
    for (let i = 0; i < 50; i++) {
      const x = (this.rand() - 0.5) * 260, z = -90 - this.rand() * 65, h = 12 + this.rand() * 35;
      this.add('box', x, h / 2 - 1, z, 7 + this.rand() * 9, h, 10, 0x234b54);
    }
  }

  private building(x: number, z: number, w: number, h: number, d: number, name: string, side: number, block: number): void {
    const colors = [this.atmosphere.wall, this.atmosphere.pavement, 0x8b6657, this.atmosphere.wall, 0x657b71];
    const front = x - side * w / 2;
    this.data.boxes.push({ x, z, hx: w / 2, hz: d / 2 });
    const collision = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), new THREE.MeshBasicMaterial({ visible: false }));
    collision.position.set(x, h / 2, z); this.root.add(collision); this.obstacles.push(collision);
    this.add('box', x, h / 2, z, w, h, d, colors[(block + this.archetype) % colors.length]);
    this.add('box', x, h + 0.15, z, w + 0.5, 0.35, d + 0.5, this.atmosphere.roof);
    this.add('box', x, h + 0.5, z, w - 1, 0.5, d - 1, this.atmosphere.roof);
    this.add('box', front - side * 0.22, 1.5, z, 0.35, 3, d, 0x294a4c);
    this.add('box', front - side * 0.55, 3.2, z, 1.6, 0.32, d + 0.4, block % 2 ? Pal.mustard : Pal.fadedRed);
    for (let dz = -d / 2 + 2; dz <= d / 2 - 2; dz += 3.6) {
      this.add('box', front - side * 0.24, 1.75, z + dz, 0.1, 1.8, 2.9, 0x122e35);
      this.add('glow', front - side * 0.3, 1.8, z + dz, 0.05, 1.35, 2.55, block % 2 ? 0xe6b669 : 0x7fc2bc);
      this.add('box', front - side * 0.35, 1.8, z + dz, 0.1, 1.8, 0.075, Pal.creamDark);
    }
    for (let y = 5; y < h - 1; y += 2.9) for (let dz = -d / 2 + 2; dz <= d / 2 - 2; dz += 3.5) {
      this.add('box', front - side * 0.06, y, z + dz, 0.18, 2.05, 1.85, 0x203d43);
      this.add(this.rand() > 0.35 ? 'glow' : 'box', front - side * 0.17, y, z + dz, 0.035, 1.7, 1.5, this.rand() > 0.4 ? 0xbba66c : 0x4e888d);
      this.add('box', front - side * 0.2, y, z + dz, 0.06, 1.75, 0.08, Pal.petrol);
    }
    this.sign(name, front - side * 0.45, 4.1, z, Math.min(13, d - 1), 1.45, -side * Math.PI / 2, block % 2 ? Pal.neonYellow : Pal.neonTurquoise);
    this.add('box', x + 3, h + 1, z + 3, 3.6, 1.5, 3, 0x456568);
    for (let n = 0; n < 3; n++) this.add('box', x + 1.7 + n * 1.2, h + 1.8, z + 3, 0.1, 0.2, 3, Pal.creamDark);
    if (this.index === 0 && block === 0) {
      for (let dz = -9; dz < 10; dz += 1.2) this.add('box', front - side * 0.9, 3.5, z + dz, 2.2, 0.28, 0.6, Pal.cream, 0, 0, side * 0.12);
      this.sign('OPEN 24 / 7', front - side * 0.8, 5.8, z, 8, 1.25, -side * Math.PI / 2, Pal.neonRed);
    }
    if (this.index === 1 && block === 0) {
      this.add('pole', front - side * 2, 6, z + 8, 0.12, 12, 0.12, Pal.creamDark);
      this.sign('MOTEL', front - side * 2, 10, z + 8, 3.6, 2, 0, Pal.neonRed);
      this.sign('VACANCY', front - side * 2, 8.4, z + 8, 3.6, 0.8, 0, Pal.neonYellow);
    }
  }

  private sign(text: string, x: number, y: number, z: number, w: number, h: number, rotation: number, color: number): THREE.Mesh {
    const texture = signCanvas(text, color, 0x193d43, 1024, 160); this.textures.push(texture);
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: texture, side: THREE.DoubleSide, toneMapped: false }));
    mesh.position.set(x, y, z); mesh.rotation.y = rotation; this.root.add(mesh); return mesh;
  }

  private lamp(x: number, z: number, side: number): void {
    this.add('pole', x, 3.1, z, 0.11, 6.2, 0.11, 0x284850);
    this.add('box', x - side * 0.7, 6.1, z, 1.5, 0.15, 0.14, Pal.petrol);
    this.add('box', x - side * 1.4, 5.95, z, 0.75, 0.25, 0.7, Pal.petrol);
    this.add('glow', x - side * 1.4, 5.79, z, 0.65, 0.045, 0.6, Pal.windowWarm);
    // A low-cost painted pool reads as warm street lighting without per-lamp shadow passes.
    this.add('box', x - side * 1.6, 0.024, z, 2.5, 0.013, 2.4, 0x6a7864);
  }

  private tree(x: number, z: number, scale: number): void {
    this.add('pole', x, 1.5 * scale, z, 0.23, 3 * scale, 0.23, 0x645b44);
    this.add('round', x, 3.8 * scale, z, 2.1 * scale, 2.8 * scale, 2.1 * scale, this.atmosphere.foliage);
    this.add('round', x + 0.7, 4.5 * scale, z + 0.2, 1.8 * scale, 2.1 * scale, 1.6 * scale, this.atmosphere.tips);
    this.add('box', x, 0.16, z, 2.5, 0.25, 2.5, this.atmosphere.pavement);
    this.data.boxes.push({ x, z, hx: 0.23, hz: 0.23 });
  }

  private car(x: number, z: number, color: number, police: boolean): void {
    this.data.boxes.push({ x, z, hx: 1.05, hz: 2.21 });
    this.add('box', x, 0.72, z, 1.8, 0.7, 4.2, police ? Pal.cream : color);
    this.add('box', x, 1.25, z + 0.25, 1.55, 0.8, 2.2, police ? 0x243b43 : color);
    this.add('box', x, 1.39, z + 0.25, 1.6, 0.45, 1.8, 0x21454f);
    this.add('box', x, 1.71, z + 0.25, 1.6, 0.15, 2.1, police ? Pal.cream : color);
    this.add('box', x, 0.5, z + 2.13, 1.9, 0.22, 0.15, Pal.creamDark);
    for (const dx of [-0.93, 0.93]) for (const dz of [-1.3, 1.3]) this.add('pole', x + dx, 0.43, z + dz, 0.43, 0.24, 0.43, 0x182d32, 0, 0, Math.PI / 2);
    for (const dx of [-0.58, 0.58]) this.add('glow', x + dx, 0.8, z + 2.14, 0.35, 0.26, 0.03, Pal.windowWarm);
    if (police) {
      this.add('glow', x - 0.35, 1.89, z + 0.25, 0.55, 0.2, 0.35, Pal.neonRed);
      this.add('glow', x + 0.35, 1.89, z + 0.25, 0.55, 0.2, 0.35, Pal.neonTurquoise);
    }
  }

  private cover(x: number, z: number, w: number, h: number, d: number, color: number): void {
    this.add('box', x, h / 2, z, w, h, d, color);
    this.data.boxes.push({ x, z, hx: w / 2, hz: d / 2 });
  }

  private sectorProps(): void {
    for (let i = 0; i < 8; i++) {
      const side = i % 2 ? -1 : 1, x = side * 16.8, z = 38 - Math.floor(i / 2) * 24 + (this.rand() - 0.5) * 4;
      switch (this.archetype) {
        case 5: // Snowbound lodges and plowed banks.
          this.cover(x, z, 2.8, 0.85, 7, this.atmosphere.roof);
          this.tree(side * 18, z + 6, 1.25);
          break;
        case 6: // Scorched fields, burnt trunks and stacked irrigation crates.
          this.cover(x, z, 2.4, 1.2, 3.8, 0x493b30);
          for (let n = 0; n < 4; n++) {
            this.add('pole', x, 1.8, z + 3 + n * 1.4, 0.12, 3.6, 0.12, 0x332e28);
            this.add('box', x + side * 0.3, 2.5, z + 3 + n * 1.4, 0.8, 0.13, 0.13, 0x332e28, 0, 0, side * 0.4);
          }
          break;
        case 7: // Frozen civic quarter: ice-blue concrete checkpoint blocks.
          this.cover(x, z, 2.8, 1.8, 6, 0x8faebb);
          this.add('box', x, 1.9, z, 3, 0.2, 6.2, this.atmosphere.roof);
          this.add('glow', x - side * 1.42, 1.1, z, 0.04, 0.16, 4.8, Pal.neonTurquoise);
          break;
        case 8: // Low desert markets and striped shade canopies.
          this.cover(x, z, 2.6, 1, 4, 0xc3945a);
          this.add('box', x, 3, z, 3.4, 0.18, 5, Pal.mustard);
          for (const dz of [-2, 2]) this.add('pole', x, 1.5, z + dz, 0.08, 3, 0.08, Pal.creamDark);
          break;
        case 9: // Orchard rows and produce pallets.
          this.cover(x, z, 2.3, 1.1, 3, 0x91653c);
          for (const dz of [-6, 6]) this.tree(x, z + dz, 1.2);
          this.add('round', x, 1.45, z, 2.2, 0.8, 2.8, 0xc57835);
          break;
        case 10: // Fuel pump islands, hose loops and service canopies.
          this.cover(x, z, 2, 1.8, 2, Pal.fadedRed);
          this.add('box', x, 2.2, z, 1.6, 0.8, 1.8, Pal.cream);
          this.add('glow', x - side * 0.81, 2.2, z, 0.03, 0.35, 1.3, Pal.neonTurquoise);
          this.add('box', x, 4, z, 3.8, 0.3, 7, Pal.fadedRed);
          this.add('pole', x + side * 1.4, 2, z, 0.12, 4, 0.12, Pal.creamDark);
          break;
        case 11: // Harvest yards: low hay-bale cover and grain silos in open lots.
          this.cover(x, z, 2.6, 1.5, 4.5, 0xb18b43);
          this.add('box', x, 1.52, z, 2.6, 0.06, 0.25, 0x755b39);
          if (i < 2) {
            const sx = side * 27, sz = side > 0 ? 9 : 34;
            this.add('pole', sx, 4, sz, 3, 8, 3, 0xa3a494);
            this.data.boxes.push({ x: sx, z: sz, hx: 3, hz: 3 });
            this.add('round', sx, 8, sz, 6, 2, 6, Pal.creamDark);
          }
          break;
        case 12: // Overgrown garden district: planter cover and lush groves.
          this.cover(x, z, 2.8, 0.9, 5, 0x56765a);
          for (const dz of [-1.5, 1.5]) this.add('round', x, 1.2, z + dz, 2.7, 1.5, 2.7, this.atmosphere.tips);
          this.tree(side * 18, z + 7, 1.5);
          break;
        case 13: // Cryogenic freight: long refrigerated containers with luminous seals.
          this.cover(x, z, 2.8, 3.4, 9, 0xb2cbd1);
          for (let dz = -4; dz <= 4; dz++) this.add('box', x - side * 1.42, 1.7, z + dz, 0.06, 3.1, 0.07, 0x658995);
          this.add('glow', x - side * 1.46, 2.9, z, 0.04, 0.12, 7.8, Pal.neonTurquoise);
          break;
        case 14: // Foundry slag bins and glowing furnaces.
          this.cover(x, z, 2.8, 2.1, 4, 0x544b43);
          this.add('glow', x, 2.12, z, 2.4, 0.03, 3.6, 0xff8b35);
          this.add('pole', x, 4, z + 4, 0.45, 8, 0.45, 0x78533b);
          this.data.boxes.push({ x, z: z + 4, hx: 0.45, hz: 0.45 });
          break;
      }
      // Varied roadside cover never enters the permanent |x| < 4.5 main route.
      if (i % 2 === 0) this.cover(side * (6.5 + this.rand()), z - 3, 2.2, 0.8 + this.rand() * 0.8, 2 + this.rand() * 2, this.atmosphere.wall);
    }
  }

  private factory(): void {
    for (const x of [-19, 19]) for (let z = 16; z > -50; z -= 25) {
      this.add('pole', x, 11, z, 0.7, 22, 0.7, 0x836c54);
      this.data.boxes.push({ x, z, hx: 0.7, hz: 0.7 });
      for (let y = 12; y < 22; y += 2) this.add('pole', x, y, z, 0.76, 0.5, 0.76, Pal.fadedRed);
      this.add('pole', x, 8.8, z, 0.7, 12, 0.7, Pal.mustard, Math.PI / 2);
      this.add('round', x + 1, 24, z, 3, 4, 3, 0x4c6d72);
    }
    for (let i = 0; i < 4; i++) {
      const x = i % 2 ? 32 : -32, z = 19 - i * 17;
      this.add('box', x, 1.4, z, 4.4, 2.8, 7, i % 2 ? Pal.fadedRed : Pal.turquoiseDark);
      this.data.boxes.push({ x, z, hx: 2.2, hz: 3.5 });
      for (let dz = -3; dz <= 3; dz += 0.5) this.add('box', x - Math.sign(x) * 2.23, 1.4, z + dz, 0.08, 2.7, 0.08, Pal.creamDark);
    }
  }

  private terminal(): void {
    for (const x of [-6, 6]) {
      const z = -54;
      this.data.boxes.push({ x, z, hx: 1.8, hz: 4.6 });
      this.add('box', x, 1.7, z, 3.4, 3.1, 9, Pal.mustard);
      this.add('box', x, 2.5, z, 3.5, 1.05, 7.5, 0x203d46);
      this.add('box', x, 3.35, z, 3.6, 0.35, 9.2, Pal.cream);
      for (let dz = -3; dz <= 3; dz++) this.add('box', x, 2.5, z + dz, 3.6, 1.1, 0.1, Pal.creamDark);
      for (const dx of [-1.65, 1.65]) for (const dz of [-2.8, 2.8]) this.add('pole', x + dx, 0.65, z + dz, 0.6, 0.3, 0.6, 0x182d32, 0, 0, Math.PI / 2);
    }
    for (const x of [-13, 13]) {
      this.add('pole', x, 5.5, -46, 0.16, 11, 0.16, Pal.creamDark);
      this.add('glow', x, 10.9, -46, 2, 0.5, 0.6, Pal.windowCold);
    }
    this.sign('EVACUATION / FINAL BOARDING', 0, 8.7, -48, 23, 2.5, 0, Pal.neonYellow);
    this.add('box', 0, 8.7, -48.1, 24, 3, 0.4, Pal.petrol);
    for (const x of [-12, 12]) this.add('pole', x, 4.3, -48, 0.2, 8.6, 0.2, Pal.creamDark);
  }

  private shelters(count: number): void {
    for (let i = 0; i < count; i++) {
      const x = i % 2 ? -14.4 : 14.4, z = i === 0 ? 8 : -31;
      const id = 200 + i;
      this.data.shelters.push({ x, z, barrierId: id, opened: false });
      this.barrier({ id, x, z, hx: 0.5, hz: 2.3, hp: 230 + Math.min(this.index, 24) * 110, maxHp: 230 + Math.min(this.index, 24) * 110, kind: 'shelter', open: false });
      this.sign('CIVILIAN SHELTER', x - Math.sign(x) * 0.55, 4.5, z, 7, 1.2, -Math.sign(x) * Math.PI / 2, Pal.neonYellow);
      this.sign('BREAK IN', x - Math.sign(x) * 0.58, 3.25, z, 3.5, 0.6, -Math.sign(x) * Math.PI / 2, Pal.cream);
    }
  }

  private barrier(barrier: Barrier): void {
    this.data.barriers.push(barrier);
    const root = new THREE.Group(); root.position.set(barrier.x, 0, barrier.z);
    if (barrier.kind === 'shelter') root.rotation.y = Math.PI / 2;
    const width = barrier.kind === 'shelter' ? barrier.hz * 2 : barrier.hx * 2;
    const depth = (barrier.kind === 'shelter' ? barrier.hx : barrier.hz) * 2;
    const height = barrier.kind === 'gate' ? 3.5 : barrier.kind === 'shelter' ? 2.7 : 1.6;
    const material = new THREE.MeshStandardMaterial({ color: barrier.kind === 'wood' ? 0x997348 : 0x456c71, roughness: 0.8 });
    const slats: THREE.Mesh[] = [];
    for (let x = -width / 2 + 0.35; x <= width / 2 - 0.35; x += 0.85) {
      const slat = new THREE.Mesh(new THREE.BoxGeometry(0.7, height, depth), material); slat.position.set(x, height / 2, 0); slat.castShadow = true; root.add(slat); slats.push(slat);
    }
    for (const y of [0.4, height - 0.25]) {
      const rail = new THREE.Mesh(new THREE.BoxGeometry(width, 0.22, depth), new THREE.MeshStandardMaterial({ color: Pal.mustard })); rail.position.y = y; root.add(rail); slats.push(rail);
    }
    const lamp = new THREE.Mesh(new THREE.BoxGeometry(width * 0.48, 0.12, 0.045), new THREE.MeshBasicMaterial({ color: Pal.neonRed })); lamp.position.set(0, height + 0.16, depth / 2 + 0.03); root.add(lamp);
    this.root.add(root); this.barrierViews.set(barrier.id, { root, slats, lamp });
  }

  private marker(text: string, x: number, z: number, color: number): THREE.Group {
    const group = new THREE.Group(); group.position.set(x, 0.05, z);
    const ring = new THREE.Mesh(new THREE.RingGeometry(2.7, 2.85, 48), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.75, side: THREE.DoubleSide })); ring.rotation.x = -Math.PI / 2; group.add(ring);
    for (let i = 0; i < 3; i++) {
      const arrow = new THREE.Mesh(new THREE.ConeGeometry(0.55, 0.75, 3), new THREE.MeshBasicMaterial({ color })); arrow.rotation.x = -Math.PI / 2; arrow.position.set(0, 0.12, 1.2 - i); group.add(arrow);
    }
    const label = this.sign(text, x, 2.2, z, 5, 0.7, 0, color); label.removeFromParent(); group.add(label); label.position.set(0, 2.2, 0);
    return group;
  }

  private flush(): void {
    const geometries: Record<Shape, THREE.BufferGeometry> = { box: new THREE.BoxGeometry(1, 1, 1), round: new THREE.IcosahedronGeometry(0.5, 1), pole: new THREE.CylinderGeometry(1, 1, 1, 7), glow: new THREE.BoxGeometry(1, 1, 1) };
    const color = new THREE.Color();
    for (const shape of Object.keys(this.pieces) as Shape[]) {
      const pieces = this.pieces[shape];
      const mesh = new THREE.InstancedMesh(geometries[shape], shape === 'glow' ? new THREE.MeshBasicMaterial({ color: 0xffffff }) : new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.85, flatShading: true }), pieces.length);
      for (let i = 0; i < pieces.length; i++) { mesh.setMatrixAt(i, pieces[i].matrix); mesh.setColorAt(i, color.setHex(pieces[i].color)); }
      mesh.castShadow = shape !== 'glow'; mesh.receiveShadow = shape !== 'glow'; mesh.computeBoundingSphere(); this.root.add(mesh);
      pieces.length = 0;
    }
  }

  private createWeather(): void {
    const weather = this.data.weather;
    // Clear autumn sectors still shed leaves; other clear sectors need no particle pool.
    if (weather === 0 && biomeSeasons[this.data.biome] !== 2) return;
    const mode = weather === 0 ? 6 : weather;
    const count = mode === 1 ? 1400 : mode === 2 ? 1000 : mode === 4 ? 96 : 520;
    const positions = new Float32Array(count * 3), phases = new Float32Array(count);
    for (let i = 0; i < count; i++) {
      positions[i * 3] = (this.rand() - 0.5) * 58;
      positions[i * 3 + 1] = this.rand() * 18;
      positions[i * 3 + 2] = (this.rand() - 0.5) * 118;
      phases[i] = this.rand();
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.setAttribute('phase', new THREE.BufferAttribute(phases, 1));
    this.weatherMaterial = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, toneMapped: false,
      uniforms: { time: { value: 0 }, mode: { value: mode }, tint: { value: new THREE.Color(mode === 1 ? 0xb8d8e8 : mode === 2 ? 0xeffaff : mode === 3 ? 0xe8c985 : mode === 4 ? 0xb2c2c1 : mode === 5 ? 0xc99b80 : 0xcf883c) } },
      vertexShader: `
        attribute float phase;
        uniform float time;
        uniform float mode;
        varying float vPhase;
        void main() {
          vPhase = phase;
          vec3 p = position;
          float speed = mode == 1.0 ? 19.0 : mode == 2.0 ? 2.0 : mode == 5.0 ? 0.8 : 0.5;
          p.y = mod(p.y - time * speed * (0.75 + phase * 0.5), 18.0) + 0.2;
          p.x = mod(p.x + 29.0 + time * (mode == 1.0 ? 2.7 : 1.3), 58.0) - 29.0;
          if (mode != 1.0) p.x += sin(time * 0.9 + phase * 30.0) * 0.8;
          if (mode == 3.0 || mode == 4.0) p.y = 0.5 + position.y * 0.15 + sin(time * 0.4 + phase * 20.0) * 0.3;
          vec4 mv = modelViewMatrix * vec4(p, 1.0);
          float size = mode == 1.0 ? 0.65 : mode == 2.0 ? 0.17 : mode == 4.0 ? 8.0 : mode == 3.0 ? 1.5 : 0.18;
          gl_PointSize = clamp(size * 650.0 / max(1.0, -mv.z), 1.0, 160.0);
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: `
        uniform float time;
        uniform float mode;
        uniform vec3 tint;
        varying float vPhase;
        void main() {
          vec2 uv = gl_PointCoord - 0.5;
          if (mode == 1.0) uv.x = uv.x * 8.0 + uv.y * 0.8;
          float radius = length(uv);
          float alpha = 1.0 - smoothstep(0.08, 0.5, radius);
          alpha *= mode == 4.0 ? 0.045 : mode == 3.0 ? 0.075 : mode == 1.0 ? 0.38 : 0.72;
          if (mode == 3.0) alpha *= 0.5 + 0.5 * sin(time * 2.0 + vPhase * 30.0);
          if (alpha < 0.005) discard;
          gl_FragColor = vec4(tint, alpha);
        }`,
    });
    const particles = new THREE.Points(geometry, this.weatherMaterial);
    particles.frustumCulled = false;
    this.root.add(particles);
  }

  update(time: number, ready: boolean): void {
    if (this.weatherMaterial) this.weatherMaterial.uniforms.time.value = time;
    this.exitMarker.visible = ready;
    this.exitMarker.position.y = 0.06 + Math.sin(time * 3) * 0.025;
    for (const barrier of this.data.barriers) {
      const view = this.barrierViews.get(barrier.id)!;
      const damage = 1 - Math.max(0, barrier.hp / barrier.maxHp);
      view.lamp.scale.x = Math.max(0.02, 1 - damage);
      (view.lamp.material as THREE.MeshBasicMaterial).color.setHex(barrier.open ? Pal.neonTurquoise : Pal.neonRed);
      for (let i = 0; i < view.slats.length; i++) {
        const slat = view.slats[i];
        slat.rotation.z = barrier.open || barrier.hp <= 0 ? (i % 2 ? -1 : 1) * 1.35 : Math.sin(i * 7) * damage * 0.17;
        slat.scale.y = barrier.open || barrier.hp <= 0 ? 0.12 : 1 - damage * (i % 3 === 0 ? 0.3 : 0);
        if (barrier.open || barrier.hp <= 0) slat.position.y = 0.12;
      }
    }
  }

  dispose(): void {
    this.root.removeFromParent();
    const geometries = new Set<THREE.BufferGeometry>(); const materials = new Set<THREE.Material>();
    this.root.traverse(object => { if (object instanceof THREE.Mesh || object instanceof THREE.Points) { geometries.add(object.geometry); for (const material of Array.isArray(object.material) ? object.material : [object.material]) materials.add(material); if (object instanceof THREE.InstancedMesh) object.dispose(); } });
    for (const g of geometries) g.dispose(); for (const m of materials) m.dispose(); for (const t of this.textures) t.dispose();
    this.weatherMaterial = undefined; this.textures.length = 0; this.barrierViews.clear(); this.obstacles.length = 0; this.root.clear();
  }
}
