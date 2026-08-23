import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Dialog, DialogTrigger, Heading, Modal, ModalOverlay,
  Popover, Tab, TabList, TabPanel, Tabs, TextArea,
} from 'react-aria-components';
import { createEngine, listBrushes, listMaterials, listSubstrates } from './engine/index.js';
import { BTN, BTN_PRIMARY, Button, Notes, Select, Slider, ToggleRow } from './components/Controls.jsx';
import { BOARD_ROWS, BRUSH_ROWS, CANNOT_SHOW, ENGINE_ROWS, MARKS, MARK_ORDER, seedBoard } from './data/board.js';
import { BellyEditor, FootprintEditor } from './components/BrushShape.jsx';

// Everything physical - brush size, thread spacing - is now stated in
// millimetres, so a finer grid shows more of the same world rather than
// shrinking it. That makes resolution a free choice.
const DETAILS = [
  { id: 'standard', name: 'Standard · 380 × 280', width: 380, height: 280 },
  { id: 'fine', name: 'Fine · 475 × 350', width: 475, height: 350 },
  { id: 'finest', name: 'Finest · 570 × 420', width: 570, height: 420 },
];
const CANVAS = { width: 760, height: 560 };
const ACTIONS = [{ id: 'draw', name: 'Draw' }, { id: 'smudge', name: 'Smudge' }];
const RATINGS = [
  { id: 'convincing', name: 'Convincing' },
  { id: 'recognizable', name: 'Recognizable' },
  { id: 'good', name: 'Good' },
  { id: 'wrong', name: 'Wrong' },
];
const DECISIONS = [
  { id: 'accept', name: 'Accept for this scope' },
  { id: 'recalibrate', name: 'Recalibrate' },
  { id: 'revise', name: 'Revise the model' },
];

const SECTION = 'border-b border-rule px-4 py-3.5 last:border-b-0';
const HEADING = 'mb-3 font-mono text-[10px] font-medium uppercase tracking-[0.13em] text-ink3';
const HINT = 'text-[12px] leading-snug text-ink3';
const CHIP = 'whitespace-nowrap rounded-full border px-2.5 py-0.5 font-mono text-[10.5px] uppercase tracking-[0.1em]';

const REGIME_CHIP = {
  flowing: 'border-pigment text-pigment',
  granular: 'border-ink3 text-ink2',
  body: 'border-sienna text-sienna',
};

const materials = listMaterials();
const substrates = listSubstrates();
const brushes = listBrushes();

/** One behaviour on the board.
 *
 * The four marks are dots, not labelled buttons. A labelled set on every row
 * turned three columns into ninety-odd words of chrome and buried the thing
 * that matters, which is the colour of the dot on the left.
 */
function BoardRow({ row, current, onMark, blocked, reason, onReason }) {
  const dot = (key) => (
    <span className="mk !h-2.5 !w-2.5" data-mark={key} />
  );
  const buttonClass = (key) =>
    `grid h-[18px] w-[18px] cursor-pointer place-items-center rounded-sm border ${
      current === key ? 'border-ink2 bg-panel2' : 'border-transparent hover:border-rule2'
    }`;

  return (
    <div
      className={`grid grid-cols-[13px_1fr_auto] items-center gap-2.5 border-b border-rule/60 py-1.5 last:border-b-0 ${
        blocked ? 'opacity-45' : ''
      }`}
      title={blocked || undefined}
    >
      <span className="mk" data-mark={current} />
      <span className="min-w-0 text-[12px] leading-tight">
        <span className="font-medium">{row.name}</span>
        <span className="ml-1.5 text-[11px] text-ink3">{blocked || row.hint}</span>
        {reason ? (
          <span className="ml-1.5 font-mono text-[10px] text-danger">· reason waiting to be saved</span>
        ) : null}
      </span>
      <span className="flex items-center gap-1">
        {MARK_ORDER.map((key) =>
          // The one mark that asks a question back. Setting it opens the box for
          // why; the answer rides along with the next saved session. A blocked
          // row gets the plain dot instead - there is nothing to explain about a
          // judgement the tool in hand cannot support, and a disabled button
          // never registers with the popover that would wrap it.
          key === 'recalibrate' && !blocked ? (
            <DialogTrigger key={key}>
              <Button
                isDisabled={!!blocked}
                title={blocked || MARKS[key].label}
                aria-label={`${row.name}: ${MARKS[key].label}`}
                aria-pressed={current === key}
                onPress={() => !blocked && onMark(row.id, key)}
                className={buttonClass(key)}
              >
                {dot(key)}
              </Button>
              <Popover placement="bottom end" className="z-50 w-72 rounded border border-rule2 bg-panel p-3 shadow-xl">
                <Dialog className="flex flex-col gap-2 outline-none">
                  <p className="text-[12px] font-medium">{row.name}</p>
                  <p className="text-[11px] leading-snug text-ink3">
                    What needs recalibrating? This is saved with your next mark, not separately.
                  </p>
                  <TextArea
                    rows={4}
                    autoFocus
                    aria-label={`Why ${row.name} needs recalibrating`}
                    value={reason || ''}
                    onChange={(event) => onReason(row.id, event.target.value)}
                    placeholder="e.g. the lag is there but far too subtle to see"
                    className="w-full resize-y rounded border border-rule2 bg-panel2 px-2.5 py-1.5
                               text-[12.5px] leading-relaxed text-ink hover:border-ink3 focus:outline-none"
                  />
                </Dialog>
              </Popover>
            </DialogTrigger>
          ) : (
            <button
              type="button"
              key={key}
              disabled={!!blocked}
              onClick={() => !blocked && onMark(row.id, key)}
              title={blocked || MARKS[key].label}
              aria-label={`${row.name}: ${MARKS[key].label}`}
              aria-pressed={current === key}
              className={buttonClass(key)}
            >
              {dot(key)}
            </button>
          ),
        )}
        <span className="ml-1 w-9 shrink-0 text-right font-mono text-[9px] text-ink3">{row.id}</span>
      </span>
    </div>
  );
}

/** A column of the board. Side by side in the drawer, so no collapsing here. */
function BoardGroup({ title, subject, rows, marks, onMark, empty, blockedFor, reasons, onReason }) {
  const tally = rows.reduce((count, row) => {
    const mark = marks[row.id]?.mark || row.seed;
    count[mark] = (count[mark] || 0) + 1;
    return count;
  }, {});
  return (
    <section className="min-w-0">
      <header className="mb-1 flex items-baseline gap-2 border-b border-rule pb-1.5">
        <span className="font-mono text-[9px] uppercase tracking-[0.12em] text-ink3">{title}</span>
        <span className="truncate text-[12px] font-semibold">{subject}</span>
        <span className="ml-auto flex shrink-0 items-center gap-1.5">
          {MARK_ORDER.slice().reverse().map((key) =>
            tally[key] ? (
              <span key={key} className="flex items-center gap-1 font-mono text-[10px] text-ink3">
                <span className="mk !h-2.5 !w-2.5" data-mark={key} />
                {tally[key]}
              </span>
            ) : null,
          )}
        </span>
      </header>
      {empty ? (
        <p className="py-2 text-[11.5px] leading-snug text-ink3">{empty}</p>
      ) : (
        <div className="flex flex-col">
          {rows.map((row) => (
            <BoardRow
              key={row.id}
              row={row}
              current={marks[row.id]?.mark || row.seed}
              onMark={onMark}
              blocked={blockedFor ? blockedFor(row) : null}
              reason={reasons?.[row.id]}
              onReason={onReason}
            />
          ))}
        </div>
      )}
    </section>
  );
}

export default function App() {
  const canvasRef = useRef(null);
  const engineRef = useRef(null);
  const strokeRef = useRef({ down: false, last: null, lastTime: 0, speed: 0.8 });

  const [ready, setReady] = useState(false);
  const [material, setMaterial] = useState('oil');
  const [substrate, setSubstrate] = useState('coldPress');
  const [action, setAction] = useState('draw');
  const [brush, setBrush] = useState('disc');
  const [brushAngle, setBrushAngle] = useState(0);
  const [sheet, setSheet] = useState(0);
  const [charge, setCharge] = useState(null);
  const [detail, setDetail] = useState('standard');
  const [boardOpen, setBoardOpen] = useState(false);
  const [drawn, setDrawn] = useState(null);
  const [drawnName, setDrawnName] = useState('My filbert');
  const [load, setLoad] = useState(0.7);
  const [water, setWater] = useState(0.3);
  const [dampness, setDampness] = useState(0);
  const [fallbackPressure, setFallbackPressure] = useState(0.55);
  const [fallbackSpeed, setFallbackSpeed] = useState(0.8);
  const [viewGain, setViewGain] = useState(2.6);

  // Going back to the palette without saying so. The engine ships with this
  // off, because a measurement of running out has to be allowed to run out;
  // the studio turns it on because painting with it off is tedious.
  const [autoReload, setAutoReload] = useState(true);
  const [reloadFill, setReloadFill] = useState(1);

  const [regime, setRegime] = useState('');
  const [profileId, setProfileId] = useState('');
  const [readout, setReadout] = useState([]);
  const [usingStylus, setUsingStylus] = useState(false);

  const [board, setBoard] = useState(null);
  const [sessions, setSessions] = useState([]);
  const [online, setOnline] = useState(true);

  // Reasons typed against a red mark, keyed by scope and row. They wait here
  // until the next save rather than going up on their own, so a judgement and
  // the reasoning behind it land in the record together.
  const [reasons, setReasons] = useState({});
  const [saved, setSaved] = useState(null);

  const [rating, setRating] = useState('recognizable');
  const [decision, setDecision] = useState('recalibrate');
  const [notes, setNotes] = useState('');

  /* ---------------------------------------------------------- engine */

  const grid = DETAILS.find((d) => d.id === detail) || DETAILS[0];
  const view = { width: grid.width * 4, height: grid.height * 4 };
  const viewRef = useRef(view);
  viewRef.current = view;

  useEffect(() => {
    let cancelled = false;
    setReady(false);
    createEngine({ width: grid.width, height: grid.height, material, substrate }).then((engine) => {
      if (cancelled) return;
      engineRef.current = engine;
      // Dev-only handle so the engine can be inspected from the console while
      // diagnosing a mark. Never referenced by application code.
      if (import.meta.env.DEV) window.__studio = { engine, readout: () => engine.readout() };
      engine.setViewGain(viewGain);
      engine.setSmoothing(false);
      if (drawn) engine.setBrushDefinition({ ...drawn, name: drawnName });
      else engine.setBrush(brush);
      engine.newSheet(sheet);
      engine.clear(dampness);
      setRegime(engine.regime());
      setProfileId(engine.profile().id);
      setReadout(engine.readout());
      setReady(true);
    });
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [detail]);

  useEffect(() => {
    const engine = engineRef.current;
    if (!engine || !ready) return;
    engine.setMaterial(material);
    engine.clear(dampness);
    setRegime(engine.regime());
    setProfileId(engine.profile().id);
    setReadout(engine.readout());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [material, ready]);

  useEffect(() => {
    const engine = engineRef.current;
    if (!engine || !ready) return;
    if (drawn) engine.setBrushDefinition({ ...drawn, name: drawnName });
    else engine.setBrush(brush);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [brush, drawn, drawnName, ready]);

  useEffect(() => {
    const engine = engineRef.current;
    if (!engine || !ready) return;
    engine.setSubstrate(substrate);
    engine.newSheet(sheet);
    engine.clear(dampness);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [substrate, ready]);

  useEffect(() => {
    if (engineRef.current && ready) engineRef.current.setViewGain(viewGain);
  }, [viewGain, ready]);

  useEffect(() => {
    if (engineRef.current && ready) engineRef.current.setAutoReload(autoReload, reloadFill);
  }, [autoReload, reloadFill, brush, drawn, ready]);

  /* ------------------------------------------------------- frame loop */

  useEffect(() => {
    if (!ready) return undefined;
    let raf = 0;
    let last = performance.now();
    let sinceReadout = 0;

    const frame = (now) => {
      const engine = engineRef.current;
      const canvas = canvasRef.current;
      if (engine && canvas) {
        const dt = Math.min(0.05, (now - last) / 1000);
        last = now;
        engine.step(dt);
        engine.render(canvas.getContext('2d'), canvas);
        sinceReadout += dt;
        if (sinceReadout > 0.16) {
          sinceReadout = 0;
          setReadout(engine.readout());
          setCharge(engine.hasReservoir() ? engine.brushCharge() : null);
        }
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [ready]);

  /* ----------------------------------------------------------- server */

  const loadBoard = useCallback(async () => {
    try {
      const response = await fetch('/api/board');
      if (!response.ok) throw new Error('board unavailable');
      const stored = await response.json();
      setBoard(stored || seedBoard());
      setOnline(true);
    } catch {
      setBoard(seedBoard());
      setOnline(false);
    }
  }, []);

  const loadSessions = useCallback(async () => {
    try {
      const response = await fetch('/api/sessions');
      if (!response.ok) throw new Error('sessions unavailable');
      setSessions(await response.json());
    } catch {
      setSessions([]);
    }
  }, []);

  useEffect(() => { loadBoard(); loadSessions(); }, [loadBoard, loadSessions]);

  const persistBoard = useCallback(async (next) => {
    setBoard(next);
    try {
      const response = await fetch('/api/board', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(next),
      });
      if (!response.ok) throw new Error('write failed');
      setOnline(true);
    } catch {
      setOnline(false);
    }
  }, []);

  /**
   * Changing medium brings its usual paper and brush with it.
   *
   * The pairing lives on the material, not here — the studio asks the engine
   * what a material is usually found on rather than keeping its own list of
   * material names. A brush you drew yourself is left alone; picking a medium
   * should not throw your own work out of your hand.
   */
  const pickMaterial = (id) => {
    setMaterial(id);
    const usual = engineRef.current?.studioDefaults(id);
    if (!usual) return;
    if (usual.substrate) setSubstrate(usual.substrate);
    if (usual.brush && !drawn) setBrush(usual.brush);
  };

  const noteReason = (scope) => (rowId, text) =>
    setReasons((current) => {
      const next = { ...current, [scope]: { ...(current[scope] || {}), [rowId]: text } };
      if (!text) delete next[scope][rowId];
      return next;
    });

  const reasonCount = Object.values(reasons).reduce((n, group) => n + Object.keys(group).length, 0);

  /** The engine's own rows: one shared set, not per brush. */
  const setEngineMark = (rowId, mark) => {
    if (!board) return;
    const now = new Date().toISOString();
    persistBoard({
      ...board,
      updatedAt: now,
      engine: { ...(board.engine || {}), [rowId]: { ...((board.engine || {})[rowId] || {}), mark, decidedAt: now } },
    });
  };

  const setBrushMark = (rowId, mark) => {
    if (!board) return;
    const now = new Date().toISOString();
    persistBoard({
      ...board,
      updatedAt: now,
      brushes: {
        ...(board.brushes || {}),
        [brushKey]: {
          ...((board.brushes || {})[brushKey] || {}),
          // brushKey, not brush: a drawn brush keeps its own row rather than
          // inheriting the note and date of whichever registry head it started from.
          [rowId]: { ...(((board.brushes || {})[brushKey] || {})[rowId] || {}), mark, decidedAt: now },
        },
      },
    });
  };

  const setMark = (rowId, mark) => {
    if (!board) return;
    const now = new Date().toISOString();
    persistBoard({
      ...board,
      updatedAt: now,
      rows: {
        ...board.rows,
        [material]: {
          ...(board.rows[material] || {}),
          [rowId]: { ...(board.rows[material]?.[rowId] || {}), mark, decidedAt: now },
        },
      },
    });
  };

  /* ------------------------------------------------------------ paint */

  const toCanvas = (event) => {
    const canvas = canvasRef.current;
    const rect = canvas.getBoundingClientRect();
    return {
      x: ((event.clientX - rect.left) / rect.width) * viewRef.current.width,
      y: ((event.clientY - rect.top) / rect.height) * viewRef.current.height,
    };
  };

  const onPointerDown = (event) => {
    try { event.currentTarget.setPointerCapture(event.pointerId); } catch { /* capture is a nicety, not a requirement */ }
    setUsingStylus(event.pointerType === 'pen');
    const at = toCanvas(event);
    strokeRef.current = {
      down: true,
      last: at,
      lastTime: performance.now(),
      speed: fallbackSpeed,
    };
    // Putting the brush down is itself a mark. Without this a tap that never
    // moves went nowhere, because only pointer movement ever reached the engine.
    engineRef.current?.stroke(action, at, at, viewRef.current, {
      pressure: event.pointerType === 'pen' && event.pressure > 0 ? event.pressure : fallbackPressure,
      speed: fallbackSpeed,
      load,
      water,
      angle: (brushAngle * Math.PI) / 180,
    });
  };

  const onPointerMove = (event) => {
    const state = strokeRef.current;
    const engine = engineRef.current;
    if (!state.down || !engine) return;

    const point = toCanvas(event);
    const now = performance.now();
    const dt = Math.max(1, now - state.lastTime) / 1000;
    const distance = Math.hypot(point.x - state.last.x, point.y - state.last.y);
    const measured = Math.max(0.1, Math.min(2, distance / dt / 320));
    state.speed = state.speed * 0.7 + measured * 0.3;

    const stylus = event.pointerType === 'pen' && event.pressure > 0;
    engine.stroke(action, state.last, point, viewRef.current, {
      pressure: stylus ? event.pressure : fallbackPressure,
      speed: state.speed,
      load,
      water,
      angle: (brushAngle * Math.PI) / 180,
    });

    state.last = point;
    state.lastTime = now;
  };

  const endStroke = (event) => {
    try {
      if (event?.pointerId != null && event.currentTarget.hasPointerCapture?.(event.pointerId)) {
        event.currentTarget.releasePointerCapture(event.pointerId);
      }
    } catch { /* nothing to release */ }
    strokeRef.current.down = false;
    engineRef.current?.liftBrush();
  };

  /* ----------------------------------------------------------- record */

  const saveSession = async () => {
    const engine = engineRef.current;
    const canvas = canvasRef.current;
    if (!engine || !canvas) return;

    const snapshot = engine.snapshot();
    const session = {
      recordedAt: new Date().toISOString(),
      material: {
        id: engine.profile().id,
        name: materials.find((m) => m.id === material)?.name,
        key: material,
      },
      substrate: { ...engine.substrateInfo(), sheet: engine.sheetId() },
      grid: { width: grid.width, height: grid.height, sheetWidthMm: 80 },
      brush: {
        ...engine.brushInfo(),
        heldAt: brush === 'disc' && !drawn ? null : `${brushAngle}°`,
        drawn: drawn
          ? {
            name: drawnName,
            outline: drawn.outline,
            belly: drawn.belly,
            softness: drawn.softness,
            stiffness: drawn.stiffness,
            widthMm: drawn.widthMm,
            capacity: drawn.capacity,
            release: drawn.release,
          }
          : null,
      },
      regime: snapshot.regime,
      settings: {
        action,
        load,
        water,
        paperDampness: dampness,
        pressure: usingStylus ? 'stylus' : fallbackPressure,
        speed: fallbackSpeed,
        viewGain,
        note: 'viewGain is a display control only; it does not change physical state.',
      },
      measurements: snapshot.measurements,
      review: { rating, decision, notes: notes.trim() },
      board: {
        paint: board?.rows?.[material] || null,
        engine: board?.engine || null,
        tool: board?.brushes?.[brushKey] || null,
      },
      recalibrate: reasonCount ? reasons : null,
      provenance: engine.profile().provenance,
      image: canvas.toDataURL('image/png'),
    };

    try {
      const response = await fetch('/api/sessions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(session),
      });
      const body = await response.json();
      if (!response.ok) throw new Error(body.error || 'save failed');

      // The reasons written against red marks belong on the rows themselves,
      // not only inside the session file, so the board carries its own why.
      if (reasonCount && board) {
        const stamp = (group, existing) =>
          Object.entries(group || {}).reduce((rows, [rowId, why]) => {
            rows[rowId] = { ...(existing?.[rowId] || {}), note: why, decidedAt: session.recordedAt };
            return rows;
          }, { ...(existing || {}) });
        persistBoard({
          ...board,
          updatedAt: session.recordedAt,
          rows: { ...board.rows, [material]: stamp(reasons.paint, board.rows?.[material]) },
          engine: stamp(reasons.engine, board.engine),
          brushes: { ...(board.brushes || {}), [brushKey]: stamp(reasons.tool, board.brushes?.[brushKey]) },
        });
      }

      setOnline(true);
      loadSessions();
      setSaved({ ok: true, file: body.file, reasons: reasonCount });
      // A clean form for the next mark, as asked.
      setReasons({});
      setNotes('');
      setRating('recognizable');
      setDecision('recalibrate');
    } catch (error) {
      setOnline(false);
      setSaved({ ok: false, message: error.message });
    }
  };

  const rows = BOARD_ROWS[material] || [];
  const marks = board?.rows?.[material] || {};
  const brushKey = drawn ? 'custom' : brush;
  const brushRows = BRUSH_ROWS[brushKey] || [];
  const brushMarks = board?.brushes?.[brushKey] || {};
  const engineMarks = board?.engine || {};
  const brushCan = ready ? engineRef.current?.brushCan() : null;

  return (
    <div
      className="grid h-full max-lg:h-auto max-lg:min-h-full
                 grid-cols-[292px_minmax(0,1fr)_352px] grid-rows-[46px_minmax(0,1fr)_auto]
                 [grid-template-areas:'bar_bar_bar''left_center_right''board_board_board']
                 max-lg:grid-cols-1 max-lg:grid-rows-[46px_auto_auto_auto_auto]
                 max-lg:[grid-template-areas:'bar''center''left''right''board']"
    >
      <header className="[grid-area:bar] flex items-center gap-4 border-b border-rule bg-panel px-4">
        <h1 className="m-0 whitespace-nowrap text-[13px] font-semibold tracking-wide">
          Sarasara · diagnostic studio
        </h1>
        <span className={`${CHIP} ${REGIME_CHIP[regime] || 'border-rule2 text-ink2'}`}>
          {regime || '…'}
        </span>
        <span className="truncate font-mono text-[10.5px] text-ink3">{profileId}</span>
        <span className={`${CHIP} ${drawn ? 'border-sienna text-sienna' : 'border-rule2 text-ink2'}`}>
          {drawn ? `${drawnName} · drawing` : brushes.find((b) => b.id === brush)?.name || brush}
        </span>
        <div className="flex-1" />
        {!online && (
          <span className={`${CHIP} border-sienna text-sienna`}>offline · not recording</span>
        )}
        <span className="whitespace-nowrap font-mono text-[10.5px] text-ink3">
          {usingStylus ? 'stylus pressure' : 'slider pressure'}
        </span>
      </header>

      {/* ------------------------------------------------ left: controls */}
      <div className="[grid-area:left] min-h-0 overflow-y-auto border-r border-rule bg-panel max-lg:overflow-visible max-lg:border-r-0 max-lg:border-t">
        <section className={SECTION}>
          <h2 className={HEADING}>Material</h2>
          <div className="flex flex-col gap-3">
            <Select label="Medium" items={materials} value={material} onChange={pickMaterial} />
            <Select label="Paper" items={substrates} value={substrate} onChange={setSubstrate} />
            <Select label="Detail" items={DETAILS} value={detail} onChange={setDetail} />
            <ToggleRow label="Contact" options={ACTIONS} value={action} onChange={setAction} />
            <Select label="Brush" items={brushes} value={brush} onChange={setBrush} />
            {brush !== 'disc' && (
              <Slider
                label="How the brush is held"
                value={brushAngle}
                onChange={setBrushAngle}
                min={0}
                max={180}
                step={1}
                format={(v) => `${v.toFixed(0)}°`}
              />
            )}
          </div>
        </section>

        <section className={SECTION}>
          <h2 className={HEADING}>The tool</h2>
          <div className="flex flex-col gap-3">
            <Slider label="Pigment load" value={load} onChange={setLoad} />
            {regime === 'flowing' && (
              <>
                <Slider label="Water on the brush" value={water} onChange={setWater} />
                <Slider label="Paper dampness" value={dampness} onChange={setDampness} />
              </>
            )}
            {regime !== 'flowing' && (
              <p className={HINT}>
                This material carries no water, so the wet controls are hidden rather than
                sitting there doing nothing.
              </p>
            )}
          </div>
        </section>

        <section className={SECTION}>
          <h2 className={HEADING}>Gesture · used when no stylus</h2>
          <div className="flex flex-col gap-3">
            <Slider label="Pressure" value={fallbackPressure} onChange={setFallbackPressure} />
            <Slider label="Speed" value={fallbackSpeed} onChange={setFallbackSpeed} min={0.1} max={2} />
            <p className={HINT}>
              A pen overrides these with real pressure. They are test inputs, not material controls.
            </p>
          </div>
        </section>

        <section className={SECTION}>
          <h2 className={HEADING}>Sheet</h2>
          <div className="flex gap-2">
            <Button
              className={`${BTN} flex-1`}
              onPress={() => {
                const next = Math.floor(Math.random() * 9999) + 1;
                engineRef.current?.newSheet(next);
                engineRef.current?.clear(dampness);
                setSheet(next);
              }}
            >
              New sheet
            </Button>
            <Button className={`${BTN} flex-1`} onPress={() => engineRef.current?.clear(dampness)}>
              Wipe
            </Button>
            <Button className={`${BTN} flex-1`} onPress={() => engineRef.current?.forceDry()}>
              Force dry
            </Button>
          </div>
          <div className="mt-2 flex gap-2">
            <Button
              className={BTN + ' flex-1'}
              isDisabled={!ready}
              onPress={() => engineRef.current?.dipBrush(load)}
            >
              Dip the brush
            </Button>
          </div>
          <div className="mt-3">
            <ToggleRow
              label="Reload when you lift"
              options={[{ id: 'on', name: 'On' }, { id: 'off', name: 'Off' }]}
              value={autoReload ? 'on' : 'off'}
              onChange={(value) => setAutoReload(value === 'on')}
            />
          </div>
          {autoReload && (
            <div className="mt-2">
              <Slider
                label="How much it picks up"
                value={reloadFill}
                onChange={setReloadFill}
                min={0.1}
                format={(v) => Math.round(v * 100) + '%'}
              />
            </div>
          )}
          <p className={HINT + ' mt-2'}>
            A drawn brush holds a finite amount and runs dry. With reloading on it
            goes back to the palette every time you lift; turn it off to feel a
            brush run out. The disc is bottomless, as it always was.
          </p>
        </section>
      </div>

      <ModalOverlay
        isOpen={!!saved}
        onOpenChange={(open) => !open && setSaved(null)}
        isDismissable
        className="fixed inset-0 z-50 grid place-items-center bg-black/35 p-6 backdrop-blur-[1px]"
      >
        <Modal className="w-full max-w-sm rounded border border-rule2 bg-panel p-5 shadow-2xl">
          <Dialog className="flex flex-col gap-3 outline-none">
            {({ close }) => (
              <>
                <Heading
                  slot="title"
                  className={`text-[15px] font-semibold ${saved?.ok ? 'text-ink' : 'text-danger'}`}
                >
                  {saved?.ok ? `${saved.what || 'Mark'} saved` : 'Could not save'}
                </Heading>
                <p className="text-[12.5px] leading-relaxed text-ink2">
                  {saved?.ok
                    ? `Written to ${saved.file}.${saved.reasons ? ` ${saved.reasons} recalibration ${saved.reasons === 1 ? 'reason is' : 'reasons are'} on the board.` : ''}`
                    : `${saved?.message}. Is "npm run lab" still running?`}
                </p>
                <Button className={`${BTN_PRIMARY} self-end`} onPress={close} autoFocus>
                  Right
                </Button>
              </>
            )}
          </Dialog>
        </Modal>
      </ModalOverlay>

      {/* -------------------------------------------------- centre: canvas */}
      <div className="[grid-area:center] flex min-h-0 min-w-0 items-center justify-center bg-ground p-5">
        <div className="flex max-h-full max-w-full flex-col gap-2.5">
          <div className="overflow-hidden rounded-sm border border-rule2 bg-white leading-none shadow-xl">
            <canvas
              ref={canvasRef}
              width={CANVAS.width}
              height={CANVAS.height}
              className="block h-auto max-w-full cursor-crosshair touch-none"
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={endStroke}
              onPointerCancel={endStroke}
              onPointerLeave={endStroke}
            />
          </div>
          <div className="flex items-center gap-3 font-mono text-[10.5px] tracking-wide text-ink3">
            <span className="text-terre">● live</span>
            <span>{grid.width}×{grid.height} cells · 80 mm sheet</span>
            <span>{action === 'draw' ? 'drawing material' : 'smudging what is there'}</span>
            <span>{sheet === 0 ? 'reference sheet' : `sheet #${sheet}`}</span>
            {charge !== null && <span>brush {Math.round(charge * 100)}% loaded</span>}
          </div>
        </div>
      </div>

      {/* ------------------------------------------------------ the board */}
      <section className="[grid-area:board] border-t border-rule bg-panel">
        <button
          type="button"
          onClick={() => setBoardOpen((open) => !open)}
          aria-expanded={boardOpen}
          className="flex w-full cursor-pointer items-center gap-3 px-4 py-2 text-left"
        >
          <span className="font-mono text-[9px] text-ink3">{boardOpen ? '▾' : '▴'}</span>
          <span className="font-mono text-[9px] uppercase tracking-[0.13em] text-ink3">The board</span>
          <span className="flex items-center gap-3">
            {[[rows, marks], [ENGINE_ROWS, engineMarks], [brushRows, brushMarks]].map(([groupRows, groupMarks], i) => {
              const tally = groupRows.reduce((count, row) => {
                const mark = groupMarks[row.id]?.mark || row.seed;
                count[mark] = (count[mark] || 0) + 1;
                return count;
              }, {});
              return (
                <span key={i} className="flex items-center gap-1.5">
                  {MARK_ORDER.slice().reverse().map((mk) =>
                    tally[mk] ? (
                      <span key={mk} className="flex items-center gap-1 font-mono text-[10px] text-ink3">
                        <span className="mk !h-2.5 !w-2.5" data-mark={mk} />
                        {tally[mk]}
                      </span>
                    ) : null,
                  )}
                </span>
              );
            })}
          </span>
          <span className="ml-auto font-mono text-[9.5px] text-ink3">
            {boardOpen ? 'hide' : 'show'}
          </span>
        </button>

        {boardOpen && (
          <div className="max-h-[42vh] overflow-y-auto border-t border-rule px-4 pb-4 pt-2">
            <div className="mb-3 flex flex-wrap gap-x-3 gap-y-1.5">
              {MARK_ORDER.slice().reverse().map((key) => (
                <span key={key} className="inline-flex items-center gap-1.5 text-[11.5px] text-ink2">
                  <span className="mk" data-mark={key} /> {MARKS[key].short}
                </span>
              ))}
            </div>
            <div className="grid gap-x-7 gap-y-5 lg:grid-cols-4 lg:[&>section+section]:border-l lg:[&>section+section]:border-rule lg:[&>section+section]:pl-7">
              <BoardGroup
                title="The paint"
                subject={materials.find((m) => m.id === material)?.name}
                rows={rows}
                marks={marks}
                onMark={setMark}
                reasons={reasons.paint}
                onReason={noteReason('paint')}
              />

              <BoardGroup
                title="The brush engine"
                subject={`judged with ${drawn ? drawnName : brushes.find((b) => b.id === brush)?.name}`}
                rows={ENGINE_ROWS}
                marks={engineMarks}
                onMark={setEngineMark}
                reasons={reasons.engine}
                onReason={noteReason('engine')}
                blockedFor={(row) =>
                  row.needs && brushCan && !brushCan[row.needs]
                    ? `this brush is ${CANNOT_SHOW[row.needs]} — pick a drawn brush`
                    : null
                }
              />

              <BoardGroup
                title="This brush"
                subject={brushes.find((b) => b.id === brush)?.name}
                rows={brushRows}
                marks={brushMarks}
                onMark={setBrushMark}
                reasons={reasons.tool}
                onReason={noteReason('tool')}
              />

              <BoardGroup
                title="The surface"
                subject={substrates.find((p) => p.id === substrate)?.name}
                rows={[]}
                marks={{}}
                onMark={() => {}}
                empty="No rows yet. Paper and canvas have never been scored on their own — they have only ever been judged through whatever was painted on them."
              />

            </div>
            <p className={`${HINT} mt-3`}>
              Green is a claim about what you have seen. Nothing a test does can set it.
            </p>
          </div>
        )}
      </section>

      {/* ------------------------------------------------- right: numbers */}
      <div className="[grid-area:right] min-h-0 overflow-y-auto border-l border-rule bg-panel max-lg:overflow-visible max-lg:border-l-0 max-lg:border-t">
        <section className={SECTION}>
          <h2 className={HEADING}>Measurements</h2>
          <div className="flex flex-col">
            {readout.map((item) => {
              const broken = item.key === 'pigment_conservation_error' && item.value > 1;
              const ledger = item.key === 'pigment_conservation_error';
              return (
                <div
                  key={item.key}
                  className="grid grid-cols-[1fr_auto] items-baseline gap-2.5 border-b border-dotted border-rule py-1.5 last:border-b-0"
                >
                  <span className="text-[12.5px] text-ink2">{item.label}</span>
                  <span
                    className={`font-mono text-[12.5px] tabular-nums ${
                      broken ? 'font-semibold text-danger' : ledger ? 'text-terre' : 'text-ink'
                    }`}
                  >
                    {formatValue(item)}
                    {item.unit ? <span className="ml-0.5 text-[10.5px] text-ink3">{item.unit}</span> : null}
                  </span>
                </div>
              );
            })}
          </div>
          <p className={`${HINT} mt-2.5`}>
            View strength changes only what you see, never what is there.
          </p>
          <div className="mt-2.5">
            <Slider
              label="View strength"
              value={viewGain}
              onChange={setViewGain}
              min={1}
              max={12}
              step={0.2}
              format={(v) => `${v.toFixed(1)}×`}
            />
          </div>
        </section>

        <Tabs className="flex min-h-0 flex-col">
          <TabList
            className="sticky top-0 z-10 flex gap-0.5 border-b border-rule bg-panel px-2.5"
            aria-label="Recording and approvals"
          >
            {[['record', 'Record'], ['shape', 'Brush'], ['history', 'Sessions']].map(([id, label]) => (
              <Tab
                key={id}
                id={id}
                className="cursor-pointer border-b-2 border-transparent px-2.5 py-2.5 font-mono text-[10px]
                           uppercase tracking-[0.11em] text-ink3 outline-none
                           selected:border-b-pigment selected:text-ink"
              >
                {label}
              </Tab>
            ))}
          </TabList>

          <TabPanel className="px-4 py-3.5 outline-none" id="record">
            <div className="flex flex-col gap-3">
              {!online && (
                <p className="rounded border border-sienna bg-siennasoft px-2.5 py-2 text-[11.5px] text-sienna">
                  Not connected to the repository — reviews will not be written.
                  Start the lab with <code className="font-mono">npm run lab</code>.
                </p>
              )}
              <Select label="Rating" items={RATINGS} value={rating} onChange={setRating} />
              <Select label="Decision" items={DECISIONS} value={decision} onChange={setDecision} />
              <Notes
                id="notes"
                rows={4}
                label="What did you see?"
                value={notes}
                onChange={setNotes}
                placeholder="Your words. This is the part no measurement can replace."
              />
              <Button className={BTN_PRIMARY} onPress={saveSession} isDisabled={!ready}>
                Save this mark
              </Button>
              {reasonCount > 0 && (
                <p className="text-[11.5px] text-danger">
                  {reasonCount === 1 ? '1 recalibration reason' : `${reasonCount} recalibration reasons`} will be
                  saved with this mark.
                </p>
              )}
            </div>
          </TabPanel>

          <TabPanel className="px-4 py-3.5 outline-none" id="shape">
            {!drawn ? (
              <div className="flex flex-col gap-3">
                <p className={HINT}>
                  Pick up a drawn brush and start shaping it. The outline is what meets the
                  paper; the curve below says how much of it comes down as you press.
                </p>
                <Button
                  className={BTN}
                  onPress={() => {
                    const base = engineRef.current?.brushDefinition(brush === 'disc' ? 'filbert' : brush);
                    if (base) { setDrawn(base); setDrawnName(`My ${base.name.toLowerCase()}`); }
                  }}
                >
                  Start from {brush === 'disc' ? 'a filbert' : brushes.find((b) => b.id === brush)?.name}
                </Button>
                <p className={HINT}>
                  The disc has no shape to edit — it is the frozen reference footprint.
                </p>
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                <div className="flex items-baseline justify-between gap-2">
                  <span className="text-[12px] font-semibold">{drawnName}</span>
                  <span className="font-mono text-[9.5px] text-ink3">{drawn.widthMm} mm · drawing</span>
                </div>

                <FootprintEditor
                  outline={drawn.outline}
                  onChange={(outline) => setDrawn((d) => ({ ...d, outline }))}
                />
                <p className={HINT}>Drag a hair. Its twin on the other side follows, so the head stays true.</p>

                <BellyEditor
                  belly={drawn.belly}
                  onChange={(belly) => setDrawn((d) => ({ ...d, belly }))}
                />
                <p className={HINT}>Left is the lightest touch, right is the whole head down.</p>

                <Slider
                  label="Head width"
                  value={drawn.widthMm}
                  onChange={(widthMm) => setDrawn((d) => ({ ...d, widthMm }))}
                  min={2}
                  max={40}
                  step={.5}
                  format={(v) => `${v.toFixed(1)} mm`}
                />
                <Slider
                  label="Stiffness of the hair"
                  value={drawn.stiffness}
                  onChange={(stiffness) => setDrawn((d) => ({ ...d, stiffness }))}
                  min={.05}
                  max={.98}
                  step={.01}
                />
                <p className={HINT}>
                  Soft hair trails behind your hand and rounds a corner off. Stiff hair
                  goes where you put it.
                </p>
                <Slider
                  label="Softness of the edge"
                  value={drawn.softness}
                  onChange={(softness) => setDrawn((d) => ({ ...d, softness }))}
                  min={.05}
                  max={1}
                  step={.01}
                />

                {/* The reservoir, where the artist asked for it to live. */}
                <Slider
                  label="How much paint it holds"
                  value={drawn.capacity ?? 2400}
                  onChange={(capacity) => setDrawn((d) => ({ ...d, capacity }))}
                  min={300}
                  max={7000}
                  step={50}
                  format={(v) => `${(v / 2400).toFixed(2)}×`}
                />
                <Slider
                  label="How freely it gives it up"
                  value={drawn.release ?? .65}
                  onChange={(release) => setDrawn((d) => ({ ...d, release }))}
                  min={.15}
                  max={1}
                  step={.01}
                  format={(v) => `${Math.round(v * 100)}%`}
                />
                <p className={HINT}>
                  Holding more and giving it up more slowly both make a dip last longer.
                  A soft head dumps its load; a stiff coarse one meters it out and drags
                  the same load much further. 1× is the stock 12 mm filbert.
                </p>

                <Notes id="brushname" rows={1} label="Name" value={drawnName} onChange={setDrawnName} />

                <div className="flex gap-2">
                  <Button
                    className={`${BTN_PRIMARY} flex-1`}
                    onPress={async () => {
                      try {
                        const response = await fetch('/api/brushes', {
                          method: 'POST',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify({ ...drawn, name: drawnName, savedAt: new Date().toISOString() }),
                        });
                        const body = await response.json();
                        if (!response.ok) throw new Error(body.error || 'save failed');
                        setSaved({ ok: true, file: body.file, what: 'Brush' });
                      } catch (error) {
                        setSaved({ ok: false, message: error.message });
                      }
                    }}
                  >
                    Save brush
                  </Button>
                  <Button className={BTN} onPress={() => setDrawn(null)}>Put it down</Button>
                </div>

                <p className={HINT}>
                  Every change is in your hand straight away — draw on the sheet and see it.
                </p>
              </div>
            )}
          </TabPanel>

          <TabPanel className="px-4 py-3.5 outline-none" id="history">
            {sessions.length === 0 ? (
              <p className={HINT}>
                No sessions recorded yet. Save a mark and it appears here and in the repository.
              </p>
            ) : (
              <div className="flex flex-col gap-2">
                {sessions.map((item) => (
                  <div key={item.file} className="rounded border border-rule bg-panel2 px-2.5 py-2">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="text-[12px] font-semibold">{item.material || 'unknown'}</span>
                      <span className="font-mono text-[10px] text-ink3">
                        {String(item.recordedAt || '').slice(0, 16).replace('T', ' ')}
                      </span>
                    </div>
                    <div className="mt-0.5 text-[11.5px] text-ink2">
                      {[item.rating, item.decision].filter(Boolean).join(' · ') || 'no verdict'}
                      {item.behavior ? ` — ${item.behavior}` : ''}
                    </div>
                    <div className="mt-1 break-all font-mono text-[10px] text-ink3">{item.file}</div>
                  </div>
                ))}
              </div>
            )}
          </TabPanel>
        </Tabs>
      </div>
    </div>
  );
}

function formatValue({ key, value }) {
  if (!Number.isFinite(value)) return '—';
  if (key === 'pigment_conservation_error') return value.toFixed(6);
  if (Math.abs(value) >= 100) return value.toFixed(1);
  if (Math.abs(value) >= 1) return value.toFixed(2);
  return value.toFixed(4);
}
