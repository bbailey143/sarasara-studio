# Brush artist review

## BRUSH-001 — the first drawn brush

- **Recorded:** 2026-08-20, `docs/validation/sessions/2026-08-20t20-02-26-oil.json`
- **Tool:** `brush.filbert.drawn.v0.1` — 12 mm filbert, held at 0°
- **Paint / paper:** Oil on Cold Press
- **Settings:** Draw, load `0.44`, **stylus pressure**, speed `0.80`
- **Measurements:** paint on the sheet `426.6`, tallest point `1.05`,
  conservation error `2.3e-8%`

### The verdict

**Artist's words, given in conversation:**

> The filbert brush is genuinely one of the cleanest brushes I've used on an
> iPad. I am confident this concept is working.

**Verdict as saved in the session file:** `recognizable / recalibrate`, with the
behaviour and notes fields left blank.

**These two do not agree, and the file is what survives.** The saved record
reads as a lukewarm result requiring rework; the artist's actual judgement was a
strong pass on the concept. The words above are recorded here because they were
given directly, but they carry weaker provenance than a saved review: there is
no rating, no named behaviour, and no note attached to the mark itself.

This is exactly the drift the validation discipline exists to prevent. The
review should be re-saved with the real verdict before this is treated as
settled evidence.

### What this does and does not settle

**Settled.** The question ADR-0003's first pass was built to answer — *can a
drawn shape become a brush the engine paints with?* — is answered yes. The mark
shows strokes that swell and taper with pressure, thin edge-on lines, and a
broad sweep that opens and closes. None of that was possible with a disc.

**Not settled, and not claimed:**

- This is **shape only**. There is no bristle stiffness, spring, damping,
  cohesion, roughness, absorbency, or reservoir in the tool yet. What feels good
  here comes from two things: the belly curve opening under pressure, and the
  brush being sized in real millimetres.
- The filbert outline, its belly curve and its edge softness are all
  hand-authored stand-ins. None were measured from a real brush.
- No brush has been compared against another. No brush has been reviewed on
  watercolor or charcoal.
- There is no board row for any of this. The board records what a *material*
  does; a tool needs rows of its own, and they do not exist.

## BRUSH-002 — hair that bends

- **Recorded:** 2026-08-20, in conversation
- **Behaviour:** `BR-06` bends and lags — the head trails the hand and rounds
  a corner off

**Artist’s words:**

> Okay - it works! […] Green light though for this stage.

**No board mark was set.** The artist said this while also reporting the board
itself was a mess to use, which is the likeliest reason. `BR-06` stands at
machine-checked until he sets it himself; nobody else may.

### What was measured

An L-shaped gesture at speed 1.4, measuring how far the mark reaches past the
corner before the head turns:

| Stiffness | Reach past the corner |
| --- | --- |
| 0.95 | 5.26 mm |
| 0.78 | 4.84 mm |
| 0.55 | 4.21 mm |
| 0.30 | 3.37 mm |
| the disc | 0.63 mm — its own half-width, no hair |

The trailing distance is measured in millimetres of travel rather than frames,
so the same gesture drags the same way however finely the pen reports.

### Corrections made on the way

- These numbers were first read backwards, as the softest brush bending least.
  A lagging head does not run past a corner — it never reaches it, because the
  hand turns first and the head cuts across.
- The rate-independence check first asserted the head still trails after 120
  cells of straight travel. That is wrong: over a long straight it should
  arrive fully. Re-measured over one trailing length.

### Still absent, deliberately

Only `stiffness` drives this. `spring` and `damping` are named in the brush
specification and would govern how a head recovers after lifting, which is not
simulated — so they are absent rather than sitting in the profile as
decoration. Runs out of paint, splays and splits, and springs back remain
unbuilt.

## BRUSH-003 — the artist marks the engine down

- **Recorded:** 2026-08-21, on the board
- **Said:** "Tested - see comments." The comments were the marks themselves.

Every engine row that stood at machine-checked was moved down by hand:

| Row | Was | Set to |
| --- | --- | --- |
| `BR-01` holds its true size | machine-checked | partial |
| `BR-02` knows how it is held | machine-checked | partial |
| `BR-03` opens with pressure | machine-checked | partial |
| `BR-04` feathers its edge | machine-checked | partial |
| `BR-05` runs out of paint | machine-checked | **not built** |
| `BR-06` bends and lags | machine-checked | partial |

No notes were left, so **the reasons are unknown**. What follows is one defect
found by going looking, not an explanation of the marks.

### A defect found while looking

Every measurement behind those machine-checked marks drew the test stroke as
one long segment. A pen reports hundreds of points per stroke, and each segment
laid a contact at **both** ends — so every join between pointer moves was
stamped twice.

The same physical gesture, drawn at different pen rates:

| Pointer moves | Paint laid | Brush left |
| --- | --- | --- |
| 1 | 522 | 55% |
| 60 | 603 | 48% |
| 150 | 741 | 36% |
| 400 | 1092 | **5%** |

So in the artist’s hand a brush emptied roughly twice as fast as the bench
measured, and how hard he appeared to press depended on how fast his hardware
talked. This is the rate-independence the brush specification has required from
the start and which was never true.

Fixed two ways: only the first contact after the brush lands starts at zero, so
joins are no longer double-stamped; and each contact lays paint for the spacing
actually used rather than a nominal one, so an over-sampled short move does not
lay a full step. Measured after: 521, 521, 521, 521, 520, 520 across one to a
thousand pointer moves.

This cost about a tenth of a percent against the old disc reference, which was
re-baselined. Bit-exactness lost, rate-independence gained.

**Whether this was what the artist saw is unknown.** It is one real defect in
the path between his hand and the measurements, and it plausibly touches size,
feathering and the reservoir alike. It is not a claim to have explained the
marks, and the other rows remain unexplained until he says what he saw.

### The consequence nobody should forget

Every approved behaviour on the board — five on oil, five on charcoal — was
painted with the disc. The artist has already accepted that a real brush puts
all ten back in question. That reckoning has not happened yet; it is deferred by
agreement, not resolved.
