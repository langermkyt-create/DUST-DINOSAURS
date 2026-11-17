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

## 2026-11-17 development session — completed

Continued the triceratops anatomy blocker from the prior session. The work was developed in PR #1, then merged into `main` as merge commit `9244cb512b2bd36574d64c9646621b19e10cf6f3`. The final validated branch head was `e35edec3fab727a7761f0352fef7cebb43c72515`.

Three substantive passes were completed:

1. **Continuous torso shell** — replaced the triceratops capsule, shoulder sphere, hip sphere and belly primitive with a closed Catmull–Rom loft spanning shoulder, rib cage and pelvis. Added a regression for density, bounds and finite generated normals.
2. **Continuous legs and grounded soles** — replaced separate upper/lower cylinders with four closed lofts, distinct fore/hind profiles, three toe pads and tapered claws per foot. Each leg's neutral sole is aligned to terrain sampled beneath its actual foot point; diagonal gait amplitude is reduced to limit rod-like swinging. Added regressions for fore/hind geometry, toe/claw assembly and scale-aware sole-height solving.
3. **Watertight curved frill** — replaced the old planar front/back fan with a shallow convex two-face plate, outer web and sealed basal chord. The regression counts undirected triangle edges and requires every edge to be shared exactly twice.

All geometry is original and procedural; no third-party art assets were introduced. The test builders are isolated from full animal assembly, off-tree mesh generation skips live animation tweens, and focused tests have 30-second fail-fast limits. The validation workflow now rejects parser diagnostics instead of silently continuing.

## 2026-11-17 verified validation

- Godot validation and Windows export workflow **#90** passed on final branch head `e35edec3`.
- Godot 4.4.1 import and script parsing passed with parser diagnostics checked.
- New triceratops torso, fore/hind leg, toe/claw, scale-aware sole-contact and watertight-frill regressions passed.
- Existing sandstone rock LOD/collision, roof shingles, desert terrain/arroyo, tyrannosaur torso/legs/tail, procedural skin and preview-route regressions passed.
- Headless main-scene launch passed.
- Windows x86_64 export passed.
- Merge commit `9244cb51` is now on `main`. The post-merge Godot validation and Windows Build workflows (#91 and #119) were queued at the time of this log update.

The 17 Nov CI proves geometry properties, script validity, main-scene headless launch and Windows export. It does **not** prove final close-up appearance or target-GPU performance. No new post-merge gameplay capture has yet been visually inspected.

## Current blockers and next work

1. Inspect a fresh post-merge gameplay capture with a close view of the triceratops body, feet and frill. Do not infer visual quality from the mesh tests.
2. Improve the triceratops head/neck transition, eye sockets, horn roots, skin microdetail and natural gait while preserving the new continuous body/limb structure.
3. Continue the whole-world pass across architecture/interiors, plants, props, animal interactions, weather and lighting; prioritize coherent material response and remove visible placeholder forms.
4. Validate on a declared target GPU with reproducible resolution/settings and frame-time/memory measurements. The previous llvmpipe/OpenGL capture is not a target-hardware benchmark.
5. Build a representative fixed-camera scene set (desert, rock/vegetation, town/interior, animals/dinosaurs, weather/time-of-day) and obtain independent visual review against concrete RDR2 reference criteria.

AAA status remains **not achieved**. Continue from the new main HEAD, inspect post-merge CI/artifacts first, then proceed to the next triceratops close-up anatomy pass.
