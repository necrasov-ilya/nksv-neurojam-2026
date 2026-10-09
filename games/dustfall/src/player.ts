import * as T from "three";
import { createOperator, animateOperator } from "./operator";
type World = {
  groundHeight(x: number, z: number): number;
  colliders: { x: number; z: number; hx: number; hz: number; height: number }[];
  solids: T.Object3D[];
};
export class Player {
  mesh = createOperator();
  position = new T.Vector3(0, 0, 145);
  velocity = new T.Vector3();
  yaw = 0;
  pitch = -0.13;
  hp = 100;
  armor = 50;
  stamina = 100;
  aim = false;
  sprinting = false;
  crouching = false;
  recoil = 0;
  vertical = 0;
  grounded = true;
  keys = new Set<string>();
  moving = 0;
  private fatigue = 0;
  private ray = new T.Raycaster();
  private target = new T.Vector3();
  private desired = new T.Vector3();
  private forward = new T.Vector3();
  private right = new T.Vector3();
  private delta = new T.Vector3();
  private camInitialized = false;
  constructor(
    public camera: T.PerspectiveCamera,
    public world: World,
  ) {
    this.reset();
  }
  reset() {
    this.position.set(0, this.world.groundHeight(0, 145), 145);
    this.velocity.set(0, 0, 0);
    this.yaw = 0;
    this.pitch = -0.12;
    this.hp = 100;
    this.stamina = 100;
    this.vertical = 0;
    this.aim = false;
    this.recoil = 0;
    this.keys.clear();
    this.fatigue = 0;
    this.sprinting = false;
    this.crouching = false;
    this.mesh.scale.set(1, 1, 1);
    this.camInitialized = false;
    this.mesh.rotation.set(0, 0, 0);
    this.mesh.position.copy(this.position);
  }
  look(x: number, y: number, sensitivity: number, invert: boolean) {
    this.yaw += x * 0.002 * sensitivity;
    this.pitch = T.MathUtils.clamp(
      this.pitch - y * 0.0016 * sensitivity * (invert ? -1 : 1),
      -0.9,
      0.55,
    );
  }
  vault() {
    if (!this.grounded) return;
    this.vertical = 5.2;
    this.grounded = false;
  }
  blocked(x: number, z: number, y: number) {
    for (const c of this.world.colliders) {
      const top = this.world.groundHeight(c.x, c.z) + c.height;
      if (y >= top - 0.15 || (this.grounded && top - y <= .38)) continue;
      if (Math.abs(x - c.x) < c.hx + 0.36 && Math.abs(z - c.z) < c.hz + 0.36)
        return true;
    }
    return false;
  }
  update(dt: number, time: number, reloading: boolean) {
    this.crouching = this.keys.has("KeyC") || this.keys.has("ControlLeft");
    this.sprinting =
      this.keys.has("ShiftLeft") &&
      !this.aim &&
      !this.crouching &&
      this.stamina > 2 &&
      this.keys.has("KeyW");
    this.forward.set(Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    this.right.set(Math.cos(this.yaw), 0, Math.sin(this.yaw));
    this.desired.set(0, 0, 0);
    if (this.keys.has("KeyW")) this.desired.add(this.forward);
    if (this.keys.has("KeyS")) this.desired.sub(this.forward);
    if (this.keys.has("KeyD")) this.desired.add(this.right);
    if (this.keys.has("KeyA")) this.desired.sub(this.right);
    const speed = this.sprinting
      ? 8.5
      : this.crouching
        ? 2.1
        : this.aim
          ? 2.8
          : 4.5;
    this.desired.normalize().multiplyScalar(speed);
    this.velocity.lerp(this.desired, 1 - Math.exp(-18 * dt));
    this.moving = this.velocity.length();
    if (this.sprinting && this.moving > 1) {
      this.stamina = Math.max(0, this.stamina - dt * 12);
      this.fatigue = 1.2;
    } else {
      this.fatigue -= dt;
      if (this.fatigue <= 0)
        this.stamina = Math.min(100, this.stamina + dt * 18);
    }
    this.vertical -= 15 * dt;
    this.position.y += this.vertical * dt;
    const nx = T.MathUtils.clamp(
        this.position.x + this.velocity.x * dt,
        -205,
        205,
      ),
      nz = T.MathUtils.clamp(this.position.z + this.velocity.z * dt, -205, 205);
    if (!this.blocked(nx, this.position.z, this.position.y))
      this.position.x = nx;
    if (!this.blocked(this.position.x, nz, this.position.y))
      this.position.z = nz;
    let floor = this.world.groundHeight(this.position.x, this.position.z);
    for (const c of this.world.colliders) {
      if (
        Math.abs(this.position.x - c.x) < c.hx + 0.2 &&
        Math.abs(this.position.z - c.z) < c.hz + 0.2
      ) {
        const top = this.world.groundHeight(c.x, c.z) + c.height;
        if (this.position.y >= top - 0.4) floor = Math.max(floor, top);
      }
    }
    if (this.position.y <= floor) {
      this.position.y = floor;
      if (this.vertical < 0) this.vertical = 0;
      this.grounded = true;
    } else this.grounded = false;
    this.mesh.position.copy(this.position);
    this.mesh.rotation.y = Math.PI - this.yaw;
    this.mesh.scale.y = this.crouching ? 0.76 : 1;
    this.recoil = Math.max(0, this.recoil - dt * 5);
    animateOperator(this.mesh, time, this.moving, this.aim, this.recoil, reloading ? 1 : 0);
    this.updateCamera(dt);
  }
  updateCamera(dt: number) {
    const height = this.crouching ? 1.25 : 1.7;
    this.target.copy(this.position);
    this.target.y += height;
    const distance = this.aim ? 2.5 : 5.2;
    this.forward.set(
      Math.sin(this.yaw) * Math.cos(this.pitch),
      Math.sin(this.pitch),
      -Math.cos(this.yaw) * Math.cos(this.pitch),
    );
    this.right.set(Math.cos(this.yaw), 0, Math.sin(this.yaw));
    this.desired
      .copy(this.target)
      .addScaledVector(this.forward, -distance)
      .addScaledVector(this.right, this.aim ? 0.7 : 0.85);
    this.desired.y += 0.55;
    this.delta.copy(this.desired).sub(this.target);
    const length = this.delta.length();
    this.ray.set(this.target, this.delta.normalize());
    this.ray.far = length;
    const hits = this.ray.intersectObjects(this.world.solids, false);
    if (hits.length)
      this.desired
        .copy(this.target)
        .addScaledVector(this.delta, Math.max(0.25, hits[0].distance - 0.25));
    if (!this.camInitialized || hits.length) {
      this.camera.position.copy(this.desired);
      this.camInitialized = true;
    } else this.camera.position.lerp(this.desired, 1 - Math.exp(-18 * dt));
    this.camera.position.y = Math.max(this.camera.position.y, this.world.groundHeight(this.camera.position.x, this.camera.position.z) + .25);
    this.target.addScaledVector(this.forward, 60);
    this.camera.lookAt(this.target);
    const fov = this.aim ? 43 : this.sprinting ? 67 : 59;
    this.camera.fov = T.MathUtils.lerp(
      this.camera.fov,
      fov,
      1 - Math.exp(-10 * dt),
    );
    this.camera.updateProjectionMatrix();
  }
}
