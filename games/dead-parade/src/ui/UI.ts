import { BIOME_NAMES, WEATHER_NAMES, type Snapshot, type RunStats } from '../core/model';
import { ITEMS, SLOT_LABELS, type ItemDef, type ItemSlot } from '../game/items';
import { baseModifiers, RARITY_NAMES, UPGRADES, type Modifiers, type Upgrade } from '../game/upgrades';
import { DISTRICTS, districtDef } from '../game/districts';
import { LEADER } from '../game/config';

export interface UIActions {
  start: (endless?: boolean) => void;
  menu: () => void;
  loadout: () => void;
  resume: () => void;
  pause: () => void;
  settingsChanged: () => void;
  previewItem: (id: string) => void;
}
export interface UISettings { master: number; music: number; sfx: number; sensitivity: number; shadows: boolean; quality: string; }
type Mutation = 'feral' | 'behemoth' | 'toxic' | 'mortar';
const MUTATIONS: { id: Mutation; name: string; icon: string; description: string }[] = [
  { id: 'feral', name: 'FERAL', icon: '╱╱╱', description: 'A fast predator. Close the gap and tear through the living.' },
  { id: 'behemoth', name: 'BEHEMOTH', icon: '⬡', description: 'A walking wrecking crew. Smash barricades and the humans behind them.' },
  { id: 'toxic', name: 'TOXIC', icon: '◎', description: 'Turn the streets green with an infectious acid attack.' },
  { id: 'mortar', name: 'MORTAR', icon: '✳', description: 'Deliver an explosive welcome from a distance.' },
];
const SCREEN_IDS: Record<string, string> = { MAIN_MENU: 'menu', LOADOUT: 'loadout', PAUSED: 'pausemenu', LEVEL_UP: 'levelup', VICTORY: 'victory', DEFEAT: 'defeat', HOWTO: 'howto', SETTINGS: 'settings' };
const STORAGE = 'dead-parade-v1';
const ICONS: Record<ItemSlot, string> = { charm: '◇', bone: '╋', organ: '◉' };
const SLOTS: ItemSlot[] = ['charm', 'organ', 'bone'];
const STAT_LABELS: Record<keyof Modifiers, string> = {
  hordeHp: 'Horde health', hordeDmg: 'Horde damage', hordeSpeed: 'Horde speed', runnerChance: 'Runner chance', bruteChance: 'Brute chance', bomberChance: 'Bomber chance', spitterChance: 'Spitter chance', riseSpeed: 'Rise speed', aggroRange: 'Detection range', biteDmg: 'Bite damage', biteSpeed: 'Bite speed', leaderHp: 'Leader health', leaderSpeed: 'Leader speed', dashCd: 'Dash cooldown', mutationDur: 'Mutation duration', xpGain: 'XP gain', explodeInfect: 'Explosion infection', hordeRegen: 'Horde healing / sec', surgeCd: 'Surge cooldown', surgeDur: 'Surge duration', bruteArmor: 'Brute armor', bomberRadius: 'Blast radius', spitterRange: 'Spitter range', spitterPuddle: 'Acid pool size', toxicInfect: 'Toxic infection', leaderThorns: 'Thorns damage', magnet: 'XP attraction',
};
const el = <T extends HTMLElement = HTMLElement>(id: string): T => document.getElementById(id) as T;
const node = (tag: string, className: string, text?: string): HTMLElement => { const n = document.createElement(tag); n.className = className; if (text !== undefined) n.textContent = text; return n; };
const clock = (time: number): string => `${Math.floor(time / 60).toString().padStart(2, '0')}:${Math.floor(time % 60).toString().padStart(2, '0')}`;
const bounded = (value: unknown, fallback: number, min: number, max: number): number => typeof value === 'number' && Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback;

export class UI {
  private current = '';
  private previous = 'MAIN_MENU';
  private endless = false;
  private values: UISettings = { master: 0.7, music: 0.45, sfx: 0.8, sensitivity: 1, shadows: true, quality: 'high' };
  private fullscreen = false;
  private equipment: Partial<Record<ItemSlot, string>> = { charm: 'rotten_sneakers', bone: 'reinforced_spine', organ: 'diseased_gland' };
  private unlocked = new Set(ITEMS.filter(item => item.rarity < 2 && item.id !== 'shock_absorber').map(item => item.id));
  private mutation: Mutation = 'feral';
  private selectedAbility: Mutation = 'toxic';
  private latest?: Snapshot;
  private ended = new WeakMap<RunStats, string>();
  private textCache = new Map<string, string>();
  private cooldownMax = [1, 1, 1];
  private lastDistrict = -1;
  private currentDistrict = districtDef(0);
  private lastRun?: RunStats;
  private itemButtons = new Map<string, HTMLButtonElement>();

  constructor(private actions: UIActions) {
    this.restore();
    const bind = (id: string, action: () => void) => el(id).addEventListener('click', action);
    const menu = () => this.actions.menu();
    const loadout = () => this.actions.loadout();
    const start = () => { if (this.fullscreen && !document.fullscreenElement) this.setFullscreen(true); this.actions.start(this.endless); };
    bind('btnEndless', () => { this.endless = true; start(); });
    bind('btnStart', () => { this.endless = false; start(); });
    bind('btnStartRun', () => start());
    ['btnRestart', 'btnWinAgain', 'btnLoseAgain'].forEach(id => bind(id, start));
    ['btnLoadout', 'btnWinLoadout', 'btnLoseLoadout'].forEach(id => bind(id, loadout));
    ['btnLoBack', 'btnQuit', 'btnWinMenu', 'btnLoseMenu'].forEach(id => bind(id, menu));
    bind('btnHow', () => this.show('HOWTO'));
    bind('btnHowBack', () => this.show(this.previous));
    bind('btnSettings', () => this.show('SETTINGS'));
    bind('btnPauseSettings', () => this.show('SETTINGS'));
    bind('btnSetBack', () => this.show(this.previous));
    bind('btnResume', () => this.actions.resume());
    bind('btnPause', () => this.actions.pause());
    bind('slotMutation', () => this.equipMutation(MUTATIONS[(MUTATIONS.findIndex(m => m.id === this.mutation) + 1) % MUTATIONS.length].id));
    document.querySelectorAll<HTMLButtonElement>('[data-slot]').forEach(button => button.addEventListener('click', () => {
      const slot = button.dataset.slot as ItemSlot;
      delete this.equipment[slot]; this.save(); this.renderEquipment(); this.actions.previewItem('');
    }));
    this.bindSettings();
    this.renderInventory();
    this.renderEquipment();
  }

  get settings(): UISettings { return this.values; }
  get screen(): string { return this.current; }
  get startingMutation(): Mutation { return this.mutation; }

  selectAbility(index: number): void {
    const mutation = MUTATIONS[index - 1];
    if (mutation) { this.selectedAbility = mutation.id; this.text('eName', mutation.name); }
  }

  show(state: string): void {
    if (state !== 'PLAYING' && !SCREEN_IDS[state]) return;
    if ((state === 'SETTINGS' || state === 'HOWTO') && this.current !== state) this.previous = this.current || 'MAIN_MENU';
    if (state !== 'PLAYING' && document.pointerLockElement) document.exitPointerLock();
    const changed = this.current !== state;
    this.current = state;
    document.querySelectorAll<HTMLElement>('.screen').forEach(screen => screen.classList.toggle('on', screen.id === SCREEN_IDS[state] || (screen.id === 'hud' && ['PLAYING', 'PAUSED', 'LEVEL_UP'].includes(state))));
    document.body.dataset.screen = state.toLowerCase();
    if (changed) this.toggleBuild(false);
    if (state !== 'PLAYING') el('vignette').classList.remove('hurt');
    if (state === 'LOADOUT') { this.renderEquipment(); this.actions.previewItem(this.equipment.charm || ''); el('btnStartRun').firstElementChild!.textContent = this.endless ? 'BEGIN ENDLESS PARADE' : 'BEGIN FIVE-DISTRICT STORY'; }
    if (state === 'SETTINGS') this.syncSettings();
    if (changed && state !== 'PLAYING') {
      const first = document.querySelector<HTMLButtonElement>(`#${SCREEN_IDS[state]} button`);
      first?.focus({ preventScroll: true });
    }
  }

  getModifiers(): Modifiers & { startMutation: Mutation } {
    const mods = baseModifiers();
    for (const slot of SLOTS) {
      const item = ITEMS.find(item => item.id === this.equipment[slot] && item.slot === slot);
      if (item && this.unlocked.has(item.id)) item.apply(mods);
    }
    return Object.assign(mods, { startMutation: this.mutation });
  }

  update(snapshot: Snapshot): void {
    this.latest = snapshot;
    if (this.lastRun !== snapshot.stats) { this.lastRun = snapshot.stats; this.lastDistrict = -1; this.cooldownMax = [1, 1, 1]; this.selectedAbility = 'toxic'; this.endless = Boolean(snapshot.endless); }
    const district = this.lastDistrict === snapshot.district ? this.currentDistrict : (this.currentDistrict = districtDef(snapshot.district));
    const infection = Math.max(0, Math.min(1, snapshot.infection));
    this.text('hudDistrict', snapshot.endless ? `ENDLESS · SECTOR ${snapshot.endless.sector} · TIER ${snapshot.endless.tier}${snapshot.endless.elite ? ' · ELITE' : ''}` : `DISTRICT ${snapshot.district + 1} / ${DISTRICTS.length}`);
    this.text('hudDistName', district.name);
    this.text('hudEnvironment', `${BIOME_NAMES[snapshot.zone.biome]} · ${WEATHER_NAMES[snapshot.zone.weather]}`);
    this.text('hudInfection', `INFECTION ${Math.round(infection * 100)}%`);
    this.text('hudTarget', `TARGET ${Math.round(district.infectionTarget * 100)}%`);
    el('infectionFill').style.width = `${infection * 100}%`;
    this.text('hudObjective', snapshot.objective);
    el('hudObjective').classList.toggle('done', snapshot.readyExit);
    const distance = Math.round(Math.hypot(snapshot.leader.x - snapshot.zone.exit.x, snapshot.leader.z - snapshot.zone.exit.z));
    this.text('hudDirection', snapshot.readyExit ? `↑ FOLLOW THE EXIT MARKER · ${distance}m` : 'INFECT HUMANS · OVERRUN SHELTERS · BREAK DEFENSES');
    this.text('hpText', `${Math.max(0, Math.ceil(snapshot.leader.hp))} / ${Math.ceil(snapshot.leader.maxHp)}`);
    const health = Math.max(0, Math.min(1, snapshot.leader.hp / snapshot.leader.maxHp));
    el('hpFill').style.width = `${health * 100}%`;
    el('hudHp').classList.toggle('critical', health < 0.3);
    el('vignette').classList.toggle('hurt', health < 0.3 && this.current === 'PLAYING');
    const mutation = snapshot.mutationTime > 0 ? MUTATIONS.find(m => m.id === snapshot.mutation) : undefined;
    const ability = mutation || MUTATIONS.find(m => m.id === this.selectedAbility)!;
    this.text('hudMut', mutation ? `${mutation.name} / ${Math.ceil(snapshot.mutationTime)}s` : `BASE FORM / ${ability.name} SELECTED`);
    this.text('hudTimer', clock(snapshot.stats.runTime));
    let horde = 0;
    for (let i = 0; i < 5; i++) { const count = snapshot.hordeCounts[i] || 0; horde += count; this.text(`count${i}`, String(count)); }
    this.text('hudHorde', String(horde));
    this.text('eName', ability.name);
    this.cooldown('Q', snapshot.surgeCooldown, 0, snapshot.surgeTime > 0);
    this.cooldown('E', snapshot.abilityCooldown, 1, false);
    this.cooldown('Sp', snapshot.dashCooldown, 2, false);
    this.text('hudLevel', `LVL ${snapshot.level}  /  ${Math.floor(snapshot.xp)} : ${snapshot.xpNext} XP`);
    el('xpFill').style.width = `${Math.max(0, Math.min(100, snapshot.xp / Math.max(1, snapshot.xpNext) * 100))}%`;
    if (this.lastDistrict !== snapshot.district) { this.lastDistrict = snapshot.district; if (this.current === 'PLAYING') this.toast(`${district.name} — ${district.note}`); }
  }

  levelUp(options: Upgrade[], onChoose: (id: string) => void): void {
    const cards = el('luCards'); cards.replaceChildren();
    let chosen = false;
    options.slice(0, 3).forEach((upgrade, index) => {
      const card = node('button', `lu-card r${upgrade.rarity}`) as HTMLButtonElement;
      card.type = 'button';
      card.dataset.upgradeId = upgrade.id;
      card.dataset.choice = String(index + 1);
      card.setAttribute('aria-keyshortcuts', String(index + 1));
      const rank = (this.latest?.upgrades.filter(id => id === upgrade.id).length || 0) + 1;
      card.append(node('span', 'card-number', `[${index + 1}]`), node('span', 'rar', `${RARITY_NAMES[upgrade.rarity]} · RANK ${rank}/${upgrade.maxRank}`), node('span', 'upgrade-glyph', ['╋', '◇', '✳'][index]), node('h3', '', upgrade.name), node('p', '', upgrade.desc), node('span', 'card-choose', `PRESS ${index + 1} / EMBRACE IT ↗`));
      card.addEventListener('click', () => {
        if (chosen) return;
        chosen = true;
        cards.querySelectorAll('button').forEach(button => { button.disabled = true; });
        onChoose(upgrade.id);
      });
      cards.append(card);
    });
    this.show('LEVEL_UP');
    cards.querySelector<HTMLButtonElement>('button')?.focus({ preventScroll: true });
  }

  toggleBuild(force?: boolean): void {
    const panel = el('buildPanel');
    const visible = force ?? panel.hidden;
    panel.hidden = !visible || !['PLAYING', 'PAUSED', 'LEVEL_UP'].includes(this.current);
    if (panel.hidden || !this.latest) return;
    const content = el('buildContent'); content.replaceChildren();
    content.append(node('h3', '', `LEVEL ${this.latest.level} / ${this.latest.mutation.toUpperCase()}`));
    const stats = node('div', 'build-stats');
    this.modifierLines(this.latest.mods).forEach(line => stats.append(node('div', '', line)));
    if (!stats.childElementCount) stats.append(node('div', '', 'Original recipe. No modifiers yet.'));
    content.append(stats, node('h3', '', 'EVOLUTIONS'));
    const counts = new Map<string, number>();
    this.latest.upgrades.forEach(id => counts.set(id, (counts.get(id) || 0) + 1));
    counts.forEach((count, id) => {
      const upgrade = UPGRADES.find(item => item.id === id);
      if (!upgrade) return;
      const entry = node('div', `build-upgrade r${upgrade.rarity}`);
      entry.append(node('b', '', `${upgrade.name} · ${count}/${upgrade.maxRank}`), node('p', '', upgrade.desc)); content.append(entry);
    });
    if (!counts.size) content.append(node('p', 'panel-note', 'Infect humans to earn your first evolution.'));
    content.append(node('h3', '', 'EQUIPMENT'));
    SLOTS.forEach(slot => content.append(node('p', 'build-item', `${SLOT_LABELS[slot]} / ${ITEMS.find(item => item.id === this.equipment[slot])?.name || 'EMPTY'}`)));
  }

  toast(text: string): void {
    const toasts = el('toasts');
    if (toasts.childElementCount >= 4) toasts.firstElementChild?.remove();
    const toast = node('div', 'toast', text); toasts.append(toast);
    window.setTimeout(() => toast.remove(), 3800);
  }

  end(snapshot: Snapshot, win: boolean): void {
    this.latest = snapshot;
    this.endless = Boolean(snapshot.endless);
    const grid = el(win ? 'winStats' : 'loseStats'); grid.replaceChildren();
    const stats = snapshot.stats;
    const rows: [string, string | number][] = [ ['TIME ON EARTH', clock(stats.runTime)], ['HUMANS INFECTED', stats.totalInfected], ['LARGEST HORDE', stats.peakHorde], ['HUMANS DEFEATED', stats.humansDefeated], ['SHELTERS OVERRUN', stats.sheltersOverrun], ['ZOMBIES LOST', stats.zombiesLost], ['LEVEL REACHED', stats.levelReached], snapshot.endless ? ['SECTOR REACHED', snapshot.endless.sector] : ['DISTRICT REACHED', `${snapshot.district + 1} / ${DISTRICTS.length}`] ];
    if (snapshot.endless) rows.push(['DEFENSE TIER', `${snapshot.endless.tier}${snapshot.endless.elite ? ' · ELITE' : ''}`], ['BIOME', BIOME_NAMES[snapshot.zone.biome]], ['WEATHER', WEATHER_NAMES[snapshot.zone.weather]]);
    this.text(win ? 'winNarrative' : 'loseNarrative', snapshot.endless ? 'THE INFECTION HAS SPREAD. THE NEXT DEFENSE LINE IS ALREADY MOBILIZING.' : win ? 'THE EVACUATION NEVER LEFT.' : 'THE CITY HOLDS… FOR NOW.');
    rows.forEach(([label, value]) => { const row = node('div', 'stat-row'); row.append(node('span', '', label), node('b', '', String(value))); grid.append(row); });
    let reward = this.ended.get(stats);
    if (reward === undefined) {
      const next = ITEMS.find(item => !this.unlocked.has(item.id));
      if (next && (win || stats.totalInfected >= 10)) { this.unlocked.add(next.id); this.save(); reward = `UNLOCKED: ${next.name} — waiting in your loadout.`; this.renderInventory(); }
      else reward = next ? 'Infect 10 humans in one run to unlock another item.' : 'THE COLLECTION IS COMPLETE. THE CITY IS NOT.';
      this.ended.set(stats, reward);
    }
    el(win ? 'winReward' : 'loseReward').textContent = reward;
    this.show(win ? 'VICTORY' : 'DEFEAT');
  }

  private text(id: string, value: string): void { if (this.textCache.get(id) !== value) { this.textCache.set(id, value); el(id).textContent = value; } }

  private cooldown(key: string, remaining: number, index: number, active: boolean): void {
    if (remaining <= 0) this.cooldownMax[index] = 1;
    else this.cooldownMax[index] = Math.max(this.cooldownMax[index], remaining);
    const ready = remaining <= 0;
    el(`ab${key}`).classList.toggle('ready', ready);
    el(`ab${key}`).classList.toggle('active', active);
    el(`cd${key}`).style.setProperty('--cooldown', `${ready ? 0 : remaining / this.cooldownMax[index] * 360}deg`);
    this.text(`t${key}`, active ? 'ACTIVE' : ready ? 'READY' : `${Math.ceil(remaining)}s`);
  }

  private renderInventory(): void {
    const inv = el('loInv'); inv.replaceChildren(); this.itemButtons.clear();
    ITEMS.forEach(item => {
      const unlocked = this.unlocked.has(item.id);
      const button = node('button', `lo-item r${item.rarity}${unlocked ? '' : ' locked'}`) as HTMLButtonElement;
      button.type = 'button'; button.setAttribute('aria-disabled', String(!unlocked));
      button.title = `${item.name} · ${SLOT_LABELS[item.slot]} · ${this.itemDescription(item)}${unlocked ? '\nClick to equip' : '\nInfect 10 humans in a run to unlock the next item'}`;
      button.append(node('span', 'item-icon', ICONS[item.slot]), node('span', 'it-name', item.name), node('span', 'it-rar', `${RARITY_NAMES[item.rarity]} / ${SLOT_LABELS[item.slot]}`), node('span', 'it-status', unlocked ? 'EQUIP' : 'LOCKED'));
      const inspect = () => { this.inspectItem(item); if (unlocked) this.actions.previewItem(item.id); };
      button.addEventListener('mouseenter', inspect); button.addEventListener('focus', inspect);
      button.addEventListener('click', () => {
        if (!this.unlocked.has(item.id)) { this.toast('Infect 10 humans in one run to unlock the next item.'); return; }
        this.equipment[item.slot] = item.id; this.save(); this.renderEquipment(); this.inspectItem(item); this.actions.previewItem(item.id);
      });
      this.itemButtons.set(item.id, button); inv.append(button);
    });
    el('loItemHint').textContent = `${this.unlocked.size} / ${ITEMS.length} UNLOCKED`;
  }

  private renderEquipment(): void {
    SLOTS.forEach(slot => { const item = ITEMS.find(item => item.id === this.equipment[slot]); const suffix = slot[0].toUpperCase() + slot.slice(1); el(`slot${suffix}`).textContent = item?.name || 'EMPTY'; el(`slot${suffix}`).parentElement!.title = item ? `${this.itemDescription(item)} · Click to unequip` : 'Choose an item from the collection'; });
    this.itemButtons.forEach((button, id) => { const equipped = Object.values(this.equipment).includes(id); button.classList.toggle('sel', equipped); button.setAttribute('aria-pressed', String(equipped)); button.querySelector('.it-status')!.textContent = equipped ? 'EQUIPPED' : this.unlocked.has(id) ? 'EQUIP' : 'LOCKED'; });
    el('slotMutationName').textContent = MUTATIONS.find(m => m.id === this.mutation)!.name;
    const choices = el('mutationChoices'); choices.replaceChildren();
    MUTATIONS.forEach((mutation, index) => {
      const button = node('button', `mutation-choice${this.mutation === mutation.id ? ' sel' : ''}`, `${index + 1} / ${mutation.name}`) as HTMLButtonElement;
      button.type = 'button'; button.title = mutation.description; button.setAttribute('aria-pressed', String(this.mutation === mutation.id));
      button.addEventListener('click', () => this.equipMutation(mutation.id)); choices.append(button);
    });
    const stats = el('loStats'); stats.replaceChildren();
    const mods = this.getModifiers();
    const heading = node('div', 'lo-stat-head'); heading.append(node('span', 'eyebrow', 'STARTING VITALS'), node('b', '', `${Math.round(LEADER.hpMax * mods.leaderHp)} HP`)); stats.append(heading);
    const lines = this.modifierLines(mods);
    const list = node('div', 'lo-stat-list'); lines.forEach(line => list.append(node('span', '', line))); if (!lines.length) list.append(node('span', '', 'Unmodified. Undeniably undead.')); stats.append(list);
    if (!el('itemDetail').childElementCount) this.inspectItem(ITEMS[0]);
  }

  private equipMutation(id: Mutation): void { this.mutation = id; this.save(); this.renderEquipment(); this.actions.previewItem(id); const mutation = MUTATIONS.find(m => m.id === id)!; const detail = el('itemDetail'); detail.replaceChildren(node('b', '', `${mutation.name} / STARTING MUTATION`), node('p', '', mutation.description)); }
  private inspectItem(item: ItemDef): void { const detail = el('itemDetail'); detail.replaceChildren(node('b', `r${item.rarity}`, `${item.name} / ${RARITY_NAMES[item.rarity]}`), node('p', '', this.itemDescription(item))); }
  private itemDescription(item: ItemDef): string { const mods = baseModifiers(); item.apply(mods); return this.modifierLines(mods).join(' · '); }
  private modifierLines(mods: Modifiers): string[] {
    const base = baseModifiers(); const lines: string[] = [];
    for (const key of Object.keys(base) as (keyof Modifiers)[]) {
      if (Math.abs(mods[key] - base[key]) < 0.0001) continue;
      const difference = mods[key] - base[key];
      const value = base[key] === 1 || key === 'bruteArmor' || key === 'spitterPuddle' ? `${Math.round(difference * 100)}%` : Number(difference.toFixed(1)).toString();
      lines.push(`${difference > 0 ? '+' : ''}${value} ${STAT_LABELS[key]}`);
    }
    return lines;
  }

  private bindSettings(): void {
    const ranges: [string, keyof Pick<UISettings, 'master' | 'music' | 'sfx' | 'sensitivity'>][] = [['setMaster', 'master'], ['setMusic', 'music'], ['setSfx', 'sfx'], ['setSens', 'sensitivity']];
    ranges.forEach(([id, key]) => el<HTMLInputElement>(id).addEventListener('input', () => { this.values[key] = Number(el<HTMLInputElement>(id).value); this.save(); this.syncSettings(); this.actions.settingsChanged(); }));
    el<HTMLInputElement>('setShadows').addEventListener('change', () => { this.values.shadows = el<HTMLInputElement>('setShadows').checked; this.save(); this.actions.settingsChanged(); });
    el<HTMLSelectElement>('setHorde').addEventListener('change', () => { this.values.quality = el<HTMLSelectElement>('setHorde').value; this.save(); this.actions.settingsChanged(); });
    el<HTMLInputElement>('setFull').addEventListener('change', () => this.setFullscreen(el<HTMLInputElement>('setFull').checked));
    document.addEventListener('fullscreenchange', () => { el<HTMLInputElement>('setFull').checked = Boolean(document.fullscreenElement); });
    this.syncSettings();
  }

  private syncSettings(): void {
    const rows: [string, string, number, boolean][] = [['setMaster', 'valMaster', this.values.master, true], ['setMusic', 'valMusic', this.values.music, true], ['setSfx', 'valSfx', this.values.sfx, true], ['setSens', 'valSens', this.values.sensitivity, false]];
    rows.forEach(([id, output, value, percent]) => { el<HTMLInputElement>(id).value = String(value); el(output).textContent = percent ? `${Math.round(value * 100)}%` : `${value.toFixed(2)}×`; });
    el<HTMLInputElement>('setShadows').checked = this.values.shadows;
    el<HTMLSelectElement>('setHorde').value = this.values.quality;
    el<HTMLInputElement>('setFull').checked = Boolean(document.fullscreenElement);
  }

  private async setFullscreen(enabled: boolean): Promise<void> {
    try {
      if (enabled && !document.fullscreenElement) await document.documentElement.requestFullscreen();
      else if (!enabled && document.fullscreenElement) await document.exitFullscreen();
      this.fullscreen = enabled; this.save(); this.actions.settingsChanged();
    } catch { this.toast('Fullscreen is unavailable in this browser window.'); }
    this.syncSettings();
  }

  private restore(): void {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE) || 'null'); if (!saved || typeof saved !== 'object') return;
      const settings = saved.settings || {};
      this.values = { master: bounded(settings.master, 0.7, 0, 1), music: bounded(settings.music, 0.45, 0, 1), sfx: bounded(settings.sfx, 0.8, 0, 1), sensitivity: bounded(settings.sensitivity, 1, 0.2, 3), shadows: typeof settings.shadows === 'boolean' ? settings.shadows : true, quality: ['high', 'medium', 'low'].includes(settings.quality) ? settings.quality : 'high' };
      if (Array.isArray(saved.unlocked)) saved.unlocked.forEach((id: unknown) => { if (typeof id === 'string' && ITEMS.some(item => item.id === id)) this.unlocked.add(id); });
      if (saved.equipment && typeof saved.equipment === 'object') { this.equipment = {}; SLOTS.forEach(slot => { const id = saved.equipment[slot]; if (ITEMS.some(item => item.id === id && item.slot === slot) && this.unlocked.has(id)) this.equipment[slot] = id; }); }
      if (MUTATIONS.some(mutation => mutation.id === saved.mutation)) this.mutation = saved.mutation;
      this.fullscreen = saved.fullscreen === true;
    } catch { /* Privacy modes may disallow storage; the loadout remains usable in memory. */ }
  }
  private save(): void {
    try { localStorage.setItem(STORAGE, JSON.stringify({ settings: this.values, equipment: this.equipment, unlocked: [...this.unlocked], mutation: this.mutation, fullscreen: this.fullscreen })); } catch { /* Session-only settings when persistent storage is unavailable. */ }
  }
}
