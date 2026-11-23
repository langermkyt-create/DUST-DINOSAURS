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


## 2026-11-18 development passes 13–14 — saloon light balance and route-complete capture

Inspected the actual PR #131 frames and diagnostics rather than treating the uploaded file as a successful preview. The close saloon frame confirms the lantern fixture and shaped bottle props are present, but the back shelf remains too dark under the runner's OpenGL Compatibility fallback. Added a dedicated shadowless warm OmniLight at the saloon back bar only; its energy, range and shadow policy are covered by the interior regression. This avoids adding a second shadow-casting light to every building.

The #131 Windows capture then provided a precise timing failure: the first 14 of 15 waypoints completed, but town_return was still missing at the 60-second capture boundary. The trace reached return_overlook at 60.18 seconds. The 50-second completion budget was therefore contradicted by measured evidence, not a scene-script error. Replaced the fixed 60-second recording with a recorder that polls for PREVIEW_ROUTE_COMPLETE, stops two seconds after the marker, and times out at 90 seconds. The route marker's accepted elapsed limit is now 85 seconds; video duration and start/end frame movement are still checked, and all 15 named stops remain mandatory.

Godot validation #128 passed all regressions and Windows x86_64 export before this lighting addition. The new lighting regression and dynamic Windows capture are pending a fresh CI run. The #131 60-second preview is a real partial recording, not a complete gameplay artifact; no Windows executable was exported from that run. AAA remains not achieved.

## 2026-11-19 development session — saguaro surface, sandstone micro-relief, and aerial perspective

Started from the inspected main head 6bea57084cc538136e91e284a1bd8ac57c3f96b3. Reviewed the latest commits, open issues/PRs (none), Godot validation #131, Windows Build #134, and the #134 artifacts. Build #134 passed and produced a 34.57-second 1280×720 H.264 preview containing all 15 named route stops plus Windows x86_64 artifacts. The preview was decoded and inspected at the town, saloon, herd, and tyrannosaur stops. It confirms the saloon interior and route work, but the overall scene remains visibly stylized/low-poly; this is not AAA evidence. The renderer fell back from Vulkan to Mesa llvmpipe/OpenGL Compatibility, so SSAO, SDFGI and SSIL were unavailable.

Three substantive passes were completed on branch automation/2026-11-19-saguaro-rock-atmosphere:

1. **Saguaro surface detail.** Added continuous tube UVs to the trunk and arm meshes and replaced the flat vertex-color-only surface with a procedural shader for six longitudinal rib highlights, areole rows, subtle spine flecks and roughness variation. Added tests/test_saguaro_detail.gd to check all three variants, bounded mesh size, finite normals, 0–1 UVs and shader features.
2. **Sandstone material response.** Extended the shared near/distant rock shader with finer grain, sediment banding, fracture/weathering variation, derivative-based micro-relief normals and roughness/AO response. Extended tests/test_rock_lod.gd to check vertex colors/normals and identical multi-scale material code on both LODs. A source review caught a duplicate local declaration in the new assertion block; it was removed before opening the PR.
3. **Arizona aerial perspective.** Enabled restrained warm distance fog at density 0.0011 while keeping volumetric fog disabled for compatibility and cost reasons. Added tests/test_atmosphere_depth.gd to verify the haze range, warm tint, compatibility-safe fog mode and long-range directional shadows.

The Godot validation workflow now runs the new saguaro and atmosphere regressions in addition to the expanded sandstone checks. CI and the PR-triggered Windows capture/export are pending; no new shader/render claim is considered visually verified until the resulting artifact is inspected.

**Next:** inspect the new capture for saguaro ribs/spines, rock strata/micro-relief and horizon haze; correct any shader compile/runtime issues; then continue the whole-world art pass (particularly more natural rock formations, non-cactus vegetation, settlement/interior material variation and animal silhouettes). Target-GPU frame-time/memory measurements and independent whole-game review remain blockers. AAA status: **not achieved**.

## 2026-11-19 visual correction — haze strength and shader cost

Inspected the complete PR #6 Windows preview and its diagnostic bundle before merging. All 15 waypoints completed and the 1280×720 H.264 file is 70.63 seconds; the route marker measured 69.52 seconds versus 33.33 seconds on the previous #134 capture. The new warm fog also washed the whole distant skyline toward beige and reduced separation between mesas and sky. The software renderer was again Mesa llvmpipe/OpenGL Compatibility.

Corrected the two issues using that evidence:
- Reduced aerial fog density from 0.0011 to 0.00035 and lowered sun scatter, retaining a warm but much more restrained horizon tint.
- Reduced the sandstone shader from six 3D noise evaluations per fragment to four. The high-frequency field is now shared by color and derivative-based micro-normal detail; the fracture mask reuses the existing grain/pores fields. The rock regression now enforces this reuse so future detail additions do not silently double the fragment-noise budget.

This is a corrective iteration, not a visual-quality sign-off. A fresh full Godot validation, Windows capture, and frame-time/route-time comparison are pending. Target-GPU performance remains unmeasured; AAA remains not achieved.

## 2026-11-19 visual review — corrected horizon and tighter preview budget

Inspected the corrected #136 capture after reducing fog density and rock shader noise. The complete 15-stop route now measures **37.45 seconds**, down from 69.52 seconds on #135 and close to the previous 33.33-second baseline on #134. This is a CI route-time comparison on the same Mesa llvmpipe/OpenGL Compatibility runner, not a target-GPU FPS benchmark. The 1280×720 video confirms the scene and route still launch, but the sky remains too uniformly beige because the engine applies fog to the sky as well as distant geometry.

The next correction sets Environment.fog_sky_affect to 0.0 so the authored blue-to-ochre procedural sky remains intact while aerial haze still affects distant world geometry. The atmosphere regression now checks that setting. The saguaro close frame showed the new areole/spine flecks but the ribs were too subtle at normal video scale, so the tube rib amplitude and shader contrast were increased modestly. The Windows preview workflow route-time guard is tightened from 85 to 60 seconds; the 37.45-second run leaves useful runner headroom while catching another major shader-cost regression.

The sky-affect and stronger saguaro pass require fresh CI and a new inspected capture. AAA remains not achieved; target-GPU performance and independent full-game review remain blockers.

## 2026-11-19 preview review — sky gradient restored; timing guard recalibrated

Inspected the full #137 capture produced after setting fog_sky_affect to 0.0 and strengthening the saguaro ribs. The sky now retains a blue upper gradient and warm ochre horizon instead of being uniformly beige. The saguaro's longitudinal ribs and pale areole/spine flecks are more legible in the close pass, although the cactus remains a stylized procedural model rather than a photoreal asset. The saloon, herd and tyrannosaur route sections remain present.

All 15 waypoints completed and the route marker reached **66.21 seconds**; the 1280×720 H.264 file is 65.53 seconds. The Windows workflow failed only because the newly tightened 60-second hard budget was exceeded; it did not fail due to a missing waypoint, shader compile error or scene crash. This run confirms that llvmpipe runner timing varies substantially (37.45 seconds on #136 versus 66.21 on #137), so 60 seconds is not a reliable hard gate. The workflow now emits a warning above 60 seconds and retains the established 85-second hard timeout. This route-time metric is not a target-GPU frame-rate measurement.

Godot validation and Windows export passed on the same source revision; the Windows capture artifact is available despite the advisory-budget failure. A fresh Windows workflow is required after this guard correction. AAA remains not achieved.

## 2026-11-19 follow-up — outcrop silhouettes, desert stones and wind-reactive ground cover

Started from main e23082c5223e82aeefdfa822e6df7b668040d20 after reviewing the #140 Windows build, the #137 validation/export run, open issues/PRs (none), the prior preview diagnostics and the full 15-stop #140 H.264 capture. The inspected 1280×720 frames confirm the town and route work, but the world remains visibly stylized: distant rock formations are too regular, small ground stones read as smooth flattened spheres, and grass tufts are sparse flat triangles. The renderer is Mesa llvmpipe/OpenGL Compatibility; target-GPU quality and performance remain unverified.

Three substantive passes were completed on automation/2026-11-19-desert-ground-pass:

1. **Sandstone outcrops.** Increased the near formation ring from 12 to 16 sides, introduced coherent broad ridges, broken edge variation and restrained ledge height changes, and changed the distant LOD to sample eight sides from the same profile. The collision remains generated from the detailed near mesh. Added tests/test_rock_formation.gd to check exact near/LOD geometry budgets, deterministic vertices, normals, strata, collision type and LOD overlap.
2. **Desert stones.** Replaced the smooth SphereMesh pebbles with two deterministic, flattened icosphere-derived sediment variants. Each mesh uses 80 flat-shaded triangles, weathered radial variation and warm vertex-color strata. The two 170-instance batches remain instanced and terrain-aligned. Added tests/test_desert_pebbles.gd for geometry, material response, determinism, placement and batching.
3. **Grass tufts.** Replaced five flat triangular blades with seven curved, tapered, folded blades carrying dry-tip color variation. Added deterministic per-instance wind phases through MultiMesh custom data and restrained two-axis shader sway. The 520 tufts remain in one instanced batch with shadows disabled. Added tests/test_desert_tufts.gd for mesh bounds, normals, shader inputs, per-instance wind data, deterministic placement and retained pebble batches.

The Godot validation workflow now includes all three new regressions. Source-level review corrected the outcrop collision-type assertion and changed the wind-phase comparison to explicit color-channel comparisons. The first pebble and grass placement tests also exposed that MultiMesh instance transforms are not queryable in these unattached headless test roots; the scatter builders now retain deterministic placement records, and the regressions validate those records rather than reporting false zero transforms.

PR #7 was merged into main as ad1ddbaa199fe96234ecd17cf74713c094bce7f7. Godot validation/export run #144 passed the complete regression suite, main-scene headless launch and Windows x86_64 export. Windows Build #147 passed the complete 15-stop route and produced a 1280×720, 30 FPS H.264 preview of 63.60 seconds; the route completion marker measured 62.07 seconds.

The #147 frames were inspected. The seven-blade ground tufts and faceted pebbles are present, but the vegetation still reads as sparse stylized clusters at normal gameplay distance, and the sandstone outcrop improvements are not yet sufficiently showcased by the route. The saloon approach frame is too tight against the facade/doorway and should be reframed to show the full entrance before entering. The town buildings, cactus silhouettes and dinosaurs remain visibly stylized rather than photorealistic.

The capture renderer is Mesa llvmpipe/OpenGL Compatibility. Vulkan initialization failed because VK_KHR_surface was unavailable; SSAO, SDFGI and SSIL were consequently disabled. This is a real route capture and a successful Windows export, not target-GPU quality or performance evidence. Target-device frame-time/memory measurements and independent whole-game assessment remain blockers. Next: correct the saloon approach composition, then continue improving frontier architecture/materials and dinosaur close-up presentation. AAA remains **not achieved**.


## 2026-11-19 follow-up — saloon entrance, weathered timber, and interior wall courses

Started from main `875a86a395106c0869812a911b7cf754b1b3e947`. Reviewed the latest commits, the #149 Windows build and its artifacts, current CI, and open issues/PRs (no pre-existing open issues or PRs). Inspected the complete 64.63-second #149 H.264 preview at 1280×720/30 FPS. The saloon doorway view was obstructed by the outward-swinging door leaf, and the approach camera was too close to the porch. The world remains visibly stylized and is not close to a verified AAA result.

Three substantive passes were completed on `automation/2026-11-19-saloon-architecture`:

1. **Saloon entrance and route composition.** The front door now swings inward and parks parallel to the left jamb. Replaced the single slab with five individually weathered planks, two cross rails, a diagonal brace, iron hinges and a latch. Moved the saloon approach stop beyond the porch and aimed it at the doorway so the exterior facade is framed before the camera enters. Extended the route and building regressions to check the door construction and entrance framing. Windows Build #150 passed; its 51.60-second 1280×720/30 FPS preview was inspected at the saloon approach and interior stops. The open doorway no longer blocks the view of the back bar, and the approach now shows the saloon facade. This is a route-composition correction, not a photorealism claim.

2. **Frontier timber material.** Extended the shared weathered-wood shader with fine directional fiber lines, narrow checks/cracks derived from the existing pore field, knot darkening, sun bleaching, and more varied roughness/AO. Wall boards and roof shingles retain different grain scales while sharing the same material response. Added `tests/test_frontier_wood_material.gd` and wired it into Godot validation; the new regression passed in the full validation run.

3. **Interior timber courses.** Added seven rear-wall and fourteen side-wall plank courses per building as a single 21-instance MultiMesh batch, reusing one unit box mesh and the weathered wood shader. Added deterministic placement/scale metadata and expanded the six-building interior regression to check board counts, dimensions, wall alignment, and material use. The first test attempt exposed the known limitation that MultiMesh instance transforms read as identity in unattached headless test roots; the builder now records deterministic source transforms and the test validates those records. A subsequent typed-index parse error was corrected before the passing run.

Godot validation/export run **#153** passed the complete regression suite, main-scene headless launch, and Windows x86_64 export. Windows Build **#156** passed the complete preview route, recording, Windows export and artifact uploads. Its H.264 preview is 40.57 seconds at 1280×720/30 FPS; the runtime diagnostics record all 15 named stops and `PREVIEW_ROUTE_COMPLETE: elapsed=39.1` seconds. The video frames were inspected at the saloon interior, exterior, herd and tyrannosaur stops.

The preview renderer again failed to initialize Vulkan because `VK_KHR_surface` was unavailable and fell back to Mesa llvmpipe/OpenGL 3 Compatibility. SSAO, SDFGI and SSIL were therefore unavailable. The preview is a genuine CI software-rendered capture, not target-GPU visual or performance evidence. No target PC/graphics card has been specified or benchmarked, and no independent whole-game art review has been completed. AAA remains **not achieved**.

PR #8 (`Improve saloon entrance framing and door construction`) contains the three passes and their regressions; it is ready for merge after the final head/status check. Next: continue the exterior architecture pass across the other town buildings (side elevations, porch/roof transitions, shutters and material variation), then revisit dinosaur close-up presentation and vegetation density. Do not repeat the saloon door or interior board work.

## 2026-11-20 follow-up — exposed side framing, window shutters, and physical trade signboards

Started from main `b58527fb07b5602b3c8428df9218bb9edf1d151a` after reviewing the latest commits, the #158 Windows preview, current CI, and open issues/PRs (no pre-existing open issues or PRs). Inspected the 53.10-second 1280×720/30 FPS #158 capture. The saloon oblique view showed a nearly featureless dark side elevation; all six buildings shared floating trade lettering and plain front windows. The world remains stylized, and AAA is not achieved.

Three substantive passes were completed on `automation/2026-11-20-frontier-facades`:

1. **Side elevation construction.** Removed the full-height dark trim overlay that masked the siding. Replaced it with three exposed structural posts per side, upper/lower belt rails, continuous side eaves fascia, and five exposed rafter tails per side. The geometry is applied consistently to all six town archetypes.
2. **Front window joinery.** Added paired weathered timber shutter panels around both street-facing windows, four horizontal slats per shutter, and two iron hinge straps per shutter. Panels, slats, and hinges are each batched in a MultiMesh to keep the additional facade detail to three draw batches per building. Deterministic source positions are retained for headless regression checks.
3. **Trade signboards.** Replaced floating Label3D lettering with a physical timber backing, top/bottom/side rails, paired iron hangers and braces, and four visible corner fasteners. Trade text is positioned on the signboard for all six buildings.

Added `tests/test_frontier_exterior.gd` and wired it into `.github/workflows/godot-validation.yml`. The first CI attempt caught a GDScript type-inference error for `shutter_x` (loop values were Variants); it was corrected with explicit float conversion in `dedff22b1c774b74837aac2da921ec8087ee4285`.

Godot validation/export run **#157** passed all 32 workflow steps: script import, all 26 regression scripts (including the new six-building exterior regression), main-scene headless launch, Windows x86_64 export, and build artifact upload. The exterior regression passed for all six buildings, including side framing counts, shutter batch counts/positions, and signboard construction.

PR #9 was merged into main as **c54e6c3c7fee1557943d1310da4b3cb37c65d69c**. The separate Windows Build #160 passed script validation and was still running its software-rendered gameplay capture at the time this entry was written; no new video has been visually approved yet. The prior #158 preview remains a genuine Mesa llvmpipe/OpenGL Compatibility capture, not target-GPU evidence. Target-device frame-time/memory measurements, a modern-GPU render review, and independent whole-game art assessment remain blockers. Next: inspect the #160 facade close-up, correct any shutter/signboard overlap revealed by the render, then continue with business-specific building silhouettes and roof/porch transitions. AAA remains **not achieved**.

## 2026-11-20 performance follow-up — batch repeated facade geometry

The first exterior-detail preview (#160) was inspected rather than accepted on CI status alone. It showed the shutters, framed trade board and side structure, but the route elapsed time was **72.4 s** versus **51.88 s** on the pre-detail #158 baseline, using the same Mesa 26.0.8 llvmpipe/OpenGL Compatibility renderer. This ~39.6% slowdown was treated as a real regression requiring a follow-up.

PR #10 added a shared `_add_scaled_mesh_multimesh` helper and converted the repeated facade elements to deterministic instance batches:
- Side posts, belt rails and eaves fascia: 12 individual meshes → 1 MultiMesh batch per building.
- Side rafter tails: 10 individual meshes → 1 MultiMesh batch per building.
- Signboard rails, iron hangers/braces, and corner bolts: 12 individual meshes → 3 MultiMesh batches per building.
- Shutter panels/slats/hinges remain in their three existing batches.

This removes **29 repeated mesh nodes per building (174 across six buildings)** while retaining the source positions/scales/rotations in metadata for regression tests. The expanded exterior test checks all six building archetypes, instance counts, dimensions, and brace angles.

PR #10 was merged into main as **d15732598f3ffadde737ad5ec528f27e14032dbc**. Godot validation/export **#160** passed all 32 steps, including import, 26 regression scripts, the new exterior batching test, main-scene launch and Windows x86_64 export. Windows Build **#163** also completed successfully and produced a real 1280×720/30 FPS preview (52.60 s video) plus diagnostics.

I inspected the #163 capture and its route log. The same software-rendered route measured **51.99 s**, compared with 51.88 s baseline: +0.11 s (+0.2%), effectively recovering the prior timing while retaining the facade details. The saloon and general-store shutters, side framing and framed trade signs are visible. The close saloon approach still crops the upper signboard edge; this is a known camera-framing defect, not a model-generation failure.

The renderer still reports missing `VK_KHR_surface`, falls back to OpenGL Compatibility on Mesa llvmpipe, and disables SSAO/SDFGI/SSIL. The timing comparison is useful only as a same-runner software-renderer regression check; it is not a target-GPU benchmark. No independent whole-game art review, high-end hardware performance test, complete interior/weather route review, or AAA sign-off has been completed. Next: widen/back off the saloon approach camera to keep the full signboard in frame, then continue building-specific silhouettes and roof/porch joinery. AAA remains **not achieved**.

## 2026-11-20 camera-framing follow-up — saloon storefront

The #163 facade preview showed that the close saloon approach cropped the top edge of the new signboard. PR #11 moved the saloon approach/exit camera from z=-2.7 m to z=0.5 m, kept it centered on the open doorway, and re-aimed the exit toward the street. The route regression now requires the 8 m+ full-facade framing distance while preserving all 15 stops, the centered doorway transitions, building clearance, and the 24.0-second authored travel budget.

PR #11 was merged into main as **b245222c84988bae33cd308b828dfa92e3e1b109**. Godot validation/export **#163** passed all 32 workflow steps, including the updated preview-route test, main-scene launch and Windows x86_64 export. Windows Build **#166** completed successfully and produced a real 1280×720/30 FPS capture (72.63 s video) plus diagnostics. I inspected the saloon approach frame: the full trade signboard, both shutters, and the porch now fit in frame.

The #166 software-rendered route measured **71.69 s**, above the 60 s advisory threshold but below the 85 s hard CI budget. This is slower than the #163 batched-facade measurement of 51.99 s. The difference is observed, but a single llvmpipe run cannot isolate whether the wider storefront view, runner load, or another variable caused it. Keep this as a performance follow-up; do not present it as a target-GPU benchmark. Renderer diagnostics remain unchanged: Vulkan surface is unavailable, OpenGL Compatibility uses Mesa llvmpipe, and SSAO/SDFGI/SSIL are disabled.

Next: profile the town facade visibility/LOD and repeat the preview timing under controlled conditions; retain the wider saloon framing unless a less expensive camera composition can preserve the full signboard. Continue the business-specific silhouettes, roof/porch joinery, interiors, weather, and target-GPU measurements. AAA remains **not achieved**.


## 2026-11-21 follow-up — shared timber shader, shared shingle material, and batched side courses

Started from main `de4d5da497ed9c333545e34fd2760977e1bfaf7d` after reviewing the latest commit, CI run #165, Windows workflow history, and open issues/PRs (none). The previous facade work still constructed the same weathered-wood shader source repeatedly for each wood material, allocated identical roof-shingle materials per building, and represented the 14 horizontal side courses as separate mesh nodes on each building.

Three implementation passes on `automation/2026-11-21-wood-material-and-siding-batches`:

1. Cache a single weathered-wood `Shader` per world and reuse it across tinted/scale-varied `ShaderMaterial` instances. Tint and grain-scale remain material uniforms, so material variation is preserved while duplicate shader resources are removed.
2. Lazily create and reuse one vertex-color roof-shingle `StandardMaterial3D` across the six buildings; preserve the authored vertex colors and roughness.
3. Replace 14 separate side-course boxes per building with one 14-instance `MultiMesh` batch. Preserve source positions/scales in metadata and extend the exterior regression to assert the batch budget and dimensions across all six building archetypes.

The exterior regression additionally verifies that every building shares the exact wood shader and shingle material resource. This is a source/resource optimization, not a claim of measured GPU frame-rate improvement. Fresh Godot validation, Windows export, and a visually inspected render are required before the change is treated as verified. The current runner's Vulkan surface limitation and lack of target-device benchmarking remain blockers. AAA remains **not achieved**.


## 2026-11-22 follow-up — distinct stable, sheriff, and general-store architecture

Started from the post-merge main commit `55193aee4d44dcf3a5f943616b7eb14613f68218`. Reviewed PR #12 and both final workflows: Godot validation #168 passed all 26 existing regression scripts, main-scene launch, and Windows x86_64 export; Windows Build #171 succeeded and produced a 71.63-second 1280×720/30 FPS preview. The preview was extracted and inspected at the storefront, saloon interior, and town overview. It confirms that the six buildings still share a nearly identical single-story shell, and that the general store lacks weather protection while the stable and sheriff office read like ordinary shops. The render remains Mesa llvmpipe/OpenGL Compatibility, not target-GPU evidence.

Three architectural passes were implemented on `automation/2026-11-22-distinct-frontier-archetypes`:

1. **Stables:** Added a track-mounted pair of sliding timber door leaves with diagonal braces and iron rollers, plus a framed hayloft vent with five vertical slats and two horizontal rails. The original walkable shell and interior collision remain unchanged.
2. **Sheriff office:** Added an eight-instance iron grille batch (six vertical bars and two crossbars) positioned behind the shutters, and a separate ten-point brass star badge with a center stud. The badge radius was adjusted after a bounds review so the regression can distinguish the star silhouette from a circle.
3. **General store:** Added an eight-stripe, two-sided canvas awning with a short valance, two sloped timber support arms, and a front rail. A source review caught a potential seam between adjacent stripes; the drop is now evaluated at shared stripe boundaries so the panels meet continuously.

Added `tests/test_building_archetypes.gd` and wired it into `.github/workflows/godot-validation.yml`. The test checks stable door/vent batches, sheriff grille counts and metallic star geometry, general-store awning vertex colors/material/bounds, and prevents archetype details from leaking onto unrelated buildings.

Source-level checks after each pass confirmed the dispatcher, stable geometry, sheriff grille/badge construction, and continuous awning boundary calculations. Godot is not installed in the local container, so runtime parsing and the new regression await GitHub Actions. The final PR must pass the complete Godot suite and Windows x86_64 export before merge. No new visual capture has yet been produced for these changes. Next: inspect the new three-archetype render, then give the hotel and rail office distinct silhouettes and continue target-hardware profiling. AAA remains **not achieved**.


### Visual correction after #173 capture

Windows Build #173 completed successfully and its real 1280×720/30 FPS capture was inspected. The striped general-store awning is visible in the street composition, but the sheriff badge read only as a small bright point beneath the deep gable shadow. This is a visible defect, so the badge was moved slightly forward, given two-sided rendering, a restrained low-energy brass emission, and a brighter worn-gold albedo. The regression now checks culling, emission, and forward placement as well as mesh bounds. The 15-stop route completed in 37.83 seconds on llvmpipe; this is a software-renderer route duration, not an FPS benchmark. Re-run Godot validation, Windows export, and a fresh visual capture before merge.


### Final verification and merge — PR #13

The badge readability correction was validated on the final PR head. Godot validation/export **#173** passed all **33** steps, including the new three-archetype regression, main-scene headless launch, and Windows x86_64 export. Windows Build **#176** passed script validation, completed the unchanged 15-stop preview route, exported the Windows executable, and uploaded the build, preview, and diagnostics.

The real preview is **1280×720 at 30 FPS**, 53.6 seconds long; the route completion marker reported 52.33 seconds on Mesa llvmpipe. The capture was inspected: the sheriff star is now clearly visible above the storefront sign, and the general-store awning reads in the street view. The fixed route does not isolate the stable sliding doors and hayloft vent, so those are source- and regression-verified but still need a dedicated close-up visual review.

PR #13 was squash-merged into main as **2656fb0b1f5058e33090466bbb32605a4b9279e6**. Next: add a separate stable close-up inspection route without changing the baseline 15-stop control route; continue distinct hotel and rail-office silhouettes, then profile target-GPU performance. Renderer limitations remain: the CI host lacks `VK_KHR_surface`, falls back to OpenGL Compatibility on Mesa llvmpipe, and disables SSAO/SDFGI/SSIL. No target-device benchmark or independent whole-game art review exists. AAA remains **not achieved**.


## 2026-11-23 — indexed terrain lattice and cached height samples

Started from verified main `e6b464a89140de1098454028dcb4c441ecfa9229`. Reviewed the latest main commit, successful Godot validation/export #175, successful Windows Build #178, the latest development log, and open issues/PRs (none). Continued the unfinished terrain/LOD performance work rather than repeating storefront or dinosaur changes.

Three focused passes:

1. **Terrain generation:** replaced the expanded triangle stream with a shared indexed grid. Each lattice point is added once and adjacent cells reference the shared corners using the prior triangle winding. This reduces the 256-segment visual grid from 393,216 repeated vertex submissions to 66,049 unique grid vertices while retaining 393,216 triangle indices.
2. **Height evaluation:** precompute each grid height once into a packed float array before building triangles. Previously each corner height was re-evaluated in adjacent cells, up to six times per lattice point. The 192-segment collision grid similarly now samples 37,249 unique lattice positions rather than emitting 221,184 repeated vertex records. Terrain shape still comes from the same authored `_terrain_height` function, so visual/collision profile alignment is preserved.
3. **Regression coverage:** updated `test_terrain_relief.gd` to assert exact shared-grid vertex and index counts, deterministic world-space lattice coordinates, valid indices, generated upward normals, collision mesh omission of normals, and interpolation against the indexed collision triangles at the existing 441 sample points.

This is a topology/submission optimization, not a visual asset claim. The code and regression were committed to a review branch. Godot is unavailable in the local execution container, so no local engine parse or render is claimed; GitHub Actions must validate the indexed SurfaceTool path and Windows export before merge. The previous successful main CI does not validate these new commits. No new video was produced in this pass. Next: inspect the PR validation and Windows build artifacts, fix any engine/API or normal-winding regressions, and merge only after checks pass. Target-GPU profiling and independent whole-game visual review remain unavailable; AAA is **not achieved**.
