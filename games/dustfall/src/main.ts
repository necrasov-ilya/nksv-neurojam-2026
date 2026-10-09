import * as T from "three";
import "./style.css";
import { Player } from "./player";
import { createWorld } from "./world";
import { animateOperator } from "./operator";
import { EnemySystem } from "./enemies";
import { AudioSystem } from "./audio";
import { renderLoadout } from "./loadout";
import {
  ITEMS,
  WEAPONS,
  loadSave,
  storeSave,
  newSave,
  addItem,
  removeItem,
  count,
  lootTable,
  type Stack,
} from "./data";
export type AppState =
  | "BOOT"
  | "MAIN_MENU"
  | "LOADOUT"
  | "DEPLOYING"
  | "IN_RAID"
  | "PAUSED"
  | "EXTRACTING"
  | "RAID_SUCCESS"
  | "PLAYER_DEAD";
const app = document.querySelector<HTMLDivElement>("#app")!;
app.innerHTML =
  '<div id="ui"><div class="loading">DUSTFALL / INITIALIZING</div></div><div id="toast"></div><div id="vignette"></div>';
const ui = document.querySelector<HTMLDivElement>("#ui")!;
const renderer = new T.WebGLRenderer({ antialias: true });
renderer.setSize(innerWidth, innerHeight);
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = T.PCFSoftShadowMap;
renderer.toneMapping = T.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.25;
app.prepend(renderer.domElement);
const scene = new T.Scene();
scene.background = new T.Color(0xbac2b1);
scene.fog = new T.FogExp2(0xbac2b1, 0.0055);
const camera = new T.PerspectiveCamera(59, innerWidth / innerHeight, 0.1, 800);
scene.add(new T.HemisphereLight(0xdce4de, 0x535746, 2.1));
const sun = new T.DirectionalLight(0xffecd0, 3.2);
sun.position.set(-45, 80, 40);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, {
  left: -90,
  right: 90,
  top: 90,
  bottom: -90,
  far: 250,
});
sun.shadow.bias = -0.001;
scene.add(sun);
scene.add(sun.target);
const world = createWorld(scene);
const solids = world.solids;
const audio = new AudioSystem();
const enemies = new EnemySystem(scene, world, audio);
const initialContainers = world.containers.slice();
const contents = new Map<number, Stack[]>();
let activeContainer: (typeof world.containers)[number] | undefined;
let searchingContainer: (typeof world.containers)[number] | undefined;
const player = new Player(camera, world);
scene.add(player.mesh);
const extraction = world.extractions[0].clone();
const ring = new T.Mesh(
  new T.RingGeometry(5.6, 6, 48),
  new T.MeshBasicMaterial({ color: 0xe9c67d, side: T.DoubleSide }),
);
ring.rotation.x = -Math.PI / 2;
ring.position.copy(extraction);
ring.position.y = extraction.y + 0.08;
scene.add(ring);
const beam = new T.Mesh(
  new T.CylinderGeometry(1.4, 2.5, 140, 16),
  new T.MeshBasicMaterial({
    color: 0xeac987,
    transparent: true,
    opacity: 0.65,
    depthWrite: false,
    fog: false,
    blending: T.AdditiveBlending,
  }),
);
beam.position.copy(extraction); beam.position.y += 70;
scene.add(beam);
const extractionLight = new T.PointLight(0xffd991,35,30,1.2);scene.add(extractionLight);
const muzzleLight = new T.PointLight(0xffbb65, 0, 7, 2);
scene.add(muzzleLight);
const muzzlePosition = new T.Vector3();
const shotTargets: T.Object3D[] = [];
let footsteps = 0, muzzleTime = 0, criticalHit = false;
const grenades: {mesh:T.Mesh,velocity:T.Vector3,fuse:number}[] = [];
const pulses:{mesh:T.Mesh<T.SphereGeometry,T.MeshBasicMaterial>;life:number}[]=[];
let save = loadSave(),
  state: AppState = "BOOT",
  backpack: Stack[] = [],
  raidWeapons: string[] = [],
  magazines: number[] = [],
  slot = 0,
  raidTime = 0,
  kills = 0,
  extractTime = 0,
  reloadTime = 0,
  healTime = 0,
  shotTimer = 0,
  beaconTimer = 0,
  toastTimer = 0,
  opening = 0,
  inventory = false,
  settings = false,
  shooting = false,
  hitTimer = 0,
  damageFlash = 0;
let latestResult = { time: 0, kills: 0, items: 0, value: 0 };
const RAID_LIMIT = 300;
let sunfall = false, warnedSunfall = false, blastTime = 0;
const flash = document.createElement('div'); flash.id = 'sunfall-flash'; app.append(flash);
const blast = new T.Mesh(new T.SphereGeometry(1,32,20),new T.MeshBasicMaterial({color:0xffc16e,transparent:true,opacity:.7,side:T.DoubleSide,depthWrite:false}));
blast.visible=false;scene.add(blast);
enemies.onBoss = () => { notify('LEVIATHAN HAS ARRIVED — heavy walker detected'); sound('alert'); };
const ray = new T.Raycaster(),
  direction = new T.Vector3(),
  target = new T.Vector3();
const clock = new T.Clock();
let time = 0,
  hudTime = 0;
function sound(name: string, position?: T.Vector3) {
  audio.init();
  audio.setVolumes(save.settings.master, save.settings.sfx, save.settings.music);
  audio.play(name, position);
}
function notify(text: string) {
  document.querySelector("#toast")!.textContent = text;
  toastTimer = 3;
}
function transition(next: AppState) {
  state = next;
  shooting = false;
  player.keys.clear();
  if (next === 'MAIN_MENU' || next === 'LOADOUT') damageFlash = 0;
  if (next !== "IN_RAID" && next !== "EXTRACTING") {
    document.exitPointerLock();
    player.aim = false;
  }
  renderUI();
}
function lock() {
  renderer.domElement
    .requestPointerLock()
    ?.catch(() => notify("Click the scene to capture the mouse."));
}
function weapon() {
  return WEAPONS.find((w) => w.id === raidWeapons[slot]) ?? WEAPONS[0];
}
function cards(stacks: Stack[], mode: string) {
  return stacks
    .map((s, i) => {
      const item = ITEMS[s.id];
      return `<button class="item ${item.rarity.toLowerCase()}" data-${mode}="${i}" title="${item.description} • Value ${item.value}"><span class="icon">${item.icon}</span><b>${item.name}</b><small>${item.rarity}</small><em>×${s.qty}</em></button>`;
    })
    .join("");
}
function renderUI() {
  ui.innerHTML = "";
  if (state === "MAIN_MENU") {
    ui.innerHTML = `<main class="menu"><div class="eyebrow">FIELD OPERATIONS / VOL. 01</div><h1>DUSTFALL</h1><p class="tagline">The world moved on.<br>Something stayed behind.</p><div class="menu-actions"><button id="loadout">DEPLOY <span>↗</span></button><button class="ghost" id="loadout2">LOADOUT</button><button class="ghost" id="settings">SETTINGS</button></div><div class="menu-bottom"><span>SOLO PVE · EXTRACTION</span><span>ASH VALLEY / 17:42</span></div></main>`;
  } else if (state === "LOADOUT") {
    renderLoadout(ui, save, {
      home: () => transition("MAIN_MENU"),
      deploy: () => { sound("ui"); deploy(); },
      change: () => { storeSave(save); player.mesh.userData.weaponId = save.equipment.primary; player.mesh.userData.operatorId = save.equipment.operator; sound("ui"); },
    });
    return;
  } else if (state === "PAUSED") {
    ui.innerHTML =
      '<main class="pause"><small>CONNECTION HELD</small><h1>TAKE A BREATH.</h1><p>The valley can wait.</p><button id="resume">RESUME ↗</button><button class="ghost" id="settings">SETTINGS</button><button class="ghost" id="abandon">ABANDON RAID</button><p>Abandoning loses your carried equipment.</p></main>';
  } else if (state === "DEPLOYING") {
    ui.innerHTML =
      '<main class="deploying"><small>INSERTION IN PROGRESS / 5 MINUTE WINDOW</small><h1>ASH VALLEY</h1><p>Extract before SUNFALL. Follow the gold light. Leviathan arrives at 02:30.</p></main>';
  } else if (state === "RAID_SUCCESS" || state === "PLAYER_DEAD") {
    const success = state === "RAID_SUCCESS";
    ui.innerHTML = `<main class="results"><small>${success ? "UPLINK CONFIRMED / OPERATOR SECURED" : "SIGNAL TERMINATED / NO RECOVERY"}</small><h1>${success ? "RAID COMPLETE" : "OPERATOR LOST"}</h1><p>${success ? "You brought something back. That is enough." : "The valley keeps what it takes."}</p><div class="stats"><div><b>${formatTime(latestResult.time)}</b><small>TIME SURVIVED</small></div><div><b>${latestResult.kills}</b><small>MACHINES DESTROYED</small></div><div><b>${latestResult.items}</b><small>ITEMS ${success ? "EXTRACTED" : "LOST"}</small></div><div><b>${latestResult.value}</b><small>SALVAGE VALUE</small></div></div><button id="return">RETURN TO BASE ↗</button></main>`;
    if(sunfall){ui.querySelector('h1')!.textContent='SUNFALL';ui.querySelector('p')!.textContent='The valley was incinerated. Five-minute extraction window expired. All carried equipment lost.';}
  } else {
    ui.innerHTML =
      '<div class="hud"><div class="compass" id="compass"></div><div class="objective"><small>FIELD OBJECTIVE</small><b>RECOVER. RETURN.</b><span id="distance"></span></div><div id="crosshair">·</div><div id="hitmarker">×</div><div id="interaction"></div><div id="extraction"></div><div class="vitals" id="vitals"></div><div class="weapon-hud" id="weaponhud"></div><div class="hint">WASD MOVE <i>SHIFT SPRINT</i> RMB AIM <i>LMB FIRE</i> E LOOT <i>TAB PACK</i> ESC PAUSE</div><div id="action-progress"></div></div>';
    ui.querySelector('.hud')!.insertAdjacentHTML('beforeend','<div id="raid-clock"></div><div id="boss-hud"></div><div id="extract-guide"></div>');
    if (!save.hinted) ui.querySelector('.hud')!.insertAdjacentHTML('beforeend', '<div id="first-raid-hint" class="controls" style="position:absolute;left:30px;top:215px;max-width:300px;background:#14221cee;padding:16px">FIRST FIELD RUN<br>Click the scene to capture your mouse.<br>E near a crate: search and collect.<br>TAB: inspect and use supplies. Q: heal.<br>Gold beam: stand inside for 7 seconds.<br>Leave before 05:00. Death loses your kit.</div>');
    if (inventory) {
      ui.innerHTML += `<section class="inventory"><header><div><small>FIELD PACK / ${backpack.length} OF 24 SLOTS</small><h2>BACKPACK</h2></div><button id="closepack">CLOSE [TAB]</button></header><div class="grid">${cards(backpack, "pack")}${Array.from({ length: 24 - backpack.length }, () => '<div class="empty-slot"></div>').join("")}</div><p>Select an item for its effect, value and USE button. Right-click to discard. Drag to reorder.<br>Salvage has no combat effect — extract to bring it into your base stash. The raid continues while your pack is open.</p></section>`;
    }
  }
  bind();
}
function bind() {
  const click = (id: string, fn: () => void) =>
    document.getElementById(id)?.addEventListener("click", () => {
      sound("ui");
      fn();
    });
  click("loadout", () => transition("LOADOUT"));
  click("loadout2", () => transition("LOADOUT"));
  click("home", () => transition("MAIN_MENU"));
  click("deploy", deploy);
  click("resume", () => {
    transition("IN_RAID");
    lock();
  });
  click("return", () => transition("LOADOUT"));
  click("abandon", () => {
    if (confirm("Abandon raid and lose carried equipment?")) finish(false);
  });
  click("settings", showSettings);
  click("closepack", toggleInventory);
  document.querySelectorAll<HTMLSelectElement>("[data-equip]").forEach(
    (el) =>
      (el.onchange = () => {
        const key = el.dataset.equip!;
        Object.assign(save.equipment, {
          [key]:
            key === "heal" || key === "utility" ? Number(el.value) : el.value,
        });
        storeSave(save);
      }),
  );
  document.querySelectorAll<HTMLButtonElement>("[data-pack]").forEach((el) => {
    const i = Number(el.dataset.pack);
    el.onclick = () => inspectItem(i);
    el.oncontextmenu = (e) => {
      e.preventDefault();
      const s = backpack.splice(i, 1)[0];
      if (s) notify(`Dropped ${ITEMS[s.id].name}`);
      renderUI();
    };
    el.draggable = true;
    el.ondragstart = (e) => e.dataTransfer?.setData("text/plain", String(i));
    el.ondragover = (e) => e.preventDefault();
    el.ondrop = (e) => {
      e.preventDefault();
      const from = Number(e.dataTransfer?.getData("text/plain"));
      if (Number.isInteger(from) && backpack[from]) {
        [backpack[from], backpack[i]] = [backpack[i], backpack[from]];
        renderUI();
      }
    };
  });
}
function inspectItem(index: number) {
  const stack = backpack[index];
  if (!stack) return;
  const item = ITEMS[stack.id];
  document.getElementById('pack-detail')?.remove();
  const panel = document.createElement('div'); panel.id = 'pack-detail';
  const action = ({patch:'Apply patch · +45 HP / 2s',plate:'Repair armor · +30',beacon:'Deploy decoy · 5s',grenade:'Throw pulse grenade',armor1:'Wear vest · 50 armor',armor2:'Wear vest · 80 armor'} as Record<string,string>)[stack.id] ?? (item.category === 'AMMO' ? 'Reload active weapon' : '');
  panel.innerHTML = `<h3>${item.name}</h3><p>${item.description}</p><p>${item.category === 'MATERIAL' || item.category === 'VALUABLE' ? 'SALVAGE — extract to store at base. No combat effect.' : 'FIELD SUPPLY — use now or extract to keep.'} · Stack value ${item.value*stack.qty} cr</p>${action ? `<button id="pack-use">${action}</button>` : ''}<button id="pack-drop">Drop stack</button>`;
  document.querySelector('.inventory')!.append(panel);
  panel.querySelector('#pack-use')?.addEventListener('click',()=>useItem(index));
  panel.querySelector('#pack-drop')!.addEventListener('click',()=>{backpack.splice(index,1);renderUI();});
}
function itemPulse(position:T.Vector3,color:number) {
  const mesh = new T.Mesh(new T.SphereGeometry(1,16,10),new T.MeshBasicMaterial({color,transparent:true,opacity:.3,wireframe:true,depthWrite:false}));
  mesh.position.copy(position);scene.add(mesh);pulses.push({mesh,life:1});
}
function throwGrenade() {
  if (!removeItem(backpack,'grenade',1)) return;
  camera.getWorldDirection(direction);
  const mesh=new T.Mesh(new T.SphereGeometry(.12,8,6),new T.MeshStandardMaterial({color:0xbba06e,metalness:.6,roughness:.5}));
  mesh.position.copy(player.position);mesh.position.y+=1.5;scene.add(mesh);
  grenades.push({mesh,velocity:direction.clone().multiplyScalar(17).add(new T.Vector3(0,5,0)),fuse:1.4});sound('ui');
}
function deploy() {
  const eq = save.equipment;
  if (!eq.primary || !count(save.stash, eq.primary)) {
    notify("Choose an available primary weapon.");
    return;
  }
  if (eq.secondary === eq.primary && count(save.stash, eq.primary) < 2) {
    notify("Only one copy of that weapon remains.");
    return;
  }
  backpack = [];
  raidWeapons = [eq.primary];
  if (eq.secondary && count(save.stash, eq.secondary)) raidWeapons.push(eq.secondary);
  for (const id of raidWeapons) removeItem(save.stash, id, 1);
  magazines = raidWeapons.map((id) => {
    const w = WEAPONS.find((w) => w.id === id)!;
    const supply = Math.min(count(save.stash, w.ammo), w.mag * save.equipment.ammo);
    removeItem(save.stash, w.ammo, supply);
    const loaded = Math.min(w.mag, supply);
    addItem(backpack, w.ammo, supply - loaded);
    return loaded;
  });
  for (const [id, want] of [
    ["patch", eq.heal],
    ["grenade", eq.utility],
  ] as [string, number][]) {
    const n = Math.min(want, count(save.stash, id));
    removeItem(save.stash, id, n);
    if (n) addItem(backpack, id, n);
  }
  for (const item of eq.extra) {
    const requested = Math.min(item.qty, count(save.stash, item.id));
    const remainder = addItem(backpack, item.id, requested);
    removeItem(save.stash, item.id, requested - remainder);
  }
  player.reset();
  const insertion = [{name:'FIELD CAMP',x:0,z:145},{name:'WEST TREELINE',x:-170,z:145},{name:'EAST APPROACH',x:170,z:145}][(save.stats.raids + 2) % 3];
  player.position.set(insertion.x, world.groundHeight(insertion.x,insertion.z), insertion.z);
  player.mesh.position.copy(player.position);
  player.armor =
    eq.armor && removeItem(save.stash, eq.armor, 1)
      ? eq.armor === "armor2"
        ? 80
        : 50
      : 0;
  save.inRaid = true;
  save.stats.raids++;
  storeSave(save);
  slot = 0;
  raidTime = 0;
  sunfall=false;warnedSunfall=false;blastTime=0;blast.visible=false;flash.style.opacity='0';
  kills = 0;
  extractTime = 0;
  reloadTime = 0;
  healTime = 0;
  opening = 0;
  shotTimer = 0;
  damageFlash = 0;
  searchingContainer = undefined;
  activeContainer = undefined;
  for (const c of world.containers) if (!initialContainers.includes(c)) scene.remove(c.mesh);
  world.containers.splice(0, world.containers.length, ...initialContainers);
  contents.clear();
  for (const c of world.containers) { c.opened = false; c.mesh.visible = true; }
  enemies.reset(player.position);
  extraction.copy(world.extractions[save.stats.raids % world.extractions.length]);
  ring.position.copy(extraction); ring.position.y += .08;
  beam.position.copy(extraction); beam.position.y += 70;
  extractionLight.position.copy(extraction);extractionLight.position.y+=4;
  player.mesh.userData.weaponId = raidWeapons[0];
  player.mesh.userData.operatorId = eq.operator;
  inventory = false;
  transition("DEPLOYING");
  setTimeout(() => {
    transition("IN_RAID");
    notify(`${insertion.name} / Find salvage, then follow the north uplink.`);
  }, 900);
}
function finish(success: boolean) {
  if(state !== 'IN_RAID' && state !== 'EXTRACTING' && state !== 'PAUSED') return;
  latestResult = {
    time: raidTime,
    kills,
    items: backpack.reduce((n, s) => n + s.qty, 0) + raidWeapons.length,
    value: backpack.reduce((n, s) => n + ITEMS[s.id].value * s.qty, 0),
  };
  save.inRaid = false;
  save.stats.kills += kills;
  if (success) {
    save.stats.wins++;
    save.stats.value += latestResult.value;
    for (const s of backpack) addItem(save.stash, s.id, s.qty, 9999);
    for (let i = 0; i < raidWeapons.length; i++) {
      addItem(save.stash, raidWeapons[i], 1, 9999);
      if (magazines[i])
        addItem(
          save.stash,
          WEAPONS.find((w) => w.id === raidWeapons[i])!.ammo,
          magazines[i],
          9999,
        );
    }
    if (player.armor > 0 && save.equipment.armor)
      addItem(save.stash, save.equipment.armor, 1, 9999);
    sound("success");
  } else {
    player.mesh.rotation.z = -1.5;
    sound("damage");
  }
  if (!save.stash.some((s) => ITEMS[s.id].category === "WEAPON")) {
    addItem(save.stash, "carbine", 1, 9999);
    addItem(save.stash, "rifleAmmo", 90, 9999);
    addItem(save.stash, "patch", 2, 9999);
  }
  storeSave(save);
  transition(success ? "RAID_SUCCESS" : "PLAYER_DEAD");
}
function toggleInventory() {
  if (state !== "IN_RAID" && state !== "EXTRACTING") return;
  inventory = !inventory;
  shooting = false;
  player.keys.clear();
  if (inventory) document.exitPointerLock();
  else lock();
  renderUI();
}
function useItem(index: number) {
  const item = backpack[index];
  if (!item) return;
  if (item.id === "patch") {
    startHeal();
  } else if (item.id === "plate" && player.armor < 80) {
    player.armor = Math.min(80, player.armor + 30);
    removeItem(backpack, "plate", 1);
    notify("Armor repaired +30");
    sound("heal");
    itemPulse(player.position,0x7dbde6);
  } else if (item.id === "beacon") {
    removeItem(backpack, "beacon", 1);
    target.copy(player.position).add(new T.Vector3(25, 0, -15));
    enemies.hear(target, 100, "decoy");
    notify("Decoy signal transmitted");
    sound("beacon", target);
    itemPulse(target,0xe6bc69);
  } else if (item.id === 'grenade') {
    throwGrenade();
  } else if (item.id === 'armor1' || item.id === 'armor2') {
    const armor=item.id==='armor2'?80:50;
    if(player.armor<armor){player.armor=armor;removeItem(backpack,item.id,1);itemPulse(player.position,0x7dbde6);sound('heal');}
    else notify('Current armor is stronger. Keep this vest as salvage.');
  } else if (ITEMS[item.id].category === 'AMMO') {
    if(item.id===weapon().ammo) reload();else notify('Switch to the matching weapon first.');
  } else notify(ITEMS[item.id].description);
  renderUI();
}
function startHeal() {
  if (healTime || player.hp >= 100 || !count(backpack, "patch")) return;
  healTime = 2;
  notify("Applying field patch…");
  sound("heal");
}
function reload() {
  if (
    reloadTime ||
    magazines[slot] >= weapon().mag ||
    !count(backpack, weapon().ammo)
  )
    return;
  reloadTime = weapon().reload;
  sound("reload");
}
const tracerGeo = new T.CylinderGeometry(0.018, 0.018, 1, 4),
  tracerMat = new T.MeshBasicMaterial({ color: 0xffe2a6 });
const effects = Array.from({ length: 48 }, () => {
  const mesh = new T.Mesh(tracerGeo, tracerMat);
  mesh.visible = false;
  scene.add(mesh);
  return { mesh, life: 0 };
});
let fxIndex = 0;
const up = new T.Vector3(0, 1, 0),
  diff = new T.Vector3();
function tracer(a: T.Vector3, b: T.Vector3) {
  const fx = effects[fxIndex++ % effects.length];
  diff.copy(b).sub(a);
  fx.mesh.position.copy(a).addScaledVector(diff, 0.5);
  fx.mesh.scale.set(1, diff.length(), 1);
  fx.mesh.quaternion.setFromUnitVectors(up, diff.normalize());
  fx.mesh.visible = true;
  fx.life = 0.06;
}
function fire() {
  if (reloadTime || shotTimer > 0) return;
  const w = weapon();
  if (!magazines[slot]) {
    shotTimer = 0.2;
    sound("empty");
    return;
  }
  magazines[slot]--;
  shotTimer = w.interval;
  healTime = 0;
  player.recoil = 1;
  camera.getWorldDirection(direction);
  direction.x += (Math.random() - 0.5) * w.spread * (player.aim ? 0.3 : 1);
  direction.y += (Math.random() - 0.5) * w.spread * (player.aim ? 0.3 : 1);
  direction.normalize();
  ray.set(camera.position, direction);
  ray.far = 220;
  shotTargets.length = 0;
  shotTargets.push(...solids);
  for (const enemy of enemies.enemies) if (enemy.hp > 0) enemy.mesh.traverse((o: T.Object3D) => { if ((o as T.Mesh).isMesh) shotTargets.push(o); });
  const hits = ray.intersectObjects(shotTargets, false);
  target.copy(camera.position).addScaledVector(direction, 150);
  if (hits.length) {
    target.copy(hits[0].point);
    const result = enemies.hit(hits[0].object, w.damage * Math.max(.35, 1 - Math.max(0, hits[0].distance - w.range) / (w.range * 2)), hits[0].point);
    if (result.hit) {
      hitTimer = .18; criticalHit = result.critical; sound("hit", target);
      if (result.killed) notify(`${result.type.toUpperCase()} DISABLED / SALVAGE AVAILABLE`);
    }
    kills = enemies.kills;
  }
  muzzlePosition.copy(player.position).addScaledVector(direction, .85);
  muzzlePosition.y += 1.5;
  tracer(muzzlePosition, target);
  muzzleLight.position.copy(muzzlePosition); muzzleLight.intensity = 8; muzzleTime = .055;
  enemies.hear(player.position, w.id === "scout" ? 110 : 80);
  player.pitch = Math.min(
    0.55,
    player.pitch + (w.id === "scout" ? 0.021 : 0.007),
  );
  sound(`shoot-${w.id}`, player.position);
}
function damage(amount: number) {
  if(state !== 'IN_RAID' && state !== 'EXTRACTING') return;
  const absorbed = Math.min(player.armor, amount * 0.45);
  player.armor -= absorbed;
  player.hp = Math.max(0, player.hp - (amount - absorbed));
  damageFlash = 0.5;
  sound("damage");
  if (player.hp <= 0) finish(false);
}
function interact() {
  if (opening > 0 || !activeContainer) return;
  searchingContainer = activeContainer;
  opening = .8;
  sound("reload", activeContainer.position);
}
function formatTime(t: number) {
  return `${Math.floor(t / 60)
    .toString()
    .padStart(2, "0")}:${Math.floor(t % 60)
    .toString()
    .padStart(2, "0")}`;
}
function showSettings() {
  settings = true;
  const panel = document.createElement("section");
  panel.className = "settings";
  panel.innerHTML = `<small>PERSONAL PREFERENCES</small><h2>SETTINGS</h2>${(["sensitivity", "master", "sfx", "music"] as const).map((k) => `<label>${k.toUpperCase()}<input aria-label="${k}" data-setting="${k}" type="range" min="0" max="${k === "sensitivity" ? 3 : 1}" step=".05" value="${save.settings[k]}"></label>`).join("")}<label>GRAPHICS QUALITY<select id="quality">${["LOW", "MEDIUM", "HIGH"].map((q) => `<option ${save.settings.quality === q ? "selected" : ""}>${q}</option>`).join("")}</select></label><label>INVERT Y<input id="invert" type="checkbox" ${save.settings.invert ? "checked" : ""}></label><button id="fullscreen">FULLSCREEN</button><button id="reset">RESET SAVE</button><div class="controls">WASD Move · Mouse Look · Shift Sprint · C Crouch<br>Space Vault · E Interact · LMB Fire · RMB Aim<br>R Reload · 1/2 Weapons · Q Heal · G Grenade<br>Tab Backpack · Esc Pause</div><button id="settingsclose">BACK</button>`;
  ui.append(panel);
  panel.querySelectorAll<HTMLInputElement>("[data-setting]").forEach(
    (el) =>
      (el.oninput = () => {
        Object.assign(save.settings, {
          [el.dataset.setting!]: Number(el.value),
        });
        storeSave(save);
      }),
  );
  panel.querySelector<HTMLSelectElement>("#quality")!.onchange = (e) => {
    save.settings.quality = (e.target as HTMLSelectElement).value;
    applyQuality();
    storeSave(save);
  };
  panel.querySelector<HTMLInputElement>("#invert")!.onchange = (e) => {
    save.settings.invert = (e.target as HTMLInputElement).checked;
    storeSave(save);
  };
  panel.querySelector("#fullscreen")!.addEventListener("click", () => {
    if (document.fullscreenElement) void document.exitFullscreen();
    else void document.documentElement.requestFullscreen();
  });
  panel.querySelector("#reset")!.addEventListener("click", () => {
    if (confirm("Permanently erase all DUSTFALL progress?")) {
      save = newSave();
      storeSave(save);
      location.reload();
    }
  });
  panel.querySelector("#settingsclose")!.addEventListener("click", () => {
    settings = false;
    panel.remove();
  });
}
function applyQuality() {
  const q = save.settings.quality;
  renderer.setPixelRatio(
    q === "LOW"
      ? 0.8
      : q === "HIGH"
        ? Math.min(devicePixelRatio, 2)
        : Math.min(devicePixelRatio, 1.25),
  );
  renderer.shadowMap.enabled = q !== "LOW";
}
window.addEventListener("keydown", (e) => {
  if (["Tab", "Space", "KeyW", "KeyA", "KeyS", "KeyD"].includes(e.code))
    e.preventDefault();
  if (settings) return;
  if (e.code === "Escape") {
    if (inventory) {
      inventory = false;
      renderUI();
    } else if (state === "IN_RAID" || state === "EXTRACTING")
      transition("PAUSED");
    return;
  }
  if (state !== "IN_RAID" && state !== "EXTRACTING") return;
  if (e.code === "Tab" && !e.repeat) {
    toggleInventory();
    return;
  }
  if (inventory) return;
  player.keys.add(e.code);
  if (e.code === "Space") player.vault();
  if (e.code === "KeyR") reload();
  if (e.code === "KeyQ") startHeal();
  if (e.code === "KeyE") interact();
  if (e.code === "Digit1" || e.code === "Digit2") {
    const n = e.code === "Digit1" ? 0 : 1;
    if (raidWeapons[n] && n !== slot) {
      slot = n;
      player.mesh.userData.weaponId = raidWeapons[slot];
      reloadTime = 0;
      shotTimer = 0.25;
    }
  }
  if (e.code === 'KeyG' && !e.repeat) throwGrenade();
});
window.addEventListener("keyup", (e) => player.keys.delete(e.code));
window.addEventListener("mousemove", (e) => {
  if (document.pointerLockElement && !inventory)
    player.look(
      e.movementX,
      e.movementY,
      save.settings.sensitivity,
      save.settings.invert,
    );
});
renderer.domElement.addEventListener("mousedown", (e) => {
  if (state !== "IN_RAID" && state !== "EXTRACTING") return;
  if (!document.pointerLockElement) {
    lock();
    return;
  }
  if (e.button === 0) {
    shooting = true;
    fire();
  }
  if (e.button === 2) player.aim = true;
});
window.addEventListener("mouseup", (e) => {
  if (e.button === 0) shooting = false;
  if (e.button === 2) player.aim = false;
});
addEventListener("contextmenu", (e) => e.preventDefault());
document.addEventListener("pointerlockchange", () => {
  if (
    !document.pointerLockElement &&
    !inventory &&
    (state === "IN_RAID" || state === "EXTRACTING")
  )
    transition("PAUSED");
});
addEventListener("blur", () => {
  if (state === "IN_RAID" || state === "EXTRACTING") transition("PAUSED");
});
addEventListener("resize", () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});
document.addEventListener("save-error", () =>
  notify("Storage unavailable. Progress cannot be persisted."),
);
function updateHUD() {
  const $ = (id: string) => document.getElementById(id);
  if (!$("vitals")) return;
  $("vitals")!.innerHTML =
    `<div><b>${Math.ceil(player.hp)}</b><span>HEALTH</span><meter min="0" max="100" value="${player.hp}"></meter></div><div><b>${Math.ceil(player.armor)}</b><span>ARMOR</span><meter max="80" value="${player.armor}"></meter></div><div><b>${Math.ceil(player.stamina)}</b><span>STAMINA</span><meter max="100" value="${player.stamina}"></meter></div>`;
  const w = weapon();
  $("weaponhud")!.innerHTML =
    `<small>${slot + 1} / ${w.id === "shotgun" ? "PUMP ACTION" : w.id === "scout" ? "SEMI AUTO" : "FULL AUTO"}</small><h3>${w.name}</h3><b>${magazines[slot]} <span>/ ${count(backpack, w.ammo)}</span></b><small>${raidWeapons[1 - slot] ? `[${2 - slot}] ${ITEMS[raidWeapons[1 - slot]].name}` : ""}</small>`;
  $("compass")!.textContent =
    `W ───── NW ───── N / ${(((player.yaw * 180) / Math.PI + 360) % 360).toFixed(0)}° ───── NE ───── E`;
  $("distance")!.textContent =
    `NORTH GANTRY / ${Math.round(player.position.distanceTo(extraction))} M · ${formatTime(raidTime)}`;
  const remaining=Math.max(0,RAID_LIMIT-raidTime);
  $('raid-clock')!.innerHTML=`<small>SUNFALL IN</small><b>${formatTime(Math.ceil(remaining))}</b><span>${remaining<=30?'EVACUATE NOW — VALLEY DETONATION':'Extract before the valley burns'}</span>`;
  $('raid-clock')!.classList.toggle('urgent',remaining<=30);
  const boss=enemies.boss;
  $('boss-hud')!.innerHTML=boss ? boss.hp>0 ? `<small>LEVIATHAN / ${Math.round(boss.position.distanceTo(player.position))} M</small><progress max="${boss.maxHp}" value="${boss.hp}"></progress><b>${Math.ceil(boss.hp)} / ${boss.maxHp}</b>` : '<small>LEVIATHAN DESTROYED</small>' : `<small>LEVIATHAN ARRIVES IN ${formatTime(Math.ceil(Math.max(0,enemies.bossClock)))}</small>`;
  const bearing=Math.atan2(extraction.x-player.position.x,player.position.z-extraction.z)-player.yaw;
  $('extract-guide')!.innerHTML=`<b style="display:inline-block;transform:rotate(${bearing}rad)">↑</b> GOLD LIGHT · EXTRACTION`;
  $("interaction")!.textContent = opening > 0 ? "SEARCHING…" : activeContainer ? "[ E ] SEARCH SALVAGE" : "";
  $("extraction")!.innerHTML = extractTime
    ? `<small>UPLINK ESTABLISHING — STAY INSIDE</small><h3>${Math.ceil(7 - extractTime)} ${Math.ceil(7 - extractTime) === 1 ? "SECOND" : "SECONDS"}</h3><progress value="${extractTime}" max="7"></progress>`
    : "";
  $("hitmarker")!.style.opacity = hitTimer > 0 ? "1" : "0";
  $("hitmarker")!.style.color = criticalHit ? "#f7cf76" : "#ece9d7";
  $("crosshair")!.className = player.aim ? "ads" : "";
  $("action-progress")!.textContent = healTime
    ? `FIELD PATCH / ${healTime.toFixed(1)}s`
    : reloadTime
      ? `RELOADING / ${reloadTime.toFixed(1)}s`
      : "";
}
applyQuality();
transition("MAIN_MENU");
function frame(elapsed: number) {
  const dt = Math.min(.04, elapsed);
  for(let i=pulses.length-1;i>=0;i--){const p=pulses[i];p.life-=dt;p.mesh.scale.setScalar(1+(1-p.life)*8);p.mesh.material.opacity=Math.max(0,p.life*.3);if(p.life<=0){scene.remove(p.mesh);p.mesh.geometry.dispose();p.mesh.material.dispose();pulses.splice(i,1);}}
  time += dt;
  toastTimer -= dt;
  if (toastTimer <= 0) document.querySelector("#toast")!.textContent = "";
  for (const fx of effects)
    if (fx.life > 0) {
      fx.life -= dt;
      fx.mesh.visible = fx.life > 0;
    }
  if(state==='IN_RAID'||state==='EXTRACTING'){
    if(!warnedSunfall&&raidTime+elapsed>=270){warnedSunfall=true;notify('SUNFALL IN 30 SECONDS — EXTRACT NOW');sound('alert');}
    if(raidTime+elapsed>=RAID_LIMIT){raidTime=RAID_LIMIT;sunfall=true;blastTime=3;blast.position.copy(player.position);blast.position.z-=45;blast.position.y+=5;blast.visible=true;blast.scale.setScalar(1);sound('grenade');finish(false);}
  }
  if (state === "IN_RAID" || state === "EXTRACTING") {
    raidTime += elapsed;
    if (!save.hinted && raidTime >= 30) {
      save.hinted = true;
      storeSave(save);
      document.getElementById('first-raid-hint')?.remove();
    }
    shotTimer -= dt;
    hitTimer -= dt;
    damageFlash = Math.max(0, damageFlash - dt);
    if (!inventory) player.update(dt, time, reloadTime > 0);
    if (shooting && (weapon().id === "carbine" || weapon().id === "smg")) fire();
    if (reloadTime > 0) {
      reloadTime -= dt;
      if (reloadTime <= 0) {
        const n = Math.min(
          weapon().mag - magazines[slot],
          count(backpack, weapon().ammo),
        );
        removeItem(backpack, weapon().ammo, n);
        magazines[slot] += n;
        reloadTime = 0;
        sound("reload");
      }
    }
    if (healTime > 0) {
      if (player.sprinting || shooting) healTime = 0;
      else {
        healTime -= dt;
        if (healTime <= 0 && removeItem(backpack, "patch", 1)) {
          player.hp = Math.min(100, player.hp + 45);
          notify("Field patch applied +45 HP");
          healTime = 0;
          sound("heal");
          itemPulse(player.position,0x8bd3a0);
          if(inventory) renderUI();
        }
      }
    }
    activeContainer = undefined;
    let closest = 3.5;
    for (const c of world.containers) {
      if (c.opened && !contents.get(c.id)?.length) continue;
      const distance = player.position.distanceTo(c.position);
      if (distance < closest) { closest = distance; activeContainer = c; }
    }
    if (opening > 0 && searchingContainer) {
      if (player.position.distanceTo(searchingContainer.position) > 4) { opening = 0; searchingContainer = undefined; }
      else {
        opening = Math.max(0, opening - dt);
        if (opening === 0) {
          const c = searchingContainer;
          const found = contents.get(c.id) ?? lootTable(c.tier);
          const names: string[] = [];
          contents.set(c.id, found.flatMap(s => {
            const remainder = addItem(backpack, s.id, s.qty);
            if (remainder < s.qty) names.push(ITEMS[s.id].name);
            return remainder ? [{id:s.id,qty:remainder}] : [];
          }));
          c.opened = true;
          notify(contents.get(c.id)!.length ? "Backpack full. Free a slot." : `RECOVERED / ${names.join(" · ")}`);
          enemies.hear(c.position, c.tier > 1 ? 50 : 12);
          sound("loot", c.position);
          searchingContainer = undefined;
        }
      }
    }
    enemies.update(dt, time, player.position, player.crouching, damage, raidTime);
    kills = enemies.kills;
    for (let i = grenades.length - 1; i >= 0; i--) {
      const g = grenades[i]; g.fuse -= dt; g.velocity.y -= dt * 15; g.mesh.position.addScaledVector(g.velocity, dt);
      const floor = world.groundHeight(g.mesh.position.x,g.mesh.position.z) + .12;
      if (g.mesh.position.y < floor) { g.mesh.position.y = floor; g.velocity.multiplyScalar(.45); g.velocity.y = Math.abs(g.velocity.y); }
      if (g.fuse <= 0) {
        for (const enemy of enemies.enemies) if (enemy.hp > 0 && enemy.position.distanceTo(g.mesh.position) < 9) enemies.hit(enemy.mesh, 145, enemy.position);
        itemPulse(g.mesh.position,0xffbc68);
        enemies.hear(g.mesh.position, 120); sound("grenade",g.mesh.position); scene.remove(g.mesh);g.mesh.geometry.dispose();(g.mesh.material as T.Material).dispose();grenades.splice(i,1);
      }
    }
    if (player.moving > 1 && !inventory) { footsteps -= dt; if (footsteps <= 0) { sound(player.sprinting ? "sprint" : "step",player.position); footsteps = player.sprinting ? .28 : .43; } }
    audio.update(player.position, direction.set(Math.sin(player.yaw),0,-Math.cos(player.yaw)), enemies.threat / 100);
    if (state === "IN_RAID" || state === "EXTRACTING") {
      const inZone = player.position.distanceTo(extraction) < 6;
      if (inZone) {
        beaconTimer -= dt;
        if (beaconTimer <= 0) { sound("beacon",extraction); enemies.hear(extraction,90); beaconTimer = 1; }
        extractTime += dt;
        state = "EXTRACTING";
        if (extractTime >= 7) finish(true);
      } else {
        extractTime = 0;
        state = "IN_RAID";
      }
    }
    hudTime -= dt;
    if (hudTime <= 0) {
      updateHUD();
      hudTime = 0.07;
    }
  } else if (state === "MAIN_MENU" || state === "LOADOUT") {
    const floor = world.groundHeight(0,145);
    player.mesh.position.set(0, floor, 145);
    player.mesh.rotation.set(0, .35, 0);
    player.mesh.userData.weaponId = save.equipment.primary;
    player.mesh.userData.operatorId = save.equipment.operator;
    animateOperator(player.mesh, time, 0, false, 0, 0);
    if (state === "LOADOUT") {
      camera.position.set(2.5, floor + 1.65, 149.8);
      camera.lookAt(1.85, floor + 1.0, 145);
    } else {
      camera.position.set(8 + Math.sin(time * .08) * 1.2, floor + 3.8, 153);
      camera.lookAt(-7, floor + 3, 117);
    }
    camera.fov = 50;
    camera.updateProjectionMatrix();
  }
  document.querySelector<HTMLElement>("#vignette")!.style.opacity =
    String(damageFlash);
  ring.rotation.z = time * 0.12;
  const beamDistance = Math.hypot(camera.position.x - extraction.x, camera.position.z - extraction.z);
  beam.material.opacity = (0.12 + 0.48 * Math.min(1, Math.max(0, (beamDistance - 6) / 24))) * (1 + Math.sin(time * 2) * .2);
  if(blastTime>0){blastTime=Math.max(0,blastTime-dt);blast.scale.setScalar(1+(3-blastTime)*100);blast.material.opacity=blastTime/3*.7;flash.style.opacity=String(Math.min(1,blastTime/1.8));if(blastTime===0)blast.visible=false;}
  world.update(time,dt);
  muzzleTime -= dt; if (muzzleTime <= 0) muzzleLight.intensity = 0;
  sun.position.set(player.position.x - 45, player.position.y + 80, player.position.z + 40);
  sun.target.position.copy(player.position);
  renderer.render(scene, camera);
}
renderer.setAnimationLoop(() => frame(clock.getDelta()));
