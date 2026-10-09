import * as THREE from 'three';

export class CameraRig {
  yaw = 0;
  pitch = 0.45;
  distance = 12;
  private readonly focus = new THREE.Vector3();
  private readonly desired = new THREE.Vector3();
  private readonly direction = new THREE.Vector3();
  private readonly raycaster = new THREE.Raycaster();
  private readonly hits: THREE.Intersection[] = [];
  private initialized = false;

  constructor(readonly camera: THREE.PerspectiveCamera) {}

  rotate(dx: number, dy: number, sensitivity = 1): void {
    this.yaw -= dx * 0.002 * sensitivity;
    this.pitch = THREE.MathUtils.clamp(this.pitch + dy * 0.002 * sensitivity, 0.12, 1.15);
  }

  update(target: THREE.Vector3, dt: number, sprinting = false, hordeSize = 5, obstacles: THREE.Object3D[] = []): void {
    this.focus.copy(target); this.focus.y += 1.4;
    const distance = this.distance + Math.min(5, hordeSize * 0.018);
    this.direction.set(Math.sin(this.yaw) * Math.cos(this.pitch), Math.sin(this.pitch), Math.cos(this.yaw) * Math.cos(this.pitch));
    this.raycaster.set(this.focus, this.direction);
    this.raycaster.far = distance;
    this.hits.length = 0;
    this.raycaster.intersectObjects(obstacles, true, this.hits);
    const clearDistance = this.hits.length ? Math.max(0.3, this.hits[0].distance - 0.3) : distance;
    this.desired.copy(this.focus).addScaledVector(this.direction, clearDistance);
    if (!this.initialized || this.hits.length) this.camera.position.copy(this.desired);
    else this.camera.position.lerp(this.desired, 1 - Math.exp(-12 * dt));
    this.initialized = true;
    this.camera.lookAt(this.focus);
    this.camera.fov = THREE.MathUtils.damp(this.camera.fov, sprinting ? 65 : 58, 8, dt);
    this.camera.updateProjectionMatrix();
  }

  reset(): void { this.initialized = false; this.yaw = 0; this.pitch = 0.45; }
}
