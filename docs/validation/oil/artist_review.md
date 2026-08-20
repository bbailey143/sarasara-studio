# Oil artist review

**Status: no artist review has taken place.**

Oil v0.1 exists to test whether the shared vocabulary and the shared bench can
carry a third material that is neither a free-flowing liquid nor a dry powder.
It has code evidence only. Nothing about how it looks has been judged.

## What to look at when the review happens

The four things that would tell an artist this is oil rather than thick
watercolor:

1. **It holds the mark.** A ridge left by the brush should stay a ridge. It
   should not relax into a smooth pool while you watch it.
2. **It moves as a body.** Pushing into existing paint should shove it along
   the stroke and pile it up ahead, not smear it thin.
3. **It takes light.** The relief should read as thickness — a lit side and a
   shadowed side — not as a darker colour.
4. **It never bleeds.** No soft edge, no spread, no halo. Oil pigment goes
   where the brush puts it and stays there.

## Known stand-ins to be sceptical of

- Yield stress `0.34`, viscosity `0.82`, packing `0.78`, particle density
  `0.62` — all normalized guesses, not measured from any paint.
- The relief shading is a simple height-gradient shade in one fixed light
  direction. It is a diagnostic, not a lighting model.
- The diagnostic colour is a single earth tone. There is no spectral colour in
  the bench yet, so glazing and mixing cannot be judged at all.
- Brush size still responds to the brush-water control, which means nothing for
  oil. It is harmless but wrong, and should be relabelled when the applicator
  work lands.

## Recording a review

Follow the same discipline as watercolor and charcoal: save the mark, the
settings, the profile version, the measurements, a rating, and an explicit
decision. Name the failing behaviour by its `OL-P-` id. A decision here can
accept a **stated scope only** — never oil as a finished medium.
