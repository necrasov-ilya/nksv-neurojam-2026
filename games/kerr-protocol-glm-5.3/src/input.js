// Mouse orbit + wheel dolly + keyboard. Dismisses hint on first input.
export class Input {
  constructor(canvas, hooks) {
    this.hooks = hooks;
    this.drag = null;
    this.hintShown = true;
    canvas.addEventListener('pointerdown', (e) => {
      if (e.target !== canvas) return;
      this.drag = { x: e.clientX, y: e.clientY, id: e.pointerId };
      try { canvas.setPointerCapture(e.pointerId); } catch (_) { /* synthetic (test) events have no active pointer */ }
      this.firstInput();
    });
    canvas.addEventListener('pointermove', (e) => {
      if (!this.drag || e.pointerId !== this.drag.id) return;
      hooks.orbitDrag(e.clientX - this.drag.x, e.clientY - this.drag.y);
      this.drag.x = e.clientX; this.drag.y = e.clientY;
    });
    const end = (e) => {
      if (this.drag && e.pointerId === this.drag.id) {
        this.drag = null;
        if (this.hooks.dragEnd) this.hooks.dragEnd();
      }
    };
    canvas.addEventListener('pointerup', end);
    canvas.addEventListener('pointercancel', end);
    canvas.addEventListener('wheel', (e) => {
      e.preventDefault();
      hooks.dolly(e.deltaY);
      this.firstInput();
    }, { passive: false });
    window.addEventListener('keydown', (e) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      this.firstInput();
      hooks.key(e.key.toLowerCase(), e);
    });
  }
  firstInput() {
    if (this.hintShown) { this.hintShown = false; this.hooks.dismissHint(); }
  }
}
