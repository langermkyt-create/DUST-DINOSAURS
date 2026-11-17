# Development progress

Last updated: 2026-11-17

## Quality target and evidence policy

Continue the Arizona 1897 vertical slice toward a measured, whole-game visual-quality target. Red Dead Redemption 2 is a visual reference only; no protected assets are copied. AAA status is **not achieved**. A successful import, headless launch, Windows export, or single attractive frame is not proof of AAA quality.

## 2026-11-16 development session

Inspected current `main` at `85c2f3ccda9288efdd31dc2550688009e344d9b2`, the latest 12 commits, both GitHub Actions workflows, recent validation/Windows runs, and open issues and pull requests. No open issues or pull requests were returned.

Three substantive geometry passes were completed:

1. **Continuous tyrannosaur torso/neck/skull loft** — replaced the coarse nine-section transition with Catmull–Rom interpolation at four subdivisions per authored interval. The resulting body has 33 longitudinal rings, 24 radial segments, 1,584 triangles and generated normals. The anatomy regression now requires at least 4,500 vertices and checks that the mesh is installed on the live animal.
2. **Unified tyrannosaur hind legs and feet** — replaced disconnected capsule/cylinder/heel pieces with a single closed loft per leg, carrying the thigh through the hock and foot. Three toe pads and claws remain on each foot. A new regression checks two continuous meshes, bounds, normals, and all six toe pads/claws. The first test attempt exposed Godot's automatic numeric suffixes on repeated sibling names; the test was corrected to count name prefixes.
3. **Closed triceratops frill plate** — added a back face and perimeter web to the scalloped fan, with restrained darker vertex tinting on the reverse and edge. A new regression verifies complete triangles, generated normals, broad silhouette and measurable thickness. Its first bounds threshold incorrectly assumed a full circular height; the test was corrected to the authored semicircular profile.

No third-party art assets were introduced. All geometry remains original and procedural.

## Verified checks

- Godot validation and Windows export workflow **#79** passed on `85c2f3cc`. Confirmed steps: project import/script parse; sandstone rock LOD/collision; cedar roof shingles; desert terrain/arroyo; tyrannosaur torso anatomy; tyrannosaur legs/feet; tapered dinosaur tails; closed triceratops frill; procedural dinosaur skin; preview route; headless main-scene launch; Windows x86_64 export.
- The new hind-leg regression passed: two lofted thigh-to-foot meshes, six toe pads and six claws.
- The new frill regression passed: closed plate geometry with generated normals and measured thickness.
- Windows Build workflow **#117** passed on the same commit. It produced a 48-second, 1280×720, 30 FPS gameplay preview and a Windows build artifact.
- The preview runtime trace completed all 11 authored camera landmarks: town establishing, main street, north exit, west ridge, herd approach/close/clearance, south detour, tyrannosaur vista, return overlook and town return.
- The 48-second video was decoded and visually inspected at representative timestamps. It clearly shows the settlement, triceratops group and tyrannosaur vista. It still reads as a simplified low-poly vertical slice; the triceratops torso/limbs and many props remain visibly primitive. The new mesh regressions prove geometry properties, not AAA visual quality.
- The preview host lacked `VK_KHR_surface` and fell back to Mesa llvmpipe/OpenGL 3. SSAO, SDFGI and SSIL were unavailable on that renderer. This is useful diagnostic capture evidence, not a target-GPU quality or performance measurement.

## 2026-11-17 development session

Continued from the open triceratops anatomy blocker in the previous session. Work is on branch `automation/triceratops-anatomy-20261117` and is intended for PR #1 after the full validation run.

Three substantive passes are in progress:

1. **Continuous torso shell** — replaced the triceratops capsule, shoulder sphere, hip sphere and belly primitive with a closed Catmull–Rom loft spanning shoulder, rib cage and pelvis. Added a regression for density, bounds and finite generated normals.
2. **Continuous legs and grounded soles** — replaced separate upper/lower cylinders with four closed lofts, distinct fore/hind profiles, three toe pads and tapered claws per foot. Each leg's neutral sole is offset against terrain sampled beneath that foot; diagonal gait amplitude is reduced to limit rod-like swinging. Added a regression for mesh continuity, dimensions, toe count and terrain contact.
3. **Watertight curved frill** — replacing the previous front/back fan and incomplete basal edge with a convex two-face plate, outer web and sealed basal chord. The regression counts undirected triangle edges and requires every edge to be shared exactly twice.

No third-party art assets were introduced; all geometry remains original and procedural.

## 2026-11-17 validation status

- Pass 1 torso loft regression and the full Godot validation/Windows export workflow passed on commit `c1df156d` (workflow #81).
- Pass 2 is committed as `9db99c03`; its CI result is pending at the time of this log update.
- Pass 3 is committed as the current branch head only after the final watertight-frill test is run by CI.
- The previous llvmpipe/OpenGL capture limitation remains. The anatomy regressions validate geometry and mesh topology, not final close-up visual quality or target-GPU performance.
- AAA status remains **not achieved**. The next step is to run the full PR validation and Windows export, inspect a fresh animal close-up capture, then continue to head articulation, skin microdetail and animal gait.

## Outstanding blockers and next work

1. Replace the triceratops' primitive torso/shoulder/hip assembly and separated cylindrical limbs with coherent, proportioned lofted anatomy; keep frill, horn and tail integration under regression.
2. Inspect close-up animal renders after each anatomy pass; test foot contact, gait phase, silhouette continuity and shading, not only vertex counts.
3. Expand fixed control scenes to include a representative desert/rock/cactus route, settlement exterior and interior, herd close-up, predator close-up, and weather/lighting variants.
4. Run captures on a declared target PC/GPU with frame-time, memory, stability and graphics-feature measurements. The current llvmpipe capture cannot establish target-hardware performance.
5. Obtain an independent visual review against concrete reference criteria: material response, texture frequency, geometry quality, animation, lighting/shadows, scene density, LOD transitions and artifact rate.

Keep the AAA gate open until the whole representative scene set, target-hardware performance/stability and independent review are evidenced.
