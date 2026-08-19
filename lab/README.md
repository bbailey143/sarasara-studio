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

## Paper comparison checkpoint

The paper selector contains four preserved archive seeds: Plain White, Hot Press, Cold Press, and Rough. They are separate from the material choice and are not measured final papers.

For charcoal, compare the same light and firm strokes on **Plain White** and **Rough**. Look for Rough to catch raised tooth first, leave believable valley gaps, and progressively reach valleys under pressure. Then repeat the accepted smudge gesture on Rough and judge whether the better tooth preserves the loose-particle feel.

For watercolor, compare one matched damp stroke on **Hot Press**, **Cold Press**, and **Rough**. Judge the change in uptake, edge character, broken contact, and paper visibility—not which one is prettiest. Save each review so the mark, selected paper, settings, rating, and decision remain in history.
The automated ledger passes CH-P-05's conservation requirements, and v0.4 smudge motion has limited artist acceptance. The recovered paper profiles and their effect on charcoal and watercolor remain pending artist review.
