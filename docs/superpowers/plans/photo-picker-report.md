# Photo acquisition and sampling report

Implemented task 3 in the authorized shared workspace. Only task-owned files were changed.

## Public integration contract

- `PhotoPickerService.pick()` and `recoverLost()` return `Future<PreparedPhoto?>`; cancellation and empty lost-data responses return null. `openSettings()` returns `Future<bool>` and safely returns false when settings cannot open.
- `photoPickerServiceProvider` creates `PluginPhotoPickerService` using `photoProcessorProvider`. Its constructor also accepts an `ImagePicker`, `PhotoProcessor`, `TargetPlatform`, and settings callback for boundary tests.
- `PhotoPickFailure.kind` uses `PhotoPickFailureKind.permissionDenied`, `unavailable`, `invalidImage`, `tooLarge`, or `processing`. Raw platform messages never enter the failure description. Unsupported decode formats become `invalidImage`.
- Native gallery selection requests a 2048×2048 maximum and disables full metadata requests. A 24 MiB encoded size guard runs before reading image bytes and again before processing.
- Lost-data retrieval calls the plugin only on Android, accepting both the files list and single-file response. No other platform invokes the recovery plugin at startup.
- `PhotoPickerScreen({required PreparedPhoto photo})` is ready for the root route. Acquisition errors belong to its caller.

## Behavior and file map

- `application/photo_picker_service.dart`: system picker, safe failure mapping, cancellation, Android recovery, and settings.
- `domain/photo_viewport.dart`: shared contain-fit, zoom/pan, forward reticle mapping, and inverse normalized touch coordinates. Letterboxed points are rejected.
- `presentation/photo_picker_screen.dart`: actual image preview, one-finger sampling, image-patch loupe while dragging, anchored pinch and two-finger pan, 1–8× zoom/reset, selected HEX/RGB/name, common gallery details, shared save/favorite actions, and selected-swatch Hero.
- Actual palette populations drive the shared `PaletteBar` percentage visualization and numeric swatch cards. Both open common color details with `ColorSource.gallery`. Tiny populations retain generous accessible controls through the shared bar component.
- The page scrolls at 360px and 2× text scaling. Controls use targets of at least 48dp. Gestures update immediately; detail transitions use the existing reduced-motion implementation.

## Verification

Tests use literal image pixels and real `PreparedPhoto`/image processing. Only external acquisition, settings, offline name loading, and local storage boundaries are replaced.

Final checks on October 21, 2026: `flutter test test/features/picker/photo_view` passed all 12 tests; scoped `flutter analyze` passed with no issues; `flutter test --reporter expanded` passed all 181 tests present at verification time. Changed Dart files were formatted.

- `photo_viewport_test.dart`: contain fitting, padding rejection, forward and inverse transforms with zoom/pan.
- `photo_picker_service_test.dart`: cancellation, actual processed color values, bounded picker options, denied/private errors, corrupt bytes, pre-read size rejection, Android list and single-file recovery, non-Android recovery suppression, and settings failure.
- `photo_picker_screen_test.dart`: real tap/drag colors, padding exclusion, loupe image patch visibility/lifecycle, actual pinch/pan sampling, reset, gallery detail/save source, rendered 3:1 percentage-bar widths from a 75/25 image, interactive percentage details, and 360px/2× layout.

Physical system picker behavior, process-death recovery on an Android device, and device display/profile color appearance still require device verification. Synthetic tests validate application transforms and values.
