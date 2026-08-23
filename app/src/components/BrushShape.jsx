import { useCallback, useRef } from 'react';

/**
 * The brush, drawn.
 *
 * The outline is what meets the paper; the belly curve says how much of that
 * outline is in contact at a given pressure. Both are geometry only — no
 * pigment, no grain, no baked mark. Every edit hands a whole new definition
 * upward, so the engine rebakes and the very next stroke uses it.
 */

const VIEW = 260;
const PAD = 26;

/** Outline points live in brush units; the far edge sits at 1. */
const toScreen = (p) => ({
  x: PAD + ((p[0] + 1.15) / 2.3) * (VIEW - PAD * 2),
  y: PAD + ((p[1] + 1.15) / 2.3) * (VIEW - PAD * 2),
});
const toBrush = (x, y) => [
  ((x - PAD) / (VIEW - PAD * 2)) * 2.3 - 1.15,
  ((y - PAD) / (VIEW - PAD * 2)) * 2.3 - 1.15,
];

export function FootprintEditor({ outline, onChange, mirror = true }) {
  const svgRef = useRef(null);
  const dragging = useRef(-1);

  const pointAt = useCallback((event) => {
    const rect = svgRef.current.getBoundingClientRect();
    return toBrush(
      ((event.clientX - rect.left) / rect.width) * VIEW,
      ((event.clientY - rect.top) / rect.height) * VIEW,
    );
  }, []);

  const move = (event) => {
    const index = dragging.current;
    if (index < 0) return;
    const [bx, by] = pointAt(event);
    const next = outline.map((p) => [p[0], p[1]]);
    next[index] = [Math.max(-1.1, Math.min(1.1, bx)), Math.max(-1.1, Math.min(1.1, by))];
    if (mirror) {
      // A brush is symmetric about its spine. Editing one hair moves its twin,
      // which halves the work and stops a lopsided head sneaking in.
      const twin = (outline.length / 2 - index + outline.length) % outline.length;
      if (twin !== index) next[twin] = [-next[index][0], next[index][1]];
    }
    onChange(next);
  };

  const path = outline.map((p, i) => {
    const s = toScreen(p);
    return `${i === 0 ? 'M' : 'L'}${s.x.toFixed(2)},${s.y.toFixed(2)}`;
  }).join(' ') + ' Z';

  return (
    <svg
      ref={svgRef}
      viewBox={`0 0 ${VIEW} ${VIEW}`}
      className="w-full touch-none select-none rounded border border-rule2 bg-panel2"
      onPointerMove={move}
      onPointerUp={() => { dragging.current = -1; }}
      onPointerLeave={() => { dragging.current = -1; }}
      role="img"
      aria-label="The brush footprint, editable"
    >
      <line x1={VIEW / 2} y1={8} x2={VIEW / 2} y2={VIEW - 8}
        stroke="currentColor" strokeWidth=".7" strokeDasharray="3 5" className="text-ink3 opacity-50" />
      <path d={path} className="fill-pigment/15 stroke-pigment" strokeWidth="1.6" />
      {outline.map((p, i) => {
        const s = toScreen(p);
        return (
          <circle
            key={i}
            cx={s.x}
            cy={s.y}
            r="4.5"
            className="cursor-grab fill-panel stroke-pigment"
            strokeWidth="1.5"
            onPointerDown={(event) => {
              event.currentTarget.setPointerCapture?.(event.pointerId);
              dragging.current = i;
            }}
          />
        );
      })}
    </svg>
  );
}

/** How much of the head is down at a given pressure. */
export function BellyEditor({ belly, onChange }) {
  const svgRef = useRef(null);
  const dragging = useRef(-1);
  const W = 260, H = 120, P = 18;

  const toXY = (point) => ({
    x: P + point.p * (W - P * 2),
    y: H - P - point.contact * (H - P * 2),
  });

  const move = (event) => {
    const index = dragging.current;
    if (index < 0) return;
    const rect = svgRef.current.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width) * W;
    const y = ((event.clientY - rect.top) / rect.height) * H;
    const next = belly.map((b) => ({ ...b }));
    const contact = Math.max(.05, Math.min(1, (H - P - y) / (H - P * 2)));
    // the ends are pinned: no pressure is still the tip, full pressure is the whole head
    const p = index === 0 ? 0
      : index === belly.length - 1 ? 1
      : Math.max(belly[index - 1].p + .04, Math.min(belly[index + 1].p - .04, (x - P) / (W - P * 2)));
    next[index] = { p, contact };
    for (let i = 1; i < next.length; i++) next[i].contact = Math.max(next[i].contact, next[i - 1].contact);
    onChange(next);
  };

  const line = belly.map((b, i) => {
    const s = toXY(b);
    return `${i === 0 ? 'M' : 'L'}${s.x.toFixed(1)},${s.y.toFixed(1)}`;
  }).join(' ');

  return (
    <svg
      ref={svgRef}
      viewBox={`0 0 ${W} ${H}`}
      className="w-full touch-none select-none rounded border border-rule2 bg-panel2"
      onPointerMove={move}
      onPointerUp={() => { dragging.current = -1; }}
      onPointerLeave={() => { dragging.current = -1; }}
      role="img"
      aria-label="How far the head comes down as pressure rises, editable"
    >
      <line x1={P} y1={H - P} x2={W - P} y2={H - P} className="stroke-rule2" strokeWidth="1" />
      <line x1={P} y1={P} x2={P} y2={H - P} className="stroke-rule2" strokeWidth="1" />
      <path d={line} fill="none" className="stroke-sienna" strokeWidth="1.8" />
      {belly.map((b, i) => {
        const s = toXY(b);
        return (
          <circle
            key={i}
            cx={s.x}
            cy={s.y}
            r="4.5"
            className="cursor-grab fill-panel stroke-sienna"
            strokeWidth="1.5"
            onPointerDown={(event) => {
              event.currentTarget.setPointerCapture?.(event.pointerId);
              dragging.current = i;
            }}
          />
        );
      })}
      <text x={P} y={H - 5} className="fill-ink3" style={{ fontSize: 8, fontFamily: 'var(--font-mono)' }}>light</text>
      <text x={W - P - 26} y={H - 5} className="fill-ink3" style={{ fontSize: 8, fontFamily: 'var(--font-mono)' }}>heavy</text>
    </svg>
  );
}
