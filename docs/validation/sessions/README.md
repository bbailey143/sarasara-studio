# Recorded sessions

Every file here is one saved mark from the diagnostic studio: what was set,
what was measured, what the artist saw, and a picture of the result.

These are written by `npm run lab` when **Save this mark** is pressed. Nothing
else writes them, and no automated run may add one.

## Reading one

| Field | Means |
| --- | --- |
| `material` / `substrate` | exact profile and paper identity, with versions |
| `regime` | `flowing`, `granular`, or `body` — chosen by properties, not by name |
| `settings` | everything the artist had set, including whether pressure came from a stylus |
| `measurements` | the full ledger at the moment of saving, conservation error included |
| `review` | the rating, the decision, the behaviour id, and the artist's own words |
| `board` | the status of every behaviour for that material at that moment |
| `image` | a PNG of the mark, inline |

`review.notes` is the part no measurement replaces. When these disagree with
the numbers, the notes win and the model is what needs looking at.

## What a decision means

- **Accept for this scope** — this precisely described behaviour is good
  enough. Never read as "the medium works".
- **Recalibrate** — the relationship is right, the values are wrong.
- **Revise the model** — the relationship itself is wrong.

A session records a judgement about a stated scope. Nothing here graduates a
material from experimental to canonical on its own.
