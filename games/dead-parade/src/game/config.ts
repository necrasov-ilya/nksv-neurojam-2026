// Central tuning knobs. Values chosen for a 10–18 min run.

export const WORLD = {
  width: 170,
  depth: 300,
  sidewalk: 3.2,
  roadW: 9,
};

export const LEADER = {
  hpMax: 130,
  speed: 6.4,
  sprintMul: 1.55,
  accel: 26,
  turnRate: 14,
  dashSpeed: 22,
  dashTime: 0.22,
  dashCooldown: 2.6,
  biteRange: 2.4,
  biteCone: (100 * Math.PI) / 180,
  biteCooldown: 0.75,
  biteDamage: 60,
  biteLockTime: 0.3,
  iFrames: 0.55,
};

export const HORDE = {
  startCount: 5,
  radius: 0.42,
  separation: 4.2,
  followDist: 2.6,
  catchup: 1.35,
  nearFrame: 1,
  midFrame: 3,
  farFrame: 8,
  nearDist: 40,
  midDist: 95,
  surgeTime: 4.0,
  surgeCooldown: 15,
  surgeSpeedBonus: 1.5,
};

export const XP = {
  infect: 12,
  civKill: 4,
  guardKill: 18,
  barricade: 20,
  shelter: 90,
  district: 120,
  levelBase: 60,
  levelGrowth: 1.32,
};

export const LOOT = {
  magnetRadius: 9,
  magnetSpeed: 16,
  life: 26,
};

export const SURGE = {
  radius: 26,
  markerDist: 17,
};

export const BOMB = {
  radius: 5.2,
  damage: 70,
  fuse: 2.0,
};

export const TOXIC = {
  cloudR: 4.6,
  dps: 26,
  life: 6,
};

export const INFECTION = {
  riseDelay: 1.3,
  biteChance: 1.0,
  meleeChance: 1.0,
  toxicChance: 0.8,
  explosionChance: 0.35,
  envChance: 0.2,
};

export const HUMANS = {
  panicRadius: 17,
  fleeSpeed: 4.4,
  athleteSpeed: 6.4,
  heavySpeed: 1.9,
};

export const ENEMIES = {
  fireRange: 26,
  fireSpread: 0.11,
  aimLead: 0.45,
  repositionDist: 12,
  panicAcc: 0.35,
};

export const COLORS = {
  sky: 0x0d1420,
  fog: 0x0f1a24,
  ground: 0x23262b,
  road: 0x2b2e33,
  sidewalk: 0x4b4a44,
  tox: 0x9ecb3b,
  tox2: 0x5d8f1f,
  amber: 0xffb347,
  red: 0xe5484d,
  cream: 0xefe6c8,
  teal: 0x3f8f8b,
  mustard: 0xc7a23a,
  petrol: 0x2f5d52,
  brick: 0x6e4a3a,
  skin: 0xd8a37a,
  zombieSkin: 0x7f9e4a,
  zombieCloth: 0x4a5238,
  runnerSkin: 0xa8c25e,
  bruteSkin: 0x5f7d33,
  bomberSkin: 0x9ee34a,
  spitterSkin: 0x86b73e,
  guard: 0x3e5570,
  rifle: 0x55635a,
  shotgun: 0x7a5230,
  grenadier: 0x5f6f3a,
  riot: 0x46586e,
  heavy: 0x3d4a3a,
  civ: 0xb0897a,
  athlete: 0xd86a4a,
  heavyCiv: 0x8a6a4a,
  worker: 0xc7a23a,
  medic: 0xe0e0e0,
};
