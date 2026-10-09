import * as T from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

type RobotType = 'Watcher' | 'Hound' | 'Warden' | 'Strider' | 'Leviathan';
type RobotState = 'IDLE' | 'PATROL' | 'SUSPICIOUS' | 'INVESTIGATE' | 'COMBAT' | 'SEARCH' | 'RETURN';
type Container = { id: number; position: T.Vector3; mesh: T.Group; tier: number; opened: boolean };
type World = {
  solids: T.Object3D[];
  colliders: { x: number; z: number; hx: number; hz: number; height: number }[];
  groundHeight(x: number, z: number): number;
  containers: Container[];
};
type Audio = { play(name: string, position?: T.Vector3): void };
type Leg = { pivot: T.Group; knee: T.Group; phase: number };
type Rig = { body: T.Group; legs: Leg[]; rotors: T.Group[]; guns: T.Group[]; core: T.MeshStandardMaterial; eyeHeight: number };
type Agent = {
  mesh: T.Group; position: T.Vector3; type: RobotType; hp: number; maxHp: number; state: RobotState;
  rig: Rig; home: T.Vector3; lastKnown: T.Vector3; goal: T.Vector3; aim: T.Vector3;
  patrolAngle: number; phase: number; stateTime: number; sightClock: number; visible: boolean;
  memory: number; suspicion: number; cooldown: number; windup: number; burst: number; distraction: number;
  searchAngle: number; speed: number; deathTime: number; hitFlash: number; strafe: number;
  wreck: Container;
};
const UP = new T.Vector3(0, 1, 0);
const specs = {
  Watcher: { hp: 95, speed: 4.9, radius: 1.2, sight: 55, range: 36, damage: 9, windup: .8, interval: 2.4 },
  Hound: { hp: 150, speed: 7.4, radius: .9, sight: 44, range: 3.6, damage: 19, windup: .65, interval: 1.9 },
  Warden: { hp: 340, speed: 2.7, radius: 1.35, sight: 62, range: 52, damage: 12, windup: 1.05, interval: 3.9 },
  Strider: { hp: 120, speed: 5.4, radius: .55, sight: 50, range: 34, damage: 10, windup: .9, interval: 2.9 },
  Leviathan: { hp: 1400, speed: 3.4, radius: 3.2, sight: 90, range: 58, damage: 26, windup: 1.5, interval: 3.4 },
};
const robotZones = [[-65, 70], [-95, -65], [80, -45], [0, 0], [115, 65], [5, -135], [-40, 10], [60, 40], [-130, -110], [125, 5], [45, -135], [-20, -70]];
const robotFormation: RobotType[] = ['Watcher', 'Hound', 'Warden', 'Hound'];
const scavengerHomes = [[-125, 20], [58, 93], [55, -105], [115, 120]];
const reinforcementTypes: RobotType[] = ['Watcher', 'Hound', 'Hound', 'Warden', 'Warden', 'Watcher'];
const initialRobotCount = robotZones.length * robotFormation.length;
const initialCount = initialRobotCount + scavengerHomes.length;
const metal = (color: number, roughness = .65, metalness = .7) => new T.MeshStandardMaterial({ color, roughness, metalness });
const armor = metal(0x777e70), edges = metal(0xb0aa90, .43), dark = metal(0x242e2d, .72), steel = metal(0x9ba4a0, .3, .85);
const ochre = metal(0xc89947, .55), ceramic = metal(0xb8b6a0, .7), black = metal(0x111a1b, .5);
const jacket = metal(0x386264, .94, .02), fabric = metal(0x675641, 1, 0), skin = metal(0xa78261, .96, 0);
const mergedGeometryCache = new Map<string, T.BufferGeometry>();
function mergeJointParts(root: T.Group, rig: Rig, type: RobotType) {
  const joints = [root, rig.body, ...rig.legs.flatMap(leg => [leg.pivot, leg.knee]), ...rig.rotors, ...rig.guns];
  const boundaries = new Set<T.Object3D>(joints);
  root.updateMatrixWorld(true);
  for (let j = 0; j < joints.length; j++) {
    const joint = joints[j], batches = new Map<T.Material, { regular: T.Mesh[]; core: T.Mesh[] }>();
    const collect = (object: T.Object3D) => {
      if (object !== joint && boundaries.has(object)) return;
      if (object instanceof T.Mesh && object.children.length === 0 && !Array.isArray(object.material)) {
        let batch = batches.get(object.material);
        if (!batch) { batch = { regular: [], core: [] }; batches.set(object.material, batch); }
        (object.userData.core ? batch.core : batch.regular).push(object);
      }
      for (const child of object.children) collect(child);
    };
    collect(joint);
    const inverse = new T.Matrix4().copy(joint.matrixWorld).invert(), transform = new T.Matrix4();
    let batchIndex = 0;
    for (const [material, batch] of batches) for (const parts of [batch.regular, batch.core]) {
      const key = `${type}:${j}:${batchIndex++}`;
      if (parts.length < 2) continue;
      let geometry = mergedGeometryCache.get(key);
      if (!geometry) {
        const geometries = parts.map(part => {
          const geometry = part.geometry.index ? part.geometry.toNonIndexed() : part.geometry.clone();
          transform.multiplyMatrices(inverse, part.matrixWorld);
          return geometry.applyMatrix4(transform);
        });
        geometry = mergeGeometries(geometries, false) ?? undefined;
        for (const geometry of geometries) geometry.dispose();
        if (!geometry) continue;
        mergedGeometryCache.set(key, geometry);
      }
      const merged = new T.Mesh(geometry, material);
      merged.castShadow = true; merged.receiveShadow = true;
      if (parts === batch.core) merged.userData.core = true;
      for (const part of parts) part.removeFromParent();
      joint.add(merged);
    }
  }
}
const geometries = new Map<string, T.BufferGeometry>();
function cached(key: string, create: () => T.BufferGeometry) { let g = geometries.get(key); if (!g) { g = create(); geometries.set(key, g); } return g; }
function panelGeometry(w: number, h: number, d: number) {
  return cached(`p${w},${h},${d}`, () => {
    const b = Math.min(w, h, d) * .18, x = w / 2 - b, y = h / 2 - b, c = Math.min(x, y) * .23;
    const shape = new T.Shape();
    shape.moveTo(-x + c, -y); shape.lineTo(x - c, -y); shape.lineTo(x, -y + c); shape.lineTo(x, y - c);
    shape.lineTo(x - c, y); shape.lineTo(-x + c, y); shape.lineTo(-x, y - c); shape.lineTo(-x, -y + c); shape.closePath();
    const geo = new T.ExtrudeGeometry(shape, { depth: Math.max(.01, d - b * 2), bevelEnabled: true, bevelSegments: 2, steps: 1, bevelSize: b, bevelThickness: b, curveSegments: 1 });
    geo.center(); return geo;
  });
}
function mesh(parent: T.Object3D, geo: T.BufferGeometry, material: T.Material, x: number, y: number, z: number) {
  const part = new T.Mesh(geo, material); part.position.set(x, y, z); part.castShadow = true; part.receiveShadow = true; parent.add(part); return part;
}
function panel(parent: T.Object3D, w: number, h: number, d: number, material: T.Material, x: number, y: number, z: number) { return mesh(parent, panelGeometry(w, h, d), material, x, y, z); }
function cylinder(parent: T.Object3D, r: number, length: number, material: T.Material, x: number, y: number, z: number, r2 = r) {
  return mesh(parent, cached(`c${r},${r2},${length}`, () => new T.CylinderGeometry(r, r2, length, 10)), material, x, y, z);
}
function sphere(parent: T.Object3D, r: number, material: T.Material, x: number, y: number, z: number) { return mesh(parent, cached(`s${r}`, () => new T.SphereGeometry(r, 12, 8)), material, x, y, z); }
function ring(parent: T.Object3D, r: number, tube: number, material: T.Material, x: number, y: number, z: number) {
  return mesh(parent, cached(`t${r},${tube}`, () => new T.TorusGeometry(r, tube, 6, 20)), material, x, y, z);
}
function rod(parent: T.Object3D, a: number[], b: number[], radius: number, material: T.Material) {
  const start = new T.Vector3(...a as [number, number, number]), end = new T.Vector3(...b as [number, number, number]);
  const diff = end.sub(start), part = cylinder(parent, radius, diff.length(), material, 0, 0, 0);
  part.position.copy(start).addScaledVector(diff, .5); part.quaternion.setFromUnitVectors(UP, diff.normalize()); return part;
}
function bolts(parent: T.Object3D, w: number, h: number, z: number) {
  for (const x of [-w / 2 + .1, w / 2 - .1]) for (const y of [-h / 2 + .1, h / 2 - .1]) cylinder(parent, .038, .045, steel, x, y, z).rotation.x = Math.PI / 2;
}
function plated(parent: T.Object3D, w: number, h: number, d: number, material: T.Material, x: number, y: number, z: number) {
  const plate = new T.Group(); plate.position.set(x, y, z); parent.add(plate); panel(plate, w, h, d, material, 0, 0, 0); bolts(plate, w, h, d / 2 + .01); return plate;
}
function buildRobot(type: RobotType) {
  const root = new T.Group(), body = new T.Group(); root.add(body);
  const core = new T.MeshStandardMaterial({ color: 0xffd18a, emissive: 0xff762d, emissiveIntensity: 1.6, roughness: .25, metalness: .35 });
  const rig: Rig = { body, legs: [], rotors: [], guns: [], core, eyeHeight: 1.5 };
  const sensor = (parent: T.Object3D, radius: number, x: number, y: number, z: number) => {
    ring(parent, radius + .045, .065, steel, x, y, z);
    const lens = sphere(parent, radius, core, x, y, z); lens.scale.z = .45; lens.userData.core = true;
    return lens;
  };
  if (type === 'Watcher') {
    body.position.y = 3.55; rig.eyeHeight = 3.55;
    panel(body, 1.3, .86, 1.32, dark, 0, 0, 0);
    plated(body, 1.37, .56, .22, armor, 0, .3, .15).rotation.x = -.3;
    plated(body, .8, .32, .2, ochre, 0, -.28, .66).rotation.x = -.4;
    for (const side of [-1, 1]) {
      plated(body, .35, .78, .9, armor, side * .6, -.02, 0).rotation.z = side * -.25;
      rod(body, [side * .5, 0, -.22], [side * 1.42, .05, -.18], .12, steel);
      rod(body, [side * .42, -.25, .3], [side * 1.3, -.1, .15], .065, dark);
      const duct = new T.Group(); duct.position.set(side * 1.42, .1, -.12); body.add(duct);
      ring(duct, .68, .13, armor, 0, 0, 0).rotation.x = Math.PI / 2;
      ring(duct, .69, .045, edges, 0, .13, 0).rotation.x = Math.PI / 2;
      ring(duct, .54, .035, black, 0, -.055, 0).rotation.x = Math.PI / 2;
      cylinder(duct, .15, .28, dark, 0, 0, 0);
      const rotor = new T.Group(); duct.add(rotor); rig.rotors.push(rotor);
      for (let n = 0; n < 5; n++) {
        const blade = new T.Group(); blade.rotation.y = n * Math.PI * 2 / 5; rotor.add(blade);
        panel(blade, .2, .055, .52, steel, 0, 0, .32).rotation.z = .2;
      }
      for (let n = 0; n < 3; n++) {
        const angle = n * Math.PI * 2 / 3;
        rod(duct, [Math.sin(angle) * .15, .17, Math.cos(angle) * .15], [Math.sin(angle) * .63, .17, Math.cos(angle) * .63], .027, edges);
      }
      panel(body, .25, .09, .92, ochre, side * 1.45, .23, -.15).rotation.y = side * .25;
    }
    const face = panel(body, .85, .62, .3, black, 0, 0, .68); face.rotation.x = -.1;
    sensor(body, .255, 0, .045, .88);
    for (const side of [-1, 1]) sensor(body, .065, side * .41, .2, .79);
    const gun = new T.Group(); gun.position.set(0, -.49, .22); body.add(gun); rig.guns.push(gun);
    sphere(gun, .16, dark, 0, 0, 0); cylinder(gun, .09, .61, steel, 0, -.035, .35).rotation.x = Math.PI / 2;
    ring(gun, .092, .025, black, 0, -.035, .66);
    for (const side of [-1, 1]) {
      rod(body, [side * .38, .35, -.43], [side * .62, .85, -.57], .022, steel);
      sphere(body, .04, ochre, side * .62, .85, -.57);
    }
    for (let n = 0; n < 5; n++) panel(body, .65, .035, .05, steel, 0, -.19 + n * .085, -.69);
  } else if (type === 'Hound') {
    body.position.y = 1.56; rig.eyeHeight = 1.62;
    panel(body, .96, .66, 1.72, dark, 0, 0, -.08);
    for (let n = 0; n < 4; n++) plated(body, 1.04, .2, .36, n === 0 ? ochre : armor, 0, .34 + Math.sin(n) * .04, .48 - n * .39).rotation.x = -.16;
    for (const side of [-1, 1]) {
      cylinder(body, .17, 1.27, dark, side * .54, -.06, -.15).rotation.x = Math.PI / 2;
      for (let n = 0; n < 5; n++) ring(body, .17, .035, steel, side * .54, -.06, .32 - n * .21);
      plated(body, .19, .48, .68, armor, side * .62, .02, .17).rotation.z = side * -.22;
      rod(body, [side * .25, -.18, -.66], [side * .35, .18, .79], .045, steel);
    }
    const head = new T.Group(); head.position.set(0, .04, .95); body.add(head);
    cylinder(head, .23, .35, steel, 0, 0, -.17).rotation.x = Math.PI / 2;
    plated(head, .77, .44, .66, ochre, 0, .08, .19).rotation.x = -.16;
    panel(head, .67, .24, .31, black, 0, -.13, .54);
    sensor(head, .15, 0, .055, .54);
    for (const side of [-1, 1]) {
      panel(head, .14, .24, .36, ceramic, side * .29, -.24, .49).rotation.x = -.3;
      panel(head, .09, .38, .18, armor, side * .34, .33, -.04).rotation.z = side * -.3;
    }
    for (const side of [-1, 1]) for (const front of [-1, 1]) {
      const pivot = new T.Group(); pivot.position.set(side * .56, 1.47, front * .6); root.add(pivot);
      cylinder(pivot, .22, .3, dark, side * .05, 0, 0).rotation.z = Math.PI / 2;
      cylinder(pivot, .145, .34, edges, side * .05, 0, 0).rotation.z = Math.PI / 2;
      rod(pivot, [side * .16, 0, 0], [side * .39, -.55, front * -.25], .12, dark);
      const cap = plated(pivot, .3, .62, .28, armor, side * .27, -.28, front * -.13); cap.rotation.z = side * .34; cap.rotation.x = front * -.35;
      rod(pivot, [side * .12, -.02, .12], [side * .39, -.58, front * -.25 + .12], .04, steel);
      const knee = new T.Group(); knee.position.set(side * .4, -.61, front * -.26); pivot.add(knee);
      sphere(knee, .155, steel, 0, 0, 0);
      rod(knee, [0, 0, 0], [side * .07, -.66, front * .39], .085, dark);
      rod(knee, [side * .11, .04, .02], [side * .13, -.48, front * .32], .036, steel);
      panel(knee, .19, .55, .23, ceramic, side * .06, -.31, front * .18).rotation.x = front * -.48;
      panel(knee, .35, .13, .49, dark, side * .08, -.74, front * .38);
      for (const toe of [-1, 1]) panel(knee, .09, .095, .27, steel, side * .08 + toe * .105, -.76, front * .4 + .18);
      rig.legs.push({ pivot, knee, phase: side === front ? 0 : Math.PI });
    }
    const tail = rod(body, [0, .15, -.9], [0, .5, -1.65], .055, dark); tail.userData.tail = true;
    sensor(body, .12, 0, .27, -.84);
  } else if (type === 'Strider') {
    body.position.y = 1.45; rig.eyeHeight = 1.93;
    core.color.setHex(0x91d2cb); core.emissive.setHex(0x378d94);
    panel(body, .68, .72, .39, jacket, 0, -.03, 0);
    panel(body, .43, .36, .13, dark, 0, .04, .24);
    for (const side of [-1, 1]) {
      panel(body, .19, .2, .14, fabric, side * .2, -.24, .27);
      panel(body, .065, .69, .055, fabric, side * .23, 0, .24).rotation.z = side * .09;
      panel(body, .29, .28, .42, jacket, side * .36, .19, 0).rotation.z = side * .2;
    }
    panel(body, .58, .75, .37, fabric, 0, .06, -.35);
    panel(body, .41, .25, .15, ochre, 0, -.16, -.57);
    cylinder(body, .12, .58, steel, -.4, .04, -.35);
    rod(body, [.29, .35, -.4], [.3, 1.13, -.42], .012, steel);
    cylinder(body, .105, .19, skin, 0, .42, 0);
    sphere(body, .23, skin, 0, .65, .01).scale.set(.88, 1.14, .88);
    sphere(body, .27, dark, 0, .78, -.025).scale.set(1, .7, 1);
    panel(body, .47, .09, .46, armor, 0, .73, .045);
    panel(body, .39, .12, .06, black, 0, .67, .22);
    panel(body, .29, .065, .035, core, 0, .67, .26).userData.core = true;
    panel(body, .27, .15, .13, fabric, 0, .51, .19);
    const gun = new T.Group(); gun.position.set(.16, -.04, .31); body.add(gun); rig.guns.push(gun);
    rod(gun, [.23, .18, -.25], [.31, -.17, -.04], .12, jacket);
    rod(gun, [.31, -.17, -.04], [.09, -.12, .2], .085, fabric);
    rod(gun, [-.46, .18, -.23], [-.4, -.15, .09], .12, jacket);
    rod(gun, [-.4, -.15, .09], [-.04, -.09, .4], .085, fabric);
    panel(gun, .15, .18, .69, dark, 0, 0, .17);
    panel(gun, .18, .13, .3, ochre, 0, -.02, .39);
    panel(gun, .1, .3, .16, black, 0, -.2, .1).rotation.x = -.18;
    cylinder(gun, .041, .51, steel, 0, .03, .72).rotation.x = Math.PI / 2;
    panel(gun, .06, .07, .12, steel, 0, .14, .22);
    panel(root, .51, .25, .32, fabric, 0, 1.01, 0);
    for (const side of [-1, 1]) {
      const pivot = new T.Group(); pivot.position.set(side * .17, .96, 0); root.add(pivot);
      panel(pivot, .25, .45, .29, fabric, 0, -.21, 0);
      panel(pivot, .13, .2, .21, jacket, side * .13, -.16, 0);
      const knee = new T.Group(); knee.position.y = -.44; pivot.add(knee);
      panel(knee, .25, .19, .13, armor, 0, -.04, .17);
      panel(knee, .21, .35, .23, fabric, 0, -.21, 0);
      panel(knee, .27, .18, .41, dark, 0, -.42, .085);
      rig.legs.push({ pivot, knee, phase: side > 0 ? 0 : Math.PI });
    }
  } else if (type === 'Warden') {
    body.position.y = 2.94; rig.eyeHeight = 3.27;
    panel(body, 1.65, 1.35, .97, dark, 0, 0, 0);
    for (const side of [-1, 1]) {
      plated(body, .64, 1.05, .3, armor, side * .58, .07, .5).rotation.z = side * -.22;
      plated(body, .8, .35, 1.04, ceramic, side * .61, .66, -.03).rotation.z = side * .16;
      plated(body, .38, .76, .28, ochre, side * .86, -.19, .15).rotation.z = side * .19;
      cylinder(body, .24, 1.1, dark, side * .66, -.04, -.69);
      ring(body, .24, .055, steel, side * .66, .35, -.69).rotation.x = Math.PI / 2;
      cylinder(body, .115, .55, steel, side * .66, .7, -.69);
      for (let n = 0; n < 5; n++) panel(body, .36, .055, .16, black, side * .66, -.36 + n * .15, -.91);
      const gun = new T.Group(); gun.position.set(side * 1.19, .06, -.03); body.add(gun); rig.guns.push(gun);
      sphere(gun, .29, steel, 0, .12, 0);
      plated(gun, .57, .8, .7, armor, side * .03, -.13, .05);
      rod(gun, [side * .18, .21, -.17], [side * .18, -.56, .18], .055, steel);
      panel(gun, .49, .37, 1.11, dark, 0, -.54, .49);
      plated(gun, .58, .23, .64, ochre, 0, -.3, .52);
      for (const offset of [-.12, .12]) {
        cylinder(gun, .095, 1.05, steel, offset, -.53, 1).rotation.x = Math.PI / 2;
        cylinder(gun, .125, .2, dark, offset, -.53, 1.52).rotation.x = Math.PI / 2;
        ring(gun, .093, .034, edges, offset, -.53, 1.63);
      }
      for (let n = 0; n < 4; n++) panel(gun, .09, .29, .3, edges, side * .29, -.52, .17 + n * .2);
    }
    ring(body, .37, .09, dark, 0, .02, .58);
    sensor(body, .285, 0, .02, .65);
    for (const side of [-1, 1]) rod(body, [side * .32, .28, .68], [side * .17, -.29, .74], .035, steel);
    panel(body, .78, .27, .76, steel, 0, .79, 0);
    plated(body, .69, .38, .5, armor, 0, 1.02, .05);
    panel(body, .51, .105, .05, core, 0, 1.04, .32).userData.core = true;
    for (const side of [-1, 1]) sensor(body, .065, side * .26, .96, .33);
    const pelvis = panel(root, 1.06, .42, .67, dark, 0, 1.98, 0);
    plated(pelvis, .63, .29, .2, ochre, 0, .02, .36);
    for (const side of [-1, 1]) {
      const pivot = new T.Group(); pivot.position.set(side * .53, 1.95, 0); root.add(pivot);
      cylinder(pivot, .25, .3, steel, side * .08, 0, 0).rotation.z = Math.PI / 2;
      rod(pivot, [0, 0, 0], [side * .09, -.78, .11], .16, dark);
      plated(pivot, .51, .72, .49, armor, side * .05, -.38, .15).rotation.x = -.1;
      rod(pivot, [side * .28, -.05, -.1], [side * .3, -.75, .03], .06, steel);
      const knee = new T.Group(); knee.position.set(side * .1, -.83, .14); pivot.add(knee);
      cylinder(knee, .21, .52, dark, 0, 0, 0).rotation.z = Math.PI / 2;
      plated(knee, .56, .36, .22, ochre, 0, 0, .24);
      rod(knee, [0, -.05, 0], [0, -.81, -.13], .16, dark);
      plated(knee, .49, .72, .39, ceramic, 0, -.49, .04).rotation.x = .15;
      for (const rodSide of [-1, 1]) rod(knee, [rodSide * .23, -.1, -.12], [rodSide * .23, -.8, -.2], .047, steel);
      panel(knee, .69, .23, .97, dark, 0, -.97, .17);
      plated(knee, .66, .18, .46, armor, 0, -.87, .42);
      for (const toe of [-1, 0, 1]) panel(knee, .16, .07, .24, steel, toe * .2, -1.08, .61);
      rig.legs.push({ pivot, knee, phase: side > 0 ? 0 : Math.PI });
    }
  } else if (type === 'Leviathan') {
    body.position.y = 5.6; rig.eyeHeight = 6.4;
    core.color.setHex(0xffd2a0); core.emissive.setHex(0xd8482a);
    panel(body, 3.4, 2.4, 2.2, dark, 0, 0, 0);
    plated(body, 1.3, 1.1, .5, armor, 0, .6, 1.1).rotation.x = -.28;
    plated(body, 1.9, .5, .7, ochre, 0, -.75, .95).rotation.x = -.35;
    for (const side of [-1, 1]) {
      plated(body, .9, 1.7, 1.6, ceramic, side * 1.35, .1, 0).rotation.z = side * -.2;
      cylinder(body, .42, 2.1, dark, side * 1.15, -.5, -.9);
      ring(body, .43, .1, steel, side * 1.15, .5, -.9).rotation.x = Math.PI / 2;
      const gun = new T.Group(); gun.position.set(side * 1.9, -.35, .5); body.add(gun); rig.guns.push(gun);
      sphere(gun, .5, steel, 0, .2, 0);
      plated(gun, 1, 1.4, .9, armor, 0, -.3, 0);
      cylinder(gun, .19, 2.1, steel, 0, -.65, 1.35).rotation.x = Math.PI / 2;
      cylinder(gun, .24, .35, dark, 0, -.65, 2.4).rotation.x = Math.PI / 2;
      ring(gun, .2, .06, edges, 0, -.65, 2.6);
      for (let n = 0; n < 3; n++) plated(gun, .18, .6, .4, ochre, side * .5, -.2 + n * .4, -.3);
    }
    sensor(body, .62, 0, .1, 1.35);
    for (const side of [-1, 1]) sensor(body, .14, side * .55, 1.15, .8);
    panel(body, .9, .35, 1.7, steel, 0, 1.35, -.2).userData.core = true;
    panel(body, 1.6, .55, .8, armor, 0, 1.75, -.2);
    for (let n = 0; n < 4; n++) panel(body, .5, .09, .5, black, 0, .95 - n * .5, -1.25);
    const pelvis = panel(root, 2.2, .8, 1.4, dark, 0, 3.9, 0);
    plated(pelvis, 1.2, .5, .4, ochre, 0, .1, .7);
    for (const side of [-1, 1]) {
      const pivot = new T.Group(); pivot.position.set(side * 1, 3.8, 0); root.add(pivot);
      cylinder(pivot, .45, .55, steel, side * .15, 0, 0).rotation.z = Math.PI / 2;
      rod(pivot, [0, 0, 0], [side * .16, -1.5, .25], .3, dark);
      plated(pivot, 1, 1.4, .9, armor, side * .1, -.72, .3).rotation.x = -.12;
      const knee = new T.Group(); knee.position.set(side * .18, -1.6, .3); pivot.add(knee);
      cylinder(knee, .38, .9, dark, 0, 0, 0).rotation.z = Math.PI / 2;
      plated(knee, 1.1, .7, .4, ochre, 0, 0, .5);
      rod(knee, [0, -.05, 0], [0, -1.5, -.3], .28, dark);
      plated(knee, 1, 1.4, .7, ceramic, 0, -.95, -.1).rotation.x = .18;
      panel(knee, 1.4, .5, 1.8, dark, 0, -1.9, .35);
      plated(knee, 1.3, .35, .8, armor, 0, -2.15, .8);
      for (const toe of [-1, 0, 1]) panel(knee, .32, .14, .5, steel, toe * .42, -2.15, 1.15);
      rig.legs.push({ pivot, knee, phase: side > 0 ? 0 : Math.PI });
    }
  }
  mergeJointParts(root, rig, type);
  return { mesh: root, rig };
}

export class EnemySystem {
  enemies: Agent[] = [];
  threat = 0;
  kills = 0;
  private pool: Agent[] = [];
  private ray = new T.Raycaster();
  private hits: T.Intersection[] = [];
  private origin = new T.Vector3();
  private direction = new T.Vector3();
  private target = new T.Vector3();
  private movement = new T.Vector3();
  private muzzle = new T.Vector3();
  private end = new T.Vector3();
  private point = new T.Vector3();
  private player = new T.Vector3(0, 0, 145);
  private camp = new T.Vector3(0, 0, 145);
  private fx: { mesh: T.Mesh; velocity: T.Vector3; life: number; duration: number; tracer: boolean }[] = [];
  private fxIndex = 0;
  private elapsed = 0;
  private reinforcements = 0;
  private reinforcementClock = 14;
  private damageClock = 0;
  private alertHeat = 0;
  private wrecks = new Set<T.Group>();
  constructor(private scene: T.Scene, private world: World, private audio: Audio) {
    const total = initialCount + reinforcementTypes.length + 1;
    for (let i = 0; i < total; i++) {
      const type = i < initialRobotCount ? robotFormation[i % robotFormation.length] : i < initialCount ? 'Strider' : i < total - 1 ? reinforcementTypes[i - initialCount] : 'Leviathan';
      const model = buildRobot(type), wreckMesh = new T.Group();
      if (type === 'Strider') {
        panel(wreckMesh, .66, .35, .76, fabric, 0, .22, 0).rotation.z = -.14;
        panel(wreckMesh, .48, .14, .36, jacket, 0, .43, .13);
        panel(wreckMesh, .1, .12, .94, dark, .34, .12, .04).rotation.y = .6;
      } else {
        panel(wreckMesh, 1.2, .46, .94, dark, 0, .25, 0).rotation.z = -.12;
        plated(wreckMesh, 1.05, .19, .76, armor, .12, .51, .02).rotation.z = .13;
        cylinder(wreckMesh, .17, .95, steel, -.39, .19, .12).rotation.z = .8;
      }
      const salvage = new T.MeshStandardMaterial({ color: 0x9dc6b6, emissive: 0x70bfa4, emissiveIntensity: .9, roughness: .5 });
      panel(wreckMesh, .42, .07, .24, salvage, .12, .65, .08);
      ring(wreckMesh, .36, .08, ochre, .49, .21, -.2).rotation.y = .7;
      this.scene.add(model.mesh, wreckMesh); wreckMesh.visible = false; this.wrecks.add(wreckMesh);
      const agent: Agent = {
        ...model, position: model.mesh.position, type, hp: 0, maxHp: specs[type].hp, state: 'IDLE', home: new T.Vector3(), lastKnown: new T.Vector3(), goal: new T.Vector3(), aim: new T.Vector3(),
        patrolAngle: i * 2.4, phase: i * 1.73, stateTime: 0, sightClock: i * .017, visible: false, memory: 0, suspicion: 0, cooldown: 1, windup: 0, burst: 0, distraction: 0, searchAngle: 0, speed: 0, deathTime: 0, hitFlash: 0, strafe: i % 2 ? 1 : -1,
        wreck: { id: 10000 + i, position: wreckMesh.position, mesh: wreckMesh, tier: 2, opened: false },
      };
      model.mesh.traverse(o => { o.userData.enemy = agent; });
      this.pool.push(agent);
    }
    const sparkGeo = new T.OctahedronGeometry(.065), traceGeo = new T.CylinderGeometry(.025, .025, 1, 4);
    const sparkMat = new T.MeshBasicMaterial({ color: 0xffb962 }), traceMat = new T.MeshBasicMaterial({ color: 0xffb578 });
    for (let i = 0; i < 64; i++) {
      const tracer = i < 16, part = new T.Mesh(tracer ? traceGeo : sparkGeo, tracer ? traceMat : sparkMat);
      part.visible = false; this.scene.add(part); this.fx.push({ mesh: part, velocity: new T.Vector3(), life: 0, duration: 1, tracer });
    }
    this.reset();
  }
  reset(insertion?: T.Vector3) {
    this.enemies.length = 0; this.kills = 0; this.threat = 0; this.alertHeat = 0; this.elapsed = 0; this.reinforcements = 0; this.reinforcementClock = 14; this.damageClock = 0;
    this.camp.copy(insertion ?? this.player.set(0, 0, 145));
    this.player.copy(this.camp);
    this.boss = null; this.bossClock = 150;
    for (let i = this.world.containers.length - 1; i >= 0; i--) if (this.wrecks.has(this.world.containers[i].mesh)) this.world.containers.splice(i, 1);
    for (const effect of this.fx) { effect.life = 0; effect.mesh.visible = false; }
    for (const agent of this.pool) { agent.hp = 0; agent.mesh.visible = false; agent.wreck.mesh.visible = false; agent.wreck.opened = false; }
    for (let i = 0; i < initialRobotCount; i++) {
      const center = robotZones[Math.floor(i / robotFormation.length)], angle = i * 2.4;
      this.spawn(this.pool[i], center[0] + Math.sin(angle) * 12, center[1] + Math.cos(angle) * 12);
    }
    for (let i = 0; i < scavengerHomes.length; i++) this.spawn(this.pool[initialRobotCount + i], scavengerHomes[i][0], scavengerHomes[i][1]);
  }
  boss: Agent | null = null;
  bossClock = 150;
  onBoss?: (position: T.Vector3) => void;
  private safeCamp(position: T.Vector3) { return (position.x-this.camp.x)**2+(position.z-this.camp.z)**2 < 30*30; }
  private blocked(x: number, z: number, radius: number, clearance: number) {
    if (Math.abs(x) > 202 || Math.abs(z) > 202 || (x-this.camp.x)**2+(z-this.camp.z)**2 < 28*28) return true;
    const floor = this.world.groundHeight(x, z);
    for (const c of this.world.colliders) {
      if (Math.abs(x - c.x) < c.hx + radius && Math.abs(z - c.z) < c.hz + radius && this.world.groundHeight(c.x, c.z) + c.height > floor + clearance) return true;
    }
    return false;
  }
  private spawn(agent: Agent, x: number, z: number) {
    const s = specs[agent.type], clearance = agent.type === 'Watcher' ? 2.7 : .45;
    let found = false;
    for (let n = 0; n < 160; n++) {
      const angle = n * 2.39996, radius = n === 0 ? 0 : 2 + Math.sqrt(n) * 2;
      const nx = x + Math.cos(angle) * radius, nz = z + Math.sin(angle) * radius;
      if (!this.blocked(nx, nz, s.radius, clearance)) { x = nx; z = nz; found = true; break; }
    }
    if (!found) return false;
    agent.position.set(x, this.world.groundHeight(x, z), z); agent.home.copy(agent.position); agent.goal.copy(agent.position); agent.lastKnown.copy(agent.position);
    agent.mesh.rotation.set(0, agent.phase, 0); agent.mesh.scale.setScalar(1); agent.mesh.visible = true;
    agent.hp = s.hp; agent.state = 'IDLE'; agent.stateTime = 0; agent.sightClock = agent.phase % .2; agent.visible = false; agent.memory = 0; agent.suspicion = 0; agent.cooldown = 1.2; agent.windup = 0; agent.burst = 0; agent.distraction = 0; agent.speed = 0; agent.deathTime = 0; agent.hitFlash = 0; agent.patrolAngle = agent.phase;
    agent.rig.core.emissive.setHex(agent.type === 'Strider' ? 0x378d94 : 0xff762d); agent.rig.core.emissiveIntensity = 1.6;
    this.enemies.push(agent); agent.mesh.updateMatrixWorld(true); return true;
  }
  private change(agent: Agent, state: RobotState) {
    if (agent.state !== state) {
      agent.state = state; agent.stateTime = 0;
      if (state !== 'COMBAT') { agent.windup = 0; agent.burst = 0; }
    }
  }
  private clearLine(a: T.Vector3, b: T.Vector3) {
    this.direction.copy(b).sub(a); const length = this.direction.length();
    if (length < .001) return true;
    this.ray.set(a, this.direction.multiplyScalar(1 / length)); this.ray.far = Math.max(0, length - .15); this.ray.near = .05;
    this.hits.length = 0; this.ray.intersectObjects(this.world.solids, false, this.hits);
    if (this.hits.length) return false;
    for (let d = 1; d < length; d += 2.5) {
      const f = d / length, x = a.x + (b.x - a.x) * f, z = a.z + (b.z - a.z) * f;
      if (a.y + (b.y - a.y) * f < this.world.groundHeight(x, z) + .08) return false;
    }
    return true;
  }
  hear(position: T.Vector3, loudness: number, event: 'noise' | 'decoy' = 'noise') {
    if (!Number.isFinite(loudness) || loudness <= 0 || !Number.isFinite(position.x) || !Number.isFinite(position.y) || !Number.isFinite(position.z)) return;
    const radius = Math.min(135, loudness);
    this.alertHeat = Math.min(100, this.alertHeat + Math.min(8, loudness * .045));
    for (const agent of this.enemies) {
      if (agent.hp <= 0 || agent.visible && agent.state === 'COMBAT' || event === 'noise' && agent.distraction > 0) continue;
      const distance = agent.position.distanceTo(position); if (distance > radius) continue;
      this.origin.copy(agent.position); this.origin.y += agent.rig.eyeHeight;
      this.target.copy(position); this.target.y += 1;
      if (!this.clearLine(this.origin, this.target) && distance > radius * .57) continue;
      agent.lastKnown.copy(position); agent.memory = 8; agent.suspicion = Math.max(agent.suspicion, .32); agent.visible = false;
      agent.distraction = event === 'decoy' ? 5 : 0;
      if (agent.state !== 'INVESTIGATE' && agent.state !== 'SUSPICIOUS') { this.change(agent, 'SUSPICIOUS'); this.audio.play('robot', agent.position); }
    }
  }
  hit(object: T.Object3D, damage: number, point: T.Vector3): { hit: boolean; killed: boolean; critical: boolean; type: string } {
    const agent = object.userData.enemy as Agent | undefined;
    if (!agent || agent.hp <= 0 || !Number.isFinite(damage) || damage <= 0) return { hit: false, killed: false, critical: false, type: '' };
    const critical = object.userData.core === true;
    agent.hp = Math.max(0, agent.hp - damage * (critical ? 2 : 1)); agent.hitFlash = .18; agent.distraction = 0;
    this.sparks(point, critical ? 7 : 4); this.alertHeat = Math.min(100, this.alertHeat + 3);
    if (agent.hp === 0) {
      this.kills++; this.alertHeat = Math.min(100, this.alertHeat + 8); agent.windup = 0; agent.burst = 0; agent.visible = false; agent.deathTime = .75;
      agent.rig.core.emissiveIntensity = 0; this.audio.play('kill', agent.position); this.sparks(point, 12);
      const wreck = agent.wreck;
      let x = agent.position.x, z = agent.position.z;
      for (let n = 0; n < 80; n++) {
        const radius = Math.sqrt(n) * 1.25, angle = n * 2.39996;
        const nx = agent.position.x + Math.cos(angle) * radius, nz = agent.position.z + Math.sin(angle) * radius;
        if (!this.blocked(nx, nz, .8, .45)) { x = nx; z = nz; break; }
      }
      wreck.position.set(x, this.world.groundHeight(x, z), z);
      wreck.mesh.rotation.y = agent.mesh.rotation.y; wreck.mesh.visible = true; wreck.opened = false; this.scene.add(wreck.mesh); this.world.containers.push(wreck);
    } else if (agent.state !== 'COMBAT') {
      // A hit tells the machine it was struck, not the unseen shooter's coordinates.
      agent.lastKnown.copy(point); agent.memory = 8; agent.suspicion = .65; this.change(agent, 'SUSPICIOUS');
    }
    return { hit: true, killed: agent.hp === 0, critical, type: agent.type };
  }
  private sparks(point: T.Vector3, count: number) {
    for (let i = 0; i < count; i++) {
      const effect = this.fx[16 + this.fxIndex++ % 48]; effect.mesh.position.copy(point); effect.mesh.scale.setScalar(.7 + Math.random()); effect.mesh.visible = true;
      effect.velocity.set((Math.random() - .5) * 5, 1.8 + Math.random() * 4, (Math.random() - .5) * 5); effect.life = effect.duration = .3 + Math.random() * .45;
    }
  }
  private tracer(a: T.Vector3, b: T.Vector3) {
    const effect = this.fx[this.fxIndex++ % 16]; this.direction.copy(b).sub(a); const length = this.direction.length();
    effect.mesh.position.copy(a).addScaledVector(this.direction, .5); effect.mesh.scale.set(1, length, 1);
    if (length > .001) effect.mesh.quaternion.setFromUnitVectors(UP, this.direction.multiplyScalar(1 / length));
    effect.mesh.visible = true; effect.life = effect.duration = .09;
  }
  private perceive(agent: Agent, hidden: boolean) {
    const s = specs[agent.type], distance = agent.position.distanceTo(this.player);
    if (agent.distraction > 0 && distance > 7) { agent.visible = false; return; }
    let sees = false;
    if (!this.safeCamp(this.player) && distance < s.sight * (hidden ? .55 : 1)) {
      const dx = this.player.x - agent.position.x, dz = this.player.z - agent.position.z;
      const facing = (Math.sin(agent.mesh.rotation.y) * dx + Math.cos(agent.mesh.rotation.y) * dz) / Math.max(.1, Math.hypot(dx, dz));
      if (distance < 7 || facing > (agent.state === 'COMBAT' || agent.state === 'SEARCH' ? -.55 : .08)) {
        this.origin.copy(agent.position); this.origin.y += agent.rig.eyeHeight;
        this.target.copy(this.player); this.target.y += hidden ? .75 : 1.35;
        sees = this.clearLine(this.origin, this.target);
      }
    }
    agent.visible = sees;
    if (sees) {
      agent.lastKnown.copy(this.player); agent.memory = 4.7;
      agent.suspicion = Math.min(1, agent.suspicion + (distance < 12 ? .42 : hidden ? .16 : .27));
      if (agent.suspicion >= 1 && agent.state !== 'COMBAT') {
        this.change(agent, 'COMBAT'); agent.cooldown = Math.max(agent.cooldown, .65 + Math.random() * .55); this.audio.play('alert', agent.position);
      } else if (agent.state === 'IDLE' || agent.state === 'PATROL' || agent.state === 'RETURN') this.change(agent, 'SUSPICIOUS');
    } else agent.suspicion = Math.max(0, agent.suspicion - .065);
  }
  private move(agent: Agent, x: number, z: number, speed: number, dt: number, faceGoal = false) {
    const dx = x - agent.position.x, dz = z - agent.position.z, length = Math.hypot(dx, dz);
    agent.speed = 0; if (length < .35) return;
    const s = specs[agent.type], distance = Math.min(length, speed * dt), angle = Math.atan2(dx, dz), clearance = agent.type === 'Watcher' ? 2.7 : .45;
    let bestScore = -Infinity, bestX = agent.position.x, bestZ = agent.position.z;
    for (let n = 0; n < 9; n++) {
      const offset = n === 0 ? 0 : Math.ceil(n / 2) * .44 * (n % 2 ? agent.strafe : -agent.strafe), a = angle + offset;
      const nx = agent.position.x + Math.sin(a) * distance, nz = agent.position.z + Math.cos(a) * distance;
      const lookX = agent.position.x + Math.sin(a) * Math.max(distance, s.radius * .65), lookZ = agent.position.z + Math.cos(a) * Math.max(distance, s.radius * .65);
      if (this.blocked(nx, nz, s.radius, clearance) || this.blocked(lookX, lookZ, s.radius, clearance)) continue;
      const floor = this.world.groundHeight(nx, nz);
      if (Math.abs(floor - this.world.groundHeight(agent.position.x, agent.position.z)) > .7) continue;
      let score = Math.cos(offset) * 3;
      for (const other of this.enemies) if (other !== agent && other.hp > 0) {
        const d = Math.hypot(nx - other.position.x, nz - other.position.z); if (d < s.radius + specs[other.type].radius) score -= 4;
      }
      if (score > bestScore) { bestScore = score; bestX = nx; bestZ = nz; }
    }
    if (bestScore > -Infinity) {
      const moved = Math.hypot(bestX - agent.position.x, bestZ - agent.position.z); agent.speed = moved / Math.max(dt, .001);
      agent.position.x = bestX; agent.position.z = bestZ;
      if (!faceGoal) this.face(agent, angle, dt);
    }
  }
  private face(agent: Agent, angle: number, dt: number) {
    const delta = Math.atan2(Math.sin(angle - agent.mesh.rotation.y), Math.cos(angle - agent.mesh.rotation.y));
    agent.mesh.rotation.y += delta * Math.min(1, dt * (agent.type === 'Warden' ? 2.4 : 5));
  }
  private beginAttack(agent: Agent) {
    agent.aim.copy(agent.lastKnown); agent.aim.y += agent.type === 'Hound' ? .6 : 1.1;
    const spread = agent.type === 'Warden' || agent.type === 'Leviathan' ? 1.3 : .85;
    agent.aim.x += (Math.random() - .5) * spread; agent.aim.z += (Math.random() - .5) * spread; agent.aim.y += (Math.random() - .5) * .55;
    agent.windup = specs[agent.type].windup; agent.burst = agent.type === 'Leviathan' ? 4 : agent.type === 'Warden' ? 3 : 1;
    if (agent.type !== 'Strider') this.audio.play('robot', agent.position);
  }
  private fire(agent: Agent, onDamage: (amount: number, source: T.Vector3) => void, hidden: boolean) {
    const s = specs[agent.type];
    this.muzzle.copy(agent.position); this.muzzle.y += agent.type === 'Leviathan' ? 5.4 : agent.type === 'Warden' ? 2.48 : agent.type === 'Watcher' ? 3.02 : agent.type === 'Strider' ? 1.44 : 1.6;
    if (agent.type === 'Warden' || agent.type === 'Leviathan') {
      const side = (agent.type === 'Leviathan' ? 1.9 : 1.19) * (agent.burst % 2 ? 1 : -1);
      this.muzzle.x += Math.cos(agent.mesh.rotation.y) * side;
      this.muzzle.z -= Math.sin(agent.mesh.rotation.y) * side;
    }
    let hitsPlayer = false;
    if (agent.type === 'Hound') {
      this.target.copy(this.player); this.target.y += .7;
      const toAim = this.point.copy(agent.aim).sub(agent.position);
      const toPlayer = this.movement.copy(this.player).sub(agent.position);
      const facing = (toAim.x * toPlayer.x + toAim.z * toPlayer.z) / Math.max(.01, Math.hypot(toAim.x, toAim.z) * Math.hypot(toPlayer.x, toPlayer.z));
      hitsPlayer = agent.position.distanceTo(this.player) < s.range && facing > .72 && this.clearLine(this.muzzle, this.target);
      this.sparks(agent.aim, 3);
    } else {
      this.direction.copy(agent.aim).sub(this.muzzle).normalize(); this.ray.set(this.muzzle, this.direction); this.ray.near = .05; this.ray.far = s.range + 8;
      this.hits.length = 0; this.ray.intersectObjects(this.world.solids, false, this.hits);
      let distance = this.hits.length ? this.hits[0].distance : s.range + 8;
      for (let d = .8; d < distance; d += 1) {
        this.point.copy(this.muzzle).addScaledVector(this.direction, d);
        if (this.point.y < this.world.groundHeight(this.point.x, this.point.z) + .06) { distance = d; break; }
      }
      this.end.copy(this.muzzle).addScaledVector(this.direction, distance);
      // Intersect the actual operator capsule against the committed aim, not a random damage roll.
      const height = hidden ? .95 : 1.65;
      for (let y = .35; y <= height; y += .32) {
        this.target.copy(this.player); this.target.y += y;
        this.point.copy(this.target).sub(this.muzzle); const projection = this.point.dot(this.direction);
        if (projection > 0 && projection < distance && this.ray.ray.distanceSqToPoint(this.target) < .34 * .34) { hitsPlayer = true; distance = projection; this.end.copy(this.muzzle).addScaledVector(this.direction, distance); break; }
      }
      this.tracer(this.muzzle, this.end); this.sparks(this.end, 2); this.audio.play('shoot-smg', this.muzzle);
    }
    if (hitsPlayer && !this.safeCamp(this.player) && this.damageClock <= 0) { this.damageClock = .14; onDamage(s.damage, agent.position); }
    agent.burst--;
    if (agent.burst > 0) { agent.windup = .22; agent.aim.x += (Math.random() - .5) * .4; agent.aim.z += (Math.random() - .5) * .4; }
    else { agent.windup = 0; agent.cooldown = s.interval + Math.random() * .8; }
  }
  private animate(agent: Agent, dt: number, time: number) {
    const moving = Math.min(1, agent.speed / (agent.type === 'Hound' ? 5 : 2));
    const cycle = time * (agent.type === 'Hound' ? 11 : agent.type === 'Strider' ? 8 : 5) + agent.phase;
    if (agent.type === 'Watcher') {
      agent.rig.body.position.y = 3.55 + Math.sin(time * 2 + agent.phase) * .18;
      agent.rig.body.rotation.z = Math.sin(time + agent.phase) * .045 - agent.strafe * moving * .07;
      agent.rig.body.rotation.x = moving * .07;
      for (const rotor of agent.rig.rotors) rotor.rotation.y += dt * 45;
    } else if (agent.type === 'Leviathan') {
      agent.rig.body.position.y = 5.6 + Math.sin(cycle * 2) * moving * .14;
      agent.rig.body.rotation.z = Math.sin(cycle) * moving * .05;
      agent.rig.body.rotation.x = agent.windup > 0 ? -.06 : 0;
      for (const leg of agent.rig.legs) { leg.pivot.rotation.x = Math.sin(cycle + leg.phase) * moving * .3; leg.knee.rotation.x = Math.max(0, -Math.sin(cycle + leg.phase)) * moving * .4; }
    } else {
      agent.rig.body.position.y = (agent.type === 'Hound' ? 1.56 : agent.type === 'Strider' ? 1.45 : 2.94) + Math.sin(cycle * 2) * moving * .055;
      agent.rig.body.rotation.z = Math.sin(cycle) * moving * .035;
      agent.rig.body.rotation.x = agent.type === 'Hound' && agent.windup > 0 ? -.13 : agent.type === 'Strider' ? moving * .1 : 0;
      for (const leg of agent.rig.legs) { leg.pivot.rotation.x = Math.sin(cycle + leg.phase) * moving * .37; leg.knee.rotation.x = Math.max(0, -Math.sin(cycle + leg.phase)) * moving * .45; }
    }
    for (const gun of agent.rig.guns) gun.rotation.x = agent.windup > 0 && agent.windup < .23 ? -.1 : 0;
    agent.hitFlash = Math.max(0, agent.hitFlash - dt);
    agent.rig.core.emissiveIntensity = agent.hitFlash > 0 ? 5 : agent.windup > 0 ? 3.3 + Math.sin(time * 32) * 1.7 : agent.state === 'COMBAT' ? 2.3 : 1.3;
  }
  update(dt: number, time: number, playerPosition: T.Vector3, isHidden: boolean, onDamage: (amount: number, source: T.Vector3) => void, raidTime: number) {
    dt = Math.max(0, Math.min(.08, dt)); this.elapsed += dt; this.damageClock -= dt; this.player.copy(playerPosition);
    this.bossClock = Math.max(0, 150 - raidTime);
    if (!this.boss && this.pool.length && this.bossClock === 0) {
      const boss = this.pool[this.pool.length - 1];
      for (let n = 0; n < 24; n++) {
        const angle = n * 2.39996, x = this.player.x + Math.sin(angle) * 70, z = this.player.z + Math.cos(angle) * 70;
        if (this.spawn(boss, x, z)) {
          this.boss = boss;
          this.audio.play('alert', boss.position);
          this.onBoss?.(boss.position);
          break;
        }
      }
    }
    let engaged = 0, attacking = 0;
    for (const agent of this.enemies) if (agent.hp > 0 && agent.windup > 0) attacking++;
    for (const effect of this.fx) if (effect.life > 0) {
      effect.life -= dt; effect.mesh.visible = effect.life > 0;
      if (!effect.tracer) { effect.velocity.y -= dt * 8; effect.mesh.position.addScaledVector(effect.velocity, dt); effect.mesh.scale.multiplyScalar(Math.max(0, 1 - dt * 1.8)); }
    }
    const safe = this.safeCamp(this.player);
    for (const agent of this.enemies) {
      if (agent.hp <= 0) {
        if (agent.deathTime > 0) { agent.deathTime -= dt; agent.mesh.rotation.z += dt * 1.5; agent.mesh.position.y -= dt * (agent.type === 'Watcher' ? 3.3 : .45); if (agent.deathTime <= 0) agent.mesh.visible = false; }
        continue;
      }
      agent.stateTime += dt; agent.memory = Math.max(0, agent.memory - dt); agent.distraction = Math.max(0, agent.distraction - dt); agent.cooldown -= dt; agent.sightClock -= dt; agent.speed = 0;
      if (agent.sightClock <= 0) { agent.sightClock += .2; this.perceive(agent, isHidden); }
      if (safe && (agent.state === 'COMBAT' || agent.windup > 0)) { agent.visible = false; agent.windup = 0; agent.burst = 0; this.change(agent, 'RETURN'); }
      if (agent.state === 'COMBAT') {
        engaged++; const dx = agent.lastKnown.x - agent.position.x, dz = agent.lastKnown.z - agent.position.z, distance = Math.hypot(dx, dz), s = specs[agent.type];
        this.face(agent, Math.atan2(dx, dz), dt);
        if (!agent.visible && agent.memory <= 0) { agent.windup = 0; agent.burst = 0; this.change(agent, 'SEARCH'); agent.searchAngle = agent.phase; }
        else if (agent.windup > 0) {
          agent.windup -= dt; if (agent.windup <= 0) this.fire(agent, onDamage, isHidden);
        } else {
          const nx = dx / Math.max(distance, .1), nz = dz / Math.max(distance, .1);
          if (agent.type === 'Watcher' && agent.visible) {
            const radial = distance < 15 ? -1 : distance > 26 ? 1 : 0;
            this.move(agent, agent.position.x + nx * radial * 8 + nz * agent.strafe * 7, agent.position.z + nz * radial * 8 - nx * agent.strafe * 7, s.speed, dt, true);
          } else if (agent.type === 'Hound') {
            const flank = distance > 7 && agent.visible ? Math.min(7, distance * .3) * agent.strafe : 0;
            this.move(agent, agent.lastKnown.x + nz * flank, agent.lastKnown.z - nx * flank, s.speed, dt, true);
          } else if (agent.type === 'Strider') {
            const retreatRange = agent.hp < agent.maxHp * .4 ? 27 : 16;
            const radial = distance < retreatRange ? -1 : distance > 25 || !agent.visible ? 1 : 0;
            const sidestep = Math.sin(agent.stateTime * .85 + agent.phase) > 0 ? agent.strafe : -agent.strafe;
            this.move(agent, agent.position.x + nx * radial * 10 + nz * sidestep * 5, agent.position.z + nz * radial * 10 - nx * sidestep * 5, s.speed * (radial < 0 ? 1 : .72), dt, true);
          } else if (agent.type === 'Warden' || agent.type === 'Leviathan') {
            if (distance > 27 || !agent.visible) this.move(agent, agent.lastKnown.x, agent.lastKnown.z, s.speed, dt, true);
            else if (distance < 13) this.move(agent, agent.position.x - nx * 5 + nz * agent.strafe * 3, agent.position.z - nz * 5 - nx * agent.strafe * 3, s.speed * .7, dt, true);
          } else this.move(agent, agent.lastKnown.x, agent.lastKnown.z, s.speed * .7, dt, true);
          if (agent.visible && agent.cooldown <= 0 && distance < s.range && attacking < 3 && !safe) { this.beginAttack(agent); attacking++; }
        }
      } else if (agent.state === 'SUSPICIOUS') {
        this.face(agent, Math.atan2(agent.lastKnown.x - agent.position.x, agent.lastKnown.z - agent.position.z), dt);
        if (agent.stateTime > .85) this.change(agent, 'INVESTIGATE');
      } else if (agent.state === 'INVESTIGATE') {
        this.move(agent, agent.lastKnown.x, agent.lastKnown.z, specs[agent.type].speed * .6, dt);
        if (agent.position.distanceTo(agent.lastKnown) < 2.5 || agent.stateTime > 15) { this.change(agent, 'SEARCH'); agent.searchAngle = agent.phase; }
      } else if (agent.state === 'SEARCH') {
        if (agent.stateTime > 10) this.change(agent, 'RETURN');
        else {
          agent.searchAngle += dt * .58;
          this.move(agent, agent.lastKnown.x + Math.sin(agent.searchAngle) * 7, agent.lastKnown.z + Math.cos(agent.searchAngle) * 7, specs[agent.type].speed * .42, dt);
          this.face(agent, agent.mesh.rotation.y + Math.sin(time * .9 + agent.phase) * .6, dt);
        }
      } else if (agent.state === 'RETURN') {
        this.move(agent, agent.home.x, agent.home.z, specs[agent.type].speed * .48, dt);
        if (agent.position.distanceTo(agent.home) < 2 || agent.stateTime > 35) this.change(agent, 'IDLE');
      } else if (agent.state === 'IDLE') {
        this.face(agent, agent.patrolAngle + Math.sin(time * .45 + agent.phase) * .65, dt);
        if (agent.stateTime > 2.5 + agent.phase % 3) {
          agent.patrolAngle += 1.7; agent.goal.copy(agent.home);
          const radius = agent.type === 'Strider' ? 23 : 13;
          agent.goal.x += Math.sin(agent.patrolAngle) * radius; agent.goal.z += Math.cos(agent.patrolAngle) * radius;
          if (agent.type === 'Strider') {
            let closest = 32 * 32;
            for (const container of this.world.containers) {
              if (container.opened || container.position.distanceToSquared(agent.home) > 38 * 38) continue;
              const distance = container.position.distanceToSquared(agent.position);
              if (distance > 4 * 4 && distance < closest) { closest = distance; agent.goal.copy(container.position); }
            }
          }
          this.change(agent, 'PATROL');
        }
      } else {
        this.move(agent, agent.goal.x, agent.goal.z, specs[agent.type].speed * .38, dt);
        if (agent.position.distanceTo(agent.goal) < 1.5 || agent.stateTime > 12) this.change(agent, 'IDLE');
      }
      agent.position.y = this.world.groundHeight(agent.position.x, agent.position.z); this.animate(agent, dt, time);
    }
    this.alertHeat = Math.max(0, this.alertHeat - dt * (engaged ? .12 : .9));
    const targetThreat = Math.min(100, this.alertHeat + engaged * 12);
    this.threat += (targetThreat - this.threat) * Math.min(1, dt * .8);
    this.reinforcementClock -= dt;
    if (!safe && this.reinforcements < reinforcementTypes.length && this.reinforcementClock <= 0 && this.threat > 24 + this.reinforcements * 14) {
      this.reinforcementClock = 18;
      const agent = this.pool[initialCount + this.reinforcements];
      for (let i = 0; i < 16; i++) {
        const angle = this.elapsed * .7 + i * 2.39996, radius = 78 + i % 3 * 9;
        const x = this.player.x + Math.sin(angle) * radius, z = this.player.z + Math.cos(angle) * radius;
        if (this.blocked(x, z, specs[agent.type].radius, agent.type === 'Watcher' ? 2.7 : .45)) continue;
        this.origin.set(x, this.world.groundHeight(x, z) + agent.rig.eyeHeight, z); this.target.copy(this.player); this.target.y += 1.5;
        // Camera orientation is not part of the API: require full world occlusion, stronger than a guessed view cone.
        if (this.clearLine(this.target, this.origin)) continue;
        if (this.spawn(agent, x, z)) { agent.lastKnown.copy(this.player); agent.memory = 12; this.change(agent, 'INVESTIGATE'); this.reinforcements++; break; }
      }
    }
  }
}
