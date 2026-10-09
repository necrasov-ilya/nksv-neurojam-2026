import { test, expect } from 'bun:test';
import { PerspectiveCamera, Vector3 } from 'three';
import { Player } from './player';

test('terrain contact survives movement, jumps and full camera rotation', () => {
  const world = { solids: [], colliders: [], groundHeight: (x: number, z: number) => Math.max(0, -z * .035) };
  const player = new Player(new PerspectiveCamera(), world);
  let minimumClearance = Infinity;
  for (let frame = 0; frame < 3600; frame++) {
    player.yaw = frame / 3600 * Math.PI * 2;
    player.keys.add('KeyW');
    if (frame % 300 === 0) player.vault();
    player.update(1 / 60, frame / 60, false);
    minimumClearance = Math.min(minimumClearance, player.position.y - world.groundHeight(player.position.x, player.position.z));
    const forward = new Vector3(0, 0, 1).applyQuaternion(player.mesh.quaternion);
    const expected = new Vector3(Math.sin(player.yaw), 0, -Math.cos(player.yaw));
    expect(forward.dot(expected)).toBeCloseTo(1, 6);
  }
  expect(minimumClearance).toBeGreaterThanOrEqual(0);
});
