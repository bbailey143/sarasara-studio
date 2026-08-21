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

**It was not what the artist saw.** He was testing with the disc:

> I was testing with the disc, that’s my bad.

### Why every one of those marks was right, for the disc

The disc is sized in cells rather than millimetres, it is round so it marks the
same in every direction, it has no belly, no hair and no reservoir. Those
absences are what make it the frozen reference. Judged through it, the engine
genuinely fails five of its own rows:

| Row | Through the disc |
| --- | --- |
| `BR-01` holds its true size | it does not — it is sized in cells |
| `BR-02` knows how it is held | it cannot — it is round |
| `BR-03` opens with pressure | no belly to open |
| `BR-05` runs out of paint | bottomless by design |
| `BR-06` bends and lags | no hair to bend |

This is a fault in the board, not in the testing. It offered a verdict it could
not support and gave no sign that the tool in hand could not show any of it.

### What was done about it

Each engine row now names what a tool must have before it can be judged. When
the brush in hand lacks it the row greys out, says why — *"this brush is
bottomless by design — pick a drawn brush"* — and refuses the click.

The five rows above were restored to machine-checked, each carrying a note
saying it was marked down through the disc and awaits a judgement made with a
drawn brush. The marks are preserved in this record rather than erased.

**`BR-04` feathers its edge was left at partial.** The disc has a soft-edged
footprint and can demonstrate feathering perfectly well, so that judgement
stands on its own feet and is nobody else’s to undo.

### The defect above still counts

The double-stamped joins were real and are fixed regardless. They were found by
going looking for a cause, and the cause turned out to be something else — but
a gesture that laid twice the paint depending on how fast the pen reported it
was a genuine breach of the brush specification, and it is now closed.

### The consequence nobody should forget

Every approved behaviour on the board — five on oil, five on charcoal — was
painted with the disc. The artist has already accepted that a real brush puts
all ten back in question. That reckoning has not happened yet; it is deferred by
agreement, not resolved.

## BRUSH-004 — the engine judged with a real brush

Session `2026-08-21t20-37-24-watercolor`. Filbert, 12 mm, on hot press at
Finest. Rated *recognizable*, decision *recalibrate*.

This is the re-test the previous entry was waiting for. Judged with a drawn
brush instead of the disc, the engine picked up its first two approvals:

| Row | Verdict with the filbert |
| --- | --- |
| `BR-01` holds its true size | **approved** |
| `BR-02` knows how it is held | **approved** |
| `BR-05` runs out of paint | partial |
| `BR-06` bends and lags | partial |
| `BR-09` lays paint by distance | partial |

And the brush itself: *reads as a filbert* and *its belly feels right* both
approved; *its hair feels right* and *worth keeping* left at partial. Shape and
belly pass. Hair and reservoir do not.

### What the artist said

> Paint runs out very quickly - too quickly, actually. The reservoir needs to
> release slower by default. I think that will need to be changeable behavior
> as Sables hold way more water than Hog Bristle, but hog bristle would hold
> and spread much more oil than a sable. I think I’m saying the reservoir
> exists, but it needs to be customizable and refinable, but default brushes
> need to spread further - running out fluid/paint more slowly. Also, let’s
> have a default setting of auto reload which can be turned on and off with a
> switch. And, we might as well add an extra setting to that auto-reload for
> the user to select how much paint is put on the brush from auto-load. I think
> that could be a per-brush setting in the brush-building studio.

And on the review form’s first question:

> Get rid of this question. I don’t think it’s really needed anymore...

### He was right, and it was measurable

One 8 cm stroke, oil, filbert, at working pressure:

| | before | after |
| --- | --- | --- |
| cost of one 8 cm stroke | 42% of a full dip | 13% |
| oil, filbert | 23 cm per dip | 85 cm |
| oil, flat | 23 cm | 116 cm |
| watercolour, filbert | 70 cm | 224 cm |
| watercolour, flat | 77 cm | 355 cm |

Two and a half strokes and the brush was dead. That is not a brush.

### What was done about it

**A head now has two numbers, not one.** `capacity` is how much paint the hair
holds; `release` is how freely it lets go on each contact. Reach per dip is one
divided by the other, so a soft head that dumps its load and a stiff one that
meters the same load out much further are both expressible. Both are per-brush
and both are meant to be edited in the brush studio.

The artist’s stated target — that hair type and medium should decide these
together, a sable holding far more water while a hog bristle holds and spreads
far more oil — is **not** modelled. These are two editable numbers, not that
coupling. Recorded as the next step, not as done.

**Auto-reload**, on by default in the studio, with an adjustable amount. It is
a convenience rather than physics, so the engine ships with it off: a test that
measures a brush running out has to be allowed to run out.

**The behaviour question is gone** from the review form.

### A second defect, found on the way

A brush low on paint laid a fraction of what was left, so the two halved
together and it approached dry without ever arriving — a filbert was still
making marks after 4,547 cm and 400 strokes. *Runs out of paint* was not true
in the literal sense.

Now a fading brush keeps making the same faint scratchy mark until the usable
charge is spent and then stops, and a trace stays clinging to the hair that
never transfers, the way a spent brush is still stained. The gauge reads what
is left to paint with, so it reaches a true zero exactly when the brush stops
marking. The residue stays on the books; it is still paint, it is just stuck.

### Evidence

Reach is now pinned in centimetres of stroke rather than in units of pigment,
because capacity and release are both meant to move and the reach they produce
is the thing that must not drift. Six deliberate breakages were tried against
the new tests — the old stingy capacity, the metering removed, the endless
fade, no residue, no reload on lift, reload ignoring its amount — and all six
were caught.

Status: `automated_relationship_verified`. The artist has not re-tested it yet.

## BRUSH-005 — the bend was too small to see

Session `2026-08-21t21-33-39-watercolor`. A brush drawn in the studio from the
filbert and saved as *My filbert*, 12 mm, on rough watercolour paper at Finest.
Rated *recognizable*, decision *recalibrate*.

First: the reservoir landed.

> The reservoir issue feels better. So does the amount of time the brush takes
> to run out.

And the session file confirms the drawn brush carried `capacity` 2400 and
`release` 0.65 through the editor, so reshaping a brush no longer empties it.

### The finding

> The bending and lagging is very understated which is why I haven’t green
> marked it.

Measured, on an 80 mm sheet:

| | before | after |
| --- | --- | --- |
| filbert, distance behind the hand | 1.53 mm | **3.78 mm** |
| soft vs stiff head rounding a corner | 0.42 mm apart | **1.26 mm apart** |
| filbert, slow gesture vs fast | 1.03 → 2.34 mm | 2.60 → 5.67 mm |

Under two per cent of the sheet, and four tenths of a millimetre between the
softest working head and the stiffest. He was reading it correctly.

### And a second thing underneath it

Lag did not depend on the size of the brush at all. A 40 mm head trailed the
same 2.46 mm as a 12 mm one. A brush bends because its hair is a cantilever, so
a wider head carries longer hair and has to lag more; that is now how it works.

Only the 12 mm case has been looked at. **The width scaling is reasoning, not
evidence** — a 40 mm soft head now trails 20 mm, which nobody has judged.

### Why the tests did not catch it

Every assertion about bending compared one brush against another: softer cuts
the corner more than stiffer, quicker bends further than slower, and the ladder
runs the right way. All of them passed at a size nobody could see. **Ordering
was tested and magnitude was not.** The new checks state the distances in
millimetres. Four deliberate breakages were tried against them and all four were
caught.

This is the second time the artist’s eye has found something the suite was
structurally incapable of noticing. It is worth saying plainly: a relationship
test proves a thing responds, never that it responds enough to matter.

### The rest of the session

Three requests about the instrument rather than the paint, all built:

**A red mark.** *"The board needs a red mark, which means I’ve checked it and
it needs recalibration."* Choosing it opens a box for the reason. The reason
waits — *"I don’t want to separately submit that, either"* — and goes up with
the next **Save this mark**, onto the row itself and into the session file.

**A clean form and a modal.** Saving now says so in a dialog and empties the
form behind it. Saving a brush had been writing to a status line that no longer
existed, so it had been silent; it uses the same dialog now.

**The reservoir in the Brush Studio.** *"These settings as well, reservoir,
belly size, etc. need to land in the Brush Studio. I don’t want to lose site of
that goal as well."* How much it holds and how freely it gives it up are both
dials there now. A thirsty, tight-releasing head spends 3% of a dip on a stroke
that costs the stock filbert 19%.

### One bug found while testing this

A brush drawn in the studio was reading its board row from whichever registry
head it had been started from, so *My filbert* inherited the stock filbert’s
note and date. Each brush keeps its own row now.

Status: `automated_relationship_verified`. The artist has not re-tested the bend.
