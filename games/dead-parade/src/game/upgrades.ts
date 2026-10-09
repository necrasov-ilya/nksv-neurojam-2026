// Roguelite upgrade pool. Mod = multiplier applied to game stats.

export type Rarity = 0 | 1 | 2 | 3; // COMMON, UNCOMMON, RARE, MUTATED
export const RARITY_NAMES = ['COMMON', 'UNCOMMON', 'RARE', 'MUTATED'];

export interface Upgrade {
  id: string;
  name: string;
  desc: string;
  rarity: Rarity;
  maxRank: number;
  apply: (m: Modifiers) => void;
}

export interface Modifiers {
  hordeHp: number;
  hordeDmg: number;
  hordeSpeed: number;
  runnerChance: number;
  bruteChance: number;
  bomberChance: number;
  spitterChance: number;
  riseSpeed: number;
  aggroRange: number;
  biteDmg: number;
  biteSpeed: number;
  leaderHp: number;
  leaderSpeed: number;
  dashCd: number;
  mutationDur: number;
  xpGain: number;
  explodeInfect: number;
  hordeRegen: number;
  surgeCd: number;
  surgeDur: number;
  bruteArmor: number;
  bomberRadius: number;
  spitterRange: number;
  spitterPuddle: number;
  toxicInfect: number;
  leaderThorns: number;
  magnet: number;
}

export function baseModifiers(): Modifiers {
  return {
    hordeHp: 1, hordeDmg: 1, hordeSpeed: 1, runnerChance: 1, bruteChance: 1, bomberChance: 1,
    spitterChance: 1, riseSpeed: 1, aggroRange: 1, biteDmg: 1, biteSpeed: 1, leaderHp: 1,
    leaderSpeed: 1, dashCd: 1, mutationDur: 1, xpGain: 1, explodeInfect: 1, hordeRegen: 0,
    surgeCd: 1, surgeDur: 1, bruteArmor: 0, bomberRadius: 1, spitterRange: 1, spitterPuddle: 0,
    toxicInfect: 1, leaderThorns: 0, magnet: 1,
  };
}

export const UPGRADES: Upgrade[] = [
  { id: 'pack_hunger', name: 'PACK HUNGER', desc: 'Horde damage +15%', rarity: 0, maxRank: 4, apply: m => { m.hordeDmg *= 1.15; } },
  { id: 'bad_blood', name: 'BAD BLOOD', desc: 'Infection rise speed +35%', rarity: 0, maxRank: 4, apply: m => { m.riseSpeed *= 1.35; } },
  { id: 'thick_skulls', name: 'THICK SKULLS', desc: 'All zombies gain +18% HP', rarity: 0, maxRank: 4, apply: m => { m.hordeHp *= 1.18; } },
  { id: 'rottengrip', name: 'ROTTEN GRIP', desc: 'Bite damage +25%', rarity: 0, maxRank: 4, apply: m => { m.biteDmg *= 1.25; } },
  { id: 'shambling_speed', name: 'SHAMBLING SPEED', desc: 'Horde moves 12% faster', rarity: 0, maxRank: 4, apply: m => { m.hordeSpeed *= 1.12; } },
  { id: 'leader_vigor', name: 'LEADER VIGOR', desc: 'Leader max HP +25%', rarity: 0, maxRank: 4, apply: m => { m.leaderHp *= 1.25; } },
  { id: 'long_nose', name: 'LONG NOSE', desc: 'Horde detection range +25%', rarity: 0, maxRank: 4, apply: m => { m.aggroRange *= 1.25; } },
  { id: 'hunger_xp', name: 'GRAVE APPETITE', desc: 'XP gain +20%', rarity: 0, maxRank: 4, apply: m => { m.xpGain *= 1.2; } },
  { id: 'quick_dash', name: 'TIGHT TWIST', desc: 'Dash cooldown -25%', rarity: 0, maxRank: 4, apply: m => { m.dashCd *= 0.75; } },
  { id: 'fast_rise', name: 'QUICK ROT', desc: 'Rise speed +20%, explosion infection chance +10%', rarity: 1, maxRank: 3, apply: m => { m.riseSpeed *= 1.2; m.explodeInfect *= 1.1; } },
  { id: 'runner_strain', name: 'RUNNER STRAIN', desc: 'Runner conversion weight +60%', rarity: 1, maxRank: 3, apply: m => { m.runnerChance *= 1.6; } },
  { id: 'brute_strain', name: 'BRUTE STRAIN', desc: 'Brute conversion weight +50%, armor +10 percentage points', rarity: 1, maxRank: 3, apply: m => { m.bruteChance *= 1.5; m.bruteArmor += 0.1; } },
  { id: 'bomber_strain', name: 'BOMBER STRAIN', desc: 'Bomber conversion weight +50%, blast radius +20%', rarity: 1, maxRank: 3, apply: m => { m.bomberChance *= 1.5; m.bomberRadius *= 1.2; } },
  { id: 'spitter_strain', name: 'SPITTER STRAIN', desc: 'Spitter conversion weight +50%, range +25%', rarity: 1, maxRank: 3, apply: m => { m.spitterChance *= 1.5; m.spitterRange *= 1.25; } },
  { id: 'alpha_jaw', name: 'ALPHA JAW', desc: 'Bite damage +40%, bite speed +15%', rarity: 1, maxRank: 3, apply: m => { m.biteDmg *= 1.4; m.biteSpeed *= 1.15; } },
  { id: 'horde_regen', name: 'PUTRID HEALING', desc: 'Zombies regenerate +1.5 HP each second', rarity: 1, maxRank: 3, apply: m => { m.hordeRegen += 1.5; } },
  { id: 'surge_long', name: 'LONG HOWL', desc: 'Surge lasts +40%', rarity: 1, maxRank: 3, apply: m => { m.surgeDur *= 1.4; } },
  { id: 'surge_fast', name: 'EAGER DEAD', desc: 'Surge cooldown -30%', rarity: 1, maxRank: 3, apply: m => { m.surgeCd *= 0.7; } },
  { id: 'leader_muscle', name: 'TOMB TONE', desc: 'Leader speed +15%, HP +10%', rarity: 1, maxRank: 3, apply: m => { m.leaderSpeed *= 1.15; m.leaderHp *= 1.1; } },
  { id: 'toxic_bite', name: 'TOXIC BITE', desc: 'Toxic infection chance +30%, explosion infection chance +15%', rarity: 2, maxRank: 2, apply: m => { m.toxicInfect *= 1.3; m.explodeInfect *= 1.15; } },
  { id: 'acidic_corpses', name: 'ACIDIC CORPSES', desc: 'Spitter pool radius +50% of base, toxic infection chance +20%', rarity: 2, maxRank: 2, apply: m => { m.spitterPuddle += 0.5; m.toxicInfect *= 1.2; } },
  { id: 'mutant_dna', name: 'MUTANT DNA', desc: 'Mutations last 50% longer', rarity: 2, maxRank: 2, apply: m => { m.mutationDur *= 1.5; } },
  { id: 'bomb_magnet', name: 'FRAG FRENZY', desc: 'Explosion infection chance +40%', rarity: 2, maxRank: 2, apply: m => { m.explodeInfect *= 1.4; } },
  { id: 'thick_hide', name: 'THICK HIDE', desc: 'Brute armor +25 percentage points (75% cap), conversion weight +20%', rarity: 2, maxRank: 2, apply: m => { m.bruteArmor += 0.25; m.bruteChance *= 1.2; } },
  { id: 'apex_predator', name: 'APEX PREDATOR', desc: 'Bite damage +60%, leader speed +10%', rarity: 3, maxRank: 1, apply: m => { m.biteDmg *= 1.6; m.leaderSpeed *= 1.1; } },
  { id: 'horde_titan', name: 'TITAN STRAIN', desc: 'All zombies +30% HP, +10% damage', rarity: 3, maxRank: 1, apply: m => { m.hordeHp *= 1.3; m.hordeDmg *= 1.1; } },
  { id: 'plague_lord', name: 'PLEASURE OF PLAGUE', desc: 'XP gain +30%, rise speed +25%', rarity: 3, maxRank: 1, apply: m => { m.xpGain *= 1.3; m.riseSpeed *= 1.25; } },
  { id: 'unholy_speed', name: 'UNHOLY SPEED', desc: 'Horde speed +20%, runner conversion weight +40%', rarity: 3, maxRank: 1, apply: m => { m.hordeSpeed *= 1.2; m.runnerChance *= 1.4; } },
  { id: 'barbed_crown', name: 'BARBED CROWN', desc: 'Return 20% of damage to attackers; leader HP +10%. Punish the gun line.', rarity: 2, maxRank: 3, apply: m => { m.leaderThorns += 0.2; m.leaderHp *= 1.1; } },
  { id: 'breach_runner', name: 'BREACH RUNNER', desc: 'Dash cooldown -15%, leader speed +8%. Slip past accurate shooters.', rarity: 1, maxRank: 3, apply: m => { m.dashCd *= 0.85; m.leaderSpeed *= 1.08; } },
  { id: 'rolling_thunder', name: 'ROLLING THUNDER', desc: 'Surge duration +20%, horde speed +8%. Keep the charge together.', rarity: 1, maxRank: 3, apply: m => { m.surgeDur *= 1.2; m.hordeSpeed *= 1.08; } },
  { id: 'marrow_reserve', name: 'MARROW RESERVE', desc: 'Horde HP +12%, regeneration +1 HP/sec. Preserve veteran followers.', rarity: 1, maxRank: 3, apply: m => { m.hordeHp *= 1.12; m.hordeRegen += 1; } },
  { id: 'chain_outbreak', name: 'CHAIN OUTBREAK', desc: 'Explosion infection chance +20%, rise speed +25%. Blasts become reinforcements.', rarity: 2, maxRank: 2, apply: m => { m.explodeInfect *= 1.2; m.riseSpeed *= 1.25; } },
  { id: 'acid_horizon', name: 'ACID HORIZON', desc: 'Spitter range +20%, pool radius +25% of base. Saturate distant defenses.', rarity: 2, maxRank: 2, apply: m => { m.spitterRange *= 1.2; m.spitterPuddle += 0.25; } },
  { id: 'siege_culture', name: 'SIEGE CULTURE', desc: 'Horde damage +15%, blast radius +15%. Feed bombers and mortar together.', rarity: 2, maxRank: 2, apply: m => { m.hordeDmg *= 1.15; m.bomberRadius *= 1.15; } },
  { id: 'iron_procession', name: 'IRON PROCESSION', desc: 'Brute armor +10 points (75% cap), horde speed +10%. Bring shields to the front.', rarity: 1, maxRank: 3, apply: m => { m.bruteArmor += 0.1; m.hordeSpeed *= 1.1; } },
  { id: 'feral_memory', name: 'FERAL MEMORY', desc: 'Mutation duration +25%, bite speed +20%. Hold your borrowed form and keep feeding.', rarity: 2, maxRank: 2, apply: m => { m.mutationDur *= 1.25; m.biteSpeed *= 1.2; } },
  { id: 'outbreak_network', name: 'OUTBREAK NETWORK', desc: 'Detection range +15%, XP gain +15%. Find new hosts and evolve sooner.', rarity: 0, maxRank: 4, apply: m => { m.aggroRange *= 1.15; m.xpGain *= 1.15; } },
];
