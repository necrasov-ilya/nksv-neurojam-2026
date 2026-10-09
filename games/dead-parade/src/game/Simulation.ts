import type { Actor, ActorKind, Barrier, Box, Cloud, Controls, Effect, Projectile, Snapshot, Zone } from '../core/model';
import { SpatialGrid } from '../utils/spatial';
import { clamp, dampAngle } from '../utils/math';
import { LEADER, HORDE, XP, INFECTION, BOMB, TOXIC, HUMANS } from './config';
import { districtDef, type DistrictDef } from './districts';
import { baseModifiers, UPGRADES, type Modifiers } from './upgrades';

const ZOMBIES: ActorKind[] = ['walker', 'runner', 'brute', 'spitter', 'bomber'];
type EnemyKind = 'guard' | 'rifleman' | 'shotgunner' | 'grenadier' | 'riot' | 'heavy' | 'flamer' | 'sniper' | 'drone' | 'sapper';
type RosterKey = 'guards' | 'riflemen' | 'shotgunners' | 'grenadiers' | 'riot' | 'heavies' | 'flamers' | 'snipers' | 'drones' | 'sappers';
const ENEMY_ROSTER: Record<EnemyKind, RosterKey> = { guard: 'guards', rifleman: 'riflemen', shotgunner: 'shotgunners', grenadier: 'grenadiers', riot: 'riot', heavy: 'heavies', flamer: 'flamers', sniper: 'snipers', drone: 'drones', sapper: 'sappers' };
const ENEMIES = Object.keys(ENEMY_ROSTER) as EnemyKind[];
const MAX_ESCORT = 300;
const ABILITIES = ['feral', 'behemoth', 'toxic', 'mortar'];
const STEP = 1 / 60;
interface Unit extends Actor {
  r: number;
  team: number;
  origin: ActorKind;
  ai: number;
  invulnerable: number;
  burst: number;
  wander: number;
}
interface Gun { hp: number; ammo: number; reload: number; rate: number; range: number; damage: number; spread: number; }
const GUNS: Record<string, Gun> = {
  guard: { hp: 85, ammo: 9, reload: 2.1, rate: .85, range: 21, damage: 8, spread: .12 },
  rifleman: { hp: 115, ammo: 18, reload: 2.6, rate: .16, range: 29, damage: 7, spread: .055 },
  shotgunner: { hp: 155, ammo: 5, reload: 3, rate: 1.5, range: 16, damage: 6, spread: .2 },
  grenadier: { hp: 130, ammo: 3, reload: 4.4, rate: 4.6, range: 28, damage: 42, spread: .12 },
  riot: { hp: 240, ammo: 8, reload: 2.5, rate: 1.05, range: 16, damage: 8, spread: .13 },
  heavy: { hp: 380, ammo: 42, reload: 4, rate: .12, range: 31, damage: 6, spread: .15 },
  flamer: { hp: 170, ammo: 26, reload: 3.6, rate: .34, range: 12, damage: 7, spread: .3 },
  sniper: { hp: 95, ammo: 4, reload: 3.2, rate: 2.6, range: 44, damage: 34, spread: .02 },
  drone: { hp: 55, ammo: 14, reload: 2.8, rate: .5, range: 24, damage: 5, spread: .16 },
  sapper: { hp: 120, ammo: 2, reload: 5, rate: 2.2, range: 30, damage: 30, spread: .06 },
};

/** Fixed-step combat with pooled entities and bounded local spatial queries. */
export class Simulation {
  snapshot!: Snapshot;
  private units: Unit[] = [];
  private pool: Unit[] = [];
  private allies = new SpatialGrid<Unit>(6);
  private humans = new SpatialGrid<Unit>(6);
  private near: Unit[] = [];
  private neighbors: Unit[] = [];
  private blastTargets: Unit[] = [];
  private shotTargets: Unit[] = [];
  private nextId = 1;
  private seed = 1;
  private accumulator = 0;
  private frame = 0;
  private dashTime = 0;
  private dashX = 0;
  private dashZ = -1;
  private surgeX = 0;
  private surgeZ = -1;
  private selected = 'toxic';
  private downTime = 0;
  private zoneInfected = 0;
  private potential = 1;
  private unrecoverable = 0;
  private waves = 0;
  private waveClock = 0;
  private reserveCivilians = 0;
  private reserveEnemies: ActorKind[] = [];
  private shelterPopulation = 0;
  private definition: DistrictDef = districtDef(0);
  private enemyHpScale = 1;

  private endless = false;

  constructor(private zoneFactory: (index: number) => Zone, endless = false) {
    this.endless = endless;
    this.reset(baseModifiers());
  }

  reset(mods: Modifiers): void {
    this.pool.push(...this.units);
    this.units = [];
    this.nextId = 1;
    this.seed = 1337;
    this.accumulator = this.frame = this.dashTime = this.downTime = 0;
    this.selected = 'toxic';
    const zone = this.zoneFactory(0);
    const leader = this.create('leader', zone.spawn.x, zone.spawn.z, mods);
    const startMutation = (mods as Modifiers & { startMutation?: string }).startMutation;
    this.snapshot = {
      actors: this.units, zone, leader, projectiles: [], clouds: [], mods: { ...mods },
      stats: { runTime: 0, totalInfected: 0, peakHorde: 5, humansDefeated: 0, sheltersOverrun: 0, zombiesLost: 0, levelReached: 1 },
      time: 0, district: 0, infection: 0, objective: '', readyExit: false,
      xp: 0, xpNext: XP.levelBase, level: 1, mutation: startMutation && ABILITIES.includes(startMutation.toLowerCase()) ? startMutation.toLowerCase() : '',
      mutationTime: startMutation ? 20 * mods.mutationDur : 0,
      surgeCooldown: 0, surgeTime: 0, dashCooldown: 0, abilityCooldown: 0,
      hordeCounts: [5, 0, 0, 0, 0], effects: [], notices: [], pendingLevel: false, won: false, lost: false, upgrades: [],
      endless: undefined,
    };
    for (let i = 0; i < HORDE.startCount; i++) this.spawn('walker', leader.x + (i - 2) * 1.15, leader.z + 2.4);
    this.populate();
    this.rebuildGrids();
    this.objective();
  }

  update(dt: number, input: Controls): void {
    const s = this.snapshot;
    if (s.won || s.lost || s.pendingLevel) return;
    if (input.select >= 1 && input.select <= 4) {
      this.selected = ABILITIES[input.select - 1];
      this.notice(`${this.selected.toUpperCase()} selected · E to unleash`);
    }
    const leader = s.leader as Unit;
    const x = input.x * Math.cos(input.yaw) - input.z * Math.sin(input.yaw);
    const z = -input.x * Math.sin(input.yaw) - input.z * Math.cos(input.yaw);
    if (leader.hp > 0) {
      if (input.dash && s.dashCooldown <= 0) {
        const length = Math.hypot(x, z);
        this.dashX = length > .01 ? x / length : Math.sin(leader.angle);
        this.dashZ = length > .01 ? z / length : Math.cos(leader.angle);
        this.dashTime = LEADER.dashTime;
        s.dashCooldown = LEADER.dashCooldown * s.mods.dashCd;
        leader.invulnerable = LEADER.iFrames;
      }
      if (input.surge && s.surgeCooldown <= 0) {
        s.surgeTime = HORDE.surgeTime * s.mods.surgeDur;
        s.surgeCooldown = HORDE.surgeCooldown * s.mods.surgeCd;
        this.surgeX = leader.x + Math.sin(leader.angle) * 22;
        this.surgeZ = leader.z + Math.cos(leader.angle) * 22;
        this.emit('surge', leader.x, leader.z);
        this.notice('DEAD PARADE! Horde surging toward your facing.');
      }
      if (input.ability && s.abilityCooldown <= 0) this.ability();
    }
    this.accumulator += clamp(dt, 0, .2);
    while (this.accumulator >= STEP && !s.pendingLevel && !s.won && !s.lost) {
      this.accumulator -= STEP;
      this.step(STEP, x, z, input.sprint);
    }
    if (s.pendingLevel) this.accumulator = 0;
  }

  chooseUpgrade(id: string): void {
    const s = this.snapshot;
    if (!s.pendingLevel) return;
    const upgrade = UPGRADES.find(item => item.id === id);
    if (!upgrade || s.upgrades.reduce((count, owned) => count + Number(owned === id), 0) >= upgrade.maxRank) return;
    const oldLeaderHp = s.mods.leaderHp, oldHordeHp = s.mods.hordeHp;
    upgrade.apply(s.mods);
    s.upgrades.push(id);
    for (const a of this.units) {
      if (a.team !== 0 || a.hp <= 0) continue;
      const ratio = a.kind === 'leader' ? s.mods.leaderHp / oldLeaderHp : s.mods.hordeHp / oldHordeHp;
      a.maxHp *= ratio;
      a.hp = Math.min(a.maxHp, a.hp * ratio + (a.kind === 'leader' ? 12 : 0));
    }
    s.pendingLevel = false;
    this.checkLevel();
  }

  private random(): number {
    this.seed = (Math.imul(this.seed, 1664525) + 1013904223) | 0;
    return (this.seed >>> 0) / 4294967296;
  }

  private create(kind: ActorKind, x: number, z: number, mods = this.snapshot.mods): Unit {
    const a = this.pool.pop() ?? {} as Unit;
    const zombie = ZOMBIES.includes(kind);
    const hp = kind === 'leader' ? LEADER.hpMax * mods.leaderHp : zombie ? (kind === 'brute' ? 240 : kind === 'runner' ? 62 : kind === 'walker' ? 78 : 92) * mods.hordeHp : GUNS[kind] ? Math.round(GUNS[kind].hp * this.enemyHpScale) : kind === 'heavyCivilian' ? 100 : 45;
    Object.assign(a, { id: this.nextId++, kind, x, z, y: 0, angle: Math.PI, hp, maxHp: hp, state: 'idle', anim: this.random() * 6,
      attack: 0, infected: false, timer: 0, vx: 0, vz: 0, cooldown: this.random() * .5, ammo: GUNS[kind]?.ammo ?? 0,
      heal: kind === 'medic', r: kind === 'brute' || kind === 'heavy' ? .65 : .38,
      team: zombie || kind === 'leader' ? 0 : 1, origin: kind, ai: 0, invulnerable: 0, burst: 0, wander: this.random() * Math.PI * 2 });
    this.units.push(a);
    return a;
  }

  private spawn(kind: ActorKind, x: number, z: number): Unit {
    const radius = kind === 'brute' || kind === 'heavy' ? .65 : .4;
    x = clamp(x, -36, 36); z = clamp(z, -52, 52);
    if (this.blocked(x, z, radius)) {
      const sx = x, sz = z;
      let found = false;
      for (let ring = 1; ring < 30 && !found; ring++) {
        for (let n = 0; n < 12; n++) {
          const angle = n * Math.PI / 6;
          const nx = clamp(sx + Math.cos(angle) * ring * .8, -36, 36);
          const nz = clamp(sz + Math.sin(angle) * ring * .8, -52, 52);
          if (!this.blocked(nx, nz, radius)) { x = nx; z = nz; found = true; break; }
        }
      }
      if (!found) { x = this.snapshot.zone.spawn.x; z = this.snapshot.zone.spawn.z; }
    }
    return this.create(kind, x, z);
  }

  private civilianKind(): ActorKind {
    const r = this.random();
    return r < .13 ? 'athlete' : r < .24 ? 'heavyCivilian' : r < .38 ? 'worker' : r < .46 ? 'medic' : 'civilian';
  }

  private populate(): void {
    const s = this.snapshot, def = this.definition = districtDef(s.district);
    this.enemyHpScale = def.hpScale * (def.elite ? 1.15 : 1);
    this.waveClock = 0;
    this.seed = def.seed;
    this.zoneInfected = this.unrecoverable = this.waves = 0;
    this.shelterPopulation = 18 + Math.min(12, s.district) * 4;
    this.reserveCivilians = 24 + Math.min(12, s.district) * 6;
    this.reserveEnemies.length = 0;
    const roster: ActorKind[] = [];
    for (const kind of ENEMIES) {
      const count = def[ENEMY_ROSTER[kind]];
      for (let i = 0; i < count; i++) roster.push(kind);
    }
    for (let i = roster.length - 1; i > 0; i--) { const j = Math.floor(this.random() * (i + 1)); [roster[i], roster[j]] = [roster[j], roster[i]]; }
    for (const kind of roster) {
      if (this.random() < .34) this.reserveEnemies.push(kind);
      else this.spawn(kind, (this.random() - .5) * 16, -7 - this.random() * 33);
    }
    this.potential = def.civs + this.reserveCivilians + s.zone.shelters.length * this.shelterPopulation + roster.length;
    for (let i = 0; i < def.civs; i++) {
      const z = i < 6 ? s.zone.spawn.z - 7 - this.random() * 6 : 33 - this.random() * 72;
      this.spawn(this.civilianKind(), (this.random() - .5) * (i < 6 ? 8 : 29), z);
    }
    s.readyExit = false;
    s.infection = 0;
    s.endless = s.district >= 5 ? { sector: s.district + 1, tier: 1 + Math.floor((s.district - 5) / 10), elite: def.elite } : undefined;
    this.notice(`${def.name} · ${def.note}`);
  }

  private step(dt: number, moveX: number, moveZ: number, sprint: boolean): void {
    const s = this.snapshot, leader = s.leader as Unit;
    s.time += dt; s.stats.runTime += dt; this.frame++;
    s.surgeCooldown = Math.max(0, s.surgeCooldown - dt);
    s.surgeTime = Math.max(0, s.surgeTime - dt);
    s.dashCooldown = Math.max(0, s.dashCooldown - dt);
    s.abilityCooldown = Math.max(0, s.abilityCooldown - dt);
    if (s.mutationTime > 0) {
      s.mutationTime = Math.max(0, s.mutationTime - dt);
      if (!s.mutationTime) { s.mutation = ''; this.notice('Mutation faded. Hunt another special civilian.'); }
    }
    this.rebuildGrids();
    if (leader.hp > 0) this.player(dt, moveX, moveZ, sprint);
    else { this.downTime += dt; if (this.downTime >= 2.2) s.lost = true; }
    for (let i = this.units.length - 1; i >= 0; i--) {
      const a = this.units[i];
      a.anim += dt * (1 + Math.hypot(a.vx, a.vz) * .38);
      a.attack = Math.max(0, a.attack - dt);
      a.cooldown = Math.max(0, a.cooldown - dt);
      a.invulnerable = Math.max(0, a.invulnerable - dt);
      if (a.kind === 'leader') continue;
      if (a.state === 'infected') {
        a.timer -= dt;
        if (a.timer <= 0) this.rise(a);
        continue;
      }
      if (a.hp <= 0) {
        a.timer -= dt;
        if (a.timer <= 0) { this.units.splice(i, 1); this.pool.push(a); }
        continue;
      }
      const distance = Math.hypot(a.x - leader.x, a.z - leader.z);
      const cadence = distance < 32 ? 1 : distance < 65 ? 3 : 8;
      a.ai += dt;
      if ((this.frame + a.id) % cadence !== 0) continue;
      const elapsed = a.ai; a.ai = 0;
      if (a.team === 0) this.zombie(a, elapsed, distance);
      else if (GUNS[a.kind]) this.enemy(a, elapsed);
      else this.civilian(a, elapsed);
    }
    this.projectiles(dt);
    this.clouds(dt);
    this.director(dt);
    this.countHorde();
    this.objective();
    if (leader.hp > 0 && s.readyExit && Math.hypot(leader.x - s.zone.exit.x, leader.z - s.zone.exit.z) < 4.5) this.advance();
  }

  private rebuildGrids(): void {
    this.allies.clear(); this.humans.clear();
    for (const a of this.units) if (a.hp > 0 && a.state !== 'infected') (a.team === 0 ? this.allies : this.humans).insert(a);
  }

  private player(dt: number, x: number, z: number, sprint: boolean): void {
    const s = this.snapshot, a = s.leader as Unit;
    const length = Math.hypot(x, z);
    if (length > 1) { x /= length; z /= length; }
    if (length > .01) a.angle = dampAngle(a.angle, Math.atan2(x, z), LEADER.turnRate, dt);
    const speed = LEADER.speed * s.mods.leaderSpeed * (sprint ? LEADER.sprintMul : 1) * (s.mutation === 'feral' ? 1.22 : s.mutation === 'behemoth' ? .85 : 1);
    const blend = 1 - Math.exp(-LEADER.accel * dt / 4);
    a.vx += (x * speed - a.vx) * blend; a.vz += (z * speed - a.vz) * blend;
    if (this.dashTime > 0) {
      this.dashTime -= dt;
      this.move(a, this.dashX * LEADER.dashSpeed * dt, this.dashZ * LEADER.dashSpeed * dt, false);
      a.state = 'dash';
    } else { this.move(a, a.vx * dt, a.vz * dt, false); a.state = length > .01 ? 'run' : 'idle'; }
    if (a.cooldown > 0) return;
    this.humans.query(a.x, a.z, LEADER.biteRange, this.near);
    let target: Unit | null = null, closest = Infinity;
    const fx = Math.sin(a.angle), fz = Math.cos(a.angle);
    for (const other of this.near) {
      const dx = other.x - a.x, dz = other.z - a.z, d = Math.hypot(dx, dz);
      if (other.hp <= 0 || d > LEADER.biteRange + other.r || (d > .65 && (dx * fx + dz * fz) / d < Math.cos(LEADER.biteCone / 2)) || !this.los(a.x, a.z, other.x, other.z)) continue;
      if (d < closest) { target = other; closest = d; }
    }
    if (target) {
      a.cooldown = LEADER.biteCooldown / s.mods.biteSpeed;
      a.attack = .32;
      this.damage(target, LEADER.biteDamage * s.mods.biteDmg * (s.mutation === 'behemoth' ? 1.6 : 1), 'melee', a);
      this.emit('bite', target.x, target.z);
    } else {
      const b = this.nearestBarrier(a.x, a.z, 2.5, fx, fz);
      if (b) { this.hitBarrier(b, LEADER.biteDamage * s.mods.biteDmg * (s.mutation === 'behemoth' ? 2.4 : 1)); a.attack = .3; a.cooldown = LEADER.biteCooldown / s.mods.biteSpeed; }
    }
  }

  private zombie(a: Unit, dt: number, distance: number): void {
    const s = this.snapshot, leader = s.leader;
    a.hp = Math.min(a.maxHp, a.hp + s.mods.hordeRegen * dt);
    const range = (a.kind === 'spitter' ? 18 * s.mods.spitterRange : 13) * s.mods.aggroRange;
    this.humans.query(a.x, a.z, range, this.near);
    let target: Unit | null = null, best = Infinity;
    for (const candidate of this.near) {
      if (candidate.hp <= 0 || candidate.state === 'infected') continue;
      const d = (candidate.x - a.x) ** 2 + (candidate.z - a.z) ** 2;
      if (d < best && this.los(a.x, a.z, candidate.x, candidate.z)) { target = candidate; best = d; }
    }
    let tx: number, tz: number;
    if (target) {
      tx = target.x; tz = target.z;
      const d = Math.sqrt(best);
      a.angle = dampAngle(a.angle, Math.atan2(tx - a.x, tz - a.z), 12, dt);
      if (a.kind === 'spitter' && d < 18 * s.mods.spitterRange && a.cooldown <= 0) {
        this.throwProjectile('acid', a.x, a.z, tx, tz, true, Math.max(.35, d / 19), 2.3);
        a.cooldown = 2.2; a.attack = .4;
      }
      if (d < (a.kind === 'brute' ? 2.05 : 1.45) && a.cooldown <= 0) {
        a.attack = .35;
        a.cooldown = a.kind === 'runner' ? .52 : a.kind === 'brute' ? 1.2 : .92;
        if (a.kind === 'bomber') { this.explode(a.x, a.z, 5 * s.mods.bomberRadius, 105 * s.mods.hordeDmg, true); this.killZombie(a); return; }
        this.damage(target, (a.kind === 'brute' ? 46 : a.kind === 'runner' ? 16 : 22) * s.mods.hordeDmg, 'melee', a);
        this.emit('bite', target.x, target.z);
      }
      if (d < (a.kind === 'spitter' ? 8 : 1.15)) { a.vx = a.vz = 0; a.state = 'attack'; return; }
    } else {
      const spread = Math.sqrt(Math.min(s.stats.peakHorde, 350)) * .53;
      const angle = a.id * 2.399963;
      const ring = 1.8 + (a.id % 11) / 10 * spread;
      tx = s.surgeTime > 0 ? this.surgeX : leader.x + Math.sin(angle) * ring;
      tz = s.surgeTime > 0 ? this.surgeZ : leader.z + Math.cos(angle) * ring;
      if (Math.hypot(tx - a.x, tz - a.z) < .9) { a.vx = a.vz = 0; a.state = 'idle'; return; }
      const b = this.nearestBarrier(a.x, a.z, a.kind === 'brute' ? 2.6 : 1.9);
      if (b && a.cooldown <= 0) {
        this.hitBarrier(b, (a.kind === 'brute' ? 105 : 19) * s.mods.hordeDmg);
        a.attack = .3; a.cooldown = a.kind === 'brute' ? .85 : 1.1;
      }
    }
    let dx = tx - a.x, dz = tz - a.z, length = Math.hypot(dx, dz) || 1;
    dx /= length; dz /= length;
    this.allies.query(a.x, a.z, 1.15, this.neighbors);
    let considered = 0;
    for (const other of this.neighbors) {
      if (other === a || other.hp <= 0) continue;
      const ox = a.x - other.x, oz = a.z - other.z, d2 = ox * ox + oz * oz;
      if (d2 > .001 && d2 < 1.8) { const pressure = .4 / Math.max(.16, d2); dx += ox * pressure; dz += oz * pressure; }
      if (++considered >= 14) break;
    }
    length = Math.hypot(dx, dz) || 1; dx /= length; dz /= length;
    const base = a.kind === 'runner' ? 8.1 : a.kind === 'brute' ? 3.65 : a.kind === 'spitter' ? 4.4 : 4.85;
    const speed = base * s.mods.hordeSpeed * (distance > 18 ? 1.5 : 1) * (s.surgeTime > 0 ? 1.6 : 1);
    a.vx = dx * speed; a.vz = dz * speed;
    this.move(a, a.vx * dt, a.vz * dt, true);
    a.angle = dampAngle(a.angle, Math.atan2(dx, dz), 9, dt);
    a.state = 'run';
  }

  private civilian(a: Unit, dt: number): void {
    const threat = this.allies.nearest(a.x, a.z, HUMANS.panicRadius, this.near);
    let dx = Math.sin(a.wander), dz = Math.cos(a.wander), speed = .65;
    if (threat) {
      dx = a.x - threat.x; dz = a.z - threat.z;
      // A lateral escape lane prevents civilians simply running into the final gate forever.
      if (Math.abs(a.z) > 44) { dz += -Math.sign(a.z) * 10; dx += Math.sin(a.wander) * 4; }
      if (Math.abs(a.x) > 29) dx -= Math.sign(a.x) * 8;
      speed = a.kind === 'athlete' ? HUMANS.athleteSpeed : a.kind === 'heavyCivilian' ? HUMANS.heavySpeed : HUMANS.fleeSpeed;
      a.state = 'panic';
    } else { a.wander += (this.random() - .5) * dt; a.state = 'walk'; }
    const length = Math.hypot(dx, dz) || 1;
    a.vx = dx / length * speed; a.vz = dz / length * speed;
    this.move(a, a.vx * dt, a.vz * dt, true);
    a.angle = dampAngle(a.angle, Math.atan2(dx, dz), 10, dt);
    if (a.kind === 'medic' && a.cooldown <= 0) {
      this.humans.query(a.x, a.z, 6, this.neighbors);
      for (const friend of this.neighbors) if (friend.hp > 0 && friend.hp < friend.maxHp) friend.hp = Math.min(friend.maxHp, friend.hp + 5);
      a.cooldown = 2;
    }
  }

  private enemy(a: Unit, dt: number): void {
    const gun = GUNS[a.kind];
    if (a.kind === 'drone') a.y = .7 + Math.sin(this.snapshot.time * 3 + a.id) * .16;
    if (a.state === 'reload') {
      a.timer -= dt; a.vx = a.vz = 0;
      if (a.timer <= 0) { a.ammo = gun.ammo; a.state = 'idle'; }
      else return;
    }
    this.allies.query(a.x, a.z, gun.range + 5, this.near);
    let target: Unit | null = null, best = Infinity;
    for (const other of this.near) {
      if (other.hp <= 0) continue;
      const d2 = (a.x - other.x) ** 2 + (a.z - other.z) ** 2;
      if (d2 < best && this.los(a.x, a.z, other.x, other.z)) { target = other; best = d2; }
    }
    if (!target) { a.state = 'idle'; a.timer = 0; a.vx = a.vz = 0; return; }
    const dx = target.x - a.x, dz = target.z - a.z, distance = Math.sqrt(best) || .01;
    if (a.state === 'lock' || a.state === 'deploy') {
      a.vx = a.vz = 0; a.timer -= dt;
      if (a.timer > 0) return;
      if (a.state === 'lock') this.fire(a, target, gun, gun.spread, a.wander);
      else this.throwProjectile('mortar', a.x, a.z, a.wander, a.burst, false, 2.1, 4.2);
      a.ammo--; a.attack = .3; a.cooldown = gun.rate; a.state = 'aim';
      return;
    }
    a.angle = dampAngle(a.angle, Math.atan2(dx, dz), a.kind === 'riot' ? 3 : a.kind === 'flamer' ? 2.5 : 8, dt);
    const desired = a.kind === 'riot' ? 4 : a.kind === 'flamer' ? 7 : a.kind === 'shotgunner' ? 10 : a.kind === 'sniper' ? 32 : a.kind === 'sapper' ? 23 : 17;
    let velocity = distance < desired - 3 ? -1.7 : distance > gun.range - 2 ? 1.8 : 0;
    if (a.kind === 'heavy') velocity *= .55;
    a.vx = dx / distance * velocity; a.vz = dz / distance * velocity;
    if (a.kind === 'drone') {
      const strafe = Math.sin(this.snapshot.time * .8 + a.id) >= 0 ? 3.8 : -3.8;
      a.vx += dz / distance * strafe; a.vz -= dx / distance * strafe;
    }
    this.move(a, a.vx * dt, a.vz * dt, true);
    a.state = a.vx || a.vz ? 'run' : 'aim';
    if (distance > gun.range || a.cooldown > 0) return;
    if (a.ammo <= 0) { a.state = 'reload'; a.timer = gun.reload; a.burst = 0; return; }
    if (a.kind === 'sniper') {
      // Lock the bearing, not the victim: the bright sight line gives a dodge window.
      a.state = 'lock'; a.timer = 1.05; a.wander = Math.atan2(dx, dz); a.angle = a.wander;
      a.vx = a.vz = 0;
      return;
    }
    if (a.kind === 'sapper') {
      // Stationary setup followed by a visible, fixed-position artillery strike.
      a.state = 'deploy'; a.timer = .85; a.wander = target.x; a.burst = target.z;
      a.vx = a.vz = 0;
      return;
    }
    a.ammo--; a.attack = .15;
    if (a.kind === 'grenadier') {
      const tx = target.x + target.vx * .25, tz = target.z + target.vz * .25;
      const clusters = this.snapshot.district >= 3 ? 3 : 1;
      for (let k = 0; k < clusters; k++) this.throwProjectile('grenade', a.x, a.z, tx + (k - (clusters - 1) / 2) * 2.6, tz + (k % 2) * 2, false, BOMB.fuse, BOMB.radius);
    } else if (a.kind === 'flamer') {
      // Short, slow-turning cone burns every exposed zombie rather than one hitscan victim.
      const fx = Math.sin(a.angle), fz = Math.cos(a.angle);
      this.allies.query(a.x, a.z, gun.range, this.shotTargets);
      for (const victim of this.shotTargets) {
        const ox = victim.x - a.x, oz = victim.z - a.z, d = Math.hypot(ox, oz);
        if (victim.hp > 0 && d <= gun.range && ox * fx + oz * fz >= d * .88 && this.los(a.x, a.z, victim.x, victim.z)) this.damage(victim, gun.damage * (1 + 2 * this.snapshot.district / (this.snapshot.district + 24)), 'toxic', a);
      }
    } else {
      const pellets = a.kind === 'shotgunner' ? 6 : 1;
      for (let i = 0; i < pellets; i++) this.fire(a, target, gun, distance < 5 ? gun.spread * 1.8 : gun.spread);
    }
    a.cooldown = gun.rate;
    if (a.kind === 'rifleman' && ++a.burst >= 3) { a.burst = 0; a.cooldown = 1.2; }
    if (a.kind === 'heavy' && ++a.burst >= 12) { a.burst = 0; a.cooldown = 1.1; }
  }

  private fire(source: Unit, target: Unit, gun: Gun, spread: number, bearing = Math.atan2(target.x - source.x, target.z - source.z)): void {
    const angle = bearing + (this.random() + this.random() - 1) * spread;
    const dx = Math.sin(angle), dz = Math.cos(angle);
    let length = gun.range;
    for (const box of this.snapshot.zone.boxes) length = Math.min(length, this.rayBox(source.x, source.z, dx, dz, length, box));
    for (const b of this.snapshot.zone.barriers) if (!b.open) length = Math.min(length, this.rayBox(source.x, source.z, dx, dz, length, b));
    this.allies.query(source.x, source.z, length, this.shotTargets);
    let hit: Unit | null = null;
    for (const a of this.shotTargets) {
      if (a.hp <= 0) continue;
      const ox = a.x - source.x, oz = a.z - source.z, along = ox * dx + oz * dz;
      if (along < 0 || along > length) continue;
      const side = Math.abs(ox * dz - oz * dx);
      if (side < a.r + .22) { length = along; hit = a; }
    }
    this.emit('shot', source.x, source.z, source.x + dx * length, source.z + dz * length);
    if (hit) this.damage(hit, gun.damage * (1 + 2 * this.snapshot.district / (this.snapshot.district + 24)), 'bullet', source);
  }

  private ability(): void {
    const s = this.snapshot, a = s.leader as Unit;
    const kind = s.mutation || this.selected;
    const required = kind === 'feral' ? 1 : kind === 'behemoth' ? 2 : kind === 'mortar' ? 4 : -1;
    if (!s.mutation && required >= 0 && s.hordeCounts[required] === 0) {
      this.notice(`${kind.toUpperCase()} needs a living ${required === 1 ? 'runner' : required === 2 ? 'brute' : 'bomber'} in your horde. Use 3 for toxic.`);
      return;
    }
    const fx = Math.sin(a.angle), fz = Math.cos(a.angle);
    a.attack = .6;
    if (kind === 'feral') {
      this.dashX = fx; this.dashZ = fz; this.dashTime = .38;
      a.invulnerable = .8;
      this.humans.query(a.x + fx * 3.5, a.z + fz * 3.5, 6, this.near);
      for (const target of this.near) if (target.hp > 0 && this.los(a.x, a.z, target.x, target.z)) this.damage(target, 115 * s.mods.biteDmg, 'melee', a);
      this.emit('surge', a.x, a.z);
      s.abilityCooldown = 7;
    } else if (kind === 'behemoth') {
      this.humans.query(a.x, a.z, 7, this.near);
      for (const target of this.near) {
        const dx = target.x - a.x, dz = target.z - a.z;
        if (dx * fx + dz * fz > -.5 && this.los(a.x, a.z, target.x, target.z)) this.damage(target, 145 * s.mods.biteDmg, 'melee', a);
      }
      for (const b of s.zone.barriers) if (!b.open && Math.hypot(b.x - a.x, b.z - a.z) < 7 + Math.max(b.hx, b.hz) && (b.x - a.x) * fx + (b.z - a.z) * fz > -1) this.hitBarrier(b, 320);
      this.emit('explosion', a.x + fx * 2, a.z + fz * 2);
      s.abilityCooldown = 10;
    } else if (kind === 'mortar') {
      this.throwProjectile('mortar', a.x, a.z, a.x + fx * 18, a.z + fz * 18, true, 1.3, 7 * s.mods.bomberRadius);
      s.abilityCooldown = 11;
    } else {
      this.addCloud(a.x + fx * 3, a.z + fz * 3, TOXIC.cloudR, TOXIC.life);
      this.emit('acid', a.x, a.z);
      s.abilityCooldown = 10;
    }
    this.notice(`${kind.toUpperCase()} unleashed`);
  }

  private damage(a: Unit, amount: number, type: 'melee' | 'toxic' | 'explosion' | 'bullet', source?: Unit): void {
    if (a.hp <= 0 || a.state === 'infected' || a.invulnerable > 0) return;
    const s = this.snapshot;
    if (a.kind === 'riot' && source) {
      const dx = source.x - a.x, dz = source.z - a.z, d = Math.hypot(dx, dz) || 1;
      if ((dx * Math.sin(a.angle) + dz * Math.cos(a.angle)) / d > .2 && type !== 'toxic') amount *= .28;
    }
    if (a.kind === 'brute') amount *= Math.max(.25, 1 - s.mods.bruteArmor);
    if (a.kind === 'leader') {
      if (s.mutation === 'behemoth') amount *= .6;
      a.invulnerable = type === 'explosion' ? .45 : .2;
      if (s.mods.leaderThorns && source?.team === 1) this.damage(source, amount * s.mods.leaderThorns, 'melee', a);
    }
    a.hp = Math.max(0, a.hp - amount);
    this.emit('hit', a.x, a.z);
    if (a.hp > 0) return;
    a.vx = a.vz = 0;
    if (a.team === 0) {
      if (a.kind === 'leader') { a.state = 'down'; this.downTime = 0; this.notice('The alpha has fallen...'); }
      else {
        if (a.kind === 'bomber') this.explode(a.x, a.z, 5 * s.mods.bomberRadius, 95 * s.mods.hordeDmg, true);
        this.killZombie(a);
      }
      return;
    }
    s.stats.humansDefeated++;
    const chance = type === 'melee' ? 1 : type === 'toxic' ? INFECTION.toxicChance * s.mods.toxicInfect : type === 'explosion' ? INFECTION.explosionChance * s.mods.explodeInfect : 0;
    this.gainXp(GUNS[a.kind] ? XP.guardKill : XP.civKill);
    if (this.random() < chance) {
      a.infected = true; a.state = 'infected'; a.timer = INFECTION.riseDelay / s.mods.riseSpeed;
      this.zoneInfected++; s.stats.totalInfected++;
      this.gainXp(XP.infect);
      this.emit('infection', a.x, a.z);
      if (s.leader.hp > 0) s.leader.hp = Math.min(s.leader.maxHp, s.leader.hp + (a.kind === 'medic' ? 26 : 1.1));
      if (a.kind === 'medic') {
        this.allies.query(a.x, a.z, 13, this.neighbors);
        for (const ally of this.neighbors) if (ally.hp > 0) ally.hp = Math.min(ally.maxHp, ally.hp + 22);
        this.notice('MEDIC CAPTURED · Nearby horde healed');
      }
      if (a.kind === 'athlete' || a.kind === 'heavyCivilian') {
        s.mutation = a.kind === 'athlete' ? 'feral' : 'behemoth';
        s.mutationTime = 20 * s.mods.mutationDur;
        s.abilityCooldown = Math.min(2, s.abilityCooldown);
        this.notice(`${s.mutation.toUpperCase()} MUTATION · 20 seconds of borrowed power`);
      }
    } else { a.state = 'dead'; a.timer = 2.4; this.unrecoverable++; }
  }

  private rise(a: Unit): void {
    const m = this.snapshot.mods;
    const runner = .13 * m.runnerChance + (a.origin === 'athlete' ? .65 : 0);
    const brute = .09 * m.bruteChance + (a.origin === 'worker' || a.origin === 'heavyCivilian' ? .5 : 0);
    const bomber = .065 * m.bomberChance, spitter = .085 * m.spitterChance;
    const total = Math.max(1, runner + brute + bomber + spitter), r = this.random() * total;
    a.kind = r < runner ? 'runner' : r < runner + brute ? 'brute' : r < runner + brute + bomber ? 'bomber' : r < runner + brute + bomber + spitter ? 'spitter' : 'walker';
    a.maxHp = (a.kind === 'brute' ? 240 : a.kind === 'runner' ? 62 : a.kind === 'walker' ? 78 : 92) * m.hordeHp;
    a.hp = a.maxHp; a.team = 0; a.r = a.kind === 'brute' ? .65 : .38; a.y = 0;
    a.state = 'rise'; a.timer = 0; a.cooldown = .4; a.invulnerable = .7;
    this.emit('infection', a.x, a.z);
  }

  private killZombie(a: Unit): void {
    if (a.state === 'dead') return;
    a.hp = 0; a.state = 'dead'; a.timer = 1.6; a.vx = a.vz = 0;
    this.snapshot.stats.zombiesLost++;
  }

  private throwProjectile(kind: Projectile['kind'], x: number, z: number, tx: number, tz: number, friendly: boolean, time: number, radius: number): void {
    const list = this.snapshot.projectiles;
    let p = list.find(item => !item.active);
    if (!p) { if (list.length >= 256) return; p = {} as Projectile; list.push(p); }
    Object.assign(p, { active: true, kind, x, z, y: 1.3, vx: (tx - x) / time, vz: (tz - z) / time,
      vy: (8 * time * time - 1.3) / time, timer: time, radius, friendly });
  }

  private projectiles(dt: number): void {
    for (const p of this.snapshot.projectiles) {
      if (!p.active) continue;
      p.timer -= dt;
      const nx = p.x + p.vx * dt, nz = p.z + p.vz * dt;
      if (p.kind === 'acid' && !this.los(p.x, p.z, nx, nz)) p.timer = 0;
      else { p.x = nx; p.z = nz; }
      p.y = Math.max(.15, p.y + p.vy * dt); p.vy -= 16 * dt;
      if (p.timer > 0) continue;
      p.active = false;
      if (p.kind === 'acid') {
        this.addCloud(p.x, p.z, p.radius * (1 + this.snapshot.mods.spitterPuddle), 3.4);
        this.emit('acid', p.x, p.z);
      } else this.explode(p.x, p.z, p.radius, p.friendly ? 155 * this.snapshot.mods.hordeDmg : (p.kind === 'mortar' ? 78 : 54) * (1 + this.snapshot.district / (this.snapshot.district + 30)), p.friendly);
    }
  }

  private addCloud(x: number, z: number, radius: number, time: number): void {
    let cloud = this.snapshot.clouds.find(c => !c.active);
    if (!cloud) { if (this.snapshot.clouds.length >= 128) return; cloud = {} as Cloud; this.snapshot.clouds.push(cloud); }
    Object.assign(cloud, { active: true, x, z, radius, time, tick: 0 });
  }

  private clouds(dt: number): void {
    for (const cloud of this.snapshot.clouds) {
      if (!cloud.active) continue;
      cloud.time -= dt; cloud.tick -= dt;
      if (cloud.time <= 0) { cloud.active = false; continue; }
      if (cloud.tick > 0) continue;
      cloud.tick += .35;
      this.humans.query(cloud.x, cloud.z, cloud.radius, this.blastTargets);
      for (const target of this.blastTargets) if (target.hp > 0 && this.los(cloud.x, cloud.z, target.x, target.z)) this.damage(target, TOXIC.dps * .35 * this.snapshot.mods.hordeDmg, 'toxic');
    }
  }

  private explode(x: number, z: number, radius: number, amount: number, friendly: boolean): void {
    // Iterate entity storage: rare area events avoid nested-query scratch aliasing on bomber chains.
    for (const a of this.units) {
      if (a.hp <= 0 || (friendly && a.team === 0)) continue;
      const distance = Math.hypot(a.x - x, a.z - z);
      if (distance <= radius + a.r && this.los(x, z, a.x, a.z)) this.damage(a, amount * (1 - .4 * distance / (radius + a.r)), 'explosion');
    }
    for (const b of this.snapshot.zone.barriers) if (!b.open && this.boxDistance(x, z, b) < radius) this.hitBarrier(b, amount * 1.6);
    this.emit('explosion', x, z);
  }

  private hitBarrier(b: Barrier, amount: number): void {
    if (b.open || b.hp <= 0) return;
    b.hp = Math.max(0, b.hp - amount);
    this.emit('debris', b.x, b.z);
    if (b.hp > 0) return;
    b.open = true;
    this.gainXp(XP.barricade);
    if (b.kind !== 'shelter') { this.notice('DEFENSIVE LINE BROKEN'); return; }
    const shelter = this.snapshot.zone.shelters.find(item => item.barrierId === b.id);
    if (!shelter || shelter.opened) return;
    shelter.opened = true;
    this.snapshot.stats.sheltersOverrun++;
    if (this.snapshot.leader.hp > 0) this.snapshot.leader.hp = Math.min(this.snapshot.leader.maxHp, this.snapshot.leader.hp + 30);
    this.gainXp(XP.shelter);
    for (let n = 0; n < this.shelterPopulation; n++) this.spawn(this.civilianKind(), shelter.x + (this.random() - .5) * 6, shelter.z + (this.random() - .5) * 6);
    this.notice(`SHELTER OVERRUN · ${this.shelterPopulation} survivors exposed · +30 HP`);
  }

  private director(dt: number): void {
    const s = this.snapshot;
    this.waveClock += dt;
    if (this.waves >= 2) return;
    let aliveHumans = 0;
    for (const a of this.units) if (a.team === 1 && a.hp > 0) aliveHumans++;
    const progress = (s.zone.spawn.z - s.leader.z) / Math.max(1, s.zone.spawn.z - s.zone.exit.z);
    const threshold = this.waves === 0 ? .3 : .66;
    if (this.waveClock < 27 && aliveHumans > 7 && progress < threshold) return;
    const weak = s.leader.hp < s.leader.maxHp * .35 || s.hordeCounts.reduce((a, b) => a + b, 0) < 8;
    const count = this.waves === 0 ? Math.ceil(this.reserveCivilians / 2) : this.reserveCivilians;
    this.reserveCivilians -= count;
    const z = clamp(s.leader.z - 14, -39, 33);
    for (let i = 0; i < count; i++) this.spawn(weak && i % 5 === 0 ? 'medic' : this.civilianKind(), (this.random() - .5) * 23, z + (this.random() - .5) * 12);
    if (!weak || this.waves === 1) {
      const countEnemies = this.waves === 0 ? Math.ceil(this.reserveEnemies.length / 2) : this.reserveEnemies.length;
      for (let i = 0; i < countEnemies; i++) this.spawn(this.reserveEnemies.pop()!, (this.random() - .5) * 13, Math.max(-42, z - (weak ? 22 : 12)));
    }
    this.waves++; this.waveClock = 0;
    this.notice(weak ? 'RELIEF: fleeing medical convoy nearby. Regroup and feed.' : 'EVACUATION WAVE · Fresh survivors ahead');
  }

  private countHorde(): void {
    const s = this.snapshot;
    s.hordeCounts.fill(0);
    let total = 0;
    for (const a of this.units) if (a.team === 0 && a.kind !== 'leader' && a.hp > 0) { s.hordeCounts[ZOMBIES.indexOf(a.kind)]++; total++; }
    s.stats.peakHorde = Math.max(s.stats.peakHorde, total);
  }

  private objective(): void {
    const s = this.snapshot, def = this.definition;
    // Only people who can still rise are in the denominator; explosive losses cannot softlock a district.
    const available = Math.max(1, this.potential - this.unrecoverable);
    s.infection = clamp(this.zoneInfected / available, 0, 1);
    let lines = 0;
    for (const b of s.zone.barriers) if (!b.open && b.kind !== 'shelter') lines++;
    const reached = s.infection >= def.infectionTarget || this.zoneInfected + this.unrecoverable >= this.potential;
    const ready = reached && lines === 0;
    if (ready && !s.readyExit) this.notice(s.district === 4 ? 'FINAL LINE BROKEN · Reach the evacuation marker!' : 'DISTRICT OVERRUN · Follow the green exit marker');
    s.readyExit = ready;
    s.objective = ready ? (s.district === 4 ? 'REACH THE LAST EVACUATION' : 'REACH THE DISTRICT EXIT') : !reached ? `INFECT ${Math.round(def.infectionTarget * 100)}% · ${Math.round(s.infection * 100)}% INFECTED${lines ? ` · ${lines} DEFENSIVE LINES` : ''}` : `BREAK ${lines} REMAINING DEFENSIVE ${lines === 1 ? 'LINE' : 'LINES'}`;
  }

  private advance(): void {
    const s = this.snapshot;
    if (s.district >= 4 && !this.endless) { s.won = true; this.notice('THE CITY BELONGS TO THE DEAD.'); return; }
    let escorts = 0;
    for (let i = this.units.length - 1; i >= 0; i--) {
      const a = this.units[i];
      if (a.state === 'infected') this.rise(a);
      if (a.hp <= 0 || a.team !== 0 || (a.kind !== 'leader' && ++escorts > MAX_ESCORT)) { this.units.splice(i, 1); this.pool.push(a); }
    }
    if (escorts > MAX_ESCORT) this.notice('The rear parade holds the infected district. 300 march onward.');
    s.district++;
    s.zone = this.zoneFactory(s.district);
    s.leader.x = s.zone.spawn.x; s.leader.z = s.zone.spawn.z;
    s.leader.vx = s.leader.vz = 0;
    s.leader.hp = Math.min(s.leader.maxHp, s.leader.hp + 35);
    (s.leader as Unit).invulnerable = 2;
    let n = 0;
    for (const a of this.units) if (a.kind !== 'leader') {
      const angle = n * 2.399963, r = 1 + Math.sqrt(n) * .7;
      a.x = s.zone.spawn.x + Math.sin(angle) * r;
      a.z = clamp(s.zone.spawn.z + Math.cos(angle) * r, -50, 52);
      if (this.blocked(a.x, a.z, a.r)) { a.x = s.zone.spawn.x; a.z = s.zone.spawn.z; }
      a.vx = a.vz = 0; a.hp = Math.min(a.maxHp, a.hp + 15); n++;
    }
    for (const p of s.projectiles) p.active = false;
    for (const c of s.clouds) c.active = false;
    s.surgeTime = 0; this.dashTime = 0;
    this.populate();
    this.rebuildGrids(); this.countHorde(); this.objective();
    this.gainXp(XP.district);
  }

  private gainXp(amount: number): void {
    this.snapshot.xp += amount * this.snapshot.mods.xpGain;
    this.checkLevel();
  }

  private checkLevel(): void {
    const s = this.snapshot;
    if (s.pendingLevel || s.xp < s.xpNext || s.leader.hp <= 0) return;
    const available = UPGRADES.some(upgrade => s.upgrades.reduce((count, id) => count + Number(id === upgrade.id), 0) < upgrade.maxRank);
    do {
      s.xp -= s.xpNext; s.level++; s.stats.levelReached = s.level;
      s.xpNext = Math.round(XP.levelBase * XP.levelGrowth ** Math.min(45, s.level - 1));
    } while (!available && s.xp >= s.xpNext);
    s.pendingLevel = available;
  }

  private blocked(x: number, z: number, radius: number): boolean {
    if (x < -37 || x > 37 || z < -54 || z > 54) return true;
    for (const b of this.snapshot.zone.boxes) if (Math.abs(x - b.x) < b.hx + radius && Math.abs(z - b.z) < b.hz + radius) return true;
    for (const b of this.snapshot.zone.barriers) if (!b.open && Math.abs(x - b.x) < b.hx + radius && Math.abs(z - b.z) < b.hz + radius) return true;
    return false;
  }

  private move(a: Unit, dx: number, dz: number, steer: boolean): void {
    const steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dz)) / .28));
    dx /= steps; dz /= steps;
    for (let i = 0; i < steps; i++) {
      const oldX = a.x, oldZ = a.z;
      if (!this.blocked(a.x + dx, a.z, a.r)) a.x += dx;
      if (!this.blocked(a.x, a.z + dz, a.r)) a.z += dz;
      if (steer && a.x === oldX && a.z === oldZ) {
        const direction = a.id % 2 ? 1 : -1;
        if (!this.blocked(a.x + dz * direction, a.z - dx * direction, a.r)) { a.x += dz * direction; a.z -= dx * direction; }
        else if (!this.blocked(a.x - dz * direction, a.z + dx * direction, a.r)) { a.x -= dz * direction; a.z += dx * direction; }
      }
    }
  }

  private boxDistance(x: number, z: number, b: Box): number {
    return Math.hypot(Math.max(0, Math.abs(x - b.x) - b.hx), Math.max(0, Math.abs(z - b.z) - b.hz));
  }

  private nearestBarrier(x: number, z: number, radius: number, fx?: number, fz?: number): Barrier | null {
    let best: Barrier | null = null, distance = radius;
    for (const b of this.snapshot.zone.barriers) {
      if (b.open) continue;
      const px = clamp(x, b.x - b.hx, b.x + b.hx), pz = clamp(z, b.z - b.hz, b.z + b.hz);
      const d = Math.hypot(px - x, pz - z);
      if (d >= distance || fx !== undefined && fz !== undefined && (px - x) * fx + (pz - z) * fz < -.2) continue;
      if (!this.los(x, z, px, pz, b.id)) continue;
      best = b; distance = d;
    }
    return best;
  }

  private los(x: number, z: number, tx: number, tz: number, ignoreBarrier = -1): boolean {
    const distance = Math.hypot(tx - x, tz - z);
    if (distance < .02) return true;
    const dx = (tx - x) / distance, dz = (tz - z) / distance;
    for (const box of this.snapshot.zone.boxes) if (this.rayBox(x, z, dx, dz, distance, box) < distance - .035) return false;
    for (const b of this.snapshot.zone.barriers) if (!b.open && b.id !== ignoreBarrier && this.rayBox(x, z, dx, dz, distance, b) < distance - .035) return false;
    return true;
  }

  private rayBox(x: number, z: number, dx: number, dz: number, length: number, b: Box): number {
    let near = 0, far = length;
    if (Math.abs(dx) < .000001) { if (x < b.x - b.hx || x > b.x + b.hx) return length; }
    else {
      const a = (b.x - b.hx - x) / dx, c = (b.x + b.hx - x) / dx;
      near = Math.max(near, Math.min(a, c)); far = Math.min(far, Math.max(a, c));
      if (near > far) return length;
    }
    if (Math.abs(dz) < .000001) { if (z < b.z - b.hz || z > b.z + b.hz) return length; }
    else {
      const a = (b.z - b.hz - z) / dz, c = (b.z + b.hz - z) / dz;
      near = Math.max(near, Math.min(a, c)); far = Math.min(far, Math.max(a, c));
      if (near > far) return length;
    }
    return far >= 0 ? near : length;
  }

  private emit(kind: Effect['kind'], x: number, z: number, tx?: number, tz?: number): void {
    const list = this.snapshot.effects;
    if (list.length < 220) list.push({ kind, x, z, y: kind === 'shot' ? 1.25 : .8, tx, tz });
  }

  private notice(text: string): void {
    const list = this.snapshot.notices;
    if (list.length < 16 && list[list.length - 1] !== text) list.push(text);
  }
}
