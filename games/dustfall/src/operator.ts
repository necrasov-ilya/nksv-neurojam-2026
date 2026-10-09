import * as T from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

const C = {
  coat: 0x365d59, fold: 0x294844, trim: 0x71958a, olive: 0x646c4c,
  pack: 0xa18b61, edge: 0xc3ad7c, leather: 0x51473a, rubber: 0x252c2a,
  metal: 0x59645f, steel: 0x87928b, gun: 0x303d3c, orange: 0xd2914f,
  lens: 0x93e2d7, black: 0x142825,
};
const DOWN = new T.Vector3(0, -1, 0);
type Surface = 'fabric' | 'metal' | 'glass';
type Buckets = Record<Surface, T.BufferGeometry[]>;

// Bake small details into three material batches per articulated piece.
// Vertex colours preserve the sewn panels and hardware without a draw per detail.
class Part {
  buckets: Buckets = { fabric: [], metal: [], glass: [] };
  constructor(readonly parent: T.Group, readonly materials: Record<Surface, T.Material>) {}
  add(geometry: T.BufferGeometry, color: number, position: number[], scale = [1, 1, 1], rotation = [0, 0, 0], surface: Surface = 'fabric') {
    const g = geometry.index ? geometry.toNonIndexed() : geometry;
    if (g !== geometry) geometry.dispose();
    g.deleteAttribute('uv');
    const matrix = new T.Matrix4().compose(new T.Vector3(position[0], position[1], position[2]), new T.Quaternion().setFromEuler(new T.Euler(rotation[0], rotation[1], rotation[2])), new T.Vector3(scale[0], scale[1], scale[2]));
    g.applyMatrix4(matrix);
    const tint = new T.Color(color);
    const colors = new Float32Array(g.getAttribute('position').count * 3);
    for (let i = 0; i < colors.length; i += 3) { colors[i] = tint.r; colors[i + 1] = tint.g; colors[i + 2] = tint.b; }
    g.setAttribute('color', new T.BufferAttribute(colors, 3));
    this.buckets[surface].push(g);
  }
  oval(color: number, p: number[], s: number[], surface: Surface = 'fabric') {
    this.add(new T.SphereGeometry(1, 16, 12), color, p, s, [0, 0, 0], surface);
  }
  pad(color: number, p: number[], s: number[], rotation = [0, 0, 0], surface: Surface = 'fabric') {
    const shape = new T.Shape();
    const r = .16;
    shape.moveTo(-.5 + r, -.5); shape.lineTo(.5 - r, -.5);
    shape.quadraticCurveTo(.5, -.5, .5, -.5 + r); shape.lineTo(.5, .5 - r);
    shape.quadraticCurveTo(.5, .5, .5 - r, .5); shape.lineTo(-.5 + r, .5);
    shape.quadraticCurveTo(-.5, .5, -.5, .5 - r); shape.lineTo(-.5, -.5 + r);
    shape.quadraticCurveTo(-.5, -.5, -.5 + r, -.5);
    const g = new T.ExtrudeGeometry(shape, { depth: .72, bevelEnabled: true, bevelSegments: 2, steps: 1, bevelSize: .07, bevelThickness: .14, curveSegments: 3 });
    g.translate(0, 0, -.36);
    this.add(g, color, p, s, rotation, surface);
  }
  cylinder(color: number, p: number[], top: number, bottom: number, length: number, rotation = [0, 0, 0], surface: Surface = 'fabric') {
    this.add(new T.CylinderGeometry(top, bottom, length, 16), color, p, [1, 1, 1], rotation, surface);
  }
  seam(color: number, points: number[][], radius = .005, surface: Surface = 'fabric') {
    const curve = new T.CatmullRomCurve3(points.map(p => new T.Vector3(p[0], p[1], p[2])));
    this.add(new T.TubeGeometry(curve, Math.max(8, points.length * 4), radius, 5, false), color, [0, 0, 0], [1, 1, 1], [0, 0, 0], surface);
  }
  ring(color: number, p: number[], radius: number, tube: number, rotation = [0, 0, 0], surface: Surface = 'metal') {
    this.add(new T.TorusGeometry(radius, tube, 6, 20), color, p, [1, 1, 1], rotation, surface);
  }
  finish() {
    for (const key of ['fabric', 'metal', 'glass'] as Surface[]) {
      const list = this.buckets[key];
      if (!list.length) continue;
      const geometry = mergeGeometries(list, false)!;
      const mesh = new T.Mesh(geometry, this.materials[key]);
      mesh.castShadow = key !== 'glass'; mesh.receiveShadow = true;
      this.parent.add(mesh);
      list.forEach(g => g.dispose());
    }
  }
}

function joint(parent: T.Group, name: string, x: number, y: number, z: number) {
  const group = new T.Group(); group.name = name; group.position.set(x, y, z); parent.add(group); return group;
}

export function createOperator(): T.Group {
  const root = new T.Group(); root.name = 'Wayfarer';
  const materials = {
    fabric: new T.MeshStandardMaterial({ vertexColors: true, roughness: .91 }),
    metal: new T.MeshStandardMaterial({ vertexColors: true, metalness: .68, roughness: .38 }),
    glass: new T.MeshStandardMaterial({ vertexColors: true, color: 0x7ea59c, emissive: 0x59d1bf, emissiveIntensity: .75, metalness: .55, roughness: .17 }),
  };
  root.userData.materials = materials;
  root.userData.operatorId = 'wayfarer';
  root.userData.appearance = '';
  const body = joint(root, 'pelvis-and-spine', 0, .99, 0);
  const chest = joint(body, 'breathing-coat', 0, 0, 0);
  const torso = new Part(chest, materials);
  // A shaped coat rather than an extruded rectangular chest.
  const profile = [[.19, -.14], [.25, -.10], [.24, .03], [.235, .18], [.27, .38], [.26, .47], [.20, .53], [.12, .55]];
  torso.add(new T.LatheGeometry(profile.map(([r, y]) => new T.Vector2(r, y)), 24), C.coat, [0, 0, 0], [1, 1, .68]);
  torso.oval(C.fold, [0, .43, -.015], [.245, .11, .17]);
  torso.cylinder(C.fold, [0, .55, 0], .105, .15, .105);
  torso.ring(C.trim, [0, .601, 0], .104, .013, [Math.PI / 2, 0, 0], 'fabric');
  torso.pad(C.olive, [0, .31, .157], [.34, .29, .072]);
  torso.pad(C.fold, [0, .31, .203], [.27, .20, .025]);
  torso.pad(C.trim, [-.087, .395, .226], [.072, .018, .008]);
  torso.pad(C.orange, [.075, .40, .226], [.035, .031, .008]);
  for (const side of [-1, 1]) {
    torso.seam(C.leather, [[side * .185, .51, -.11], [side * .20, .49, .10], [side * .185, .28, .20], [side * .18, .04, .16]], .028);
    torso.pad(C.steel, [side * .184, .34, .225], [.056, .064, .013], [0, 0, side * -.06], 'metal');
    torso.pad(C.leather, [side * .184, .34, .235], [.030, .039, .006]);
    torso.pad(C.olive, [side * .12, .025, .177], [.18, .15, .088], [0, side * .16, 0]);
    torso.pad(C.pack, [side * .12, .069, .228], [.164, .055, .025]);
    torso.pad(C.leather, [side * .12, .01, .23], [.023, .11, .012]);
    torso.oval(C.steel, [side * .12, .045, .251], [.012, .012, .006], 'metal');
    torso.seam(C.trim, [[side * .24, .41, .065], [side * .25, .26, .10], [side * .235, .14, .13]], .004);
    for (let i = 0; i < 3; i++) torso.seam(C.fold, [[side * .15, -.07 + i * .045, .13], [side * .23, -.055 + i * .045, .09], [side * .24, -.03 + i * .045, -.025]], .006);
  }
  torso.seam(C.metal, [[0, .54, .12], [0, .44, .19], [0, .27, .214], [0, .13, .18]], .005, 'metal');
  torso.pad(C.leather, [0, -.045, .006], [.485, .068, .315]);
  torso.pad(C.steel, [0, -.04, .187], [.07, .055, .021], [0, 0, 0], 'metal');
  torso.pad(C.rubber, [0, -.04, .201], [.044, .031, .008]);
  torso.finish();

  const pack = joint(chest, 'expedition-pack', 0, .21, -.205);
  const gear = new Part(pack, materials);
  gear.pad(C.leather, [0, 0, -.025], [.39, .53, .22]);
  gear.pad(C.pack, [0, .015, -.115], [.37, .49, .22]);
  gear.pad(C.edge, [0, .215, -.15], [.38, .105, .24]);
  gear.pad(C.olive, [0, -.075, -.245], [.265, .205, .064]);
  gear.pad(C.pack, [0, .01, -.286], [.275, .055, .022]);
  for (const side of [-1, 1]) {
    gear.seam(C.leather, [[side * .12, .24, -.05], [side * .12, .24, -.25], [side * .12, -.23, -.25], [side * .12, -.25, -.05]], .018);
    gear.pad(C.steel, [side * .12, .065, -.267], [.048, .065, .013], [0, 0, 0], 'metal');
    gear.pad(C.leather, [side * .12, .065, -.277], [.024, .04, .008]);
    gear.seam(C.edge, [[side * .175, .16, -.22], [side * .177, -.16, -.22], [side * .15, -.205, -.23]], .004);
  }
  // The bedroll has visible spiral ends, compressed webbing and a stitched hem.
  gear.cylinder(C.olive, [0, .34, -.12], .105, .105, .49, [0, 0, Math.PI / 2]);
  for (const side of [-1, 1]) {
    for (const radius of [.04, .073, .095]) gear.ring(C.fold, [side * .247, .34, -.12], radius, .005, [0, Math.PI / 2, 0], 'fabric');
    gear.ring(C.leather, [side * .145, .34, -.12], .105, .013, [0, Math.PI / 2, 0], 'fabric');
  }
  gear.oval(C.metal, [.245, -.10, -.10], [.075, .13, .085], 'metal');
  gear.cylinder(C.rubber, [.245, .025, -.1], .027, .027, .038);
  gear.seam(C.leather, [[.18, .12, -.03], [.255, -.14, -.02], [.245, -.2, -.1]], .013);
  gear.cylinder(C.metal, [-.21, .41, -.04], .003, .005, .36, [0, 0, -.07], 'metal');
  gear.cylinder(C.rubber, [-.205, .255, -.04], .013, .013, .10);
  gear.oval(C.orange, [-.223, .592, -.04], [.011, .014, .011]);
  for (let i = 0; i < 5; i++) gear.seam(i % 2 ? C.edge : C.pack, [[-.19 - i * .007, .12, -.18], [-.28 - i * .006, -.02, -.22], [-.27 - i * .006, -.23, -.19], [-.18 - i * .005, -.20, -.17], [-.19 - i * .007, .12, -.18]], .008);
  gear.ring(C.orange, [-.25, -.18, -.27], .039, .007);
  gear.finish();

  const head = joint(chest, 'helmet', 0, .69, 0);
  const helmet = new Part(head, materials);
  helmet.oval(C.rubber, [0, -.035, 0], [.145, .18, .135]);
  helmet.oval(C.olive, [0, .045, -.015], [.17, .182, .158]);
  helmet.pad(C.metal, [0, .115, .033], [.20, .09, .22], [-.14, 0, 0], 'metal');
  helmet.pad(C.rubber, [0, .022, .137], [.282, .094, .036]);
  helmet.oval(C.black, [0, .025, .153], [.132, .048, .036], 'metal');
  for (const side of [-1, 1]) {
    helmet.pad(C.lens, [side * .067, .033, .183], [.096, .025, .014], [0, side * -.14, 0], 'glass');
    helmet.oval(C.metal, [side * .15, -.004, -.005], [.035, .078, .064], 'metal');
    helmet.cylinder(C.rubber, [side * .183, -.005, -.002], .034, .034, .018, [0, 0, Math.PI / 2]);
    helmet.seam(C.pack, [[side * .12, .08, .11], [side * .115, -.095, .105], [side * .067, -.15, .10]], .014);
    helmet.oval(C.rubber, [side * .103, -.097, .144], [.052, .051, .041]);
    helmet.cylinder(C.metal, [side * .104, -.097, .176], .038, .038, .024, [Math.PI / 2, 0, 0], 'metal');
    for (let i = -2; i <= 2; i++) helmet.pad(C.black, [side * .104 + i * .011, -.097, .192], [.004, .046 - Math.abs(i) * .008, .005]);
    helmet.seam(C.trim, [[side * .04, .218, -.04], [side * .11, .179, -.105], [side * .148, .09, -.11]], .005);
    helmet.oval(C.steel, [side * .123, .118, .113], [.01, .01, .008], 'metal');
  }
  helmet.pad(C.fold, [0, -.103, .132], [.14, .11, .075], [.14, 0, 0]);
  helmet.pad(C.metal, [0, -.112, .181], [.064, .058, .022], [0, 0, 0], 'metal');
  helmet.seam(C.rubber, [[-.118, -.11, .132], [-.18, -.18, .10], [-.18, -.27, .055], [-.10, -.32, .09]], .017);
  helmet.pad(C.orange, [0, .147, .137], [.065, .021, .006]);
  helmet.finish();

  const legs: { thigh: T.Group; shin: T.Group; boot: T.Group }[] = [];
  for (const side of [-1, 1]) {
    const thigh = joint(body, side < 0 ? 'left-thigh' : 'right-thigh', side * .145, -.01, 0);
    const upper = new Part(thigh, materials);
    upper.oval(C.fold, [0, -.055, 0], [.137, .13, .126]);
    upper.cylinder(C.coat, [0, -.21, 0], .119, .091, .33);
    upper.oval(C.coat, [0, -.20, 0], [.124, .205, .112]);
    upper.pad(C.olive, [side * .097, -.18, .022], [.08, .19, .15], [0, side * -.4, side * .05]);
    upper.pad(C.pack, [side * .122, -.12, .038], [.052, .042, .135], [0, side * -.4, 0]);
    upper.seam(C.trim, [[side * .104, -.065, .067], [side * .10, -.21, .076], [side * .072, -.35, .068]], .005);
    for (let i = 0; i < 3; i++) upper.seam(C.fold, [[-.07, -.30 - i * .025, .063], [0, -.286 - i * .03, .10], [.073, -.31 - i * .025, .06]], .008);
    upper.finish();
    const shin = joint(thigh, 'knee-hinge', 0, -.425, 0);
    const lower = new Part(shin, materials);
    lower.oval(C.fold, [0, -.01, 0], [.094, .092, .09]);
    lower.cylinder(C.coat, [0, -.18, 0], .085, .067, .30);
    lower.oval(C.coat, [0, -.18, -.01], [.09, .17, .086]);
    lower.pad(C.rubber, [0, -.022, .086], [.163, .17, .043]);
    lower.pad(C.metal, [0, -.021, .117], [.131, .132, .035], [-.10, 0, 0], 'metal');
    lower.pad(C.olive, [0, -.022, .140], [.081, .063, .012]);
    lower.ring(C.leather, [0, -.075, 0], .089, .014, [Math.PI / 2, 0, 0], 'fabric');
    lower.seam(C.trim, [[side * .067, -.115, .05], [side * .073, -.225, .053], [side * .058, -.325, .035]], .004);
    for (let i = 0; i < 3; i++) lower.ring(C.fold, [0, -.26 - i * .027, 0], .071 - i * .002, .006, [Math.PI / 2, 0, 0], 'fabric');
    lower.finish();
    const boot = joint(shin, 'hiking-boot', 0, -.38, 0);
    const shoe = new Part(boot, materials);
    shoe.pad(C.rubber, [0, -.133, .043], [.188, .044, .31]);
    shoe.pad(C.leather, [0, -.104, .051], [.18, .059, .291]);
    shoe.oval(C.leather, [0, -.071, .072], [.093, .067, .159]);
    shoe.oval(C.rubber, [0, -.07, .147], [.094, .055, .085]);
    shoe.cylinder(C.leather, [0, -.021, -.017], .079, .082, .135);
    shoe.ring(C.pack, [0, .036, -.017], .079, .009, [Math.PI / 2, 0, 0], 'fabric');
    shoe.pad(C.fold, [0, -.035, .07], [.089, .132, .034], [-.35, 0, 0]);
    for (let i = 0; i < 4; i++) {
      const y = .015 - i * .026, z = .086 + i * .014;
      shoe.seam(C.edge, [[-.034, y, z], [.035, y - .021, z + .009]], .004);
      shoe.seam(C.edge, [[.034, y, z], [-.035, y - .021, z + .009]], .004);
      for (const s of [-1, 1]) shoe.oval(C.steel, [s * .041, y, z], [.007, .007, .004], 'metal');
    }
    for (let i = 0; i < 5; i++) for (const s of [-1, 1]) shoe.pad(C.rubber, [s * .085, -.137, -.063 + i * .052], [.033, .034, .033], [0, s * .15, 0]);
    shoe.seam(C.edge, [[-.085, -.095, -.053], [-.09, -.089, .10], [0, -.098, .221], [.09, -.089, .10], [.085, -.095, -.053]], .003);
    shoe.finish(); legs.push({ thigh, shin, boot });
  }

  const arms: { upper: T.Group; lower: T.Group; hand: T.Group; shoulder: T.Vector3; target: T.Vector3; elbow: T.Vector3; direction: T.Vector3; wristRotation: T.Quaternion }[] = [];
  for (const side of [-1, 1]) {
    const upper = joint(chest, side < 0 ? 'left-upper-arm' : 'right-upper-arm', side * .295, .465, 0);
    const sleeve = new Part(upper, materials);
    sleeve.oval(C.coat, [0, -.05, 0], [.118, .127, .118]);
    sleeve.cylinder(C.coat, [0, -.18, 0], .092, .070, .22);
    sleeve.oval(C.coat, [0, -.19, 0], [.097, .132, .093]);
    sleeve.pad(C.olive, [side * .081, -.064, .016], [.058, .145, .151], [0, 0, side * .14]);
    sleeve.pad(C.orange, [side * .112, -.067, .042], [.008, .057, .043]);
    sleeve.seam(C.trim, [[side * .089, -.08, .054], [side * .086, -.17, .058], [side * .06, -.28, .045]], .004);
    for (let i = 0; i < 3; i++) sleeve.ring(C.fold, [0, -.225 - i * .022, 0], .077 - i * .003, .005, [Math.PI / 2, 0, 0], 'fabric');
    sleeve.finish();
    const lower = joint(upper, 'elbow-hinge', 0, -.30, 0);
    const forearm = new Part(lower, materials);
    forearm.oval(C.fold, [0, -.01, 0], [.072, .076, .072]);
    forearm.cylinder(C.coat, [0, -.14, 0], .075, .053, .24);
    forearm.oval(C.coat, [0, -.13, 0], [.078, .13, .071]);
    forearm.pad(C.metal, [0, -.018, -.062], [.112, .115, .026], [.1, 0, 0], 'metal');
    forearm.pad(C.olive, [0, -.14, -.067], [.093, .135, .021]);
    forearm.ring(C.leather, [0, -.236, 0], .056, .013, [Math.PI / 2, 0, 0], 'fabric');
    if (side < 0) {
      forearm.pad(C.rubber, [0, -.19, -.07], [.08, .07, .02]);
      forearm.pad(C.lens, [0, -.19, -.086], [.05, .04, .008], [0, 0, 0], 'glass');
    }
    forearm.finish();
    const hand = joint(lower, 'gripping-glove', 0, -.285, 0);
    const glove = new Part(hand, materials);
    glove.oval(C.leather, [0, 0, 0], [.049, .049, .041]);
    glove.pad(C.olive, [0, .009, -.030], [.074, .052, .018]);
    for (let i = 0; i < 4; i++) {
      glove.oval(C.leather, [-.030 + i * .020, -.036, .026], [.012, .035, .022]);
      glove.oval(C.pack, [-.030 + i * .020, -.010, -.033], [.008, .011, .007]);
      glove.seam(C.fold, [[-.037 + i * .020, -.028, .035], [-.030 + i * .020, -.03, .048], [-.023 + i * .020, -.028, .035]], .0025);
    }
    glove.oval(C.leather, [side * .046, -.003, .026], [.022, .029, .022]);
    glove.finish();
    arms.push({ upper, lower, hand, shoulder: upper.position.clone(), target: new T.Vector3(), elbow: new T.Vector3(), direction: new T.Vector3(), wristRotation: new T.Quaternion() });
  }

  const gun = joint(chest, 'primary-weapon', .17, .25, .32);
  const weapons: Record<string, T.Group> = {};
  for (const id of ['carbine', 'smg', 'scout']) {
    const weapon = joint(gun, id, 0, 0, 0); weapons[id] = weapon; weapon.visible = id === 'carbine';
    const w = new Part(weapon, materials);
    const scout = id === 'scout', smg = id === 'smg';
    const length = scout ? .67 : smg ? .34 : .49;
    w.pad(C.gun, [0, 0, .015], [.105, .125, .30]);
    w.pad(C.metal, [0, .055, .052], [.092, .038, .335], [0, 0, 0], 'metal');
    w.pad(C.rubber, [0, -.112, -.088], [.075, .153, .079], [-.26, 0, 0]);
    w.pad(C.olive, [0, -.018, -.235], [.075, .072, .19]);
    w.pad(C.rubber, [0, -.025, -.345], [.087, .135, .06]);
    w.pad(C.leather, [0, .036, -.245], [.079, .028, .15]);
    w.cylinder(C.metal, [0, .018, length * .62], .022, .022, length, [Math.PI / 2, 0, 0], 'metal');
    w.pad(C.olive, [0, .003, .235], [.12, .10, smg ? .14 : .28]);
    w.cylinder(C.gun, [0, .018, length * 1.12 + .03], scout ? .032 : .029, scout ? .032 : .029, scout ? .16 : .065, [Math.PI / 2, 0, 0], 'metal');
    w.cylinder(C.black, [0, .018, length * 1.12 + (scout ? .111 : .064)], .018, .018, .004, [Math.PI / 2, 0, 0]);
    w.ring(C.steel, [0, .018, length * 1.12 + (scout ? .11 : .062)], scout ? .030 : .027, .003);
    for (let i = 0; i < (smg ? 3 : 6); i++) {
      w.pad(C.rubber, [.061, .009, .13 + i * .034], [.009, .033, .019]);
      w.pad(C.rubber, [-.061, .009, .13 + i * .034], [.009, .033, .019]);
      w.pad(C.metal, [0, .081, -.09 + i * .041], [.095, .014, .016], [0, 0, 0], 'metal');
    }
    w.pad(C.metal, [.058, .015, .002], [.014, .056, .098], [0, 0, 0], 'metal');
    w.pad(C.black, [.067, .02, .003], [.006, .03, .067]);
    w.cylinder(C.steel, [.079, .011, -.018], .008, .008, .03, [0, 0, Math.PI / 2], 'metal');
    for (const z of [-.098, .109]) w.oval(C.steel, [.057, -.032, z], [.006, .006, .006], 'metal');
    w.seam(C.metal, [[-.037, -.067, -.05], [-.037, -.122, -.039], [-.037, -.122, .028], [-.037, -.061, .032]], .006, 'metal');
    w.pad(C.metal, [0, -.077, -.004], [.018, .047, .016], [-.25, 0, 0], 'metal');
    if (scout) {
      w.pad(C.metal, [0, .104, -.006], [.055, .055, .13], [0, 0, 0], 'metal');
      w.cylinder(C.gun, [0, .147, .015], .041, .034, .255, [Math.PI / 2, 0, 0], 'metal');
      w.cylinder(C.lens, [0, .147, .145], .034, .034, .006, [Math.PI / 2, 0, 0], 'glass');
      for (const z of [-.054, .076]) w.ring(C.steel, [0, .147, z], .037, .006);
      w.cylinder(C.metal, [0, .195, .02], .018, .018, .025, [0, 0, 0], 'metal');
    } else {
      w.pad(C.gun, [0, .106, .02], [.071, .069, .061]);
      w.pad(C.lens, [0, .112, .055], [.047, .034, .007], [0, 0, 0], 'glass');
    }
    w.seam(C.leather, [[.057, -.015, -.25], [.13, -.24, -.03], [.07, -.11, .28]], .009);
    w.finish();
    const magazine = joint(weapon, 'magazine', 0, -.083, .078);
    const mag = new Part(magazine, materials);
    mag.pad(C.gun, [0, -.093, .012], [.078, smg ? .25 : scout ? .10 : .19, .09], [-.14, 0, 0]);
    for (let i = 0; i < 3; i++) mag.pad(C.metal, [.042, -.035 - i * .042, .012], [.005, .008, .073], [0, 0, 0], 'metal');
    mag.pad(C.pack, [0, smg ? -.205 : scout ? -.14 : -.19, .029], [.085, .025, .099]);
    mag.finish(); weapon.userData.magazine = magazine;
  }
  const breacher = joint(gun, 'shotgun', 0, 0, 0); weapons.shotgun = breacher;
  const shotgun = new Part(breacher, materials);
  shotgun.pad(C.gun, [0,0,0], [.13,.14,.31]);
  shotgun.pad(C.leather, [0,-.02,-.29], [.12,.15,.3]);
  shotgun.pad(C.rubber, [0,-.03,-.45], [.15,.19,.055]);
  shotgun.pad(C.rubber, [0,-.12,-.08], [.08,.17,.08], [-.25,0,0]);
  shotgun.cylinder(C.steel,[0,.04,.36],.039,.039,.58,[Math.PI/2,0,0],'metal');
  shotgun.cylinder(C.gun,[0,-.055,.32],.029,.029,.5,[Math.PI/2,0,0],'metal');
  shotgun.cylinder(C.black,[0,.04,.655],.03,.03,.012,[Math.PI/2,0,0]);
  shotgun.pad(C.metal,[0,.098,.58],[.02,.055,.02]);
  for(let i=0;i<4;i++){shotgun.cylinder(C.orange,[-.078,-.012,-.1+i*.055],.021,.021,.105,[0,0,0],'metal');shotgun.cylinder(C.steel,[-.078,.043,-.1+i*.055],.022,.022,.015,[0,0,0],'metal');}
  shotgun.finish();
  const pump = joint(breacher,'pump',0,-.06,.30);
  const pumpArt = new Part(pump,materials);pumpArt.pad(C.leather,[0,0,0],[.15,.105,.21]);
  for(let i=0;i<6;i++)pumpArt.ring(C.rubber,[0,0,-.09+i*.036],.066,.008);
  pumpArt.finish();breacher.userData.pump=pump;
  breacher.userData.magazine=joint(breacher,'loading-port',0,-.083,0);
  const medicBadge = joint(chest,'medic-badge',.2,.4,.23);
  const badgeArt = new Part(medicBadge,materials);badgeArt.pad(0xe3ded0,[0,0,0],[.09,.12,.025]);badgeArt.pad(0xb25842,[0,0,.016],[.06,.022,.006]);badgeArt.pad(0xb25842,[0,0,.016],[.022,.07,.006]);badgeArt.finish();
  const rangerHood = joint(chest,'ranger-collar',0,.56,-.02);
  const hoodArt = new Part(rangerHood,materials);hoodArt.ring(0x827350,[0,0,0],.18,.055,[Math.PI/2,0,0],'fabric');hoodArt.finish();
  root.userData.medicBadge=medicBadge;root.userData.rangerHood=rangerHood;
  root.userData.gun = gun; root.userData.weaponId = 'carbine';
  root.userData.rig = { body, chest, pack, head, legs, arms, weapons, time: -1, phase: 0, aim: 0, reload: 0, reloadClock: 0, handTarget: new T.Vector3(), inverse: new T.Quaternion() };
  animateOperator(root, 0, 0, false, 0, 0);
  return root;
}

export function animateOperator(group: T.Group, time: number, speed: number, aim: boolean, recoil: number, reload: number) {
  const rig = group.userData.rig;
  if (!rig) return;
  const appearance = group.userData.operatorId || 'wayfarer';
  if(group.userData.appearance !== appearance){
    const colors:Record<string,number>={wayfarer:0xffffff,mender:0xffb9a0,ranger:0xbed094};
    group.userData.materials.fabric.color.setHex(colors[appearance] ?? colors.wayfarer);
    group.userData.medicBadge.visible=appearance==='mender';group.userData.rangerHood.visible=appearance==='ranger';
    group.userData.appearance=appearance;
  }
  const dt = rig.time < 0 ? 1 / 60 : T.MathUtils.clamp(time - rig.time, 0, .08);
  rig.time = time;
  const blend = 1 - Math.exp(-dt * 12);
  const walk = Math.min(1, Math.abs(speed) / 4.5), run = T.MathUtils.clamp((Math.abs(speed) - 4.5) / 3, 0, 1);
  rig.phase += dt * (7.5 + run * 4.5) * Math.min(1, Math.abs(speed) / .7);
  rig.aim += ((aim ? 1 : 0) - rig.aim) * blend;
  rig.reload += ((reload > 0 ? 1 : 0) - rig.reload) * blend;
  rig.reloadClock = reload > 0 ? rig.reloadClock + dt : 0;
  const breath = Math.sin(time * 2.2), step = Math.sin(rig.phase);
  rig.body.position.y = .99 + Math.abs(Math.sin(rig.phase * 2)) * .025 * walk;
  rig.body.rotation.z = step * .024 * walk;
  rig.chest.rotation.x = .018 * breath + run * .075 * (1 - rig.aim);
  rig.chest.rotation.y = step * .035 * walk * (1 - rig.aim);
  rig.chest.scale.y = 1 + breath * .004;
  rig.head.rotation.set(-.025 + rig.aim * .055, Math.sin(time * .43) * .035 * (1 - rig.aim), -rig.body.rotation.z * .4);
  rig.pack.rotation.x = Math.sin(rig.phase - .35) * .025 * walk;
  rig.pack.rotation.z = -step * .022 * walk;
  for (let i = 0; i < 2; i++) {
    const stride = Math.sin(rig.phase + i * Math.PI);
    const leg = rig.legs[i];
    leg.thigh.rotation.x = -stride * (.48 + run * .20) * walk;
    leg.thigh.rotation.z = (i === 0 ? .025 : -.025);
    leg.shin.rotation.x = Math.max(0, stride) * (.70 + run * .42) * walk + .035;
    leg.boot.rotation.x = -leg.thigh.rotation.x * .28 - leg.shin.rotation.x * .32;
  }
  const gun = group.userData.gun as T.Group;
  const selected = rig.weapons[group.userData.weaponId] ? group.userData.weaponId : 'carbine';
  for (const id of ['carbine', 'smg', 'scout', 'shotgun']) rig.weapons[id].visible = id === selected;
  const reloadWave = Math.sin(Math.min(1, rig.reloadClock / 1.6) * Math.PI);
  gun.position.set(.09 - rig.aim * .01, .29 + rig.aim * .19 + breath * .006 - rig.reload * .03, .205 - rig.aim * .045 - recoil * .085);
  gun.rotation.set(-.12 * (1 - rig.aim) - recoil * .11 + rig.reload * .26, -.075 * (1 - rig.aim) + rig.reload * .13, rig.reload * -.24 + step * .016 * walk * (1 - rig.aim));
  gun.updateMatrix();
  rig.weapons[selected].userData.magazine.position.y = -.083 - rig.reload * reloadWave * .095;
  rig.weapons.shotgun.userData.pump.position.z=.3-Math.sin(Math.min(1,recoil)*Math.PI)*.09-rig.reload*reloadWave*.08;
  // Two-bone arm IK: the stock, trigger hand and support hand remain connected
  // throughout aim blending, recoil and the magazine / belt reach of a reload.
  for (let i = 0; i < 2; i++) {
    const arm = rig.arms[i], support = i === 0;
    arm.target.set(support ? -.035 : 0, support ? -.057 : -.12, support ? .17 : -.089).applyMatrix4(gun.matrix);
    if (support && rig.reload > .001) {
      rig.handTarget.set(-.18, -.10, .17);
      const reach = Math.sin(Math.min(1, rig.reloadClock / .75) * Math.PI);
      arm.target.lerp(rig.handTarget, rig.reload * reach);
      if (rig.reloadClock > .75) {
        rig.handTarget.set(0, -.20 - reloadWave * .095, .09).applyMatrix4(gun.matrix);
        arm.target.lerp(rig.handTarget, rig.reload * Math.max(0, 1 - (rig.reloadClock - 1.5) * 3));
      }
    }
    arm.direction.copy(arm.target).sub(arm.shoulder);
    const distance = T.MathUtils.clamp(arm.direction.length(), .08, .58);
    arm.direction.normalize();
    arm.target.copy(arm.shoulder).addScaledVector(arm.direction, distance);
    // Both lengths are physical segment lengths; the bend plane points down/out.
    const along = (.30 * .30 - .285 * .285 + distance * distance) / (2 * distance);
    const height = Math.sqrt(Math.max(0, .30 * .30 - along * along));
    arm.elbow.set(support ? -.65 : .65, -1, -.12);
    arm.elbow.addScaledVector(arm.direction, -arm.elbow.dot(arm.direction)).normalize().multiplyScalar(height).addScaledVector(arm.direction, along).add(arm.shoulder);
    arm.direction.copy(arm.elbow).sub(arm.shoulder).normalize();
    arm.upper.quaternion.setFromUnitVectors(DOWN, arm.direction);
    rig.inverse.copy(arm.upper.quaternion).invert();
    arm.direction.copy(arm.target).sub(arm.elbow).normalize().applyQuaternion(rig.inverse);
    arm.lower.quaternion.setFromUnitVectors(DOWN, arm.direction);
    arm.wristRotation.copy(arm.upper.quaternion).multiply(arm.lower.quaternion).invert().multiply(gun.quaternion);
    arm.hand.quaternion.copy(arm.wristRotation);
  }
}
