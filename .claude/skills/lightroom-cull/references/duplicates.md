# Duplicates and near-duplicates

There is no perceptual hashing available — `get_photo_preview` returns an image
content block, not a file on disk, so nothing can be hashed. Detection is
therefore two-stage: **metadata clustering narrows the field, visual comparison
confirms.** Clustering first is what keeps this from being an O(n²) comparison
across the whole folder.

---

## Stage 1 — cluster from metadata (no previews)

Run over the `get_folder_photos` result before any rendering. Two photos are in
the same candidate cluster when **all** hold:

- `captureTime` within **10 seconds** of the previous member (chain, not
  pairwise — a 30-frame burst chains correctly),
- same `focalLength`,
- same orientation (derive from `croppedDimensions`).

Tighten to 3 seconds for high-frame-rate bursts if a cluster exceeds 40 members;
that's usually two separate events getting chained.

Singleton clusters are the common case and need no further work.

**Near-duplicates outside a burst** — the same bird, same perch, ten minutes
apart — will not chain. Catch these with a second, looser sweep: same
`focalLength` and captureTime within **5 minutes**, flagged as a *weak* cluster.
Weak clusters are only compared visually if two or more members survive scoring;
don't spend previews confirming them up front.

---

## Stage 2 — order the visual pass

Emit the batch order so cluster members land in the **same batch** wherever
possible. Comparison requires both frames in context at once; a cluster split
across two batches means re-rendering.

A cluster larger than 15 (a long burst) gets its own dedicated batch or
consecutive batches, and comparison happens across the whole cluster at the end
of the last one.

---

## Stage 3 — confirm and mark

After every member of a cluster has a verdict:

1. Count survivors — members not rejected in Gate 1 / Gate 2.
2. **0 or 1 survivor → nothing to do.** This is the normal, healthy outcome of a
   burst: the cull already picked the frame. Do not mark it.
3. **2+ survivors → confirm they're actually near-duplicates.** Same subject,
   same setup, materially the same picture? Two frames from one burst where the
   bird launches in the second are *not* duplicates — they're two pictures. If
   they're genuinely different photographs, dissolve the cluster and stop.
4. Confirmed duplicate group → mark **every surviving member**:
   - `set_color_label` → `yellow`
   - `set_keywords` → additive union of existing keywords plus
     `Duplicate Review` and `dup-<runId>-<NN>` where `NN` is the group's
     two-digit index within the run.

The per-group keyword is what makes this usable — `Duplicate Review` finds all of
them at once, `dup-20260523-1412-03` isolates one group for side-by-side review
in Lightroom's own compare view, which is where the final pick belongs.

**Do not pick a winner.** Frames that are this close differ by things that don't
survive a 1024px JPEG — a hair of focus, a wingtip position, a catchlight. The
user makes that call in Compare view; the skill's job is to put the candidates in
front of them.

If one member of a duplicate group earned 5 stars and the others didn't, still
mark all survivors including the starred one. The star and the review label
answer different questions.

---

## Reporting

In the run summary, report duplicate groups as: group keyword, member count, and
filenames. Nothing else — the user is going to open Lightroom to resolve them
anyway.
