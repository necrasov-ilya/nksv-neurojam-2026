import { ITEMS, WEAPONS, count, type Save, type Stack } from './data';
import './loadout.css';

type Kit = Save['equipment'] & { operator: string; ammo: number; extra?: Stack[] };
type Actions = { home: () => void; deploy: () => void; change: () => void };
type Slot = 'primary' | 'secondary' | 'armor';
const operators = ['wayfarer', 'mender', 'ranger'];
const operatorNotes = ['A steady hand beyond the wall.', 'Leave no one in the dust.', 'Read the horizon. Move unseen.'];
const escape = (s: string) => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
const number = (n: number) => n.toLocaleString('en-US');
const weapon = (id: string) => WEAPONS.find(w => w.id === id);

function icon(id: string, className = '') {
  const shapes: Record<string, string> = {
    carbine: '<path d="M8 35h15l8-10h38l8 5h28v5H78l-4 6H52l-5 17H36l5-19H29L13 49H7z"/><path d="M49 20h18v5H49zm34 17h13v4H83z"/>',
    smg: '<path d="M14 32h16l9-8h35l6 5h20v6H79l-9 7H56l-3 17H41V42H28L13 45z"/><path d="M44 19h20v5H44zm30 23h7v9h-7z"/>',
    scout: '<path d="M5 38h23l8-7h45l5 2h24v4H83l-4 6H53l-4 12H39l3-13H30L9 50H5z"/><path d="M47 21h23v8H47zm-4 1h5v6h-5zm27-1h5v8h-5z"/>',
    shotgun: '<path d="M7 37h25l7-7h33l8 3h29v5H76l-7 7H50l-3 12H36l4-14H30L10 51H6z"/><path d="M66 40h30v6H66z"/>',
    armor1: '<path d="M40 13l11 7h18l11-7 9 15-10 9v27H41V37l-10-9z"/><path d="M49 36h22v17H49z" fill="var(--kit-surface)"/>',
    armor2: '<path d="M40 13l11 7h18l11-7 9 15-10 9v27H41V37l-10-9z"/><path d="M48 32h24v24H48z" fill="var(--kit-surface)"/><path d="M52 37h16v14H52z"/>',
    plate: '<path d="M45 16h30l7 11v25L60 66 38 52V27z"/><path d="M48 29h24v4H48zm0 10h24v4H48z" fill="var(--kit-surface)"/>',
    patch: '<path d="M35 20h50v42H35z"/><path d="M56 28h8v10h10v8H64v10h-8V46H46v-8h10z" fill="var(--kit-surface)"/>',
    grenade: '<path d="M52 13h16v11l9 9v24l-9 9H51l-9-9V33l10-9z"/><path d="M69 15h8l9 23-5 3-9-20h-3z"/>',
    beacon: '<path d="M48 41h24v23H48zm9-24h6v24h-6z"/><path d="M47 19q-14 12 0 24m26-24q14 12 0 24M39 12q-23 19 0 38m42-38q23 19 0 38" fill="none" stroke="currentColor" stroke-width="3"/>',
  };
  let shape = shapes[id];
  if (!shape && ITEMS[id]?.category === 'AMMO') shape = '<path d="M34 29l6-12 6 12v34H34zm20 0l6-12 6 12v34H54zm20 0l6-12 6 12v34H74z"/>';
  if (!shape) shape = '<path d="M41 21h38v38H41zM35 28h6v5h-6zm0 13h6v5h-6zm0 13h6v5h-6zm44-26h6v5h-6zm0 13h6v5h-6zm0 13h6v5h-6z"/><path d="M50 30h20v20H50z" fill="var(--kit-surface)"/>';
  return `<svg class="kit-icon ${className}" viewBox="0 0 120 80" aria-hidden="true" fill="currentColor">${shape}</svg>`;
}

/** Selection is a reservation; only deployment removes items from base storage. */
export function renderLoadout(host: HTMLElement, save: Save, actions: Actions) {
  const kit = save.equipment as Kit;
  kit.operator = operators.includes(kit.operator) ? kit.operator : 'wayfarer';
  kit.ammo = Math.max(1, Math.min(5, Math.floor(kit.ammo || 3)));
  kit.extra ??= [];
  let category = 'ALL';
  let active: Slot = 'primary';
  let selected = kit.primary || save.stash.find(s => ITEMS[s.id])?.id || '';
  let notice = '';

  function totals() {
    const reserved: Record<string, number> = {};
    const backpack: Record<string, number> = {};
    const add = (dest: Record<string, number>, id: string, qty: number) => { if (id && qty > 0) dest[id] = (dest[id] || 0) + qty; };
    for (const slot of ['primary', 'secondary', 'armor'] as const) add(reserved, kit[slot], 1);
    for (const slot of ['primary', 'secondary'] as const) {
      const w = weapon(kit[slot]);
      if (w) {
        add(reserved, w.ammo, w.mag * kit.ammo);
        add(backpack, w.ammo, w.mag * (kit.ammo - 1));
      }
    }
    for (const [id, qty] of [['patch', kit.heal], ['grenade', kit.utility]] as const) {
      add(reserved, id, qty); add(backpack, id, qty);
    }
    for (const s of kit.extra || []) { add(reserved, s.id, s.qty); add(backpack, s.id, s.qty); }
    const slots = Object.entries(backpack).reduce((n, [id, qty]) => n + Math.ceil(qty / (ITEMS[id]?.stack || 1)), 0);
    const risk = Object.entries(reserved).reduce((n, [id, qty]) => n + (ITEMS[id]?.value || 0) * qty, 0);
    const value = save.stash.reduce((n, s) => n + (ITEMS[s.id]?.value || 0) * s.qty, 0);
    const reasons: string[] = [];
    if (!weapon(kit.primary)) reasons.push('Equip a primary weapon.');
    if (kit.secondary && !weapon(kit.secondary)) reasons.push('Replace the invalid secondary weapon.');
    for (const [id, qty] of Object.entries(reserved)) {
      const available = count(save.stash, id);
      if (qty > available) reasons.push(`${ITEMS[id]?.name || id}: need ${qty}, only ${available} in base.`);
    }
    if (slots > 24) reasons.push(`Backpack is ${slots - 24} slots over capacity.`);
    return { reserved, slots, risk, value, reasons };
  }

  function commit() { actions.change(); draw(); }
  function take(id: string, delta: number) {
    notice = '';
    const current = totals();
    const available = count(save.stash, id) - (current.reserved[id] || 0);
    if (delta > 0 && available <= 0) { notice = `All ${ITEMS[id].name} already reserved. Nothing was duplicated.`; draw(); return; }
    const beforeHeal = kit.heal, beforeUtility = kit.utility;
    const beforeExtra = (kit.extra || []).map(s => ({ ...s }));
    if (id === 'patch') kit.heal = Math.max(0, kit.heal + delta);
    else if (id === 'grenade') kit.utility = Math.max(0, kit.utility + delta);
    else {
      const extra = kit.extra!.find(s => s.id === id);
      if (extra) extra.qty = Math.max(0, extra.qty + delta);
      else if (delta > 0) kit.extra!.push({ id, qty: 1 });
      kit.extra = kit.extra!.filter(s => s.qty > 0);
    }
    if (delta > 0 && totals().slots > 24) {
      kit.heal = beforeHeal; kit.utility = beforeUtility; kit.extra = beforeExtra;
      notice = 'Backpack full. Return a packed item to reserve space.';
      draw(); return;
    }
    commit();
  }

  function equip(id: string, slot: Slot) {
    notice = '';
    const old = kit[slot];
    kit[slot] = id;
    if ((totals().reserved[id] || 0) > count(save.stash, id)) {
      kit[slot] = old;
      notice = `No spare ${ITEMS[id].name}. Unequip the other slot first.`;
      draw(); return;
    }
    selected = id;
    commit();
  }

  function detail(id: string) {
    const item = ITEMS[id];
    if (!item) return '<div class="kit-detail-empty">Select an item to inspect and pack it.</div>';
    const w = weapon(id);
    const stats = w ? `<div><span>DAMAGE</span><b>${w.damage}</b></div><div><span>MAGAZINE</span><b>${w.mag} rounds</b></div><div><span>RELOAD</span><b>${w.reload}s</b></div>` : `<div><span>STACK SIZE</span><b>${item.stack}</b></div><div><span>IN BASE</span><b>${count(save.stash, id)}</b></div>`;
    return `<div class="kit-detail-heading">${icon(id)}<div><span class="kit-kicker">${item.rarity} / ${item.category}</span><h3>${escape(item.name)}</h3></div></div><p>${escape(item.description)}</p><div class="kit-detail-stats">${stats}<div><span>UNIT VALUE</span><b>${number(item.value)} cr</b></div></div><div class="kit-detail-actions">${w ? `<button data-assign="primary" data-id="${id}">Equip primary [1]</button><button data-assign="secondary" data-id="${id}">Equip secondary [2]</button>` : id === 'armor1' || id === 'armor2' ? `<button data-assign="armor" data-id="${id}">Wear armor</button>` : `<button data-take="${id}">Pack one →</button>`}<span>${['MATERIAL','VALUABLE'].includes(item.category) ? 'Salvage: extract to keep its value. No combat use.' : 'Inspect first. Use a button to change your kit.'}</span></div>`;
  }

  function draw() {
    const scrollTop = host.querySelector('.kit-storage')?.scrollTop || 0;
    const screenScrollTop = host.querySelector('.kit-screen')?.scrollTop || 0;
    const focused = document.activeElement instanceof HTMLElement && host.contains(document.activeElement) ? document.activeElement : null;
    const focusAttribute = focused ? Array.from(focused.attributes).find(a => a.name.startsWith('data-')) : null;
    const focusSelector = focused?.id ? `#${focused.id}` : focusAttribute ? `[${focusAttribute.name}="${focusAttribute.value}"]` : '';
    const t = totals();
    const ids = [...new Set(save.stash.filter(s => s.qty > 0 && ITEMS[s.id]).map(s => s.id))];
    const filtered = ids.filter(id => category === 'ALL' || (category === 'WEAPONS' ? ITEMS[id].category === 'WEAPON' : category === 'SALVAGE' ? ['MATERIAL', 'VALUABLE'].includes(ITEMS[id].category) : !['WEAPON', 'MATERIAL', 'VALUABLE'].includes(ITEMS[id].category)));
    const ammoIds = [...new Set([kit.primary, kit.secondary].map(id => weapon(id)?.ammo).filter((id): id is string => !!id))];
    const steppers = (id: string, qty: number, label: string) => `<div class="kit-pack-row"><span>${label}</span><div class="kit-stepper"><button data-minus="${id}" aria-label="Return one ${label}" ${qty <= 0 ? 'disabled' : ''}>−</button><b>${qty}</b><button data-take="${id}" aria-label="Pack one ${label}" ${count(save.stash, id) <= (t.reserved[id] || 0) || t.slots >= 24 && qty % ITEMS[id].stack === 0 ? 'disabled' : ''}>+</button></div><small>${Math.max(0, count(save.stash, id) - (t.reserved[id] || 0))} in reserve</small></div>`;
    host.innerHTML = `<section class="kit-screen" aria-label="Expedition loadout">
      <div class="kit-header"><button id="home" class="kit-back" aria-label="Back to base">← BASE</button><div><span class="kit-kicker">EXPEDITION PREPARATION</span><h2>PACK FOR THE UNKNOWN<span>.</span></h2></div><div class="kit-base-value"><span class="kit-kicker">BASE INVENTORY</span><strong>${number(t.value)} <small>cr</small></strong></div></div>
      <div class="kit-layout"><section class="kit-operator" aria-label="Operator and equipment">
        <div class="kit-operator-top"><span class="kit-kicker">01 / YOUR OPERATOR</span><div class="kit-operator-tabs" role="group" aria-label="Operator">${operators.map(name => `<button data-operator="${name}" aria-pressed="${kit.operator === name}">${name}</button>`).join('')}</div><p>${operatorNotes[operators.indexOf(kit.operator)]}</p></div>
        <div class="kit-character-clear" aria-hidden="true"><span>LIVE FIELD PREVIEW</span><i></i></div>
        <div class="kit-equipment"><div class="kit-equipment-heading"><span class="kit-kicker">EQUIPPED HARDWARE</span><span>Choose a slot, then a weapon</span></div><div class="kit-equipment-cards">${(['primary', 'secondary', 'armor'] as const).map(slot => `<div class="kit-equipment-card ${slot === active ? 'kit-active' : ''}"><button class="kit-slot" data-equip="${slot}" aria-pressed="${slot === active}"><span class="kit-kicker">${slot}</span>${kit[slot] ? icon(kit[slot]) : '<span class="kit-empty-gear">—</span>'}<b>${kit[slot] ? escape(ITEMS[kit[slot]]?.name || 'Unknown') : 'Empty slot'}</b><small>${kit[slot] ? `${Math.max(0, count(save.stash, kit[slot]) - (t.reserved[kit[slot]] || 0))} spare in base` : slot === 'primary' ? 'Required to deploy' : 'Optional'}</small></button>${kit[slot] ? `<button class="kit-unequip" data-unequip="${slot}" aria-label="Unequip ${slot}">Return to stash</button>` : ''}</div>`).join('')}</div></div>
      </section><section class="kit-storage" aria-label="Stash and packing"><div class="kit-stash-head"><div><span class="kit-kicker">02 / BASE STASH</span><h3>Take only what you need.</h3></div><span>${ids.length} item types</span></div>
      <div class="kit-tabs" role="tablist" aria-label="Stash categories">${['ALL', 'WEAPONS', 'SUPPLIES', 'SALVAGE'].map(tab => `<button role="tab" data-category="${tab}" aria-selected="${category === tab}">${tab}</button>`).join('')}</div>
      <div class="kit-stash-grid" role="tabpanel" aria-label="${category.toLowerCase()} stash">${filtered.map(id => { const item = ITEMS[id], packed = t.reserved[id] || 0; return `<button class="kit-item kit-rarity-${item.rarity.toLowerCase()} ${id === selected ? 'kit-selected' : ''}" data-item="${id}" aria-label="${escape(item.name)}, ${count(save.stash, id)} in base, ${packed} selected" aria-pressed="${packed > 0}"><span class="kit-item-category">${item.category}</span><span class="kit-item-qty">×${count(save.stash, id)}</span>${icon(id)}<b>${escape(item.name)}</b><small>${packed ? `${packed} selected · ` : ''}${Math.max(0, count(save.stash, id) - packed)} reserve</small></button>`; }).join('') || '<div class="kit-empty-stash">No items in this category. Bring salvage home from an expedition.</div>'}</div>
      <div class="kit-detail" aria-label="Item information">${detail(selected)}</div>
      <div class="kit-manifest"><div class="kit-manifest-head"><span class="kit-kicker">03 / PACKING MANIFEST</span><span class="${t.slots > 24 ? 'kit-warning' : ''}">${t.slots} / 24 backpack slots</span></div><div class="kit-manifest-hardware">${(['primary', 'secondary', 'armor'] as const).map(slot => `<span><small>${slot}</small>${escape(ITEMS[kit[slot]]?.name || 'None')}</span>`).join('')}</div><div class="kit-pack-controls">${steppers('patch', kit.heal, 'Field patches')}${steppers('grenade', kit.utility, 'Pulse grenades')}</div><label class="kit-ammo-label" for="kit-ammo"><span>AMMUNITION <small>Loaded magazine included</small></span><b>${kit.ammo} ${kit.ammo === 1 ? 'magazine' : 'magazines'} / weapon</b></label><input id="kit-ammo" type="range" min="1" max="5" step="1" value="${kit.ammo}" aria-label="Total magazines per weapon"><div class="kit-ammo-summary">${ammoIds.map(id => `<span class="${(t.reserved[id] || 0) > count(save.stash, id) ? 'kit-warning' : ''}">${ITEMS[id].name}<b>${t.reserved[id] || 0} needed / ${count(save.stash, id)} available</b></span>`).join('') || '<span>Equip a weapon to calculate ammunition.</span>'}</div>${kit.extra!.length ? `<div class="kit-extra"><span class="kit-kicker">ADDITIONAL CARGO</span>${kit.extra!.map(s => `<div><span>${escape(ITEMS[s.id]?.name || s.id)} <b>×${s.qty}</b></span><button data-minus="${s.id}" aria-label="Return one ${escape(ITEMS[s.id]?.name || s.id)}">− 1</button><button data-return="${s.id}">Return all</button></div>`).join('')}</div>` : ''}<p class="kit-selection-note">Selected items stay in your stash until deployment. This is a reservation, not a duplicate.</p></div>
      </section></div><div class="kit-footer"><button class="kit-clear" data-clear>Clear loadout</button><div class="kit-risk"><span class="kit-kicker">AT RISK</span><b>${number(t.risk)} <small>cr</small></b><span>${number(Math.max(0, t.value - t.risk))} cr remains at base</span></div><div class="kit-deploy-area"><p class="${t.reasons.length ? 'kit-warning' : ''}" role="status">${notice ? escape(notice) : t.reasons.length ? escape(t.reasons.join(' ')) : 'Kit ready. Extract alive to bring it home.'}</p><button id="deploy" class="kit-deploy" ${t.reasons.length ? 'disabled' : ''} aria-describedby="kit-deploy-reason">DEPLOY <span>→</span></button><span id="kit-deploy-reason" class="kit-sr-only">${escape(t.reasons.join(' ') || 'All equipment available.')}</span></div></div>
    </section>`;
    const left = host.querySelector('.kit-operator')!;
    left.append(host.querySelector('.kit-manifest')!);
    host.querySelector('.kit-operator-top > .kit-kicker')!.textContent = '01 / YOUR RAID KIT — TAKEN INTO THE FIELD';
    host.querySelector('.kit-stash-head h3')!.textContent = 'Base stash — stays safe here';
    host.querySelector('.kit-equipment-heading > span:last-child')!.textContent = 'Inspect right → Equip explicitly';
    host.querySelector('.kit-manifest-hardware')!.remove();
    host.querySelector('.kit-selection-note')!.textContent = 'Left: equipment and supplies you will carry. Right: base stock. Only DEPLOY removes the selected kit from storage.';
    host.querySelector('#home')!.addEventListener('click', actions.home);
    host.querySelector('#deploy')!.addEventListener('click', () => { if (!totals().reasons.length) actions.deploy(); });
    host.querySelectorAll<HTMLElement>('[data-category]').forEach(el => el.onclick = () => { category = el.dataset.category!; draw(); });
    host.querySelectorAll<HTMLElement>('[data-operator]').forEach(el => el.onclick = () => { kit.operator = el.dataset.operator!; commit(); });
    host.querySelectorAll<HTMLElement>('[data-equip]').forEach(el => el.onclick = () => { active = el.dataset.equip as Slot; category = active === 'armor' ? 'SUPPLIES' : 'WEAPONS'; if (kit[active]) selected = kit[active]; notice = `Choose an item on the right, then press Equip ${active}.`; draw(); });
    host.querySelectorAll<HTMLElement>('[data-unequip]').forEach(el => el.onclick = () => { kit[el.dataset.unequip as Slot] = ''; notice = ''; commit(); });
    host.querySelectorAll<HTMLElement>('[data-item]').forEach(el => {
      el.onclick = () => { selected = el.dataset.item!; notice = ''; draw(); host.querySelector('.kit-detail')?.scrollIntoView({block:'nearest'}); };
    });
    host.querySelectorAll<HTMLElement>('[data-minus]').forEach(el => el.onclick = () => take(el.dataset.minus!, -1));
    host.querySelectorAll<HTMLElement>('[data-return]').forEach(el => el.onclick = () => { kit.extra = kit.extra!.filter(s => s.id !== el.dataset.return); notice = ''; commit(); });
    host.querySelector<HTMLElement>('[data-clear]')!.onclick = () => { kit.primary = ''; kit.secondary = ''; kit.armor = ''; kit.heal = 0; kit.utility = 0; kit.ammo = 1; kit.extra = []; notice = ''; commit(); };
    host.querySelector<HTMLInputElement>('#kit-ammo')!.onchange = e => { kit.ammo = Number((e.currentTarget as HTMLInputElement).value); notice = ''; commit(); };
    bindDetail();
    host.querySelector('.kit-storage')!.scrollTop = scrollTop;
    host.querySelector('.kit-screen')!.scrollTop = screenScrollTop;
    if (focusSelector) host.querySelector<HTMLElement>(focusSelector)?.focus({ preventScroll: true });
  }
  function bindDetail() {
    host.querySelectorAll<HTMLElement>('[data-assign]').forEach(el => el.onclick = () => equip(el.dataset.id!, el.dataset.assign as Slot));
    host.querySelectorAll<HTMLElement>('[data-take]').forEach(el => el.onclick = () => take(el.dataset.take!, 1));
  }
  draw();
}
