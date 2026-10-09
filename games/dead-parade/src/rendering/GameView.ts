import * as THREE from 'three';
import type { Actor, Snapshot, Zone } from '../core/model';
import { CameraRig } from './CameraRig';
import { VFX } from './VFX';
import { CityWorld } from './World';
import { ActorRenderer } from './ActorRenderer';

type ViewMode = 'menu' | 'loadout' | 'playing' | 'end';
interface Trace { x: number; y: number; z: number; tx: number; tz: number; life: number; color: number; }
const effectColors = { bite: 0xc3db73, infection: 0xa7dc69, shot: 0xffd7a2, explosion: 0xffa454, hit: 0xb98454, debris: 0xd4b582, surge: 0x8be7d4, acid: 0xa8ed79 };

function displayActor(id: number, kind: Actor['kind'], x: number, z: number): Actor {
  return { id, kind, x, z, y: 0, angle: 0, hp: 100, maxHp: 100, state: 'idle', anim: 0, attack: 0, infected: false, timer: 0, vx: 0, vz: 0, cooldown: 0, ammo: 0, heal: false };
}

export class GameView {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly cameraRig: CameraRig;
  private readonly camera = new THREE.PerspectiveCamera(54, 1, 0.1, 260);
  private readonly actors = new ActorRenderer();
  private readonly vfx: VFX;
  private world: CityWorld;
  private readonly sunlight = new THREE.DirectionalLight(0xffd5a0, 3.1);
  private readonly skylight = new THREE.HemisphereLight(0xc1e8eb, 0x3d4a32, 2.5);
  private readonly rim = new THREE.DirectionalLight(0x8edddd, 1.6);
  private readonly focus = new THREE.Vector3();
  private readonly cameraTarget = new THREE.Vector3();
  private readonly sunTarget = new THREE.Object3D();
  private mode: ViewMode = 'menu';
  private quality = 'high';
  private elapsed = 0;
  private preview = '';
  private previewPulse = 0;
  private readonly previewActors = [displayActor(-1, 'leader', 0, 0)];
  private readonly menuActors: Actor[] = [displayActor(-1, 'leader', 4, 39)];
  private readonly platform = new THREE.Group();
  private readonly transform = new THREE.Object3D();
  private readonly color = new THREE.Color();
  private readonly warning: THREE.InstancedMesh;
  private readonly projectileMesh: THREE.InstancedMesh;
  private readonly cloudMesh: THREE.InstancedMesh;
  private readonly leaderRing: THREE.Mesh;
  private readonly traces: Trace[] = Array.from({ length: 96 }, () => ({ x: 0, y: 0, z: 0, tx: 0, tz: 0, life: 0, color: 0xffffff }));
  private traceCursor = 0;
  private readonly linePositions = new Float32Array(24576);
  private readonly lineColors = new Float32Array(24576);
  private readonly lineGeometry = new THREE.BufferGeometry();
  private readonly lines: THREE.LineSegments;
  private lineCount = 0;
  private markerCapacity = 256;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.15;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.scene.background = new THREE.Color(0x54838e);
    this.scene.fog = new THREE.FogExp2(0x54838e, 0.0105);
    this.scene.add(this.skylight);
    this.sunlight.position.set(-25, 38, 25); this.sunlight.castShadow = true;
    this.sunlight.shadow.mapSize.set(2048, 2048);
    this.sunlight.shadow.camera.left = this.sunlight.shadow.camera.bottom = -32;
    this.sunlight.shadow.camera.right = this.sunlight.shadow.camera.top = 32;
    this.sunlight.shadow.camera.near = 1; this.sunlight.shadow.camera.far = 110;
    this.sunlight.shadow.normalBias = 0.055; this.sunlight.shadow.bias = -0.0002;
    this.scene.add(this.sunlight, this.sunTarget); this.sunlight.target = this.sunTarget;
    this.rim.position.set(20, 15, -30); this.scene.add(this.rim);
    this.world = new CityWorld(0); this.scene.add(this.world.root, this.actors.root);
    this.environment();
    this.vfx = new VFX(this.scene, 640);
    this.cameraRig = new CameraRig(this.camera);
    this.cameraRig.distance = 10;
    this.warning = new THREE.InstancedMesh(new THREE.RingGeometry(0.91, 1, 32), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.8, side: THREE.DoubleSide, depthWrite: false }), this.markerCapacity);
    this.projectileMesh = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.17, 1), new THREE.MeshBasicMaterial({ color: 0xffffff }), this.markerCapacity);
    this.cloudMesh = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1, 1), new THREE.MeshBasicMaterial({ color: 0xb2d86d, transparent: true, opacity: 0.17, depthWrite: false }), this.markerCapacity * 4);
    for (const mesh of [this.warning, this.projectileMesh, this.cloudMesh]) { mesh.count = 0; mesh.frustumCulled = false; mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.scene.add(mesh); }
    this.lineGeometry.setAttribute('position', new THREE.BufferAttribute(this.linePositions, 3).setUsage(THREE.DynamicDrawUsage));
    this.lineGeometry.setAttribute('color', new THREE.BufferAttribute(this.lineColors, 3).setUsage(THREE.DynamicDrawUsage));
    this.lineGeometry.setDrawRange(0, 0);
    this.lines = new THREE.LineSegments(this.lineGeometry, new THREE.LineBasicMaterial({ vertexColors: true, transparent: true, opacity: 0.85, depthWrite: false })); this.lines.frustumCulled = false; this.scene.add(this.lines);
    this.leaderRing = new THREE.Mesh(new THREE.RingGeometry(0.74, 0.81, 40), new THREE.MeshBasicMaterial({ color: 0xe3e4ab, transparent: true, opacity: 0.65, side: THREE.DoubleSide, depthWrite: false })); this.leaderRing.rotation.x = -Math.PI / 2; this.scene.add(this.leaderRing);
    const plinth = new THREE.Mesh(new THREE.CylinderGeometry(1.5, 1.65, 0.16, 64), new THREE.MeshStandardMaterial({ color: 0x294e4b, metalness: 0.2, roughness: 0.65 })); plinth.position.y = -0.09; plinth.receiveShadow = true; this.platform.add(plinth);
    const trim = new THREE.Mesh(new THREE.TorusGeometry(1.5, 0.018, 6, 80), new THREE.MeshBasicMaterial({ color: 0xcad286 })); trim.rotation.x = Math.PI / 2; this.platform.add(trim); this.platform.visible = false; this.scene.add(this.platform);
    const kinds: Actor['kind'][] = ['walker', 'walker', 'runner', 'walker', 'brute', 'spitter', 'walker', 'bomber', 'walker', 'runner', 'walker', 'walker'];
    for (let i = 0; i < 24; i++) this.menuActors.push(displayActor(-2 - i, kinds[i % kinds.length], (i % 6 - 2.5) * 1.55, 32.5 - Math.floor(i / 6) * 2.5));
    this.resize();
    this.update(undefined, 0, 'menu');
  }

  zone(index: number): Zone {
    this.world.dispose();
    this.world = new CityWorld(Math.max(0, Math.floor(index)));
    this.scene.add(this.world.root);
    this.environment();
    this.cameraRig.reset(); this.vfx.clear();
    for (const trace of this.traces) trace.life = 0;
    return this.world.data;
  }

  private environment(): void {
    const palette = this.world.atmosphere, weather = this.world.data.weather;
    const overcast = weather === 1 || weather === 2 || weather === 4 || weather === 5;
    (this.scene.background as THREE.Color).setHex(palette.sky);
    const fog = this.scene.fog as THREE.FogExp2;
    fog.color.setHex(palette.sky);
    fog.density = weather === 4 ? 0.029 : weather === 5 ? 0.019 : weather === 2 ? 0.020 : palette.fog;
    this.sunlight.color.setHex(palette.sun); this.sunlight.intensity = overcast ? 2.1 : 3.3;
    this.skylight.color.setHex(palette.sky); this.skylight.groundColor.setHex(palette.ground); this.skylight.intensity = overcast ? 2.3 : 2.7;
    this.rim.color.setHex(palette.sky); this.rim.intensity = overcast ? 1.2 : 1.6;
    this.renderer.toneMappingExposure = weather === 5 ? 1.04 : 1.15;
  }

  resize(): void {
    const width = Math.max(1, this.renderer.domElement.clientWidth || window.innerWidth);
    const height = Math.max(1, this.renderer.domElement.clientHeight || window.innerHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, this.quality === 'low' ? 1 : this.quality === 'medium' ? 1.5 : 2));
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.composition(); this.camera.updateProjectionMatrix();
  }

  private composition(): void {
    const width = Math.max(1, this.renderer.domElement.clientWidth || window.innerWidth), height = Math.max(1, this.renderer.domElement.clientHeight || window.innerHeight);
    this.camera.clearViewOffset();
    if (this.mode === 'menu') this.camera.setViewOffset(width, height, -width * 0.2, 0, width, height);
    if (this.mode === 'loadout') this.camera.setViewOffset(width, height, width * 0.28, 0, width, height);
  }

  setQuality(shadows: boolean, quality: string): void {
    this.quality = quality.toLowerCase(); this.renderer.shadowMap.enabled = shadows;
    this.sunlight.castShadow = shadows;
    this.resize();
  }

  previewItem(id: string): void { this.preview = id; this.previewPulse = 1; }

  update(snapshot: Snapshot | undefined, dt: number, mode: ViewMode): void {
    dt = Math.min(0.1, Math.max(0, dt)); this.elapsed += dt;
    if (mode !== this.mode) {
      this.mode = mode; this.cameraRig.reset(); this.composition();
      if (mode !== 'loadout') { this.preview = ''; this.previewPulse = 0; }
      this.vfx.clear(); for (const trace of this.traces) trace.life = 0;
    }
    this.platform.visible = mode === 'loadout'; this.world.root.visible = mode !== 'loadout';
    this.leaderRing.visible = mode === 'playing';
    this.warning.visible = this.projectileMesh.visible = this.cloudMesh.visible = this.lines.visible = mode === 'playing' || mode === 'end';
    let actorList: readonly Actor[];
    if (mode === 'loadout') {
      const actor = this.previewActors[0]; actor.angle = 0.18 + Math.sin(this.elapsed * 0.27) * 0.5 + this.previewPulse * 0.25;
      actor.anim += dt; actor.y = Math.sin(this.previewPulse * Math.PI) * 0.07; actor.attack = this.previewPulse > 0.7 ? 0.15 : 0;
      this.previewPulse = Math.max(0, this.previewPulse - dt * 1.5);
      this.camera.position.set(1, 2.6, 6.5); this.camera.lookAt(0, 1.42, 0); this.camera.fov = 39;
      actorList = this.previewActors; this.focus.set(0, 0, 0);
    } else if (mode === 'menu' || !snapshot) {
      for (const actor of this.menuActors) { actor.anim += dt; actor.angle = Math.sin(this.elapsed * 0.2 + actor.id) * 0.13; }
      this.camera.position.set(6.2 + Math.sin(this.elapsed * 0.08) * 0.7, 3.8, 47.4); this.camera.lookAt(4, 1.6, 39); this.camera.fov = 49;
      actorList = this.menuActors; this.focus.set(4, 0, 39); this.world.update(this.elapsed, false);
    } else {
      actorList = snapshot.actors;
      this.focus.set(snapshot.leader.x, snapshot.leader.y, snapshot.leader.z);
      if (mode === 'end') {
        this.cameraTarget.set(this.focus.x + 12, this.focus.y + 13, this.focus.z + 15);
        this.camera.position.lerp(this.cameraTarget, 1 - Math.exp(-dt * 0.7)); this.camera.lookAt(this.focus); this.camera.fov = 55;
      } else {
        this.cameraRig.update(this.focus, dt, Math.hypot(snapshot.leader.vx, snapshot.leader.vz) > 8, snapshot.hordeCounts.reduce((n, count) => n + count, 0), this.world.obstacles);
      }
      this.leaderRing.position.set(snapshot.leader.x, 0.04, snapshot.leader.z);
      (this.leaderRing.material as THREE.MeshBasicMaterial).color.setHex(snapshot.surgeTime > 0 ? 0x76ffe0 : 0xd3e6ad);
      this.world.update(snapshot.time, snapshot.readyExit);
      this.effects(snapshot, dt);
    }
    this.camera.updateProjectionMatrix();
    this.sunlight.position.set(this.focus.x - 23, 35, this.focus.z + 18); this.sunTarget.position.copy(this.focus);
    this.actors.update(actorList, this.elapsed, this.camera, this.quality, mode === 'loadout' ? this.preview : '');
    this.vfx.update(dt);
    this.renderer.render(this.scene, this.camera);
  }

  private line(x: number, y: number, z: number, tx: number, ty: number, tz: number, color: number): void {
    if (this.lineCount + 6 > this.linePositions.length) return;
    let n = this.lineCount;
    this.linePositions[n] = x; this.linePositions[n + 1] = y; this.linePositions[n + 2] = z;
    this.linePositions[n + 3] = tx; this.linePositions[n + 4] = ty; this.linePositions[n + 5] = tz;
    this.color.setHex(color);
    for (let i = 0; i < 2; i++, n += 3) { this.lineColors[n] = this.color.r; this.lineColors[n + 1] = this.color.g; this.lineColors[n + 2] = this.color.b; }
    this.lineCount += 6;
  }

  private effects(snapshot: Snapshot, dt: number): void {
    for (const effect of snapshot.effects) {
      const color = effect.color ?? effectColors[effect.kind];
      if (effect.kind === 'shot') {
        const trace = this.traces[this.traceCursor]; this.traceCursor = (this.traceCursor + 1) % this.traces.length;
        trace.x = effect.x; trace.y = effect.y || 1.35; trace.z = effect.z; trace.tx = effect.tx ?? effect.x; trace.tz = effect.tz ?? effect.z; trace.color = color; trace.life = 0.095;
      } else this.vfx.burst(effect.x, effect.y || 1, effect.z, color, effect.kind === 'explosion' ? 36 : effect.kind === 'surge' ? 30 : 9);
    }
    this.lineCount = 0;
    for (const trace of this.traces) {
      if (trace.life <= 0) continue;
      trace.life -= dt; this.line(trace.x, trace.y, trace.z, trace.tx, 1.1, trace.tz, trace.color);
    }
    let warnings = 0, projectiles = 0, clouds = 0;
    for (const projectile of snapshot.projectiles) {
      if (!projectile.active || projectiles >= this.markerCapacity) continue;
      const color = projectile.friendly ? 0xa6f178 : 0xff6747;
      this.transform.position.set(projectile.x, Math.max(0.18, projectile.y), projectile.z); this.transform.rotation.set(this.elapsed * 5, 0, this.elapsed * 4); this.transform.scale.setScalar(projectile.kind === 'mortar' ? 1.8 : 1); this.transform.updateMatrix();
      this.projectileMesh.setMatrixAt(projectiles, this.transform.matrix); this.projectileMesh.setColorAt(projectiles++, this.color.setHex(color));
      const impactTime = projectile.kind === 'grenade' ? Math.max(0, projectile.timer) : Math.max(0, (projectile.vy + Math.sqrt(projectile.vy * projectile.vy + 19.6 * Math.max(0, projectile.y))) / 9.8);
      const tx = projectile.x + projectile.vx * impactTime, tz = projectile.z + projectile.vz * impactTime;
      this.transform.position.set(tx, 0.045, tz); this.transform.rotation.set(-Math.PI / 2, 0, 0);
      this.transform.scale.setScalar(Math.max(0.3, projectile.radius) * (0.96 + Math.sin(this.elapsed * 12) * 0.04)); this.transform.updateMatrix();
      this.warning.setMatrixAt(warnings, this.transform.matrix); this.warning.setColorAt(warnings++, this.color.setHex(color));
      if (projectile.kind !== 'grenade') {
        let px = projectile.x, py = projectile.y, pz = projectile.z;
        for (let i = 1; i <= 8; i++) {
          const t = impactTime * i / 8, x = projectile.x + projectile.vx * t, z = projectile.z + projectile.vz * t, y = Math.max(0.1, projectile.y + projectile.vy * t - 4.9 * t * t);
          this.line(px, py, pz, x, y, z, color); px = x; py = y; pz = z;
        }
      }
    }
    for (const cloud of snapshot.clouds) {
      if (!cloud.active || warnings >= this.markerCapacity || clouds + 4 >= this.markerCapacity * 4) continue;
      this.transform.position.set(cloud.x, 0.055, cloud.z); this.transform.rotation.set(-Math.PI / 2, 0, 0); this.transform.scale.setScalar(cloud.radius); this.transform.updateMatrix();
      this.warning.setMatrixAt(warnings, this.transform.matrix); this.warning.setColorAt(warnings++, this.color.setHex(0xb3df69));
      for (let i = 0; i < 4; i++) {
        const phase = this.elapsed * 0.65 + i * Math.PI / 2;
        this.transform.position.set(cloud.x + Math.cos(phase) * cloud.radius * 0.35, 0.3 + i * 0.12, cloud.z + Math.sin(phase) * cloud.radius * 0.35);
        this.transform.rotation.set(0, phase, 0); this.transform.scale.set(cloud.radius * 0.65, 0.55 + Math.sin(phase) * 0.1, cloud.radius * 0.65); this.transform.updateMatrix(); this.cloudMesh.setMatrixAt(clouds++, this.transform.matrix);
      }
    }
    this.warning.count = warnings; this.projectileMesh.count = projectiles; this.cloudMesh.count = clouds;
    for (const mesh of [this.warning, this.projectileMesh, this.cloudMesh]) { mesh.instanceMatrix.needsUpdate = true; if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true; }
    this.lineGeometry.setDrawRange(0, this.lineCount / 3); this.lineGeometry.attributes.position.needsUpdate = true; this.lineGeometry.attributes.color.needsUpdate = true;
  }
}
