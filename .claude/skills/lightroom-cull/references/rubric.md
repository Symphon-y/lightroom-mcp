# Scoring rubric

Two gates. Gate 1 is technical and binary — any failure is a reject regardless of
how good the frame is otherwise. Gate 2 is craft, scored, and decides keep vs.
banger.

---

## Gate 1 — technical disqualifiers

Any single one of these → `reject`. Assess at the 2048px verification tier, not
at triage.

- **Focus miss.** Critical focus is not on the subject's eye (wildlife, portrait)
  or the plane that carries the picture (landscape). Focus on the wing, the
  shoulder, the branch in front, or the ground behind is a miss. This is the
  single highest-volume reject on long-lens work — be strict, since it can't be
  fixed later.
- **Motion blur that isn't intentional.** Shutter too slow for the subject or the
  reach. Cross-check `shutterSpeed` and `focalLength` from the metadata: hand-held
  at 600mm and 1/125s is a red flag before you even look.
- **Blown highlights on the subject.** Specular glints are fine; a clipped white
  breast, a clipped sky *that the composition depends on*, or clipped feather
  detail is not. Recoverable-looking clipping on a RAW file still counts as
  failure if it's on the subject.
- **Shadows crushed past recovery** on the part of the frame that carries the
  picture.
- **Subject clipped by the frame edge** in a way that reads as an accident rather
  than a choice — a wingtip or tail amputated at the border.
- **Eyes closed / nictitating membrane / obscuring branch across the face**, for
  animal and bird subjects.

Record which gate failed in the manifest. The reject-pattern summary at the end
is built from these.

---

## Gate 2 — craft, scored 1–5 each

Assessed at the 1024px triage tier. Score every surviving frame on all seven.

### Composition
The strongest single factor. Clear subject, intentional framing, negative space
used rather than left over, leading lines, a working foreground/background
relationship. 5 = the frame could not be cropped tighter or looser without
losing something. 2 = subject centered by default, dead space with no function.

### Light
Direction, contrast, quality, and timing. Intentional light beats abundant light.
5 = the light is doing work — rim, backlight through feathers, directional
shaping, weather. 3 = clean but neutral. 1 = flat overcast midday with no shaping.

### Subject separation
Does the eye land where it should, instantly? Separation can come from depth of
field, tonal contrast, color contrast, framing, or light. 5 = unmistakable. 2 =
subject tonally merges with its background, viewer has to hunt.

### Background control
The most reliable amateur/professional tell. Watch for: branches or poles
emerging from the subject, bright blown patches pulling the eye, cluttered
mid-ground, a distracting horizon line through the head, hot spots at the frame
edge. 5 = clean and deliberate. 2 = busy in a way that fights the subject.

### Timing / gesture
For wildlife especially — the head turn, the wing position, the catchlight, the
call, the moment of tension. A perched bird doing nothing is a 3 at best no
matter how clean. 5 = a moment that won't repeat.

### Color
Believable and coherent. This is a pre-edit judgment: the question is whether the
file's color is *deliberate and workable*, not whether it's already graded.
Mixed color temperature, a color cast fighting the subject, or a palette with no
relationship between subject and surround scores low.

### Intent
Does the frame read as a decision or as a capture? The synthesizing criterion —
if the other six are high but the frame still feels like it happened *to* the
photographer, intent is low.

---

## Thresholds

- **Reject** — any Gate 1 failure, **or** mean Gate 2 below 3.0, **or** either
  Composition or Subject separation at 2 or below (those two can't be rescued by
  the rest).
- **Keep** (no write) — everything else. This is the large middle and it should
  be the largest surviving bucket by far.
- **Banger** (5 stars) — no Gate 1 failure, **every** Gate 2 criterion at 4+,
  **and** at least one at 5 in Light, Timing, or Composition. A frame that is
  uniformly 4s and nothing more is a strong keep, not a banger.

---

## Output-fit check (applies at the banger threshold only)

Before awarding 5 stars, check the frame survives the crops it's destined for:
a 4:5 vertical and a 16:9 horizontal both pulled from the same file. If the
composition only works at native 3:2 — subject too close to a short edge, no
headroom, or the negative space collapses under either crop — it's a strong keep
rather than a banger. Frames that hold up in all three ratios are the ones worth
the star.

Drop this section if the intended output changes.

---

## Calibration notes

- Score the file, not the potential edit. "This would look great with work" is a
  keep, not a banger.
- Don't reward difficulty. A rare species badly photographed is still badly
  photographed; note the rarity in the report if it's obviously a species worth
  keeping for record purposes, and keep rather than reject.
- Don't penalize a frame for being a member of a burst. Duplicate handling is a
  separate step and never affects the score.
- When genuinely torn between reject and keep, **keep**. The reject flag is cheap
  to review, but a frame the user never sees again is a real loss.
