export type Stack = { id: string; qty: number };
export type Item = {
  id: string;
  name: string;
  category: string;
  rarity: string;
  value: number;
  stack: number;
  description: string;
  icon: string;
};
const definitions: [
  string,
  string,
  string,
  string,
  number,
  number,
  string,
  string,
][] = [
  [
    "carbine",
    "AR-4 Carbine",
    "WEAPON",
    "COMMON",
    240,
    1,
    "30-round automatic. Balanced recoil, reliable at medium range.",
    "⌁",
  ],
  [
    "smg",
    "VEK-9 SMG",
    "WEAPON",
    "UNCOMMON",
    320,
    1,
    "36-round close-range automatic. Fast and controllable.",
    "⌁",
  ],
  [
    "scout",
    "M77 Scout",
    "WEAPON",
    "RARE",
    580,
    1,
    "10-round semi-auto. Powerful precision fire.",
    "⌁",
  ],
  [
    "shotgun",
    "JN-2 Breacher",
    "WEAPON",
    "UNCOMMON",
    410,
    1,
    "Pump-action 6-round slug thrower. Heavy damage up close.",
    "⌁",
  ],
  [
    "shotAmmo",
    "Breacher Shells",
    "AMMO",
    "UNCOMMON",
    3,
    48,
    "6-gauge slug shells.",
    "▥",
  ],
  [
    "rifleAmmo",
    "Rifle Ammo",
    "AMMO",
    "COMMON",
    2,
    120,
    "Carbine ammunition.",
    "▥",
  ],
  ["smgAmmo", "SMG Ammo", "AMMO", "COMMON", 1, 144, "Compact ammunition.", "▥"],
  [
    "scoutAmmo",
    "Marksman Ammo",
    "AMMO",
    "UNCOMMON",
    4,
    60,
    "Precision ammunition.",
    "▥",
  ],
  [
    "patch",
    "Field Patch",
    "HEALING",
    "COMMON",
    35,
    5,
    "Q: apply for two seconds to restore 45 health. Sprinting or shooting cancels.",
    "✚",
  ],
  [
    "plate",
    "Armor Plate",
    "ARMOR",
    "UNCOMMON",
    60,
    3,
    "Use in backpack to restore 30 armor durability.",
    "⬡",
  ],
  [
    "armor1",
    "Field Vest I",
    "ARMOR",
    "COMMON",
    120,
    1,
    "50 durability. Absorbs 45% of incoming damage.",
    "⬡",
  ],
  [
    "armor2",
    "Field Vest II",
    "ARMOR",
    "RARE",
    280,
    1,
    "80 durability. Absorbs 45% of incoming damage.",
    "⬡",
  ],
  [
    "grenade",
    "Pulse Grenade",
    "UTILITY",
    "UNCOMMON",
    90,
    3,
    "G: short-fuse pulse blast. 145 damage within 9 meters.",
    "◉",
  ],
  [
    "beacon",
    "Signal Beacon",
    "UTILITY",
    "RARE",
    180,
    2,
    "Use from backpack to distract nearby machines.",
    "⌖",
  ],
  [
    "circuit",
    "Circuit Bundle",
    "MATERIAL",
    "COMMON",
    28,
    6,
    "Salvaged control traces from dormant machines.",
    "⌘",
  ],
  [
    "glass",
    "Optic Glass",
    "MATERIAL",
    "UNCOMMON",
    65,
    4,
    "Uncracked industrial lens blanks.",
    "◇",
  ],
  [
    "servo",
    "Servo Core",
    "MATERIAL",
    "RARE",
    170,
    3,
    "A compact articulated drive in working condition.",
    "⚙",
  ],
  [
    "cell",
    "Power Cell",
    "MATERIAL",
    "UNCOMMON",
    85,
    4,
    "A sealed, rechargeable energy cartridge.",
    "▰",
  ],
  [
    "relay",
    "Industrial Relay",
    "MATERIAL",
    "COMMON",
    40,
    5,
    "Mechanical switching assembly.",
    "▧",
  ],
  [
    "module",
    "Cipher Module",
    "VALUABLE",
    "EPIC",
    650,
    1,
    "A sealed memory module. Its silence is expensive.",
    "◈",
  ],
  [
    "fiber",
    "Synthetic Fiber",
    "MATERIAL",
    "COMMON",
    22,
    8,
    "Woven thermal insulation recovered from conduits.",
    "≋",
  ],
  [
    "processor",
    "Rare Processor",
    "VALUABLE",
    "RARE",
    290,
    2,
    "Intact logic array from a pre-fall controller.",
    "▣",
  ],
];
export const ITEMS: Record<string, Item> = Object.fromEntries(
  definitions.map(
    ([id, name, category, rarity, value, stack, description, icon]) => [
      id,
      { id, name, category, rarity, value, stack, description, icon },
    ],
  ),
);
export const WEAPONS = [
  { id: "carbine", name: "AR-4 CARBINE", mag: 30, damage: 27, interval: 0.115, reload: 1.9, spread: 0.012, range: 90, ammo: "rifleAmmo" },
  { id: "smg", name: "VEK-9 SMG", mag: 36, damage: 18, interval: 0.075, reload: 1.55, spread: 0.016, range: 45, ammo: "smgAmmo" },
  { id: "scout", name: "M77 SCOUT", mag: 10, damage: 82, interval: 0.58, reload: 2.4, spread: 0.004, range: 180, ammo: "scoutAmmo" },
  { id: "shotgun", name: "JN-2 BREACHER", mag: 6, damage: 96, interval: 0.9, reload: 2.2, spread: 0.02, range: 30, ammo: "shotAmmo" },
];
export type Save = {
  stash: Stack[];
  equipment: {
    primary: string;
    secondary: string;
    armor: string;
    heal: number;
    utility: number;
    operator: string;
    ammo: number;
    extra: Stack[];
  };
  settings: {
    sensitivity: number;
    master: number;
    sfx: number;
    music: number;
    quality: string;
    invert: boolean;
  };
  stats: { raids: number; wins: number; kills: number; value: number };
  inRaid: boolean;
  hinted: boolean;
};
export const SAVE_KEY = "dustfall.save.1";
export function newSave(): Save {
  return {
    stash: [
      { id: "carbine", qty: 3 },
      { id: "smg", qty: 2 },
      { id: "scout", qty: 1 },
      { id: "shotgun", qty: 1 },
      { id: "shotAmmo", qty: 24 },
      { id: "rifleAmmo", qty: 600 },
      { id: "smgAmmo", qty: 432 },
      { id: "scoutAmmo", qty: 120 },
      { id: "patch", qty: 15 },
      { id: "armor1", qty: 4 },
      { id: "armor2", qty: 1 },
      { id: "grenade", qty: 6 },
    ],
    equipment: {
      primary: "carbine",
      secondary: "smg",
      armor: "armor1",
      heal: 3,
      utility: 1,
      operator: "wayfarer",
      ammo: 5,
      extra: [],
    },
    settings: {
      sensitivity: 1,
      master: 0.65,
      sfx: 0.85,
      music: 0.35,
      quality: "MEDIUM",
      invert: false,
    },
    stats: { raids: 0, wins: 0, kills: 0, value: 0 },
    inRaid: false,
    hinted: false,
  };
}
export function storeSave(s: Save) {
  try {
    const totals: Record<string, number> = {};
    for (const item of s.stash) totals[item.id] = (totals[item.id] ?? 0) + item.qty;
    s.stash = Object.entries(totals).filter(([,qty]) => qty > 0).map(([id,qty]) => ({id,qty}));
    localStorage.setItem(SAVE_KEY, JSON.stringify(s));
  } catch {
    document.dispatchEvent(new CustomEvent("save-error"));
  }
}
export function loadSave(): Save {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return newSave();
    const p = JSON.parse(raw),
      s = newSave();
    if (!Array.isArray(p.stash)) return s;
    s.stash = p.stash
      .filter((x: Stack) => ITEMS[x.id] && Number.isFinite(x.qty) && x.qty > 0)
      .map((x: Stack) => ({ id: x.id, qty: Math.floor(x.qty) }));
    s.equipment = { ...s.equipment, ...p.equipment };
    s.settings = { ...s.settings, ...p.settings };
    s.stats = { ...s.stats, ...p.stats };
    s.hinted = !!p.hinted;
    s.inRaid = false;
    for (const key of ["primary", "secondary", "armor"] as const) {
      if (!s.stash.some(item => item.id === s.equipment[key])) s.equipment[key] = "";
    }
    if (p.inRaid) {
      s.equipment.primary =
        s.stash.find((x) => ITEMS[x.id].category === "WEAPON")?.id || "";
      s.equipment.secondary = "";
      s.equipment.armor =
        s.stash.find((x) => x.id === "armor1" || x.id === "armor2")?.id || "";
      if (!s.equipment.primary) {
        s.stash.push({id:"carbine",qty:1},{id:"rifleAmmo",qty:90},{id:"patch",qty:2});
        s.equipment.primary = "carbine";
      }
      storeSave(s);
    }
    return s;
  } catch {
    return newSave();
  }
}
export function addItem(
  stacks: Stack[],
  id: string,
  qty: number,
  capacity = 24,
): number {
  if (!ITEMS[id]) return qty;
  for (const s of stacks) {
    if (s.id !== id) continue;
    const n = Math.min(qty, Math.max(0, ITEMS[id].stack - s.qty));
    s.qty += n;
    qty -= n;
    if (!qty) return 0;
  }
  while (qty > 0 && stacks.length < capacity) {
    const n = Math.min(qty, ITEMS[id].stack);
    stacks.push({ id, qty: n });
    qty -= n;
  }
  return qty;
}
export function removeItem(stacks: Stack[], id: string, qty: number): boolean {
  if (count(stacks, id) < qty) return false;
  for (let i = stacks.length - 1; i >= 0 && qty; i--) {
    if (stacks[i].id !== id) continue;
    const n = Math.min(qty, stacks[i].qty);
    stacks[i].qty -= n;
    qty -= n;
    if (!stacks[i].qty) stacks.splice(i, 1);
  }
  return true;
}
export function count(stacks: Stack[], id: string) {
  return stacks.reduce((n, s) => n + (s.id === id ? s.qty : 0), 0);
}
export function lootTable(tier: number): Stack[] {
  const pool =
    tier > 1
      ? ["servo", "processor", "cell", "glass", "module", "shotgun", "shotAmmo"]
      : ["circuit", "fiber", "relay", "rifleAmmo", "patch", "shotAmmo"];
  return Array.from({ length: tier > 1 ? 3 : 2 }, () => {
    const id = pool[Math.floor(Math.random() * pool.length)];
    return {
      id,
      qty:
        id === "rifleAmmo"
          ? 30
          : id === "shotAmmo"
            ? 6
            : id === "shotgun"
              ? 1
              : id === "module"
                ? 1
                : 1 + Math.floor(Math.random() * 2),
    };
  });
}
