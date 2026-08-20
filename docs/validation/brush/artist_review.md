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

### The consequence nobody should forget

Every approved behaviour on the board — five on oil, five on charcoal — was
painted with the disc. The artist has already accepted that a real brush puts
all ten back in question. That reckoning has not happened yet; it is deferred by
agreement, not resolved.
