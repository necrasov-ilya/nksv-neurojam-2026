// Uniform spatial hash for neighbor queries. Rebuilt per tick from dirty lists.

export interface SpatialItem {
  x: number;
  z: number;
  r: number; // query radius contribution
}

interface Cell<T> { items: T[]; }

export class SpatialGrid<T extends SpatialItem> {
  readonly cell: number;
  private map = new Map<number, Cell<T>>();

  constructor(cellSize = 6) { this.cell = cellSize; }
  private key(cx: number, cz: number): number { return (cx & 0xffff) * 65536 + (cz & 0xffff); }

  clear(): void { this.map.clear(); }

  insert(item: T): void {
    const cx = Math.floor(item.x / this.cell), cz = Math.floor(item.z / this.cell);
    const k = this.key(cx, cz);
    let c = this.map.get(k);
    if (!c) { c = { items: [] }; this.map.set(k, c); }
    c.items.push(item);
  }

  /** Collect items within radius (2D, xz) around point. Writes into out array. */
  query(x: number, z: number, r: number, out: T[]): number {
    out.length = 0;
    const cx0 = Math.floor((x - r) / this.cell), cx1 = Math.floor((x + r) / this.cell);
    const cz0 = Math.floor((z - r) / this.cell), cz1 = Math.floor((z + r) / this.cell);
    for (let cx = cx0; cx <= cx1; cx++) {
      for (let cz = cz0; cz <= cz1; cz++) {
        const c = this.map.get(this.key(cx, cz));
        if (!c) continue;
        const items = c.items;
        for (let i = 0; i < items.length; i++) {
          const it = items[i];
          const dx = it.x - x, dz = it.z - z;
          const rr = r + it.r;
          if (dx * dx + dz * dz <= rr * rr) out.push(it);
        }
      }
    }
    return out.length;
  }

  /** Nearest item within radius, or null. */
  nearest(x: number, z: number, r: number, out: T[]): T | null {
    const n = this.query(x, z, r, out);
    if (n === 0) return null;
    let best: T | null = null, bd = Infinity;
    for (let i = 0; i < out.length; i++) {
      const it = out[i];
      const d = (it.x - x) * (it.x - x) + (it.z - z) * (it.z - z);
      if (d < bd) { bd = d; best = it; }
    }
    return best;
  }
}
