# Task 8 implementation report

Status: DONE. No commits created. Task 9 APIs are ready. Final focused gate:
19/19 passing. Final full gate: 758/758 passing (739 baseline + 19 new).

## Files and behavior

- `lib/features/room_studio/application/mask_overlay_service.dart`: exact
  `MaskOverlayService.render({required MaskBitmap masks, required RoomLayer
  layer, required RgbColor tint, int featherRadius = 2}) -> Future<Uint8List>`;
  `IsolateMaskOverlayService` and `maskOverlayServiceProvider`. Runs the existing
  `buildLayerAlpha` and real RGBA PNG encoding inside `Isolate.run`.
- `lib/features/room_studio/presentation/room_mask_viewport.dart`: exact requested
  `RoomMaskViewport` constructor; consumes existing `RoomMaskTool`. Owns decoded
  images, one current overlay cache entry and transient gesture state only.
- `test/features/room_studio/presentation/mask_overlay_service_test.dart`:
  2 actual worker PNG tests.
- `test/features/room_studio/presentation/room_mask_viewport_test.dart`:
  17 real widget/raster/gesture/cache/semantics tests.

Read-only baseline comparison against
`/private/tmp/color-lab-task8-base.68TpbU/source` confirms the only `lib` additions
are the two files above, and the only `test` addition is their presentation
directory. No existing producer/model/controller/Capture/README/config was edited.

## Integration contract for Task 9

Place the viewport inside finite width/height constraints. Pass the current
immutable photo/masks, photo ID, mask revision, selected layer/tool, brush
fraction, visibility and edit-enabled flags. Supply `onStroke`; it fires exactly
once for an accepted one-pointer up and carries the captured layer, add/erase
mode, normalized disconnected segments and brush diameter. The screen still
captures photo ID and revision for the Task 7 controller command.

Move supports one-pointer pan and anchored two-pointer pinch, zoom 1–8. Add and
Erase buffer until up; second pointers, cancel events, tool/layer/photo/revision/
enable/visibility/brush changes roll back the preview. Resizing cancels a pending
stroke. Off-image and off-visible-viewport travel create disconnected gaps,
including when the zoomed image extends beyond the widget clip. An eager gesture
recognizer owns viewport interactions against the surrounding editor ScrollView.

The photo, PNG and vector preview all use the same `PhotoViewport.imageRect`;
hits use its inverse plus the visible clip. The original PNG is decoded unchanged.
The selected-layer overlay uses the existing theme primary tint at 45% display
opacity; service PNG alpha itself remains the exact derived kernel alpha.
Original-only and disabled brush modes cannot submit strokes. Image semantics
say `Room photo, Wall mask preview` (selected layer varies), or `Original room
photo`; failed overlay rendering is described as unavailable. No recolor,
accuracy/confidence claims, or pixel work in build/paint.

Cache key: photoId, maskRevision, layer, tint and feather radius (2 in viewport).
No mask pixel equality checks. Rebuild, resize, Move and visibility toggles reuse
the current decoded result. A changed key clears the old overlay synchronously;
generation checks guard both PNG completion and decoded-image completion. A new
photo ID or PreparedPhoto identity resets transforms and immediately clears the
old photo. Ordinary layer/theme/revision changes preserve zoom/pan. Task 9 can
change the widget key for an explicit Restore reset without making every revision
reset the transform.

Each stale decoded image is disposed. Codecs are disposed in `finally`. Widget
disposal invalidates both generations and disposes current decoded images. PNG
buffers are not retained as a second cache. Isolate.run owns and closes its
worker/ports; obsolete in-flight worker operations are allowed to finish and their
output is discarded. No long-lived worker, callback port or model is owned here.

## TDD and focused verification

Every Flutter command below retained this exact prefix:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter
```

Initial RED before adding either production file:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/mask_overlay_service_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart --reporter expanded
```

The first sandboxed invocation exited 71 (`sandbox_apply: Operation not permitted`)
before Flutter ran. Reissued with approved execution escalation while retaining
the inner compiler-denial profile. That RED exited 1, `+0 -2`: both test files
failed to load because the requested service/viewport production files and their
APIs did not yet exist. No unrelated import/type failures occurred.

The first implementation run passed the two worker tests, then exposed a raster
test harness hang: `toImage` was awaited inside fake async. Interrupted that run;
it reported `+2` and one incomplete widget test plus interruption finalization
noise (the tool returned exit 0 for the interrupt; this was not a passing run).
Moved raster capture into `tester.runAsync`, matching existing raster test
practice. The same focused command then exited 0, 15/15 passing.

Additional genuine regression RED before fixing parent-scroll ownership:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_mask_viewport_test.dart --plain-name 'viewport claims brush and Move drags inside a scrolling editor' --reporter expanded
```

Exited 1, `+0 -1`: expected parent offset 0, actual 80. A scale recognizer still
lost to vertical scrolling at the lower drag slop (focused `+17 -1`, actual offset
60). Checked Flutter's recognizer source, then used an eager recognizer because
all transform/edit calculations already use raw pointer events. Focused command
exited 0, 18/18. Added cache tint/visibility coverage; the first run exited 1,
`+18 -1` because MaterialApp theme animation hadn't yet delivered its new tint.
Made the harness theme transition immediate, consistent with its reduced-motion
configuration. No production change was needed for tint invalidation.

Final focused GREEN used the initial exact two-file command above. Exit 0:
`00:02 +19: All tests passed!`. No warnings/errors in that run.

## Actual evidence

- Worker PNG at independently known 7×7 fixture coordinates: center RGB
  17/99/201 and alpha255; distant floor pixel alpha0; radius1 edge alpha64;
  corner alpha143. Input labels remain unchanged.
- Non-square 9×5 PNG retains dimensions, only selected ownership contributes;
  default radius2 center alpha255, boundary175, distant other-layer alpha0.
  Invalid radius3 returns ArgumentError.
- Raster captures of the actual installed painter prove the selected left wall
  region is tinted and the right floor remains exact original `[100,100,100,255]`.
  Resizing 320×320 (letterboxed) to240×120 preserves corresponding pixels.
  Selecting floor reverses which region is tinted. Hiding the overlay restores
  exact original pixels and the original preview bytes remain unchanged.
- Vector preview changes an actual on-image pixel during down, disappears after
  accepted up, and does not mutate masks. Captured stroke begins at(.25,.5),
  disconnects through the letterbox, and re-enters at(.75,.5).
- At2× zoom, clipped travel outside the widget disconnects despite still being
  inside the larger image; accepted coordinates are .375 and .625. A40px pan
  maps the next hit to .3125. Revision/theme edits preserve this transform;
  a new photo returns it to .25. Zoom clamp checks map to .46875 at8× and .25
  after a pinch below1×. Move/rebuild/resize never add service render calls.
- Second-pointer and cancel sequences emit no command. Accepted up emits once.
  Individual tool/layer/photo/revision/disable/hide/brush mutations cancel active
  previews. Parent scroll remains at0 during both Add and Move drags.
- Revision change clears the old red raster immediately; new-photo green
  completion wins over late old red PNG. Replacement photo gray50 is never
  contaminated by an older overlay, including a decode started before the
  replacement. Completion after disposal causes no exception. Tint change
  invalidates; original toggle reuses cached PNG.
- 360dp viewport,2× text, reduced motion, light and dark themes: image semantics
  describe mask previews, original-only and disabled do not paint, no layout or
  framework exception. The explicit semantics handle is disposed inline.

## Final gates

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze lib/features/room_studio/application/mask_overlay_service.dart lib/features/room_studio/presentation/room_mask_viewport.dart test/features/room_studio/presentation/mask_overlay_service_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart
```

Exit0, `No issues found!`. An earlier analyzer invocation found one braces-style
info; fixed before the final clean run.

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Exit0, `Formatted 183 files (0 changed)`. Formatting edits were restricted to the
four Task8 Dart files before this read-only global gate.

Exactly one final full suite was run:

```sh
/usr/bin/sandbox-exec -f /private/tmp/color-lab-no-native.XP4L3M/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
```

Exit0, `00:20 +758: All tests passed!`. No failed/skipped tests or native-compiler
attempt was reported. Barrier retained for every Flutter invocation. No SDK,
dependency or build configuration changes, cache deletion, native build/install,
data clear, APK generation, or `dart run` was performed.

## Self-review and limits

Reviewed lifecycle generations/disposal, shared geometry, clip gaps, one-command
ownership, same-key cache reuse and transform preservation. Corrected parent
scroll interception with a demonstrated regression. The requested four-file
scope is intact; viewport is one focused widget plus its private painter.

This proves Flutter raster and gesture behavior on the host test renderer, not
phone compatibility or model accuracy. Tests use explicitly synthetic masks and
photos for known pixel expectations; no synthetic output is presented as AI
evidence. No standalone preview artifact was added in Task8. Existing AI gate,
24/32MiB limits,24Mpixel/16384axis/1600working bounds and Android24/iOS13 floors
remain untouched. The viewport has no new interaction controls; the Task9 screen
owns 48dp controls and full editor accessibility/navigation. No outstanding
correctness concern identified during self-review.
