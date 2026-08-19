# Diagnostic lab

Open [`diagnostic-lab.html`](diagnostic-lab.html) directly in a browser. It is intentionally dependency-free: no install step and no server are required.

This is an observation prototype, not a validated production solver. Use it to exercise the review workflow and to identify which behaviors need a real implementation. A saved JSON record is evidence of the review decision, not proof that the equations are correct.

The current lab uses a small property-driven shared solver rather than separate named-medium engines. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for its canonical property and model mapping.

## Charcoal smudge test

1. Choose **Charcoal** and **Draw material**, then make a dense mark.
2. Without clearing, change **Contact action** to **Smudge existing material**.
3. Begin inside the dark mark and drag toward a lighter or blank area.
4. Watch **Relocated by contact** and **Conservation error**. Relocated material should rise while total pigment remains conserved.
5. Judge whether the source softens and the trail gains existing charcoal in a dusty, controllable way. A blank-paper smudge must remain blank.
6. Save the review. The mark, action, settings, measurements, rating, and decision remain available in History and in the exported JSON.

The automated ledger passes CH-P-05's conservation requirements. The visual and tactile charcoal judgment remains pending artist review.
