// Loadout items. Slots: charm, organ, bone. Unlocks persist via localStorage.
import type { Modifiers } from './upgrades';
export type ItemSlot = 'charm' | 'organ' | 'bone';

export interface ItemDef {
  id: string;
  name: string;
  desc: string;
  slot: ItemSlot;
  rarity: 0 | 1 | 2 | 3;
  apply: (m: Modifiers) => void;
}

export const ITEMS: ItemDef[] = [
  { id: 'rotten_sneakers', name: 'ROTTEN SNEAKERS', desc: '+8% movement speed', slot: 'charm', rarity: 0, apply: m => { m.leaderSpeed *= 1.08; m.hordeSpeed *= 1.04; } },
  { id: 'bounce_sole', name: 'MOONSOLE', desc: 'Dash cooldown -20%', slot: 'charm', rarity: 0, apply: m => { m.dashCd *= 0.8; } },
  { id: 'lucky_tooth', name: 'LUCKY TOOTH', desc: '+15% XP gain', slot: 'charm', rarity: 1, apply: m => { m.xpGain *= 1.15; } },
  { id: 'war_horn', name: 'RUSTY HORN', desc: 'Surge cooldown -25%', slot: 'charm', rarity: 1, apply: m => { m.surgeCd *= 0.75; } },
  { id: 'magnet_amulet', name: 'GRAVE MAGNET', desc: 'XP orb attraction +50%', slot: 'charm', rarity: 2, apply: m => { m.magnet *= 1.5; } },
  { id: 'reinforced_spine', name: 'REINFORCED SPINE', desc: '+15% max HP', slot: 'bone', rarity: 0, apply: m => { m.leaderHp *= 1.15; } },
  { id: 'iron_rib', name: 'IRON RIB', desc: '+10% horde HP', slot: 'bone', rarity: 0, apply: m => { m.hordeHp *= 1.1; } },
  { id: 'shock_absorber', name: 'SPONGE MARROW', desc: 'Leader takes 12% less damage', slot: 'bone', rarity: 1, apply: m => { m.leaderHp *= 1.12; } },
  { id: 'thunder_femur', name: 'THUNDER FEMUR', desc: 'Bite damage +18%', slot: 'bone', rarity: 1, apply: m => { m.biteDmg *= 1.18; } },
  { id: 'brute_bone', name: 'BRUTE BONE', desc: 'Brutes +15% HP, +10% chance', slot: 'bone', rarity: 2, apply: m => { m.hordeHp *= 1.05; m.bruteChance *= 1.1; m.bruteArmor += 0.05; } },
  { id: 'diseased_gland', name: 'DISEASED GLAND', desc: '+12% explosion infection', slot: 'organ', rarity: 0, apply: m => { m.explodeInfect *= 1.12; } },
  { id: 'hive_brain', name: 'HIVE BRAIN', desc: '+15% horde detection radius', slot: 'organ', rarity: 1, apply: m => { m.aggroRange *= 1.15; } },
  { id: 'putrid_heart', name: 'PUTRID HEART', desc: 'Zombies regenerate slowly', slot: 'organ', rarity: 1, apply: m => { m.hordeRegen += 1.2; } },
  { id: 'toxic_lungs', name: 'TOXIC LUNGS', desc: 'Toxic infection +25%', slot: 'organ', rarity: 2, apply: m => { m.toxicInfect *= 1.25; } },
  { id: 'primal_cortex', name: 'PRIMAL CORTEX', desc: 'Mutations last +30%', slot: 'organ', rarity: 2, apply: m => { m.mutationDur *= 1.3; } },
];

export const ALL_ITEMS = ITEMS;
export const SLOT_LABELS: Record<ItemSlot, string> = { charm: 'CHARM', organ: 'ORGAN', bone: 'BONE' };
