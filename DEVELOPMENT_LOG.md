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


## 2026-11-17 second development pass — triceratops close-up refinement

Inspected \`main\` at \`45994d27da9e60d47f62253a2f9d54dfdee57779\`, the latest commits, both workflows, open issues and pull requests. No open issues or pull requests were present at the start of this pass. Main's Godot validation workflow \`#92\` and Windows Build \`#120\` had succeeded.

### Baseline visual review

Downloaded and decoded the 48-second \`1280×720, 30 FPS\` gameplay preview from Windows Build \`#120\`. Inspected a contact sheet at three-second intervals and individual frames of the settlement, herd and tyrannosaur vista. The preview is a real gameplay capture, but it remains a strongly stylized low-poly slice: the ground reads as a broad dark plane, cactus and rock silhouettes are simple, the town is largely exterior-only, and the triceratops still has visibly intersecting head masses. This confirms the head close-up is a worthwhile next target; it does not support an AAA claim. The capture host uses software rendering (Mesa llvmpipe/OpenGL 3), so it is not a target-GPU benchmark.

### Geometry and material passes

1. **Skull, jaw and neck transition** — replaced four intersecting skull/jaw spheres with separate closed Catmull–Rom lofts that overlap the existing torso shell deliberately. Added a shared head rig for the skull, jaw, frill and facial details, plus paired eye sockets and smaller eye layers.
2. **Horn anatomy** — replaced constant-radius rotated cylinders with curved, tapered, capped keratin tubes for the two brow horns and nasal horn. Added three hide-coloured root collars so the horn bases embed into the skull instead of floating above it.
3. **Skin response and gait** — added a high-frequency procedural relief signal, restrained derivative-based normal perturbation, micro-grain variation, roughness breakup and AO modulation. Reworked the four leg tweens so diagonal pairs share a cycle and opposing pairs start out of phase; added a restrained head nod and vertical breathing motion.
4. **Shading continuity correction** — indexed the new skull/jaw and horn surfaces before generating normals. This shares coincident ring vertices so the lofts shade smoothly rather than exposing every triangulation edge.

All new geometry is original and procedural; no third-party art assets were added.

### Regressions and CI

- Added \`tests/test_triceratops_head.gd\` for closed skull/jaw/horn topology, bounds, generated normals, eye sockets, horn counts and root collars.
- Added \`tests/test_triceratops_gait.gd\` for diagonal-pair synchronization and the four leg pivots.
- Extended \`tests/test_dinosaur_skin.gd\` to require procedural micro-relief, derivative normal perturbation, AO and a positive strength parameter.
- Added both new focused tests to \`.github/workflows/godot-validation.yml\`.
- The first head test attempts exposed a test-only issue: Godot automatically suffixes duplicate sibling names. The regression was corrected to count name prefixes. The subsequent final branch validation **#99** passed import/parser checks, all triceratops and existing world regressions, preview-route validation, headless main-scene launch and Windows x86_64 export.

The passing validation is on PR branch \`f05491878dd73d488d7eb7bd4b465f814b45e2b7\`, not yet on \`main\`. A fresh post-change gameplay capture has not yet been generated or visually inspected. The merge should trigger the Windows Build workflow; inspect that artifact before claiming a visible improvement.

### Current blockers and next work

1. Review the fresh post-merge capture at close range to confirm the head, eye sockets, horn roots, smooth normals and gait read correctly in the rendered game.
2. Continue the whole-world quality pass: remove the large flat-looking ground read, improve rock/cactus material breakup and silhouette variation, and add an actual interior route/control scene rather than assuming the exterior town proves interior quality.
3. Improve dinosaur skin/eye close-ups and foot-ground interaction based on the new rendered capture.
4. Add reproducible fixed-camera scenes for desert, rocks/vegetation, town/interior, animals/dinosaurs and weather/time-of-day.
5. Obtain target-GPU measurements and independent visual review against specific RDR2 criteria. The current llvmpipe capture cannot establish target-hardware quality or performance.

AAA status remains **not achieved**. Continue from the merged head, inspect the new Windows Build preview first, then choose the next highest-impact world-level blocker.


## 2026-11-17 third development pass — evidence-route close-up

The post-merge Windows Build \`#121\` completed successfully and produced a fresh 48-second \`1280×720, 30 FPS\` preview on main \`e8b4b0f2\`. I decoded the video and inspected a 3-second contact sheet plus the triceratops close-up crop. The new head/eye/horn work is present in the scene, but the existing \`herd_close\` camera still framed the family from roughly 10.8 m and aimed at the herd center. At 1280×720, the new anatomy was not large enough on screen to evaluate reliably.

To make the next visual check meaningful, the preview route now moves to a 6.3 m west-flank shot and aims at the lead triceratops head. The next camera segment is tested to move monotonically away from that animal while remaining at least 8 m from the other family members; the southbound route then resumes after the explicit clearance point. The route duration is unchanged.

The focused preview-route regression and the full Godot validation workflow **#102** passed on branch commit \`9ee3472f25a96ddb644446e0890cf7addb972002\`. This is a camera/evidence improvement only. It does not change the dinosaur mesh and does not establish visual quality. The post-merge Windows Build must produce another capture, which must be inspected at the new head close-up before the next art decision.

AAA status remains **not achieved**. Next: merge after checks, inspect the new close-up capture, then continue from the actual rendered result.


## 2026-11-18 development pass 1 — Arizona basin and arroyo landform

Reviewed main `a0cdfe4a`, the latest Godot/Windows workflows, open issues and pull requests (none open), and inspected the successful Windows Build #122 gameplay capture at native 1280×720 frames. The real capture shows the current ground reading as a nearly uniform dark plane with too little large-scale relief; scattered rocks and plants appear to sit on a visually flat basin.

Changed `scripts/world.gd` to raise the terrain grid from 224 to 256 segments (about 2.0 m spacing across the 520 m field) and replaced the very low-amplitude height blend with overlapping basin undulation, dune fields, fine wind ripples, and a deeper, wider winding arroyo with raised shoulders. The visible mesh and trimesh collision still come from the same height function, and all building, plant, rock and animal placement continues to sample that same function.

Expanded `tests/test_terrain_relief.gd` to check basin elevation range, arroyo bank/channel separation, generated normals, upward triangle winding and complete mesh topology. This is a geometry pass; no claim is made that the renderer has visually confirmed the new terrain yet. The existing CI already runs this regression, so the next push will validate it through the full Godot workflow and Windows export.

AAA remains not achieved. Continue with the terrain material response, then native desert ground-cover variety.


### Terrain regression correction

The first terrain CI run (#105) confirmed import/parser success and all preceding regressions, but the new test's average generated-normal Y threshold failed. The test was relying on the engine's averaged vertex-normal representation as a proxy for triangle winding. Replaced that assumption with a direct geometric cross-product check on every emitted triangle, while retaining a non-zero generated-normal check. This tests the actual mesh winding independently of interpolation/normal averaging. The terrain change itself remains unchanged; rerun the full validation before proceeding.


## 2026-11-18 development pass 2 — layered Arizona soil response

The #122 and #124 baseline captures show a very dark, nearly uniform brown foreground. The first terrain-height pass adds measurable basin relief and a deeper arroyo, but the current shader still suppresses those forms visually. Replaced the single dark soil blend with a restrained sun-bleached dust/ochre/pale-sand palette, broad sediment variation, clay streaks, arroyo wash staining, slope-aware exposed sandstone, gravel/pores, fine-grain derivative normals, roughness variation and subtle AO. The shader derives slope from the world-space terrain normal, so exposed rock response follows the actual generated surface rather than a screen-space guess.

Added `tests/test_terrain_material.gd` and wired it into the full Godot validation workflow. The regression verifies the material channels and palette ordering; shader compilation is exercised by Godot import and the next rendered Windows preview. No claim of visual success is made until that capture is inspected.
