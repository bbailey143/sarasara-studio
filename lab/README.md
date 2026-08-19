# Diagnostic lab

Open [`diagnostic-lab.html`](diagnostic-lab.html) directly in a browser. It is intentionally dependency-free: no install step and no server are required.

This is an observation prototype, not a validated production solver. Use it to exercise the review workflow and to identify which behaviors need a real implementation. A saved JSON record is evidence of the review decision, not proof that the equations are correct.

The current lab uses a small property-driven shared solver rather than separate named-medium engines. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for its canonical property and model mapping.

## Pressure behavior panel

The card to the right of the drawing surface lets the artist tune pressure in place. Drag either brown handle, use the paired sliders for precise or keyboard adjustment, or start with **Linear**, **Soft**, or **Firm**. The dark dot shows current hand pressure and resulting material force. **Paper texture**, **Particle breakup**, **Smear**, and **Speed** range from `0` to `2`; `1.00` is the previously tested behavior.

Changes affect the next contact and do not alter marks already on the paper. Calibration survives refreshes and is copied into every review JSON and history card. **Reset all** restores the original curve and influences. Treat these as an artist's diagnostic recipe, not measured science or a canonical medium definition.

## Loose, grainy charcoal target

The current charcoal v0.6 target comes from the artist's labeled **Stamp / 1 Layer / Multi-Layer / Smudge** reference. See [`LOOSE_GRAIN_CHARCOAL_TARGET.md`](../docs/reference/material-studies/LOOSE_GRAIN_CHARCOAL_TARGET.md). Test those four behaviors before isolating smaller fracture questions: first contact should be broken and particulate, one layer should retain paper gaps, repeated layers should deepen without flattening, and smudging should create a lighter directional veil while preserving darker source structure.

## Charcoal smudge test

1. Choose **Charcoal** and **Draw material**, then make a dense mark.
2. Without clearing, change **Contact action** to **Smudge existing material**.
3. Begin inside the dark mark and drag toward a lighter or blank area.
4. Watch **Relocated by contact** and **Conservation error**. Relocated material should rise while total pigment remains conserved.
5. Judge whether the source softens and the trail gains existing charcoal in a dusty, controllable way. A blank-paper smudge must remain blank.
6. Save the review. The mark, action, settings, measurements, rating, and decision remain available in History and in the exported JSON.

## Paper comparison checkpoint

The paper selector contains four preserved archive seeds—Plain White, Hot Press, Cold Press, and Rough Watercolor Paper—plus sample-guided Pastel White and Pastel Light Cream candidates. They are separate from the material choice and are not measured final papers.

For charcoal, use **Pastel Paper — White**. Make a steady light stroke at pressure `0.25`, then a matched firm stroke at `0.75`. Look for a quiet field of tiny fibers—not large hills—with the firm stroke progressively reaching more of the shallow spaces. Repeat on **Pastel Paper — Light Cream** and confirm only the ground color changes. Then make a dense mark and repeat the accepted smudge gesture. The artist completed and accepted this full comparison for the v0.2 diagnostic scope; repeat it only when checking a later regression.

For watercolor, compare one matched damp stroke on **Hot Press**, **Cold Press**, and **Rough Watercolor Paper**. Judge the change in uptake, edge character, broken contact, and paper visibility—not which one is prettiest. Save each review so the mark, selected paper, settings, rating, and decision remain in history.
The automated ledger passes CH-P-05's conservation requirements, v0.4 smudge motion has limited artist acceptance, and CH-P-01/02 have artist acceptance for Pastel Paper v0.2's diagnostic scope. The profiles remain experimental rather than measured production papers.

## Charcoal fracture and dust checkpoint

1. Choose **Charcoal**, **Pastel Paper — White**, and **Draw material**.
2. Make a short stroke with pigment load `0.35`, pressure `0.25`, and speed `0.35`.
3. Clear the surface. Repeat the same gesture with load `1.00`, pressure `0.85`, and speed `1.60`.
4. In the stronger gesture, look for a few coarser crumbs staying near the stroke while finer dust travels slightly farther. Watch **Coarse fragments** and **Fine dust** fall after your hand lifts.
5. Reject or recalibrate the result if it looks like evenly sprinkled dots, a spray brush, glitter, or decoration unrelated to the stroke. The particles must appear to break from the contacted material.
6. Confirm **Conservation error** stays below `1%`. Switch to Smudge and drag on blank paper; it must create no particles.
7. Save the review. The moderate-smudge breakup/drag is already accepted; this matched Draw comparison is the remaining artist question for CH-P-03 / CH-P-04.

The lab records offered material, material left on the applicator, settled pigment, loose pigment, coarse fragments, fine dust, off-canvas loss, and the artist's image/settings in the exported JSON and browser history. These quantities verify the ledger; they do not prove that the breakup looks or feels right.

### Pressure-smear relationship carried into v0.6

`CH-LAB-1787158644333` rated the v0.5.1 moderate smudge **Convincing / Accept** at pressure `0.55` and speed `1.00`. `CH-LAB-1787159371656` then rated the strong pressure-`0.85`, speed-`1.60` smudge **Recognizable / Recalibrate** because it pushed the material away without pressing a dark smear into the paper. v0.5.2 preserves the accepted moderate path and adds pressure anchoring only above it.

Make one dense source mark. Test the moderate reference first at `0.55` / `1.00`; it should remain dusty, surface-connected, and controllable. Without treating that as strong pressure, repeat from a fresh dense mark at `0.85` / `1.60`. The strong pass should leave rubbed charcoal in the contacted trail while some loose dust still moves ahead. Watch **Pressed into paper** rise. Reject it if the whole mark still sweeps away, if no dark smear remains, or if everything becomes a stopped putty slab. Review this as the **Smudge** section of the combined v0.6 loose-charcoal gate.
