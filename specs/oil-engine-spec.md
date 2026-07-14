# Oil Painting Simulation — Implementation Spec

**For:** the Rheology / Brush / Pigment / Lighting engine sprint (Flutter · iPad · Metal)
**Status:** implementation-ready. Each stage gives the physical model, the discretized update, and the GPU pass (inputs → output → kernel).
**Companion:** `watercolor-engine-spec.md`. The **spectral pigment model and Kubelka-Munk color (that doc's §3 pigment fields + §6)** are reused *unchanged* here. This spec only specifies what oil does differently: viscoplastic transport, a dynamic height field, a bidirectionally-loaded brush, and height-field lighting.
**Reference model:** Baxter, Wu, Govindaraju, Lin & Manocha, *IMPaSTo: A Realistic, Interactive Model for Paint* (NPAR 2004); Baxter, *Physically-Based Modeling Techniques for Interactive Digital Painting* (thesis); Chen et al., *WetBrush* (SIGGRAPH Asia 2015). Rheology from Bingham / Herschel-Bulkley viscoplastics.

---

## 1. The two facts that make oil not watercolor

Everything in this document descends from two physical properties. State them plainly to whoever implements this, because half the bugs will come from forgetting them:

1. **Oil is viscoplastic — it has a yield stress `τ_y`.** Below a threshold shear stress it does not flow; it holds its shape as a soft solid. This is impasto, held knife-ridges, and persistent brushmarks. Watercolor has `τ_y = 0`; oil does not. The flow law is **Herschel-Bulkley**: `τ = τ_y + K·γ̇ⁿ` (`γ̇` = shear rate, `K` = consistency, `n` < 1 = shear-thinning).

2. **Oil pigment does not self-diffuse. The diffusion coefficient is zero — always.** Color mixes *only* where paint is mechanically transported (dragged, folded, smeared by the brush or by slump). Two touching colors at rest never blend. This is why oil **marbles and streaks** where watercolor **blooms**. Thinning with medium lowers `τ_y` and `K` (more flow) but never introduces diffusion — thinned oil still marbles, never blooms.

If you take only two things from this spec: **flow is gated by yield stress**, and **mixing is transport, not diffusion**.

---

## 2. What is reused vs new

| From watercolor spec | Status here |
|---|---|
| Spectral pigment fields (8-band `K`,`S`) | **Reused** — but one wet layer, not suspended/deposited (§5) |
| 48-pigment `Palette` LUT | **Reused unchanged** |
| Kubelka-Munk mixing + spectrum→RGB collapse | **Reused** as the *albedo* stage, then lit (§9) |
| Semi-Lagrangian advection | Reused, but driven by paste flux, not incompressible flow |
| Incompressible pressure-projection fluid | **Dropped.** Replaced by volume-conserving viscoplastic flux (§7) |
| Evaporation / capillary / wet-mask / blooms | **Dropped.** Oil stays wet in-session; no drying dynamics |
| — | **New:** dynamic height field `h` (impasto relief) |
| — | **New:** bidirectional brush reservoir (pickup + deposit) |
| — | **New:** yield-stress rheology (the paste engine) |
| — | **New:** height-field lighting (the sculptural render) |

The engine mapping, with one addition (**Lighting**):

| Engine | Owns |
|---|---|
| **Brush** | Loaded deformable tool; footprint, pressure→depth, bidirectional pickup/deposit, reservoir (Phase A) |
| **Rheology** (was Fluid) | Height-field viscoplastic flow: yield gate, Herschel-Bulkley flux, volume conservation (Phase B) |
| **Pigment** | Spectral load riding the paint; mechanical (non-diffusive) mixing; KM albedo (Phase C, F) |
| **Texture** | Static canvas tooth/weave; drybrush gating (feeds A, F) |
| **Canvas State** | Persistent height + paint-spectrum textures; undo; tiling (§3, §10) |
| **Lighting** (new) | Height-field normals, oil specular, glaze KM-over-substrate → the visible frame (Phase F) |

---

## 3. Data model (textures)

Sim-resolution `S×S`. Reuses the watercolor spectral pigment fields, but there is **one** paint layer (oil is wet-and-mobile everywhere at once — there is no suspended/deposited split), so half as many spectral textures.

| Texture | Channels | Format | Ping-pong | Contents |
|---|---|---|---|---|
| `Surface` | RG | **RG32F** | yes | `h` (paint height/volume), `m` (medium/binder fraction 0..1) |
| `Flux` | RG | RG16F | no | face flux `q` from the rheology solve (scratch) |
| `Struct` | R | R16F | yes | thixotropic structure 0..1 (modulates `τ_y`); optional (§8) |
| `Kpaint0,Kpaint1` | RGBA×2 | **RGBA32F** | yes | paint **absorption** spectrum, 8 bands |
| `Spaint0,Spaint1` | RGBA×2 | **RGBA32F** | yes | paint **scattering** spectrum, 8 bands |
| `PaintProps` | RGBA | **RGBA32F** | yes | `(load, granWt, —, —)` — extensive sums, see watercolor §3 |
| `Palette` | RGBA | RGBA32F (static) | no | 48-pigment LUT (reused unchanged) |
| `Canvas` | RGB | RGBA8 (static) | no | R=tooth height, G=absorbency, B=weave direction |
| `Color` | RGBA | RGBA8 | no | lit output (Canvas State owns) |

**Brush reservoir** is *not* a canvas-sized texture — it is small per-brush state (a handful of texels or a uniform block): reservoir volume `V_b`, reservoir spectrum `K_b[8]`,`S_b[8]`, reservoir medium `m_b`. Updated once per stamp (§7 A). This is the "what's currently on the brush" that makes a dirty brush dirty.

**Height must be float32.** `h` is both the physics state (slope drives flow) and the lighting input (normals are `∇h`); half-float relief quantizes into visible terraces under raking light.

**No suspended/deposited split, so no per-layer `Props` pair** — one `PaintProps`. Load ties to volume: `load ≈ h · pigmentFraction`, i.e. thinning with medium lowers load at fixed height.

---

## 4. Conventions

- **Grid space.** One texel = one cell, size `Δx`. `Δt` is a real timestep here (rheology is explicit; see the stability limit in §8), unlike watercolor's `Δt=1`.
- **Surface height** `H = b + h`, where `b = Canvas.tooth` (static) and `h` = paint. Flow is driven by `∇H`.
- **Staggered flux.** Compute `q` on cell *faces* (MAC layout) so `∇·q` conserves volume exactly. Face flux `q_{i+½}` lives between cells `i` and `i+1`.
- **Neighbors / sampling.** As watercolor §4. Semi-Lagrangian stays bilinear + clamped; prefer **BFECC** or MacCormack advection for pigment (§6) to keep streaks crisp.

---

## 5. Physical model — shallow viscoplastic flow

Paint is a shallow layer of Herschel-Bulkley fluid on the canvas. Two things move it: **the brush** (dominant, imposes velocity) and **gravity/self-leveling** (weak, slow slump of thick or steep accumulations). Both are gated by yield stress.

**Base shear stress** in a shallow layer of thickness `h` on slope `∇H`:
```
τ_base = ρ g h |∇H|          (ρ = paint density, g = gravity-like constant)
```

**Yield criterion + Herschel-Bulkley flux** (the core of the engine):
```
if τ_base ≤ τ_y:   q = 0                     ← sub-yield: relief HOLDS (impasto)
else:              q = −Mob(h) · (1 − τ_y/τ_base)^(1+1/n) · ∇H
   with           Mob(h) = (ρ g / K)^(1/n) · h^(2+1/n) / (2 + 1/n)
```
Then volume-conserving height update:
```
∂h/∂t = −∇·q
```
Read what this gives you, physically:
- The `(1 − τ_y/τ_base)` factor is the Bingham excess-stress term. When stress barely exceeds yield, flow is near-zero; **this is exactly what freezes sub-yield relief and lets ridges stand.**
- `Mob ∝ h^(2+1/n)` means thick paint slumps and thin films essentially don't move under gravity — correct. Impasto peaks are thick but *steep* stress is offset by high `τ_y`; tune so peaks hold.
- `n < 1` (shear-thinning): the harder the local shear, the lower the effective resistance — brushing mobilizes, rest re-stiffens.

**Brush stress dominates.** Under the brush footprint the imposed shear far exceeds `τ_y`, so the paint there is fully mobilized (and shear-thinned). Model the brush not through `τ_base` but as an imposed velocity field `u_brush` that advects paint directly (§7 A/B). When the brush lifts, `τ_base` alone governs, drops below `τ_y`, and the marks freeze. **That freeze-on-lift is the whole feel of oil.**

---

## 6. Mixing model — mechanical, not diffusive

The pigment spectra (`Kpaint*`,`Spaint*`) and `PaintProps` **advect with the same transport as `h`** — the rheology flux `q` and the brush velocity `u_brush` — with **diffusion coefficient exactly 0.**

Consequences to preserve:
- **Two static colors never blend.** No flux without stress ⇒ no mixing at rest. Do not add a "small diffusion for stability"; it will read as watercolor bleed and destroy the oil character. If you need stability, get it from the advection scheme, not diffusion.
- **Streaks, not blends.** Semi-Lagrangian introduces numerical diffusion that blurs streaks over many steps. Use **BFECC/MacCormack** advection for the pigment channels to keep marbling crisp; plain bilinear is acceptable for `h` itself.

> **Implementation status (documented departure).** The Phase-5 CPU reference
> (`core/oil/oil_simulation.dart`) transports **all** extensive fields — `h`,
> medium, spectra, props — by conservative donor-cell/upwind fractions in both
> the brush-drag pass (A2) and the flux pass (B2), instead of BFECC for A2
> pigment. Chosen deliberately for this reference: exact volume/pigment
> conservation (§8's own requirement), guaranteed no-color-where-no-paint, and
> co-transport of pigment with its carrying paint. Crispness cost is bounded
> because sub-yield paint does not move at all. The GPU port must revisit
> BFECC/MacCormack for A2 as specified here. (Recorded per the roadmap's
> departure-documentation rule; also noted in ARCHITECTURE.md.)
- **The brush is the mixer.** Real mixing happens in two places: (1) the brush **reservoir** accumulates a spectral average of everything it picks up (dirty brush), and redeposits that blend; (2) the velocity field **folds** adjacent colors mechanically. Full, even mixing only after much working — as in reality.

Optical mixing of whatever *is* co-located in a cell is Kubelka-Munk exactly as in watercolor §6 (`K = Σ cₚKₚ`, etc.). Spectral is still what makes the 48-pigment palette free (per-pixel cost is fixed regardless of palette size) and what makes dirty-brush greys read correctly instead of muddy.

---

## 7. Per-frame pipeline

Pass format as watercolor §5: **In → Out → kernel**. Order per frame: **A** brush exchange & drag, **B** rheology flow, **C** transport pigment, **(D** thixotropy, optional**)**, **F** light & composite.

### Phase A — Brush (Brush engine)

The brush is a loaded tool with a footprint (from tip shape × pressure), a reservoir, and a motion vector. Two coupled effects: **bidirectional mass exchange** and **drag**.

**A1. Bidirectional exchange (deposit ⇄ pickup).** At each footprint cell, move paint between reservoir and canvas toward pressure-weighted equilibrium. Both directions carry volume **and** spectrum **and** medium together.
- **In:** `Surface`, `Kpaint*`,`Spaint*`,`PaintProps`, brush reservoir + uniforms `(footprint, pressure P, motion)` → **Out:** same canvas fields; reservoir updated (separate small target)
```glsl
float fp   = footprintWeight(X);                 // 0..1 tip coverage × pressure
// deposit: brush → canvas (loaded brush lays paint down)
float dep  = depositRate * fp * max(0.0, V_b - h);
// pickup: canvas → brush (dragging lifts wet paint)
float pick = pickupRate  * fp * h * dragSpeed;
h += dep - pick;
// spectra follow the mass, blended by amount moved (reservoir K_b, S_b):
for (b in 0..7) {
   Kpaint[b] += dep*K_b[b] - pick*Kpaint[b];
   Spaint[b] += dep*S_b[b] - pick*Spaint[b];
}
// reservoir accumulates picked-up paint (this is the dirty brush):
//   V_b += Σpick;  K_b ← volume-weighted blend of K_b and picked Kpaint;  likewise m_b
```
Reservoir spectra are updated as a **volume-weighted running average** (extensive sums / total, exactly the watercolor `Props` trick). A brush loaded with one color that drags through another becomes, correctly, a mix.

**A2. Brush drag (advection under footprint).** The brush imposes velocity `u_brush` (its motion × coupling) on the paint it touches — this smears and folds, the primary mixer.
- **In:** `Surface`,`Kpaint*`,`Spaint*`,`PaintProps`, `u_brush` → **Out:** same, advected
```glsl
vec2 velB = u_brush * coupling * footprintWeight(X);
vec2 back = X - dt * velB * texel;
h        = bilinear(h, back);
// pigment via BFECC to keep the smear crisp (see §6):
Kpaint'  = bfecc(Kpaint, velB, dt);   Spaint' = bfecc(Spaint, velB, dt);
PaintProps' = bfecc(PaintProps, velB, dt);
```
`coupling` < 1 lets the brush partly slide over paint rather than fully carrying it — the difference between a grabbing bristle drag and a light glide.

### Phase B — Rheology (Rheology engine)

**B1. Compute yield-gated flux** on faces (§5). Zero flux where sub-yield — this is where relief is preserved.
- **In:** `Surface`, `Canvas`, `Struct` → **Out:** `Flux`
```glsl
float tauY = tauY0 * mix(1.0, structAt(X), thixo)      // structure stiffens yield (§8)
           * (1.0 - medium*mediumThinning);            // medium lowers yield
vec2 gradH = faceGrad(H);                               // H = Canvas.tooth + h
float tb   = rho * g * h * length(gradH);              // base shear stress
if (tb <= tauY) { q = vec2(0.0); }
else {
   float excess = pow(1.0 - tauY/tb, 1.0 + 1.0/n);
   float mob    = pow(rho*g/K, 1.0/n) * pow(h, 2.0+1.0/n) / (2.0+1.0/n);
   q = -mob * excess * gradH;
}
```

**B2. Apply flux (volume-conserving height update)** and carry pigment on the same flux.
- **In:** `Surface`, `Flux`, `Kpaint*`,`Spaint*`,`PaintProps` → **Out:** same, updated
```glsl
h -= dt * divergence(Flux);                            // ∂h/∂t = −∇·q, exact on staggered grid
// pigment rides the flux (upwind, mass-weighted) — NOT diffused:
advectByFlux(Kpaint, Spaint, PaintProps, Flux, dt);    // donor-cell / upwind for conservation
h = max(h, 0.0);
```
Use **upwind / donor-cell** transport for the flux-driven pigment step so mass is conserved and no color appears where no paint went.

### Phase C — (folded into B2)

Pigment transport is done with the flux in B2 and with the brush in A2; there is no separate diffusion/settling phase. Oil has neither. This is deliberate — see §6.

### Phase D — Thixotropy (optional; Rheology engine)

**D1. Structure recovery.** Paint stiffens when left alone, thins when worked. Track `Struct ∈ [0,1]`.
- **In:** `Struct`, recent shear (from `|q|` or `|u_brush|`) → **Out:** `Struct'`
```glsl
float shear = length(q) + brushShear(X);
struct += dt * ( recover*(1.0 - struct) - breakdown*shear*struct );
struct = clamp(struct, 0.0, 1.0);
```
Feeds `τ_y` in B1. Skip for v1 if you want; peaks still hold from static `τ_y`. Adds the "sets up after a few seconds" quality.

### Phase F — Lighting & composite (Lighting engine)

**F1. Albedo (Kubelka-Munk → RGB).** Identical to watercolor F1 spectral collapse, but there is a single paint layer (no deposited+suspended sum) and the result is *albedo* to be lit, not the final pixel.
```glsl
vec3 XYZ = 0.0;
for (b in 0..7) {
   float ks = Kpaint[b] / (Spaint[b] + 1e-4);
   float R  = 1.0 + ks - sqrt(ks*ks + 2.0*ks);
   XYZ += R * cieXYZ[b];
}
vec3 albedo = max(XYZ2SRGB * XYZ, 0.0);                // still linear-light here
```
For a **glaze** (thin transparent paint over dried substrate), use the finite-thickness KM layer-over-substrate reflectance with `h` as thickness and the substrate color as background — this is the watercolor §12 "finite-thickness" upgrade, and it's mandatory here for glazing to read.

**F2. Height-field lighting (the sculptural pass).** Normals from the paint relief; diffuse + a glossy oil specular; raking light exaggerates impasto.
- **In:** `Surface`, albedo, light uniforms `(L dir, view V)`, `Canvas` → **Out:** `Color`
```glsl
float hL=Hx(-1,0), hR=Hx(1,0), hD=Hx(0,-1), hU=Hx(0,1);   // H = tooth + h
vec3 N = normalize(vec3(-(hR-hL)/(2.0*dx), -(hU-hD)/(2.0*dx), 1.0));
float diff = max(0.0, dot(N, L));
vec3  Hh   = normalize(L + V);
float spec = pow(max(0.0, dot(N, Hh)), gloss) * oilSheen;  // oil binder is glossy
vec3 col = albedo * (ambient + diff) + spec;
// drybrush: where paint is thin, canvas tooth shows through (broken color)
float toothMask = smoothstep(toothLo, toothHi, Canvas.tooth - h);
col = mix(col, canvasColor, toothMask * step(h, dryThin));
col = linearToSRGB(col);                                   // gamma last
```
`gloss`/`oilSheen` separate a matte, heavily-mediumed passage from a fresh glossy stroke. Raking `L` (low angle) is what makes impasto pop; expose light direction to the user.

The CPU composite remains straight alpha internally. Immediately before its
disposable RGBA8 buffer is decoded with Flutter `PixelFormat.rgba8888`, use the
same shared premultiplication boundary required by the watercolor spec F1.
Do not premultiply the persistent spectral/height fields or apply the conversion
twice in a future shader path.

---

## 8. Numerical stability & precision

- **Explicit flux is CFL-limited** (unlike watercolor's unconditional semi-Lagrangian). Stability roughly `dt ≤ Δx² / (2·max Mob)`. Thick, thin (low-`K`) paint has high `Mob` → the limit bites. **Substep Phase B** (2–8 substeps/frame) rather than shrinking the frame `dt`; the brush passes don't need substepping.
- **Yield gate must be a hard branch**, not a smooth ramp, or relief slowly creeps (everything below yield leaks). A crisp `if (tb ≤ tauY)` is correct and cheap.
- **Volume conservation:** use staggered faces + donor-cell transport. Track total `Σh` in debug; it must be flat except at brush deposit/pickup. Drift means a non-conservative advection slipped in.
- **`h ≥ 0` clamp** every height write. Negative height → NaN normals → black holes under lighting.
- **Height float32** (physics + normals). Pigment spectra float32 (accumulation, as watercolor). `Flux` half-float is fine.
- **No pigment diffusion, ever** (§6). If instability tempts you toward it, add advection substeps or switch to BFECC instead.

---

## 9. Regime cookbook (the named styles)

The same engine produces every oil style purely by parameter/brush state. Presets:

| Regime | `τ_y` | `K` (consistency) | `h` deposited | medium `m` | opacity (`S`) | brush | Look |
|---|---|---|---|---|---|---|---|
| **Impasto / knife** | high | high | high | ~0 | high | stiff, high pressure, high deposit | Standing ridges, sharp relief, strong specular |
| **Wet-on-wet (Bob Ross)** | low | low | thin over a base medium layer | high (base "liquid white") | med | soft, gliding, low coupling | Soft blends at the brush interface; colors fold, don't diffuse |
| **Glazing** | very low | low | very thin | high | very low (transparent) | soft, light | Optical depth via finite-thickness KM over dried layer |
| **Scumbling / drybrush** | high | high | low | low | high | stiff, low load, fast | Broken color; canvas tooth shows (F2 `toothMask`) |
| **Blending / sfumato** | low–med | low | med | med | med | soft, repeated light passes | Gradual mechanical mix over many strokes |

Bob Ross specifically = a **base medium layer** (low-`τ_y`, high-`m`, thin white) laid first, so subsequent strokes ride on a slick, low-yield film that lets the brush pick up and fold the underlayer — blending at the interface without any diffusion. That is why his blends are soft but his colors still never "bloom": it's all mechanical.

---

## 10. Resolution, tiling, undo

Reuse watercolor §7 with these deltas:
- **Height needs resolution** for crisp impasto edges under raking light. Run the **lighting/normal read at canvas resolution** even if the rheology solve is coarser: solve `h` at ≤512², but upsample `h` (bicubic) before computing normals in F2, or keep a higher-res `h` and a coarser flux grid. Sharp knife-edges are a normal-map phenomenon; don't let them get bilinear-blurred.
- **Tiling by activity:** step rheology only on tiles the brush touched recently *plus* any tile with `max τ_base > τ_y` (still slumping). A finished thick passage keeps slumping微ly for a while, then falls below yield everywhere and deactivates — same dirty-tile machinery as watercolor.
- **Undo/checkpoint** snapshots the *whole wet state* — `Surface` (h,m), the four paint spectra, `PaintProps` — because oil has no "dry vs wet" separation in-session; it's all live. That's ~7 float textures (~28 MB at 512²). Snapshot at stroke boundaries; incremental by dirty tile.

---

## 11. Parameter reference

| Symbol | Name | Range | Notes |
|---|---|---|---|
| `dt`, substeps | timestep / B-substeps | — / 2–8 | CFL-limited flux (§8) |
| `tauY0` | base yield stress | — | ↑ = stiffer, holds sharper relief |
| `K` | consistency | — | ↑ = more resistant (thicker body) |
| `n` | flow index | 0.3–0.9 | <1 shear-thinning |
| `rho·g` | slump drive | — | gravity leveling strength |
| `depositRate` | brush → canvas | 0.1–0.6 | paint laydown |
| `pickupRate` | canvas → brush | 0.05–0.4 | dirty-brush / drag lift |
| `coupling` | brush grab | 0.2–1.0 | 1 = full carry, low = glide |
| `mediumThinning` | medium → yield/consistency drop | 0–1 | how much `m` fluidizes |
| `recover`,`breakdown` | thixotropy | — | structure re-set / shear-thin (§8, optional) |
| `gloss`,`oilSheen` | specular | — | fresh glossy vs mediumed matte |
| `toothLo/Hi`,`dryThin` | drybrush gating | — | canvas show-through (F2) |
| `BANDS`,`PALETTE_N` | spectral / palette | 8 / 48 | reused from watercolor |

---

## 12. Flutter / iPad path

Identical decision tree to watercolor §10 (Option A `ui.FragmentShader` to prototype → Option C native Metal external texture to ship; `flutter_gpu` as the middle path). Two oil-specific notes:
- **Substepped explicit rheology + a lighting pass** raises pass count over watercolor. The pressure-Jacobi loop is gone (no projection), which roughly *offsets* the added rheology substeps, so the per-frame budget is comparable. Net: still 60 fps on M-series iPad at 512².
- The **lighting pass wants canvas-resolution normals** (§10), so the final F2 pass runs at display res while the sim runs coarse — plan the texture sizes accordingly.

---

## 13. Validation tests (definition of done)

Each isolates one mechanism:

1. **Impasto holds** — lay a thick stiff-brush ridge; it must keep its relief indefinitely (sub-yield), and raking light must show it. (§5 yield gate, F2.)
2. **Slump** — an *excessively* thick blob on a tilted canvas creeps downhill slowly, then stops when thin enough to fall below yield. (§5 `Mob`, excess-stress.)
3. **Marble, not bloom** — drag one color through another: streaks that partially fold together. Then let them sit — **no further mixing.** If they keep blending at rest, a diffusion term leaked in (§6).
4. **Dirty brush** — load white, drag through red, then paint on clean canvas: stroke starts pink, not white. (Reservoir blend, A1.)
5. **Wet-on-wet blend** — thin low-yield base layer, then a stroke across it blends softly at the interface but colors don't diffuse outward. (§9 Bob Ross preset.)
6. **Drybrush broken color** — thin paint on high-tooth canvas leaves the valleys bare. (F2 `toothMask`.)
7. **Volume conservation** — `Σh` constant except under brush deposit/pickup. (§8.)

---

## 14. Known simplifications & upgrades

- **Height-field vs full 3D / MPM.** This is a shallow (2.5D) model — fast, and right for the vast majority of oil behavior. A Material Point Method paint sim captures overhangs, folding-over, and true 3D knife work, but is far heavier; consider only for an offline "final render" mode.
- **Footprint brush vs bristle-level.** The brush here is a footprint + reservoir. A deformable 3D bristle brush (Baxter / WetBrush) gives per-bristle streaking and splay; a large upgrade to the Brush engine, orthogonal to the rheology.
- **Single wet layer vs stratified.** One layer can't represent a fully wet glaze sitting on genuinely dry paint with distinct rheology. A two-layer (wet-over-cured) model adds real glazing/overpainting depth — the natural v2.
- **Drying.** In-session oil is wet; over days it skins and cures. If long-project persistence matters, add a slow `τ_y`-rising "cure" field that eventually locks a layer (converting it to the substrate for future glazes).
- **Pigment optics.** Reuses watercolor's per-RGB-band (8) spectral KM. Full spectral (16+) helps only the most saturated mixes; rarely worth it.

---

*Interfaces to hold stable during the port: the texture list in §3, the pass order and I/O in §7, and the parameter names in §11. The shared pigment/KM contract with `watercolor-engine-spec.md` (§6 there) must stay identical so both media share one Pigment engine and one palette.*
