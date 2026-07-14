# Brush Physics Engine — Implementation Spec

**For:** the Brush engine implementation sprint (Flutter · iPad · Metal)
**Status:** implementation-ready backbone. This document defines the brush state, contact mathematics, stroke sampling, reservoir bookkeeping, and the stable handoff to every medium.
**Companions:** `watercolor-engine-spec.md` and `oil-engine-spec.md`. Their field names, spectral pigment representation, pass order, and engine ownership remain authoritative.
**Reference models:** physically based deformable-brush work by Baxter et al. and WetBrush-style bristle/contact modeling, reduced to a real-time 2.5D model suitable for an iPad painting surface.

---

## 1. The rule that keeps the whole app coherent

A brush is a **tool**, not a paint effect.

A `Sable Round #5` has one physical definition: its hair bundle, belly, point, spring, splay, fluid holding capacity, and contact behavior. That same brush can carry watercolor, oil, ink, gouache, or a future medium. Changing the loaded medium must not silently replace the brush or switch to a baked “watercolor stamp.”

The division is strict:

| Question | Owner |
|---|---|
| Where is the brush, how fast is it moving, and how is it tilted? | **Brush** |
| What portion of the tip touches the surface? | **Brush** |
| How do hairs bend, splay, lag, split, and recover? | **Brush** |
| How much carrying space is available inside the hairs? | **Brush** |
| What paint/pigment/carrier is currently held by the brush? | **Brush reservoir**, using shared pigment data |
| Given this contact, how much material may transfer? | **Brush proposes contact opportunity; active medium resolves transfer** |
| Does transferred water flow, bloom, evaporate, or granulate? | **Watercolor / Fluid / Pigment / Texture engines** |
| Does transferred oil hold a ridge, slump, marble, or shine? | **Oil Rheology / Pigment / Lighting engines** |
| What does the paper or canvas tooth do? | **Texture engine**; Brush may sample it, never own it |

**Forbidden shortcut:** no brush preset may contain a watercolor edge, paper grain, oil ridge, bloom, pigment granulation, or other medium result baked into its footprint. A footprint describes hair contact only.

---

## 2. Architecture and stable boundary

The Brush engine consumes pointer samples and a physical brush definition. It emits a time-ordered stream of **contact samples**. The active medium consumes those samples and decides how its material responds.

```text
stylus / mouse
      ↓
Input normalization
      ↓
Brush dynamics: pose → bend → splay → footprint → bristle contact
      ↓
BrushContactSample (medium-agnostic)
      ↓
Medium adapter
  ├─ watercolor: splat water + suspended pigment + impulse
  ├─ oil: bidirectional exchange + imposed drag velocity
  └─ future medium: its own transfer law
      ↓
medium simulation → pigment optics → visible canvas
```

The brush does **not** write directly to `Water`, `Surface`, `Velocity`, `Ksus*`, or `Kpaint*`. The watercolor and oil Phase A passes remain exactly as specified in their companion documents; their medium adapters translate the contact stream into those writes.

This clarifies the wording in the companion specs:

- Watercolor Phase A “Brush splat” is the **watercolor adapter consuming a brush contact**, not watercolor physics inside the Brush engine.
- Oil Phase A pickup/deposit is a **joint operation**: the Brush engine owns footprint, reservoir capacity, bristle drag, and contact opportunity; the Oil adapter owns `depositRate`, `pickupRate`, paint-height equilibrium, and writes to oil fields.

---

## 3. Coordinate system, units, and symbols

Use physical units inside the Brush engine. Convert to canvas/grid units only in the medium adapter.

| Symbol | Meaning | Unit / range |
|---|---|---|
| `x = (x,y)` | tip center on canvas | millimetres |
| `v = dx/dt` | filtered tip velocity | mm/s |
| `a = dv/dt` | filtered acceleration | mm/s² |
| `P` | normalized normal pressure | 0..1 |
| `T = (t_x,t_y)` | stylus tilt vector in canvas plane | magnitude 0..1 |
| `φ` | barrel rotation / azimuth | radians |
| `Δt` | time since previous resampled contact | seconds |
| `d` | travel since previous contact | mm |
| `R₀` | unloaded bundle radius | mm |
| `L` | exposed bristle length | mm |
| `q` | normalized compression / penetration | 0..1 |
| `s` | splay amount | 0..1 |
| `b` | bend vector at the ferrule-to-tip model | mm |
| `cᵢ` | contact weight of bristle cluster `i` | 0..1 |

Canvas coordinates must be independent of zoom. A #5 round must cover the same physical painting width when the user zooms in; zoom only changes screen-to-canvas conversion.

For a display sample `p_screen`, canvas position is:

```text
x_canvas = View⁻¹ · p_screen
x_mm     = x_canvas · mmPerCanvasUnit
```

All pressure and tilt values must be normalized before reaching brush mathematics. Raw tablet ranges are never allowed in size, splay, or reservoir equations.

---

## 4. Physical brush definition

A saved brush preset describes construction, not a rendered mark.

```text
BrushDefinition
  id, name, family
  geometry:
    nominalSize, R0, L, ferruleWidth, aspect, tipProfile
  fibers:
    clusterCount, density, diameter, lengthVariation
    stiffness, damping, spring, lateralFriction
    cohesion, roughness, absorbency
  deformation:
    maxCompression, maxSplay, splitThreshold, recoveryRate
  reservoir:
    totalCapacity, tipCapacityFraction, bellyCapacityFraction
    releaseConductance, pickupConductance
  contact:
    normalFriction, tangentFriction, textureFollowing
  variation:
    seed, clusterPositionJitter, stiffnessJitter, lengthJitter
```

### 4.1 Tip families

The family chooses the unloaded cross-section and bristle layout, not a stamp image.

| Family | Unloaded contact model | Key behavior |
|---|---|---|
| Round | radial bundle tapering to a point | toe → belly growth, directional point |
| Flat | rectangular bundle | broad face, narrow edge, corner marks |
| Bright | short flat, higher stiffness | crisp, low-lag scrubbing |
| Filbert | rounded rectangle | soft-edged broad stroke |
| Mop | wide soft radial bundle | large capacity, large lag and splay |
| Rigger / liner | long thin bundle | delayed following, long continuous release |
| Fan | wide sparse wedge | separated clusters and combing |
| Knife | rigid polygon, zero fibers | hard contact geometry; reservoir is surface coating |

`tipProfile(u)` gives the unloaded bristle endpoint radius/width at normalized distance `u ∈ [0,1]` from bundle center. Profiles are analytic curves or small signed-distance fields. They must contain **no pigment or medium appearance**.

### 4.2 Material properties of the tool

Use normalized artist-facing properties backed by physical coefficients:

- `stiffness`: resistance to bend and splay.
- `spring`: speed of returning toward the unloaded shape.
- `damping`: loss of oscillation; prevents a rubbery tip.
- `cohesion`: how strongly wet hairs remain grouped.
- `roughness`: irregular contact and dry broken marks.
- `absorbency`: capacity within/along fibers, distinct from paper absorbency.
- `lateralFriction`: how strongly the surface drags the tip sideways.

These belong to the brush even though a loaded medium may modify them. For example, water can increase hair cohesion while heavy oil increases damping. The adapter supplies modifiers; it does not replace the base brush.

---

## 5. Input normalization and stroke resampling

Brush behavior must depend on physical motion, not the tablet’s event rate.

### 5.1 Pressure calibration

Normalize raw pressure using the device’s reported minimum and maximum, then apply dead-zone removal and an artist curve:

```text
p₀ = clamp((p_raw - p_min) / max(p_max - p_min, ε), 0, 1)
p₁ = clamp((p₀ - p_dead) / max(1 - p_dead, ε), 0, 1)
P  = p₁^γp
```

Default `γp ≈ 1.35` gives finer light-pressure control. The user pressure curve may replace the power curve, but its output is always clamped to `[0,1]`.

Mouse fallback uses a fixed configurable `P_mouse` (default `0.55`). It must pass through the same downstream math.

### 5.2 Position, velocity, and tilt filtering

Use time-aware exponential smoothing so behavior remains stable across 60–240 Hz input:

```text
α(Δt, τ) = 1 - exp(-Δt / τ)
x_f ← lerp(x_f, x_raw, α(Δt, τx))
P_f ← lerp(P_f, P_raw, α(Δt, τp))
T_f ← lerp(T_f, T_raw, α(Δt, τt))
```

Recommended starting points: `τx = 6 ms`, `τp = 10 ms`, `τt = 16 ms`. Prediction may reduce visible latency, but predicted samples never update reservoir state until confirmed.

Velocity uses the filtered positions:

```text
v_raw = (x_f - x_prev) / max(Δt, 1 ms)
v     ← lerp(v, v_raw, α(Δt, τv))
```

### 5.3 Equal-distance resampling

Generate contact samples at spacing `ℓ`, independent of event spacing:

```text
ℓ = clamp(k_spacing · r_contact, ℓ_min, ℓ_max)
N = ceil(|x_n - x_{n-1}| / ℓ)
```

Interpolate position, pressure, tilt, azimuth, and time for the `N` samples. Defaults:

- `k_spacing = 0.18` for continuous paint.
- `ℓ_min = 0.08 mm` prevents runaway sample counts.
- `ℓ_max = 0.75 mm` prevents gaps in very large brushes.

At very low speed, also emit at a maximum dwell interval (default `16.7 ms`) so a pressed brush can compress, load, or exchange material without moving. Dwell must not create infinite material: transfer is multiplied by `Δt` and bounded by reservoir/canvas availability.

---

## 6. Brush dynamics

The shipping model is a deformable bristle **cluster** system, not thousands of literal hairs. `16–64` persistent clusters give the visible structure of a brush while remaining practical. A simpler analytic footprint is the v1 fallback (§14).

### 6.1 Compression from pressure

Pressure controls contact compression, not brush diameter directly:

```text
q_target = q_min + (q_max - q_min) · smoothstep(0, 1, P)^γq
q ← q + (1 - exp(-Δt/τq)) · (q_target - q)
```

Contact size then emerges from brush geometry and splay. This prevents the digital “pressure equals circle radius” look.

### 6.2 Bend and directional lag

Surface drag bends the bundle opposite travel. Treat the tip as a damped spring:

```text
m_b · b̈ + c_b · ḃ + k_b · b = F_drag
F_drag = -μ_t · C · v_rel
```

where `C` is total contact, `μ_t` is tangent friction, and `v_rel` is brush motion relative to the surface material.

Use semi-implicit Euler:

```text
bVel += Δt · (F_drag - c_b·bVel - k_b·b) / m_b
b    += Δt · bVel
|b|  = min(|b|, b_max)
```

When lifted, `C = 0` and the spring returns the brush toward `b = 0`. Long soft hairs use low `k_b`, producing visible lag; brights use high `k_b`.

### 6.3 Splay

Splay is driven by compression and lateral shear, resisted by stiffness and cohesion:

```text
s_target = clamp(
    a_q·q + a_shear·|v_rel|·C
    - a_stiff·stiffness
    - a_coh·cohesionEffective,
    0, maxSplay
)
s ← s + (1 - exp(-Δt/τs)) · (s_target - s)
```

`cohesionEffective` is the base hair cohesion multiplied by a medium-supplied wetting modifier. The brush owns the equation; the active medium supplies only the modifier.

### 6.4 Tilt and contact ellipse

Let `θ` be the stylus angle from surface normal, derived from `|T|`. Tilt shifts contact from point to belly and stretches it along the tilt direction:

```text
r_major = R₀ · (1 + kq·q + ks·s + kt·sin θ)
r_minor = R₀ · (r_tip + kq·q + ks·s)
centerOffset = T_hat · L · sin θ · k_offset
```

For a round, light upright contact keeps `r_tip` small and preserves the point. Pressure and tilt reveal the belly. For a flat, the same transform acts on its rectangular/rounded-rectangle profile.

### 6.5 Cluster state and splitting

Each cluster `i` stores a rest offset `rᵢ`, length multiplier, stiffness multiplier, deflection `δᵢ`, contact `cᵢ`, and reservoir share `Vᵢ`.

```text
δ̈ᵢ + 2ζᵢωᵢ δ̇ᵢ + ωᵢ²δᵢ = Fᵢ / mᵢ
pᵢ = x + A(q,s,T,φ)·rᵢ + b + δᵢ
```

Neighbor cohesion acts as springs between clusters. A visible split begins only when lateral separation stress exceeds the threshold:

```text
splitDriveᵢⱼ = |pᵢ - pⱼ| / max(|rᵢ-rⱼ|, ε)
linkActiveᵢⱼ = splitDriveᵢⱼ < splitThreshold · cohesionEffective
```

Broken links may reform gradually when the brush unloads and clusters approach. Round sables should remain coherent at ordinary pressure; fan and damaged/dry brushes can split earlier.

### 6.6 Paper/canvas texture following

The Brush engine may sample the Texture engine’s static height `τ(x)` beneath each cluster:

```text
cᵢ = smoothstep(z_tipᵢ + contactSoftness, z_tipᵢ, τ(pᵢ))
```

This changes which hairs touch. It does not decide pigment granulation, capillary flow, drybrush opacity, or lighting; those remain medium/texture/composite behaviors.

---

## 7. Footprint mathematics

The brush outputs a coverage/contact field `W(x)`, a normalized bristle-density field `D(x)`, and an imposed bristle velocity `U(x)` over a small local tile.

### 7.1 Cluster footprint

Each cluster contributes an anisotropic kernel:

```text
dᵢ²(x) = (x-pᵢ)ᵀ Σᵢ⁻¹ (x-pᵢ)
wᵢ(x)  = cᵢ · exp(-0.5 dᵢ²) · edgeᵢ(x)
W(x)   = clamp(Σᵢ wᵢ(x), 0, 1)
D(x)   = Σᵢ wᵢ(x) / max(Σᵢ cᵢ, ε)
```

`Σᵢ` comes from cluster width, compression, splay, tilt, and family shape. `edgeᵢ` may add deterministic fiber roughness from the brush seed. It may not sample pigment color or bake a paper texture.

### 7.2 Local velocity and shear

The velocity imposed on material is the weighted velocity of touching clusters:

```text
U(x) = Σᵢ wᵢ(x)·vᵢ / max(Σᵢ wᵢ(x), ε)
Shear(x) = |U(x) - u_surface(x)| · W(x)
```

The medium decides how much of `U` couples into its own transport. Oil uses it for `u_brush`; watercolor converts a smaller portion into its splat `impulse` and then lets the Fluid engine take over.

### 7.3 Contact pressure field

Distribute total normal force across active clusters:

```text
F_n = F_max · P
Π(x) = F_n · Σᵢ wᵢ(x)kᵢ / max(∫Σᵢ wᵢkᵢ dx, ε)
```

The integral of `Π` equals `F_n`. This is important: splaying the brush spreads the same force over more area rather than inventing more pressure.

---

## 8. Reservoir model — the brush carries material without becoming a medium

The reservoir records what is physically in the tool. It uses the same 8-band spectral `K/S` convention and palette data as both companion specs.

### 8.1 State

Use extensive quantities so mixing and transfer conserve material:

```text
BrushReservoir
  Vcarrier                 total liquid/binder volume
  Vpigment                 pigment load
  Ksum[8], Ssum[8]         spectral extensive sums
  granWt, stainWt          shared pigment-property sums
  mediumFractions[]        watercolor/oil/etc. carrier identity, session constrained
  clusterFill[i]           0..capacityᵢ
  tipFill, bellyFill       fast and slow compartments
```

Recover averages only when needed:

```text
K̄[b] = Ksum[b] / max(Vpigment, ε)
S̄[b] = Ssum[b] / max(Vpigment, ε)
γ̄    = granWt / max(Vpigment, ε)
σ̄    = stainWt / max(Vpigment, ε)
```

This is consistent with watercolor `PropsSus/PropsDep` and oil `PaintProps`. Never average already-averaged colors; add and subtract extensive spectral quantities.

### 8.2 Tip-to-belly movement

Material moves between a quick tip compartment and a slower belly compartment:

```text
J_tb = g_tb · (fill_belly - fill_tip)
V_tip   += Δt · J_tb
V_belly -= Δt · J_tb
```

Long absorbent brushes have high belly capacity and moderate conductance, giving a long stroke whose release slowly tapers. A synthetic bright has smaller capacity and faster exhaustion.

### 8.3 Transfer opportunity

For each cluster, the Brush engine proposes bounded conductances:

```text
Goutᵢ = releaseConductance · cᵢ · fillᵢ · Δt
Ginᵢ  = pickupConductance  · cᵢ · (1-fillᵢ) · Δt
```

These are **maximum opportunities**, not final transferred amounts. The active medium adapter applies its own availability and resistance:

```text
outᵢ = min(Goutᵢ · mediumReleaseFactor, reservoirAvailableᵢ)
inᵢ  = min(Ginᵢ  · mediumPickupFactor, canvasAvailableAt(pᵢ))
```

Every accepted transfer returns one exact `TransferReceipt` for the physical
contact. Its material fields are extensive totals, never per-cell densities:

```text
acceptedOutflow, acceptedInflow
pigmentOut, pigmentIn
kOut[8], kIn[8], sOut[8], sIn[8]
granulationOut/In, stainingOut/In
```

The spectral and property totals belong exactly to their corresponding pigment
total. Only receipts update the reservoir. This prevents conservation errors
when a medium rejects part of a proposed transfer and gives the canvas one
authoritative answer for how much material may appear.

### 8.4 Loading, rinsing, and cross-medium safety

- Loading from a pigment well adds carrier, pigment load, `K/S`, and pigment properties to reservoir sums.
- Pickup from the canvas adds exactly the quantities removed by the medium adapter.
- Deposit subtracts exactly the quantities accepted by the medium adapter.
- Rinsing is an explicit reservoir exchange; it is not “set color to clean.”
- The dirty/rinse UI follows a real accepted `pigmentIn` receipt, not a stroke
  color label or a nearby-pigment guess. Watercolor and oil use the same rule.
- Checkpoint replay restores stored reservoir snapshots and offers zero pickup;
  it must not remove the same canvas material twice.
- A single active stroke uses one medium family. Switching from oil to watercolor requires an explicit clean/replace action or a product-level mixed-media rule. The Brush engine must never silently reinterpret oil binder as water.

---

## 9. Stable `BrushContactSample` contract

One contact sample is a compact header plus either an analytic footprint description or a small brush-local texture tile.

```text
BrushContactSample
  sequenceId, strokeId, time, dt
  centerMm, previousCenterMm
  velocityMmPerSec, accelerationMmPerSec2
  pressure, tilt, azimuth, barrelRotation
  compression, splay, bend
  boundsMm
  footprintW        contact coverage 0..1
  densityD          relative fiber density 0..1
  pressurePi        force-preserving pressure field
  bristleVelocityU  local imposed velocity
  shear             local contact shear
  clusterContacts[] optional sparse contact list; each entry preserves
                    clusterId, center, previousCenter, physical radius,
                    coverage, force share, and local velocity
  transferOffer     bounded out/in opportunity by cluster or tile
  reservoirSnapshot read-only pre-transfer averages
```

Required invariants:

1. `pressure`, `footprintW`, `densityD`, and all fill values are finite and clamped to `[0,1]`.
2. `dt > 0`; distance and time units are explicit.
3. `∫ pressurePi dx = F_max·P` within numerical tolerance.
4. A contact contains no medium-specific field names and no final color.
5. Reservoir mutation occurs only after an accepted `TransferReceipt`.
6. Random variation is deterministic from `(brushSeed, strokeId, sequenceId, clusterId)`; frame rate cannot change the mark.
7. A medium adapter may scale units, but it must preserve each sparse cluster's
   physical radius. Replacing every cluster radius with the whole-brush radius
   is a contract violation and creates both false stamps and unbounded work.
8. All sibling clusters in one `BrushContactSample` are simultaneous. A medium
   may batch their geometry, but it may not mutate persistent material after
   each sibling in a way that lets cluster order change lift, drying, or color.

---

## 10. Medium adapters

### 10.1 Watercolor adapter

Maps the contact contract to `watercolor-engine-spec.md` Phase A1 without changing that spec’s field names:

```text
receiptWater = accepted carrier-outflow total
receiptLoad  = accepted pigment-outflow total
forceShareᵢ  = P·coverageᵢ / Σⱼcoverageⱼ
shareᵢ       = coverageᵢ·forceShareᵢ / Σⱼ(coverageⱼ·forceShareⱼ)
contactP     = clamp(ΣᵢforceShareᵢ, 0, 1)
impulse(x)   = k_waterDrag · bristleVelocityU(x) · footprintW(x)
```

`contactP` is the bounded pressure supplied to watercolor push and wet-union
rules. Each sibling carries a force share, not another copy of the whole stylus
pressure; the shares must sum to `P` within tolerance. Duplicating `P` on every
sibling invents force, while averaging valid shares loses force. Bristle count
must not change the artist's normalized pressure.

For each cluster, preserve its physical radius and normalize its surviving
discrete kernel over the clipped canvas footprint. Pigment and carrier may use
different shapes (for example, a slightly wider carrier halo), but each shape
is normalized independently. Distribute the cluster share of each accepted
total through the corresponding normalized kernel. Therefore radius and edge
clipping change placement, never accepted quantity.

Accumulate every sibling cluster into temporary contact buffers, then mutate
the watercolor fields once from one pre-contact state. The batch writes:

- carrier to `Water.h`;
- pigment spectral sums to `Ksus*`, `Ssus*`, and `PropsSus`;
- the bounded impulse to `Velocity`.

The adapter does **not** create blooms, rims, granulation, staining, or spreading. Those remain emergent from watercolor Phases B–E. Pickup/lift into the brush may occur only from material the Pigment/Fluid state reports as available; staining resistance remains governed by watercolor `σ` and E3.

Watercolor carrier and pigment are not required to share one pressure curve.
The adapter resolves the brush's bounded opportunity using the binding
watercolor composition rule: light contact is pigment-rich/water-poor and
gently fluid-coupled; firm contact expresses proportionally more carrier and
stronger bristle-to-fluid motion. The accepted carrier, pigment, spectra, and
property sums must still be returned as one exact conservation receipt. These
are watercolor meanings owned by the adapter; the Brush engine must not encode
them into a Sable, Flat, Mop, or other brush definition.

That accepted receipt is also the live canvas authority: zero accepted carrier
and pigment writes zero material. A documented fixed reservoir-unit →
simulation-unit conversion is permitted, but it must be independent of UI
strength, pressure, footprint/radius, clipped area, event count, callback rate,
and dwell-stamp count. Pressure and elapsed contact time were already resolved
while accepting the receipt; applying either again to receipt material is a
contract violation. A material-empty brush contact may still supply its bounded
geometry/velocity so the medium can mechanically push material already on the
canvas. The current watercolor conversion constants and normalization equations
are binding in `watercolor-engine-spec.md` A1.

### 10.2 Oil adapter

Maps the same contact to `oil-engine-spec.md` Phase A:

```text
fp(x)   = footprintW(x)
velB(x) = bristleVelocityU(x) · coupling · fp(x)
dep(x)  = min(transferOffer.out, depositRate · fp · max(0, V_b-h))
pick(x) = min(transferOffer.in,  pickupRate  · fp · h · dragSpeed)
```

It moves `Surface.h/m`, `Kpaint*`, `Spaint*`, and `PaintProps` using exact accepted quantities, then returns a receipt. Oil `depositRate`, `pickupRate`, `coupling`, height availability, yield stress, and non-diffusive transport remain oil properties.

The brush supplies the drag motion; it does not decide whether a ridge holds. That is the Rheology engine’s yield gate.

### 10.3 Future-medium rule

A new medium may consume existing contact fields and define new transfer receipts. It may not require a duplicate “version” of each brush. If a new medium truly requires a new physical brush property, add that property to `BrushDefinition` with a sensible default for all existing brushes.

---

## 11. GPU/CPU split and pass order

Recommended split:

**CPU once per input sample**

- tablet normalization and resampling;
- global pose, velocity, pressure, tilt;
- low-count cluster spring integration;
- deterministic random state;
- reservoir header and stroke history.

**GPU once per emitted contact**

1. Rasterize all sibling clusters into temporary brush-local `W`, `D`, `Π`, and `U` contact data (prefer MRT), preserving each cluster radius.
2. Resolve the active adapter's bounded offer into one exact accepted receipt; reduce its extensive totals to a small receipt buffer.
3. Normalize each medium footprint over its clipped contact bounds, distribute the receipt totals, and mutate persistent canvas fields once for the whole physical contact.
4. Apply that same receipt to CPU/small-GPU reservoir state in strict sequence order.
5. Continue the active medium pipeline exactly as its spec requires.

Contact tiles should be sized to the footprint bounds plus a 2–4 texel halo, not full-canvas. Use float16 for `W`, `D`, and `U`; use float32 for reservoir spectral sums and accumulated transfer receipts.

Do not let multiple in-flight contacts update the same reservoir out of order. Canvas writes may batch, but reservoir receipts are sequential because contact `n+1` depends on what contact `n` deposited or picked up.

---

## 12. Numerical safety and conservation

- Clamp normalized input at entry and again before contact evaluation.
- Cap `Δt` used by spring integration (recommend `≤ 1/60 s`) and substep after an input pause; never take one giant spring step.
- Use semi-implicit Euler for bend/cluster springs. If stiffness requires more than four substeps per frame, use an analytic damped-spring update.
- Clamp footprint covariance eigenvalues away from zero before inversion.
- Clamp all reservoir extensive quantities `≥ 0` after a receipt; debug builds should assert rather than hide large negatives.
- For every transfer, test conservation:

```text
brushBefore + canvasBefore = brushAfter + canvasAfter
```

  independently for carrier volume, pigment load, every `K/S` band, `granWt`, and `stainWt`, within float tolerance.
- Dwell transfer uses real `Δt`; event duplication must not multiply paint.
- Predicted stylus points may render a temporary preview footprint, but cannot permanently alter canvas physics or reservoir state until confirmed.

---

## 13. Parameter reference

| Symbol / field | Meaning | Starting range |
|---|---|---|
| `R0` | unloaded bundle radius | physical brush size |
| `L` | exposed hair length | family-specific |
| `clusterCount` | simulated bristle groups | 16–64 |
| `stiffness` | bend/splay resistance | 0..1 authoring scale |
| `spring` | shape recovery | 0..1 authoring scale |
| `damping` | motion damping | 0..1 authoring scale |
| `cohesion` | cluster grouping | 0..1 |
| `roughness` | deterministic contact irregularity | 0..1 |
| `absorbency` | fiber holding tendency | 0..1 |
| `maxSplay` | maximum lateral expansion | 0..1 |
| `splitThreshold` | cluster-link break threshold | 0.7–1.5 normalized strain |
| `totalCapacity` | reservoir capacity | derived from bundle volume × absorbency |
| `releaseConductance` | maximum outward transfer opportunity | 0..1/s |
| `pickupConductance` | maximum inward transfer opportunity | 0..1/s |
| `k_spacing` | sample spacing / contact radius | 0.12–0.25 |
| `τx,τp,τt` | input smoothing time constants | 4–20 ms |
| `P_mouse` | mouse fallback pressure | ~0.55 |

The UI may use friendly terms and pictures, but saved presets should retain these stable physical values. Medium-specific controls such as watercolor water load or oil thinner amount belong to the loaded material/reservoir setup, not to the immutable brush construction.

---

## 14. Implementation ladder

Build fidelity in layers without changing the contact contract.

### Level 1 — analytic deformable footprint

- One family signed-distance shape.
- Compression, tilt ellipse, bend lag, scalar splay.
- One tip/belly reservoir.
- Emits the full contract, with analytic `W/D/Π/U`.

This is enough to connect both companion medium engines and prove separation.

### Level 2 — persistent bristle clusters (recommended shipping baseline)

- `16–64` clusters with deterministic variation.
- Per-cluster contact, spring lag, capacity, local velocity.
- Cohesion and controlled splitting.
- Texture-height following.

This produces point/belly transitions, combing, broken edges, and dirty-brush streaks without individual-hair cost.

### Level 3 — specialist brushes

- Adaptive cluster refinement near contact edges.
- Hysteresis for splits/rejoining.
- Ferrule collision and more exact 3D tilt.
- Knife/comb/sponge contact solvers sharing the same output contract.

Do not delay medium integration for Level 3.

---

## 15. Validation tests — definition of done

### A. Brush-only tests on a neutral diagnostic surface

1. **Size is physical** — a #5 round has the same canvas width at every zoom level.
2. **Event-rate independence** — replay one recorded gesture at 60, 120, and 240 Hz; footprint and reservoir totals agree within tolerance.
3. **Pressure safety** — raw pressure outside the device range never creates an oversized blob or NaN.
4. **Point-to-belly** — a sable round makes a fine upright toe, expands smoothly under pressure, and returns without a sudden circular pop.
5. **Directional lag** — a long rigger trails behind a fast curve and catches up on slowing; a bright shows much less lag.
6. **Tilt** — tilting a round reveals its belly along the tilt axis; rotating a flat changes face/edge contact.
7. **Splay without explosion** — increasing pressure spreads contact while conserving total normal force.
8. **Controlled split** — a normal wet sable stays coherent; a fan or deliberately dry/damaged brush separates into stable clusters.
9. **Determinism** — identical recorded input plus seed produces byte-equivalent contact samples.

### B. Reservoir and conservation tests

10. **Long stroke depletion** — a loaded mop releases strongly, then tapers as tip and belly empty; it cannot release more than it held.
11. **Dirty brush** — pickup changes later deposits by exact spectral mass balance.
12. **Dwell bound** — holding still may exchange material but never exceeds available brush/canvas material.
13. **Round-trip conservation** — deposit then pickup conserves carrier, load, all 8 `K/S` bands, and weighted pigment properties within tolerance.

### C. Cross-medium identity tests

14. **Same brush, different medium** — use the exact same saved `Sable Round #5` definition and gesture with watercolor and oil. Contact geometry must match; the resulting material behavior must differ.
15. **Watercolor is emergent** — no bloom or dark rim exists in the contact tile; it appears only after watercolor simulation phases.
16. **Oil is emergent** — no ridge lighting or yield decision exists in the contact tile; it appears only through oil rheology and lighting.
17. **No hidden stamp** — inspect every brush asset/preset: none may contain a prepainted watercolor/oil mark used for deposition.

---

## 16. Artist-facing acceptance scenes

Automated tests protect the mathematics; these scenes protect the feel.

- **Sable Round #5 sheet:** hairline, slow pressure ramp, fast pressure ramp, C-curve, spiral, side-loaded belly, lift to point.
- **One brush / two media:** the same recorded stroke lays a flowing watercolor wash, then a mechanically ridged oil stroke. The silhouette should clearly come from one tool while the material behavior is unmistakably different.
- **Loaded-to-dry stroke:** begin fully loaded and paint until exhausted. Watercolor should lose carrier/pigment according to its adapter; oil should show decreasing body and increasing broken contact.
- **Dirty-brush passage:** pick up a second color mid-stroke and continue onto clean surface. Transition should be gradual through the reservoir, never an instant color switch.
- **Texture pass:** repeat on smooth hot-press paper and coarse canvas. Hair contact may change with height, while granulation/drybrush/lighting remains owned by the appropriate companion engine.

These require a human visual pass on the target iPad and stylus. Passing equations alone is not final brush approval.

---

## 17. Known simplifications and upgrades

- **Cluster brush vs literal hairs.** Clusters preserve the dominant visible mechanics at a fraction of the cost. Individual hairs are a later specialist/offline mode.
- **2.5D contact.** The model captures tilt, bend, and surface height but not full bristle tangling or paint films stretched between hairs.
- **One reservoir mixture.** Tip/belly compartments capture depletion and dirty-brush behavior. Per-cluster spectra are an upgrade for extreme multicolor loading.
- **No baked mark textures.** Small textures are allowed for bristle density/shape variation only. They must be grayscale physical structure, deterministic, and independent of medium/pigment appearance.
- **Device calibration.** Pressure curves vary by stylus. Keep device calibration outside saved brush definitions so a shared brush preset remains the same brush on every device.

---

*Interfaces to hold stable during implementation: `BrushDefinition` construction properties (§4), normalized physical units (§3–5), `BrushContactSample` (§9), accepted-transfer receipts (§8), and the medium-adapter ownership rules (§10). The shared 8-band pigment `K/S` representation must remain identical to both companion specs. A brush describes the tool; the active medium describes what the tool moves.*
