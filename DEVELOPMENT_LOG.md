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


## 2026-11-18 development pass 3 — native creosote ground cover

The inspected #123 capture confirms the raised terrain mesh is still visually subtle at the current preview camera height; the new material pass is therefore being checked separately before any further amplitude change. The same capture also shows a species gap: the open basin contains saguaros, isolated grass tufts and boulders, but no low woody desert shrubs, leaving large areas visually empty.

Added an original procedural creosote-bush mesh with tapered woody stems and paired narrow leaves, vertex-color variation and generated normals. Added three deterministic shape variants and 90 instances in three MultiMesh batches. Placement samples the shared terrain height and explicitly avoids the settlement radius, herd members, tyrannosaur vista and arroyo channel; shrubs are non-colliding ground cover so they do not interfere with player or dinosaur movement.

Added `tests/test_creosote_bushes.gd` and wired it into Godot validation. The regression checks complete mesh arrays, proportions, deterministic geometry and scatter, three draw batches, terrain-aligned roots and clearances. The next Windows capture must be inspected for silhouette quality and overdraw before increasing shrub density or adding more plant species.


## 2026-11-18 development pass 4 — terrain lighting and capture reliability

The new #125 rendered capture was inspected. The foreground remains unusually dark even after the layered soil palette was added. The earlier terrain regression had been corrected to test geometric triangle orientation but had not asserted the generated vertex-normal direction itself. The capture and shader's slope mask together indicate that the terrain normals need to be checked as a lighting input, not only as a triangle count. Reversed the terrain triangle winding to match Godot's front-face convention and strengthened the regression to require upward generated normals on every vertex.

The #125 Windows preview also reached the final `return_overlook` but the 48-second recording ended before `town_return` completed. Increased the deterministic CI capture to 60 seconds and moved its end-frame comparison to 56 seconds, preserving the complete route rather than silently omitting its last waypoint.

The first creosote regression (#108) reached the placement-height assertion and failed; expanded its diagnostic to report the exact instance, actual origin, expected terrain height and error, and made failure cleanup release both temporary test worlds. The next CI run must resolve this before the vegetation pass is considered verified. AAA remains not achieved.


### Creosote placement regression correction

The first placement assertion exposed that reading `MultiMesh.get_instance_transform()` from an off-tree `SceneTree` dummy-renderer test returns the default identity transform rather than the authored CPU-side placement record. The production placement loop already computes the root position before submitting it to the MultiMesh. It now retains those 30 source positions as lightweight node metadata; the regression compares deterministic source placements, verifies each root against the shared terrain-height function, and checks settlement/arroyo clearance without depending on a renderer-side RID buffer. The real Windows preview remains the visual check for the instanced output.


## 2026-11-18 development pass 5 — volumetric creosote foliage

Inspected the successful 60-second #127 capture at native resolution. The terrain normals now point upward (minimum generated normal Y 0.995), and the layered soil shader produces a much more legible sunlit orange-ochre surface with visible sediment breakup. The 60-second capture completes the full preview route and all required waypoints. The first creosote iteration, however, reads as a sparse, dark, spiky tuft rather than a rounded woody Sonoran shrub.

Reworked each leaf from a flat diamond into a small four-ring, five-sided volumetric lens, increased the branch count to 10–12, added a third paired-leaf tier, brightened the sage/olive palette and twig material, raised shrub scale modestly, and increased the instanced population from 90 to 126 while retaining three MultiMesh batches. The regression now requires dense geometry and the 126 seeded, terrain-aligned placement records. This is a mesh/material refinement; the next preview must be inspected before claiming that the shrub silhouette is resolved.

## 2026-11-18 development pass 6 — creosote canopy performance budget

Inspected main `475bdfd1`, the latest commits, both workflows, open issues/PRs, and the failed Windows Build `#129` diagnostics. The #129 preview captured the saloon approach and triceratops close-up but stopped at herd clearance and never completed the south detour; its required waypoint check failed, so no Windows executable was uploaded. The runtime log showed Mesa llvmpipe/OpenGL 3. The capture does not isolate a single bottleneck, but the preceding change had increased every shrub to a dense multi-ring leaf mesh.

Reduced only the creosote-specific geometry cost while preserving the 126 seeded shrubs and their terrain placement:
- Leaf lenses now use three rings and four sides instead of four rings and five sides.
- Creosote woody branches use eight radial sides; saguaros retain their original 16-sided tube geometry.
- Each variant uses 8–10 radial branches, two paired leaf tiers and a terminal leaf, keeping a rounded volumetric canopy instead of reverting to flat cards.
- The regression enforces 3,000–4,000 vertices per variant and a combined source-vertex budget below 470,000.

Godot validation **#112** passed import/parser checks, all existing regressions, the new creosote geometry/scatter budget, headless main-scene launch and Windows x86_64 export. The regression reported **435,456 instanced source vertices across 126 shrubs**. This is a measured geometry budget, not a measured GPU frame-time improvement; the post-merge Windows capture is still required to confirm that the incomplete #129 route is resolved.

## 2026-11-18 development pass 7 — separate visual and collision terrain grids

Kept the 256-segment terrain mesh for visible silhouettes, material response and generated lighting normals, but changed the static collision shape to a 192-segment mesh sampled from the exact same `_terrain_height` function. The collision-only mesh omits normals, which the physics shape does not use.

Extended `tests/test_terrain_relief.gd` to build both production grids, check their vertex counts and confirm that the collision mesh omits its unused normal array. It samples 441 world-space points against the triangle-interpolated collision mesh.

Godot validation **#114** passed. The collision grid uses **43.75% fewer vertices** than the render grid, and the maximum sampled deviation from the authored terrain height was **0.061 m** (limit 0.08 m). The visible 256-segment terrain is unchanged.

## 2026-11-18 development pass 8 — walk-through saloon interior and route evidence

Inspected the existing six building archetypes and their interior builders. The rooms already had walkable floor colliders and archetype-specific furniture, but lacked a coherent exposed timber structure and the preview route never entered one. Added three ceiling joists, four corner studs, five lower wall-trim runs and a named warm lantern to each room. The saloon now has a framed reflective mirror, back shelf and five bottle props behind the service bar.

Added a deterministic preview sequence through the centered saloon doorway: approach, interior bar/mirror framing, exit, then a street-clearance stop before the northbound route. Added `tests/test_building_interiors.gd` for all six room archetypes and expanded the route regression plus Windows capture waypoint list.

The first route regression correctly caught a new path from the saloon exit that crossed the sheriff-office footprint. Added `town_street_clearance` on the open main street and required it in both the route test and Windows capture trace. Final Godot validation **#121** passed:
- Six room archetypes: 18 ceiling joists, 24 corner studs, 30 trim pieces and six lantern lights.
- Saloon bar, mirror, back shelf and five bottle props.
- 15 unique camera stops and 47 seconds of authored route travel, including the saloon interior.
- Existing dinosaur, terrain, rock, roof, vegetation and material regressions.
- Headless main-scene launch and Windows x86_64 export.

The interior route and new vegetation have not yet been visually inspected in a successful post-change Windows gameplay capture. The CI host remains Mesa llvmpipe/OpenGL 3; target-GPU performance, high-quality Forward+ lighting, and independent whole-game visual review remain open blockers.

AAA status remains **not achieved**. Next: merge only after the final PR validation, inspect the post-merge Windows preview and its saloon interior frame, then continue with rock/plant material integration and target-GPU measurement.


## 2026-11-18 development passes 9–12 — saloon prop quality and pre-merge capture

Continued from the measured #130 failure and the open preview-route PR rather than repeating the completed terrain, vegetation, and interior-shell work.

1. Rebuilt the shared interior lantern as a recognizable iron-cage fixture: ceiling stem, upper/lower caps, four protective bars, and a warm emissive globe. The existing warm OmniLight remains the actual illumination source. The interior regression checks fixture components and emissive material.
2. Replaced the five saloon shelf cylinders with one continuous lathed-style bottle mesh per prop, including a tapered shoulder/neck, separate cork and front-facing paper label. Five restrained glass colors distinguish the bottles without introducing unrelated clutter. The regression checks count, mesh surface, bounds, corks, and labels.
3. Added a brass customer-side foot rail with three support brackets and a narrow brass counter inlay. The regression checks the rail mesh length/orientation, supports, and inlay.
4. Enabled the Windows Build workflow on pull requests, not only pushes to main. The pre-merge workflow now requires all 15 named route stops, a route-complete marker, and an elapsed-time value no greater than 50 seconds. This lets the full software-rendered capture and Windows export reject a partial route before merge.

The three saloon passes and the pre-merge CI wiring are committed on the existing PR branch. Their full Godot regression, 60-second capture, route-completion timing, and Windows export remain pending CI at this point. No new visual-quality claim is made until the resulting video is inspected. Mesa llvmpipe/OpenGL 3 remains a known limitation for lighting and target-GPU performance. AAA is not achieved.
