import * as THREE from 'three';

export class VFX {
  readonly mesh: THREE.InstancedMesh;
  private readonly positions: Float32Array;
  private readonly velocities: Float32Array;
  private readonly life: Float32Array;
  private readonly transform = new THREE.Object3D();
  private readonly color = new THREE.Color();
  private cursor = 0;

  constructor(scene: THREE.Scene, private readonly capacity = 256) {
    this.positions = new Float32Array(capacity * 3);
    this.velocities = new Float32Array(capacity * 3);
    this.life = new Float32Array(capacity);
    this.mesh = new THREE.InstancedMesh(
      new THREE.IcosahedronGeometry(0.12, 0),
      new THREE.MeshBasicMaterial({ color: 0xffffff }),
      capacity,
    );
    this.mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.mesh.frustumCulled = false;
    this.transform.scale.setScalar(0);
    this.transform.updateMatrix();
    for (let i = 0; i < capacity; i++) {
      this.mesh.setMatrixAt(i, this.transform.matrix);
      this.mesh.setColorAt(i, this.color);
    }
    scene.add(this.mesh);
  }

  burst(x: number, y: number, z: number, color = 0x9ecb3b, count = 12): void {
    this.color.setHex(color);
    for (let n = 0; n < Math.min(count, this.capacity); n++) {
      const i = this.cursor;
      this.cursor = (this.cursor + 1) % this.capacity;
      const p = i * 3;
      this.positions[p] = x; this.positions[p + 1] = y; this.positions[p + 2] = z;
      this.velocities[p] = (Math.random() - 0.5) * 6;
      this.velocities[p + 1] = 2 + Math.random() * 3;
      this.velocities[p + 2] = (Math.random() - 0.5) * 6;
      this.life[i] = 0.5 + Math.random() * 0.4;
      this.mesh.setColorAt(i, this.color);
    }
    if (this.mesh.instanceColor) this.mesh.instanceColor.needsUpdate = true;
  }

  update(dt: number): void {
    for (let i = 0; i < this.capacity; i++) {
      if (this.life[i] <= 0) continue;
      const p = i * 3;
      this.life[i] = Math.max(0, this.life[i] - dt);
      this.velocities[p + 1] -= 9.8 * dt;
      for (let axis = 0; axis < 3; axis++) this.positions[p + axis] += this.velocities[p + axis] * dt;
      this.transform.position.fromArray(this.positions, p);
      this.transform.scale.setScalar(Math.min(1, this.life[i] * 5));
      this.transform.updateMatrix();
      this.mesh.setMatrixAt(i, this.transform.matrix);
    }
    this.mesh.instanceMatrix.needsUpdate = true;
  }

  clear(): void {
    this.life.fill(0);
    this.transform.scale.setScalar(0);
    this.transform.updateMatrix();
    for (let i = 0; i < this.capacity; i++) this.mesh.setMatrixAt(i, this.transform.matrix);
    this.mesh.instanceMatrix.needsUpdate = true;
  }

  dispose(): void {
    this.mesh.removeFromParent();
    this.mesh.geometry.dispose();
    (this.mesh.material as THREE.Material).dispose();
    this.mesh.dispose();
  }
}
