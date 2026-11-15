# Development progress

Last updated: 2026-11-15

## Current direction

Continue the Arizona 1897 vertical slice toward a measured, whole-game visual-quality target. Red Dead Redemption 2 is a visual reference only; no protected assets are copied. AAA status is **not achieved** and must not be claimed without representative captures, target-hardware performance data, and independent review.

## This session

Inspected current `main` at `04d55887537bab8b40988483109163e538ef33cc`, the latest 12 commits, both GitHub Actions workflows, recent Windows/validation runs, and open issues/PRs. No open repository issues or pull requests were returned.

Four development passes were completed and committed directly to `main`:

- `c97f226` — made preview waypoint verification tolerant of GDScript's actual print separator, increased the capture window to 48 seconds, and preserved runtime/waypoint/frame diagnostics even when capture fails.
- `c8eda80`, `706d16f`, `fdd9a69` — added staggered cedar shingle courses to both gable planes and a deterministic geometry/integration regression. The roof surface contains 308 triangles with generated normals and per-tile weathering.
- `8ba7267`, `b7d4c41`, `05b8416` — added an original world-space procedural dinosaur hide shader with broad/fine mottling, scale-like albedo breakup, and roughness variation. The regression found 41 hide meshes using the shader across the triceratops and tyrannosaur.
- `e6326dd`, `3067801` — tuned the preview-only tween speed and short waypoint holds after a measured 48-second software-rendered capture reached only the first three of seven camera stops. The latest preview pacing is 3.0x tween speed with a 0.35-second in-game hold per stop; this remains pending visual confirmation.

No third-party art assets were added; the new roof and skin details are procedural and authored in the project.

## Verified checks

- GitHub Actions validation/export run `#52` passed on `3067801cdcc9a41ed70de312cd5565610bb338e0`: Godot 4.4.1 import, rock LOD/collision regression, roof shingle regression, dinosaur skin regression, preview-route regression, headless main-scene launch, and Windows x86_64 export all succeeded.
- Roof regression: 308 triangles, deterministic seeded geometry, vertex colors, generated normals, and installation on a built saloon.
- Dinosaur skin regression: 41 hide meshes across both dinosaur species use the new shader and positive detail scales.
- Existing rock regression remains green: 120 near triangles versus 36 distant triangles, with detailed concave collision retained.
- Windows preview run `#82` on `c97f226` produced a real 48-second 1280×720, 30 FPS MP4 but correctly failed its completeness gate: only `town_establishing`, `main_street`, and `herd_approach` completed. The diagnostic artifact was retained. This exposed the slow software-rendered tween clock and motivated the latest preview-only pacing adjustment.
- A real 42-second 1280×720, 30 FPS preview from the earlier `04d5588` revision was decoded and inspected. It showed the settlement and warm sky, but the route did not adequately demonstrate the dinosaur landmarks and the scene still reads as a simplified low-poly vertical slice. The new shingle and skin changes have not yet been visually inspected in a rendered capture.
- Windows Build run `#90` for the current code revision was still in progress when this log was updated; its final preview, waypoint trace, and Windows artifact must be inspected before claiming capture/export success for that workflow.

## Next unfinished work

1. Inspect the newest Windows Build preview from `3067801`; verify all seven waypoint markers, the herd close-up, tyrannosaur vista, and the rendered roof/skin details.
2. If the route still fails, tune only from its saved runtime log and measured capture; do not weaken the landmark completeness gate.
3. Inspect representative desert, rock/cactus, settlement interior, and animal scenes. Expand the control-scene set beyond the current town-to-herd flythrough.
4. Continue replacing primitive-looking animal and prop construction with coherent authored meshes, more convincing anatomy, material response, and animation; extend LOD/collision coverage.
5. Declare a target PC, collect frame-time/memory measurements, and review stability and image quality on that hardware.
6. Keep the AAA gate open until the full representative scene set, performance, stability, and independent visual review are evidenced.

Do not treat a successful import, headless launch, Windows export, or a single attractive frame as proof of visual quality.
