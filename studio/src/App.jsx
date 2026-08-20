import { useCallback, useEffect, useRef, useState } from 'react';
import { Tab, TabList, TabPanel, Tabs } from 'react-aria-components';
import { createEngine, listMaterials, listSubstrates } from './engine/index.js';
import { BTN, BTN_PRIMARY, Button, Notes, Select, Slider, ToggleRow } from './components/Controls.jsx';
import { BOARD_ROWS, MARKS, MARK_ORDER, seedBoard } from './data/board.js';

const SIM = { width: 190, height: 140 };
const VIEW = { width: 760, height: 560 };
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

export default function App() {
  const canvasRef = useRef(null);
  const engineRef = useRef(null);
  const strokeRef = useRef({ down: false, last: null, lastTime: 0, speed: 0.8 });

  const [ready, setReady] = useState(false);
  const [material, setMaterial] = useState('oil');
  const [substrate, setSubstrate] = useState('coldPress');
  const [action, setAction] = useState('draw');
  const [load, setLoad] = useState(0.7);
  const [water, setWater] = useState(0.3);
  const [dampness, setDampness] = useState(0);
  const [fallbackPressure, setFallbackPressure] = useState(0.55);
  const [fallbackSpeed, setFallbackSpeed] = useState(0.8);
  const [viewGain, setViewGain] = useState(2.6);

  const [regime, setRegime] = useState('');
  const [profileId, setProfileId] = useState('');
  const [readout, setReadout] = useState([]);
  const [usingStylus, setUsingStylus] = useState(false);

  const [board, setBoard] = useState(null);
  const [sessions, setSessions] = useState([]);
  const [online, setOnline] = useState(true);
  const [status, setStatus] = useState(null);

  const [rating, setRating] = useState('recognizable');
  const [decision, setDecision] = useState('recalibrate');
  const [behavior, setBehavior] = useState('');
  const [notes, setNotes] = useState('');

  /* ---------------------------------------------------------- engine */

  useEffect(() => {
    let cancelled = false;
    createEngine({ ...SIM, material, substrate }).then((engine) => {
      if (cancelled) return;
      engineRef.current = engine;
      // Dev-only handle so the engine can be inspected from the console while
      // diagnosing a mark. Never referenced by application code.
      if (import.meta.env.DEV) window.__studio = { engine, readout: () => engine.readout() };
      engine.setViewGain(viewGain);
      engine.clear(dampness);
      setRegime(engine.regime());
      setProfileId(engine.profile().id);
      setReadout(engine.readout());
      setReady(true);
    });
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
    engine.setSubstrate(substrate);
    engine.clear(dampness);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [substrate, ready]);

  useEffect(() => {
    if (engineRef.current && ready) engineRef.current.setViewGain(viewGain);
  }, [viewGain, ready]);

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
        if (sinceReadout > 0.16) { sinceReadout = 0; setReadout(engine.readout()); }
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
      x: ((event.clientX - rect.left) / rect.width) * canvas.width,
      y: ((event.clientY - rect.top) / rect.height) * canvas.height,
    };
  };

  const onPointerDown = (event) => {
    try { event.currentTarget.setPointerCapture(event.pointerId); } catch { /* capture is a nicety, not a requirement */ }
    setUsingStylus(event.pointerType === 'pen');
    strokeRef.current = {
      down: true,
      last: toCanvas(event),
      lastTime: performance.now(),
      speed: fallbackSpeed,
    };
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
    engine.stroke(action, state.last, point, VIEW, {
      pressure: stylus ? event.pressure : fallbackPressure,
      speed: state.speed,
      load,
      water,
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
      substrate: engine.substrateInfo(),
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
      review: { rating, decision, behavior: behavior.trim(), notes: notes.trim() },
      board: board?.rows?.[material] || null,
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
      setStatus({ tone: 'ok', text: `Saved to ${body.file}` });
      setOnline(true);
      loadSessions();
    } catch (error) {
      setStatus({ tone: 'bad', text: `Could not save: ${error.message}. Is "npm run lab" running?` });
      setOnline(false);
    }
  };

  const rows = BOARD_ROWS[material] || [];
  const marks = board?.rows?.[material] || {};

  return (
    <div
      className="grid h-full max-lg:h-auto max-lg:min-h-full
                 grid-cols-[292px_minmax(0,1fr)_352px] grid-rows-[46px_minmax(0,1fr)]
                 [grid-template-areas:'bar_bar_bar''left_center_right']
                 max-lg:grid-cols-1 max-lg:grid-rows-[46px_auto_auto_auto]
                 max-lg:[grid-template-areas:'bar''center''left''right']"
    >
      <header className="[grid-area:bar] flex items-center gap-4 border-b border-rule bg-panel px-4">
        <h1 className="m-0 whitespace-nowrap text-[13px] font-semibold tracking-wide">
          Sarasara · diagnostic studio
        </h1>
        <span className={`${CHIP} ${REGIME_CHIP[regime] || 'border-rule2 text-ink2'}`}>
          {regime || '…'}
        </span>
        <span className="truncate font-mono text-[10.5px] text-ink3">{profileId}</span>
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
            <Select label="Medium" items={materials} value={material} onChange={setMaterial} />
            <Select label="Paper" items={substrates} value={substrate} onChange={setSubstrate} />
            <ToggleRow label="Contact" options={ACTIONS} value={action} onChange={setAction} />
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
            <Button className={`${BTN} flex-1`} onPress={() => { engineRef.current?.clear(dampness); setStatus(null); }}>
              Fresh sheet
            </Button>
            <Button className={`${BTN} flex-1`} onPress={() => engineRef.current?.forceDry()}>
              Force dry
            </Button>
          </div>
        </section>
      </div>

      {/* -------------------------------------------------- centre: canvas */}
      <div className="[grid-area:center] flex min-h-0 min-w-0 items-center justify-center bg-ground p-5">
        <div className="flex max-h-full max-w-full flex-col gap-2.5">
          <div className="overflow-hidden rounded-sm border border-rule2 bg-white leading-none shadow-xl">
            <canvas
              ref={canvasRef}
              width={VIEW.width}
              height={VIEW.height}
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
            <span>{SIM.width}×{SIM.height} cells</span>
            <span>{action === 'draw' ? 'drawing material' : 'smudging what is there'}</span>
          </div>
        </div>
      </div>

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
            {[['record', 'Record'], ['board', 'Board'], ['history', 'Sessions']].map(([id, label]) => (
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
                id="behavior"
                rows={2}
                label="Which behaviour is this about?"
                value={behavior}
                onChange={setBehavior}
                placeholder="e.g. OL-01 holds its shape"
              />
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
              {status && (
                <div
                  className={`rounded border px-2.5 py-2 text-[12px] ${
                    status.tone === 'ok'
                      ? 'border-terre bg-terresoft text-ink'
                      : 'border-danger text-danger'
                  }`}
                >
                  {status.text}
                </div>
              )}
            </div>
          </TabPanel>

          <TabPanel className="px-4 py-3.5 outline-none" id="board">
            <div className="mb-3 flex flex-wrap gap-x-3 gap-y-1.5">
              {MARK_ORDER.slice().reverse().map((key) => (
                <span key={key} className="inline-flex items-center gap-1.5 text-[11.5px] text-ink2">
                  <span className="mk" data-mark={key} /> {MARKS[key].short}
                </span>
              ))}
            </div>
            <div className="flex flex-col">
              {rows.map((row) => {
                const current = marks[row.id]?.mark || row.seed;
                return (
                  <div
                    key={row.id}
                    className="grid grid-cols-[16px_1fr] items-start gap-2.5 border-b border-rule py-2.5 last:border-b-0"
                  >
                    <span className="mk mt-1" data-mark={current} />
                    <div>
                      <div className="flex items-baseline justify-between gap-2">
                        <span className="text-[12.5px] font-medium leading-tight">
                          {row.name}
                          <small className="mt-px block text-[11.5px] font-normal text-ink3">{row.hint}</small>
                        </span>
                        <span className="font-mono text-[9.5px] tracking-wide text-ink3">{row.id}</span>
                      </div>
                      <div className="mt-1.5 flex gap-1">
                        {MARK_ORDER.map((key) => (
                          <button
                            type="button"
                            key={key}
                            onClick={() => setMark(row.id, key)}
                            aria-label={`${row.name}: ${MARKS[key].label}`}
                            aria-pressed={current === key}
                            className={`flex cursor-pointer items-center gap-1.5 rounded-sm border bg-panel2 px-1.5 py-1
                                        font-mono text-[9.5px] uppercase tracking-wide ${
                                          current === key ? 'border-ink2 text-ink' : 'border-rule2 text-ink3'
                                        }`}
                          >
                            <span className="mk !h-2.5 !w-2.5" data-mark={key} />
                            {MARKS[key].short}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            <p className={`${HINT} mt-3`}>
              Green is a claim about what you have seen. Nothing a test does can set it.
            </p>
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
