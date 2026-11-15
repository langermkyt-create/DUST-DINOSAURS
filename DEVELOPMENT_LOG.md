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
- `f0fc894` — reduced the overly dense warm fog and moved ambient fill to the sky after inspecting a real capture that showed the ground and sky washed out.
- `03814df` — attempted to target synthetic input at the Godot window; this did not produce a reliable camera move.
- `5164421`, `d7bed5a`, `2e93b51` — added a deterministic in-game preview flythrough, disabled global fog for a controlled contrast test, and made the camera route reproducible without fake keyboard input.
- `fe0a756` — removed X11 activation waits that can block under a headless Xvfb display.
- `d6f67c8` — increased sky ambient fill, reduced excessive SSAO, and strengthened procedural ground grain after inspecting the new flythrough: the sky gradient and camera movement were visible, but the ground remained too dark.
- `63a740b` — added CI checks for preview duration, visible camera movement, and runtime errors after capture.
- `198a3a3` — made the rock LOD regression test free its temporary scene so test runs do not leave physics/rendering resources allocated.

## Verified checks

- Godot 4.4.1 import, the rock LOD/collision regression test, main-scene headless launch, and Windows export all passed on `2e93b51865509d22c436be7327799dd0f045e4fe`.
- The LOD regression reports 120 near triangles versus 36 distant triangles, with the detailed concave collision retained.
- Godot validation/import, regression test, headless launch, and Windows export passed on `d6f67c848e7dfaab48f67e589d568c90bab0a6b6`; its Windows gameplay capture was still running.
- The newest motion-check workflow (`63a740b`) and test-cleanup workflow (`198a3a3`) were running/queued when this note was updated.
- A real 38-second 1280×720, 30 FPS preview from `c4b763d` was decoded and inspected; it showed a washed-out scene and did not convincingly demonstrate movement.
- A real 40-second 1280×720, 30 FPS preview from `d7bed5a` was decoded and inspected. It showed a blue-to-warm sky gradient and a moving camera route through the settlement. The ground and shadows were still too dark, so `d6f67c8` changes ambient fill, SSAO, and ground microvariation. That lighting adjustment is awaiting a new inspected render.

## Next unfinished work

1. Inspect the newest Windows build and gameplay preview from the latest `main`; verify the in-game camera route and the CI frame-difference assertion.
2. Inspect the post-fog lighting after the ambient/SSAO/terrain-grain adjustment. Tune contrast, terrain micro-detail, sky gradient, and shadow readability only from captured evidence.
3. Expand representative visual checks beyond the street: desert route, rock/cactus formations, settlement interiors, triceratops herd, and distant tyrannosaur.
4. Continue replacing primitive-looking animal/prop construction with coherent authored meshes and animation, then measure performance on a declared target PC.
5. Keep the AAA gate open until the whole-game scene set, stability, performance, and independent visual review are all evidenced.

Do not treat a successful import, headless launch, or Windows export as proof of visual quality.
