# Watercolor behavioral prototype tests

These tests belong in a small diagnostic laboratory, not in the product interface. Each test should expose fields, totals, and a simple visualization of the event.

| ID | Test | Observable check | Result |
| --- | --- | --- | --- |
| WC-P-01 | Damp-paper spread | A marked carrier/pigment packet reaches damp cells farther or sooner than matched dry cells. | `partial_not_isolated` — paper dampness is stored separately and the accepted v0.6 review used damp paper, but no matched dry-versus-damp spread assertion has been recorded. |
| WC-P-02 | Carrier/pigment separation | Carrier mass and pigment load remain separately conserved while transport and evaporation occur. | `automated_relationship_verified` — carrier decreases through uptake/evaporation while mobile and deposited pigment remain separately measured and total pigment error stays below 1% in the automated check. Artist acceptance is limited to the v0.6 shared interaction. |
| WC-P-03 | Settling contrast | Two particle populations with different density/size produce different settling behavior under the same carrier. | `not_run` — the diagnostic profile has only one stand-in particle population. |
| WC-P-04 | Drying edge | A receding mobility boundary changes deposited load or optical density near the edge. | `partial_not_isolated` — drying converts mobile pigment to deposited pigment and conserves total pigment, but no edge band or local optical-density comparison is measured. |
| WC-P-05 | Wet crossing | Blue then yellow on an active shared wet field produces a co-located spectral mixture. | `not_run` — the lab has one display color and no spectral two-pigment mixture scene. |
| WC-P-06 | Clean-water bloom | A water impulse moves active pigment outward while conserving total pigment and retaining a center share. | `partial_not_isolated` — clean water adds no pigment, remobilizes deposited pigment, and preserves total pigment automatically; outward bloom shape and retained-center share are not measured or artist-accepted. |
| WC-P-07 | Paper contrast | The same contact on smooth and porous substrates produces different uptake and spread. | `not_run` — dampness can vary, but only one stand-in paper profile exists. |
| WC-P-08 | Failure range | Puddling, overworking, and dryback can emerge by changing inputs, without a watercolor failure toggle. | `not_run` — no matched failure-envelope scene or artist record exists. |

Physics checks must report conservation and parameter values. They do not replace the artist review sheet.

## Artist-status boundary

Review `WC-LAB-1787100187504` is `artist_accepted_limited_scope`: the artist rated the v0.6 shared substrate → carrier → pigment → applicator interaction **Good** and accepted it for the initial diagnostic scope. It does not change WC-P-03, WC-P-05, WC-P-07, or WC-P-08 to passed, and it does not complete the overall watercolor gate.
