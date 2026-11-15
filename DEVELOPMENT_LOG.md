# Development progress

Last updated: 2026-11-15

## Current direction

Continue the Arizona 1897 vertical slice toward a measured, whole-game visual-quality target. Red Dead Redemption 2 is a visual reference only; no protected assets are copied. AAA status is **not achieved** and must not be claimed without representative captures, target-hardware performance data, and independent review.

## This session

Baseline inspected: `main` at `55572f145354be40929748f70f33ac645cccd8ce` (2026-11-14). No open repository issues or pull requests were returned. The previous Windows workflow had failed during GDScript parsing; its logs identified untyped array-index values and a cylinder helper that rejected Material arguments.

Changes committed directly to `main`:

- `5633ef2` — fixed GDScript type inference and allowed cylinder props to reuse existing Material resources.
- `23ddf7e` — added a lower-cost sandstone outcrop mesh for distance rendering. Near mesh: 120 triangles; distant mesh: 36 triangles (70% fewer), with overlapping visibility ranges and the detailed collision retained.
- `c4b763d` — improved triceratops idle animation: diagonal leg pairs, tail pivot sway, and subtle torso breathing.
- `c5ce1ee`, `59aebc1`, `f3c8dd1`, `9e880f6` — added the rock LOD/collision regression test, wired it into CI, and corrected the test to identify the explicitly named collision node.
- `f0fc894` — reduced the overly dense warm fog, moved ambient fill to the sky, and softened the sun after inspecting a real gameplay capture that showed the ground and sky washed out.
- `03814df` — made the automated gameplay capture focus and send input directly to the Godot window after the first inspected capture showed almost no camera/player movement.

## Verified checks

- Godot 4.4.1 imported and parsed the scripts successfully on `9e880f608e52b6f783b83860723c80dd435e42aa`.
- The new rock LOD/collision regression test passed on that commit.
- The main scene launched headlessly successfully on that commit.
- Windows export was still running when this note was written; the latest capture/Windows build also needs its final artifact inspected.
- A real 38-second 1280×720, 30 FPS preview from `c4b763d` was decoded and inspected. It showed the settlement, but the image was visibly washed out and the scripted movement was not convincingly demonstrated. The fog and capture-input changes above are responses to those observed defects; they still require a new inspected render.

## Next unfinished work

1. Inspect the newest Windows build and gameplay preview from the latest `main`; verify the new focus/input sequence actually moves and turns the player.
2. Inspect the post-fog lighting on a real render. Tune contrast, terrain micro-detail, sky gradient, and shadow readability only from captured evidence.
3. Expand representative visual checks beyond the street: desert route, rock/cactus formations, settlement interiors, triceratops herd, and distant tyrannosaur.
4. Continue replacing primitive-looking animal/prop construction with coherent authored meshes and animation, then measure performance on a declared target PC.
5. Keep the AAA gate open until the whole-game scene set, stability, performance, and independent visual review are all evidenced.

Do not treat a successful import, headless launch, or Windows export as proof of visual quality.
