---
name: lightroom-cull
description: Cull and organize photographs in Adobe Lightroom Classic via the lightroom-mcp server — assess a folder of shots against professional criteria (composition, light, subject separation, exposure, color, sharpness, background control, timing, intent), flag the failures as rejected, star the standouts 5, and mark near-duplicate survivors for review. Use this whenever the user asks to cull, triage, rate, star, reject, sort, or "go through" photos, mentions a shoot folder or import they want narrowed down, asks which frames are keepers, or wants duplicates or burst sequences sorted out — even if they don't say the word "cull" and even if they only name the folder.
---

# Lightroom Cull

Autonomous first-pass cull of a Lightroom Classic folder. Writes to the catalog
without asking per photo — the user has opted into that. Writes are limited to
four operations and are always additive or recoverable:

| Verdict | Write |
|---|---|
| Fails the bar | `set_flag` → reject |
| Survives, unremarkable | *nothing* — left untouched |
| Banger | `set_rating` → 5 |
| Near-duplicate survivor | `set_color_label` → yellow **+** `set_keywords` → `Duplicate Review`, `dup-<runId>-<NN>` |

Never delete, move, remove keywords, or clear a rating. Reject is a flag, not a
deletion; the user can invert it in one keystroke.

## Prerequisites

Check these before starting; stop and say which one failed rather than
half-running:

1. Lightroom Classic is open with the target catalog, and the plugin's socket
   server is started (Plug-in Manager → Lightroom MCP → Start Server).
2. The MCP tools `list_folders`, `get_folder_photos`, `set_color_label`, and
   `sweep_preview_temp` are available. These are additions beyond the original
   Phase 1 set — if any are missing, the server predates them. Say so and stop;
   there is no fallback that scopes to a folder.
3. `get_photo_preview` responds. Render one photo as a smoke test before
   committing to a 400-frame run.

## Workflow

### 1. Resolve scope

`list_folders`, then match the user's words against folder names. Fuzzy match is
fine; ambiguity is not — if two folders plausibly match, ask which. Each
folder's `photoCount` (recursive, includes subfolders) comes straight back from
`list_folders` — confirm the resolved folder path and that count in one line
before starting, because the run is going to take roughly `photoCount × 4
seconds` and writes are automatic.

Ask whether subfolders are included only if the folder has children (a folder
has children if another folder's `parentPath` in the same `list_folders` result
equals its `path`).

`get_folder_photos` is paginated (default 40 per page, hard cap 100 — the
per-photo payload is large enough that bigger pages can exceed the MCP
response size limit) — almost every real folder needs multiple calls
(`offset`/`limit`) to see everything. Fetch all pages before clustering; don't
cull a partial folder silently. For a folder in the thousands, that's dozens of
calls — budget for it rather than trying to widen the page size.

### 2. Open a run manifest

Write `.lightroom-cull/<folder-slug>-<YYYYMMDD-HHMM>.json` in the working
directory. This is the resume point — preview rendering is ~3s per photo and a
dropped socket mid-run must not cost the whole pass.

```json
{
  "runId": "20260523-1412",
  "folderPath": "D:/Photos/2026/05-17-river",
  "startedAt": "...",
  "photos": {
    "<photoId>": {
      "fileName": "DSC04871.ARW",
      "state": "pending|triaged|verified|written|deferred",
      "scores": { "composition": 4, "light": 5, "...": 0 },
      "gateFailures": ["focus"],
      "verdict": "reject|keep|banger",
      "dupGroup": "dup-20260523-1412-03"
    }
  }
}
```

On startup, if a manifest exists for this folder from the last 24h, offer to
resume it instead of re-rendering everything.

### 3. Cluster before looking

Read `references/duplicates.md` now. Burst clustering runs off the
`get_folder_photos` result alone — `captureTime`, `focalLength`, and
`croppedDimensions` (for orientation) come back on every photo, no separate
metadata call and no previews needed — and clustering determines how the
visual pass is ordered, so it has to happen first.

### 4. Visual pass

Process in **batches of 15**, in cluster order (cluster members adjacent, so
comparison is possible within a batch).

Two tiers, and never render the same tier twice for one photo:

- **Triage** — `get_photo_preview` at `maxDimension: 1024`, `quality: 0.75`.
  Enough for composition, light, separation, background, timing, color. Not
  enough for critical focus.
- **Verification** — `maxDimension: 2048` only for photos that survive triage.
  Confirm focus is on the eye / the plane that matters, and check for motion
  blur that 1024px hides. A frame can fail here after passing triage; that's
  expected and is the single most common reject reason on a long-lens shoot.

Score against `references/rubric.md` — read it before the first batch.

After each batch: write verdicts to the catalog, update the manifest, sweep temp
(step 6). Never accumulate a whole folder's verdicts in memory before writing.

**On a transient error** (the plugin's known mid-session reconnect): retry the
call once. If it fails again, mark the photo `deferred` and move on. Report
deferred photos at the end; don't let one bad socket moment stall the run.

### 5. Write verdicts

Guardrails, applied per photo before any write — these protect the user's own
curation, which is the one thing this skill can't reconstruct:

- `pickStatus == 1` (user flagged it a pick) → **never reject**. Score it, and if
  it doesn't earn 5 stars, leave it alone entirely.
- `rating >= 1` already set → **never lower it**, never reject. Raising to 5 is
  allowed if it earns it.
- `colorNameForLabel` already set to something other than yellow → leave the
  label alone; the user is using it for something. Still apply the keyword.
- Existing keywords → `set_keywords` must be additive. Read the photo's current
  keywords from the folder listing and send the union, never the replacement.

### 6. Sweep temp

After **every** batch, not just at the end. `get_photo_preview` cleans up its own
export, but an export orphaned by a dropped connection is never cleaned — and
this workflow renders enough previews for that to accumulate.

Call `sweep_preview_temp`. It only removes directories older than its age
threshold (default 10 minutes), so nothing currently in flight is touched.

### 7. Mark duplicate groups

Per `references/duplicates.md`, after all members of a cluster have verdicts.
Only clusters with **two or more survivors** get marked; a cluster where nine
frames rejected and one survived isn't a duplicate problem, it's a burst that
worked.

### 8. Report

Short. Counts by verdict, the duplicate groups and their sizes, deferred photos,
and — the part that's actually useful — the two or three patterns behind the
rejects (e.g. "38 rejects were background clutter at the tree line; 21 were
focus on the wing rather than the eye"). Name the 5-star frames by filename.

Don't restate the rubric or narrate the batches.

## Calibration

5 stars is scarce. On a normal outing it's 0–3 frames out of several hundred; a
run that stars 15 photos has miscalibrated, and the right response is to say so
rather than hand over an inflated list. Reject is not scarce — 50–70% of a
wildlife take is a legitimate reject rate.

If the user pushes back on specific calls, adjust within the run and note the
adjustment in the report. Don't silently re-cull.

## Reference files

- `references/rubric.md` — the two-gate scoring model and what each criterion
  looks like at 1024px. Read before the first batch.
- `references/duplicates.md` — clustering, comparison, and group marking. Read
  before the visual pass is ordered.
