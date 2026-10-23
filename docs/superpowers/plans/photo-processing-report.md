# Photo processing delivery

Implemented the three planned public interfaces in the owned files:

- `PreparedPhoto({required int width, required int height, required Uint8List rgbaBytes, required Uint8List previewBytes, required List<PaletteColor> palette})`, with public final fields of the same names and `RgbColor sample(double x, double y)`.
- Pure Dart top-level `PreparedPhoto preparePhoto(Uint8List bytes)`.
- `abstract interface class PhotoProcessor { Future<PreparedPhoto> prepare(Uint8List bytes); }`, `const IsolatePhotoProcessor()`, and overridable Riverpod `photoProcessorProvider`.

`PreparedPhoto` copies incoming bytes and palette, exposes unmodifiable typed-data views/list, and requires positive dimensions with exactly width × height × 4 RGBA bytes. Finite sample coordinates clip to image edges and map using floor(x × width), floor(y × height); nonfinite coordinates throw `ArgumentError`. The production factory returns opaque RGBA and PNG with identical oriented dimensions.

## Errors and limits

The exact error API is `enum PhotoProcessingFailure { invalidImage, tooLarge, unsupported }` and `final class PhotoProcessingException implements Exception { const PhotoProcessingException(this.kind); final PhotoProcessingFailure kind; }`. `toString()` includes only the category, never raw codec details.

Public limits are `maxPhotoEncodedBytes = 32 * 1024 * 1024`, `maxPhotoDecodedPixels = 24000000`, `maxPhotoDecodedAxis = 16384`, `maxPhotoPreviewAxis = 1600`, and `maxPhotoPaletteAxis = 200`. Limits are inclusive. Encoded bytes are checked before parsing or isolate input copying. Codec header dimensions are checked before frame decode; each decoder also receives a 24-million-pixel budget. Malformed PNG and BMP fixtures prove header-based rejection. The application checks the returned frame dimensions again before further processing.

Supported decoder signatures are JPEG, PNG, GIF, WebP, BMP, and TIFF. Known ISO-BMFF image containers (including HEIF/HEIC/AVIF) and PSD return `unsupported`; unrecognized/corrupt bytes return `invalidImage`. This intentionally limits the decoder surface instead of probing every package format.

## Processing behavior

Only frame zero is decoded. GIF/WebP partial first frames are placed at their declared offsets on a white canvas, with orientation applied after placement. JPEG image 4.12.0 already bakes and removes EXIF orientation; the pipeline checks remaining orientation before applying it to avoid double rotation. All eight JPEG orientations are covered by fixtures.

Indexed/16-bit/alpha images are normalized to opaque 8-bit RGB by compositing over white before downsampling. The preview is bounded to 1600px, preserving aspect ratio and a minimum axis of one pixel. Palette input is bounded to 200px and uses the existing `extractPalette` with k=8, seed=42, mergeThreshold=8. Population fractions come from the sampled image; solid or low-variety images return their actual number of clusters. Area-resizing may average small details, so palette percentages are estimates of the reduced preview, not exact original-image segmentation.

The installed image package's animated WebP path bypasses its explicit pixel budget for the embedded bitstream and loses container EXIF. The implementation wraps the first ANMF frame as a bounded still WebP, validates actual dimensions against the frame descriptor before pixel decode, rejects nested/ambiguous image chunks, and restores container EXIF. This avoids decoding the animation and closes that allocation path.

Decoded channel values are interpreted as sRGB consistently by the sampler and PNG preview. Source ICC tags are removed from output so the renderer cannot independently reinterpret the preview. Wide-gamut/profile conversion and physical-device color calibration are outside this delivery. Codec pixel caps bound image area, but peak process memory has not been measured on physical devices; decoding/normalizing still has intermediate image allocations. The native picker dimension cap owned by the acquisition task normally provides a smaller input.

`IsolatePhotoProcessor` snapshots input before asynchronous work and calls Flutter `compute(preparePhoto, bytes)`. The top-level callback and its imports are pure Dart; only the adapter imports Flutter/Riverpod. On Flutter web, compute follows Flutter's web execution semantics and does not create a native isolate.

## Verification

Tests were written before production files and first failed because the planned APIs were missing. Subsequent functional red/green cycles caught partial GIF canvas placement, animated WebP EXIF loss, partial WebP orientation loss, and source ICC propagation. A tiny GIF fixture initially encoded as black due to neural quantization; explicit palette fixtures fixed the test data rather than changing the decoder.

- `flutter test test/core/image test/features/picker/photo_processing`: 35 passed, zero failures.
- `flutter analyze lib/features/picker/domain/prepared_photo.dart lib/core/image/photo_processing.dart lib/features/picker/application/photo_processor.dart test/core/image test/features/picker/photo_processing`: no issues.
- `dart format` run on all three production files and their scoped tests.

Coverage includes literal pixel order, matching preview bytes, floor mapping/clipping/nonfinite inputs, defensive snapshots, dimensions/buffer validation, alpha/indexed/16-bit normalization, hidden transparent RGB before resize, palette fractions/determinism, preview/thin-image limits, EXIF orientations 1–8, animated first-frame/canvas behavior, malformed inputs, known unsupported format, encoded and decoded limits, embedded WebP budget, isolate results/failures, and caller mutation during processing.

Full-suite integration is owned by root and deliberately deferred while sibling UI implementation is in progress, at root's request. No platform camera/gallery behavior or physical-device memory/color claim follows from these synthetic tests.
