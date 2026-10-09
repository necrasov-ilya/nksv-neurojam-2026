// Keyboard + mouse input state. Movement is reported in world axes here;
// the leader applies camera yaw.

const SCROLL_KEYS = new Set([
  "Space",
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
]);

export class Input {
  private keys = new Set<string>();
  private pressed = new Set<string>();
  private consumed: string[] = [];
  private mouse = { x: 0, y: 0, dx: 0, dy: 0, lmb: false, rmb: false, wheel: 0 };
  private enabled = false;

  attach(canvas: HTMLCanvasElement): void {
    const keyDown = (e: KeyboardEvent) => {
      if (SCROLL_KEYS.has(e.code)) e.preventDefault();
      if (!this.keys.has(e.code)) {
        this.pressed.add(e.code);
        this.keys.add(e.code);
      }
    };
    const keyUp = (e: KeyboardEvent) => {
      this.keys.delete(e.code);
    };
    const focusLost = () => this.keys.clear();
    const mouseMove = (e: MouseEvent) => {
      // Pointer-position independent deltas work without pointer lock.
      this.mouse.dx += e.movementX ?? 0;
      this.mouse.dy += e.movementY ?? 0;
      this.mouse.x = e.clientX;
      this.mouse.y = e.clientY;
    };
    const mouseDown = (e: MouseEvent) => {
      if (e.button === 0) this.mouse.lmb = true;
      if (e.button === 2) this.mouse.rmb = true;
    };
    const mouseUp = (e: MouseEvent) => {
      if (e.button === 0) this.mouse.lmb = false;
      if (e.button === 2) this.mouse.rmb = false;
    };
    const wheel = (e: WheelEvent) => {
      this.mouse.wheel += e.deltaY;
    };
    const context = (e: Event) => e.preventDefault();

    window.addEventListener("keydown", keyDown);
    window.addEventListener("keyup", keyUp);
    window.addEventListener("blur", focusLost);
    document.addEventListener("mousemove", mouseMove);
    document.addEventListener("mousedown", mouseDown);
    document.addEventListener("mouseup", mouseUp);
    document.addEventListener("wheel", wheel, { passive: true });
    window.addEventListener("contextmenu", context);
    this.enabled = true;
  }

  setEnabled(on: boolean): void {
    this.enabled = on;
    if (!on) this.keys.clear();
  }

  /** Key held this frame */
  isDown(code: string): boolean {
    return this.enabled && this.keys.has(code);
  }

  /** Edge trigger this frame */
  wasPressed(code: string): boolean {
    return this.pressed.has(code);
  }

  /** Consume an edge trigger (one-shot UI actions). */
  consume(code: string): boolean {
    if (this.pressed.has(code)) {
      this.pressed.delete(code);
      return true;
    }
    return false;
  }

  clearFrame(): void {
    this.pressed.clear();
    this.mouse.dx = 0;
    this.mouse.dy = 0;
    this.mouse.wheel = 0;
    this.consumed.length = 0;
  }

  getMouseDx(): number {
    return this.mouse.dx;
  }
  getMouseDy(): number {
    return this.mouse.dy;
  }
  isLmb(): boolean {
    return this.mouse.lmb;
  }
  isRmb(): boolean {
    return this.mouse.rmb;
  }
  getWheel(): number {
    return this.mouse.wheel;
  }
  cursor(): { x: number; y: number } {
    return { x: this.mouse.x, y: this.mouse.y };
  }

  /** Movement vector in world axes (positive Z = "north" on screen for WASD W). */
  moveVec(): { x: number; z: number } {
    let x = 0;
    let z = 0;
    if (this.isDown("KeyW")) z += 1;
    if (this.isDown("KeyS")) z -= 1;
    if (this.isDown("KeyA")) x -= 1;
    if (this.isDown("KeyD")) x += 1;
    const len = Math.sqrt(x * x + z * z);
    if (len > 0) {
      x /= len;
      z /= len;
    }
    return { x, z };
  }
}