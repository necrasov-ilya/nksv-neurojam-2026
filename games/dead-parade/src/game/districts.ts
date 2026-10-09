// Five story districts + ten handcrafted endless sectors; beyond that sectors
// are scaled procedurally (per-tier enemy budget & hp growth).

export interface DistrictDef {
  name: string;
  kicker: string;
  goal: string;
  seed: number;
  civs: number;
  guards: number;
  riflemen: number;
  shotgunners: number;
  grenadiers: number;
  riot: number;
  heavies: number;
  flamers: number;
  snipers: number;
  drones: number;
  sappers: number;
  barricadeLines: number;
  shelters: number;
  infectionTarget: number;
  note: string;
  biome: number;
  weather: number;
  hpScale: number;
  elite: boolean;
}

type Partial2 = Partial<DistrictDef> & Pick<DistrictDef, 'name' | 'seed' | 'civs'>;

const base: DistrictDef = {
  name: '', kicker: '', goal: '', seed: 1, civs: 24, guards: 0, riflemen: 0, shotgunners: 0,
  grenadiers: 0, riot: 0, heavies: 0, flamers: 0, snipers: 0, drones: 0, sappers: 0,
  barricadeLines: 0, shelters: 1, infectionTarget: 0.62, note: '', biome: 0, weather: 0, hpScale: 1, elite: false,
};

const mk = (over: Partial2): DistrictDef => ({ ...base, ...over });

export const DISTRICTS: DistrictDef[] = [
  mk({ name: 'SUBURBS', kicker: 'DISTRICT 1 / 5', goal: 'GROW THE HORDE', seed: 1337, civs: 30, guards: 2, infectionTarget: 0.55, biome: 0, weather: 0, note: 'Quiet streets. Loud soon.' }),
  mk({ name: 'DOWNTOWN', kicker: 'DISTRICT 2 / 5', goal: 'INFECT THE SHOPPING DISTRICT', seed: 2401, civs: 36, guards: 4, riflemen: 4, shotgunners: 2, barricadeLines: 1, shelters: 2, infectionTarget: 0.6, biome: 1, weather: 1, note: 'Police first response.' }),
  mk({ name: 'POLICE BLOCK', kicker: 'DISTRICT 3 / 5', goal: 'BREAK THE POLICE LINE', seed: 3505, civs: 26, guards: 3, riflemen: 6, shotgunners: 3, grenadiers: 2, riot: 2, barricadeLines: 2, infectionTarget: 0.62, biome: 2, weather: 4, note: 'They brought grenades.' }),
  mk({ name: 'INDUSTRIAL BELT', kicker: 'DISTRICT 4 / 5', goal: 'OVERRUN THE FACTORY FLOOR', seed: 4608, civs: 30, guards: 2, riflemen: 7, shotgunners: 3, grenadiers: 3, riot: 2, heavies: 1, barricadeLines: 2, infectionTarget: 0.65, biome: 3, weather: 5, note: 'Toxic pipes, tight alleys.' }),
  mk({ name: 'LAST EVACUATION', kicker: 'DISTRICT 5 / 5', goal: 'BREAK THE FINAL LINE', seed: 5701, civs: 22, guards: 4, riflemen: 8, shotgunners: 4, grenadiers: 3, riot: 2, heavies: 2, barricadeLines: 2, infectionTarget: 0.75, biome: 4, weather: 1, note: 'The last buses are leaving.' }),
];

// Ten handcrafted endless sectors (index 5..14). Story continues past the buses:
// the parade rolls into the winter outskirts, ash country and burning groves.
export const ENDLESS_SECTORS: DistrictDef[] = [
  mk({ name: 'WINTER HEIGHTS', kicker: 'SECTOR 6', seed: 6103, civs: 28, guards: 4, riflemen: 8, shotgunners: 4, grenadiers: 3, riot: 2, heavies: 2, snipers: 1, drones: 2, barricadeLines: 2, infectionTarget: 0.64, biome: 5, weather: 2, hpScale: 1.15, note: 'Snow muffles the screaming.' }),
  mk({ name: 'ASHEN FIELDS', kicker: 'SECTOR 7', seed: 6209, civs: 30, guards: 3, riflemen: 9, shotgunners: 3, grenadiers: 4, riot: 2, heavies: 2, flamers: 2, drones: 3, barricadeLines: 2, infectionTarget: 0.64, biome: 6, weather: 5, hpScale: 1.2, note: 'The crops burn on their own.' }),
  mk({ name: 'FROZEN QUARTER', kicker: 'SECTOR 8', seed: 6317, civs: 26, guards: 5, riflemen: 8, shotgunners: 4, grenadiers: 3, riot: 3, heavies: 2, snipers: 2, sappers: 2, barricadeLines: 3, infectionTarget: 0.66, biome: 7, weather: 2, hpScale: 1.25, note: 'Riot shields in the blizzard.' }),
  mk({ name: 'SUNBAKED ROWS', kicker: 'SECTOR 9', seed: 6421, civs: 32, guards: 4, riflemen: 9, shotgunners: 4, grenadiers: 4, riot: 2, heavies: 3, flamers: 2, drones: 3, barricadeLines: 2, infectionTarget: 0.64, biome: 8, weather: 3, hpScale: 1.3, note: 'Heat haze, hot lead.' }),
  mk({ name: 'EMBER GROVE', kicker: 'SECTOR 10', seed: 6527, civs: 28, guards: 4, riflemen: 10, shotgunners: 4, grenadiers: 4, riot: 3, heavies: 3, flamers: 3, snipers: 2, barricadeLines: 3, infectionTarget: 0.66, biome: 9, weather: 5, hpScale: 1.35, note: 'The orchard is a firewall.' }),
  mk({ name: 'PETROL STATION ROW', kicker: 'SECTOR 11', seed: 6631, civs: 30, guards: 5, riflemen: 9, shotgunners: 5, grenadiers: 4, riot: 3, heavies: 3, flamers: 2, sappers: 3, drones: 2, barricadeLines: 2, infectionTarget: 0.66, biome: 10, weather: 3, hpScale: 1.4, note: 'Everything here explodes.' }),
  mk({ name: 'HARVEST HILLS', kicker: 'SECTOR 12', seed: 6737, civs: 34, guards: 4, riflemen: 10, shotgunners: 4, grenadiers: 4, riot: 3, heavies: 3, snipers: 2, drones: 4, barricadeLines: 3, infectionTarget: 0.68, biome: 11, weather: 0, hpScale: 1.4, note: 'Autumn leaves, autumn bones.' }),
  mk({ name: 'GREEN DISTRICT', kicker: 'SECTOR 13', seed: 6841, civs: 30, guards: 5, riflemen: 11, shotgunners: 5, grenadiers: 5, riot: 3, heavies: 3, flamers: 3, snipers: 2, sappers: 2, barricadeLines: 3, infectionTarget: 0.68, biome: 12, weather: 1, hpScale: 1.45, note: 'Overgrowth hides the guns.' }),
  mk({ name: 'CRYO DEPOT', kicker: 'SECTOR 14', seed: 6953, civs: 26, guards: 5, riflemen: 11, shotgunners: 5, grenadiers: 5, riot: 4, heavies: 3, snipers: 3, drones: 4, barricadeLines: 3, infectionTarget: 0.7, biome: 13, weather: 2, hpScale: 1.5, note: 'They froze the sample. It woke up.' }),
  mk({ name: 'MOLTEN YARD', kicker: 'SECTOR 15', seed: 7069, civs: 28, guards: 6, riflemen: 12, shotgunners: 5, grenadiers: 5, riot: 4, heavies: 4, flamers: 4, snipers: 2, sappers: 3, barricadeLines: 3, infectionTarget: 0.7, hpScale: 1.55, elite: true, biome: 14, weather: 5, note: 'Scrap, fire, and the last holdouts.' }),
];

const scaleEnemy = (value: number, tier: number) => Math.min(14, Math.round(value * 1.22 ** Math.min(tier, 16)));

/** Handcrafted table, then a deterministic escalation cycle for deeper sectors. */
export function districtDef(index: number): DistrictDef {
  if (index < DISTRICTS.length) return DISTRICTS[index];
  const cycle = index - DISTRICTS.length;
  if (cycle < ENDLESS_SECTORS.length) return ENDLESS_SECTORS[cycle];
  const tier = Math.floor(cycle / ENDLESS_SECTORS.length);
  const source = ENDLESS_SECTORS[cycle % ENDLESS_SECTORS.length];
  return {
    ...source,
    kicker: `SECTOR ${index + 1} · DEPTH ${tier + 1}`,
    seed: (source.seed + tier * 97) >>> 0,
    civs: Math.min(40, source.civs + tier * 2),
    guards: scaleEnemy(source.guards, tier),
    riflemen: scaleEnemy(source.riflemen, tier),
    shotgunners: scaleEnemy(source.shotgunners, tier),
    grenadiers: scaleEnemy(source.grenadiers, tier),
    riot: scaleEnemy(source.riot, tier),
    heavies: scaleEnemy(source.heavies, tier),
    flamers: scaleEnemy(source.flamers, tier),
    snipers: scaleEnemy(source.snipers, tier),
    drones: scaleEnemy(source.drones, tier),
    sappers: scaleEnemy(source.sappers, tier),
    barricadeLines: Math.min(3, source.barricadeLines + (tier % 2)),
    hpScale: source.hpScale * (1 + 4 * tier / (tier + 12)),
    elite: tier > 0 || source.elite,
  };
}
