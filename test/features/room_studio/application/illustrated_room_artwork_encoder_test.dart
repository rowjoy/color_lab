import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('encodes the complete colored Study artwork at 2400 x 1600', (
    tester,
  ) async {
    final png = await tester.runAsync(
      () => SvgIllustratedRoomArtworkEncoder().encodePng(_distinctDraft()),
    );

    expect(png, isNotNull);
    expect(png!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final decoded = image.decodePng(png);
    expect(decoded, isNotNull);
    expect((decoded!.width, decoded.height), (2400, 1600));
    _expectRgb(decoded, (1200, 440), '#D11111');
    _expectRgb(decoded, (1200, 80), '#11D111');
    _expectRgb(decoded, (2200, 1520), '#1111D1');
    _expectRgb(decoded, (1200, 1180), '#D1A111');
    _expectRgb(decoded, (360, 500), '#9FD7EA');
  });

  testWidgets('rejects grayscale before loading any picture', (tester) async {
    var loads = 0;
    final encoder = SvgIllustratedRoomArtworkEncoder(
      loadPicture: (draft) async {
        loads++;
        return IllustratedRoomLoadedPicture(
          picture: _emptyPicture(),
          size: const ui.Size(1200, 800),
        );
      },
    );

    await expectLater(
      encoder.encodePng(
        IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study),
      ),
      throwsA(isA<IllustratedRoomRenderException>()),
    );
    expect(loads, 0);
  });

  testWidgets('maps missing and private loader failures to one safe type', (
    tester,
  ) async {
    final missing = IllustratedRoomTemplate(
      id: 'missing-room',
      title: 'Missing room',
      summary: 'Missing encoder fixture.',
      assetPath: 'assets/rooms/not-present.svg',
      defaultPaletteId: 'fallback',
      palettes: [
        IllustratedRoomPalette(
          id: 'fallback',
          name: 'Fallback',
          guidance: 'Test-only fallback.',
          colors: IllustratedRoomCatalog.study.defaultPalette.colors,
        ),
      ],
      surfaceLabels: const IllustratedRoomSurfaceLabels(
        wall: 'Wall',
        ceiling: 'Ceiling',
        floor: 'Floor',
        furniture: 'Furniture',
      ),
      focalPoint: const IllustratedRoomFocalPoint(x: 0, y: 0),
      paletteReviewLabel: 'Test review',
      paletteSourceNote: 'Test display note.',
    );
    final missingDraft = IllustratedRoomDraft.grayscale(
      missing,
    ).applyPalette('fallback');
    final missingFailure = await tester.runAsync(
      () => _failureOf(
        SvgIllustratedRoomArtworkEncoder().encodePng(missingDraft),
      ),
    );
    expect(missingFailure, isA<IllustratedRoomRenderException>());

    final privateFailure = await _failureOf(
      SvgIllustratedRoomArtworkEncoder(
        loadPicture: (_) async => throw StateError('private asset detail'),
      ).encodePng(_distinctDraft()),
    );
    expect(privateFailure, isA<IllustratedRoomRenderException>());
    expect(privateFailure.toString(), isNot(contains('private asset detail')));
  });

  testWidgets('rejects an incompatible artboard and disposes its picture', (
    tester,
  ) async {
    final source = _emptyPicture();
    final encoder = SvgIllustratedRoomArtworkEncoder(
      loadPicture: (_) async => IllustratedRoomLoadedPicture(
        picture: source,
        size: const ui.Size(600, 400),
      ),
    );

    await expectLater(
      encoder.encodePng(_distinctDraft()),
      throwsA(isA<IllustratedRoomRenderException>()),
    );
    expect(source.debugDisposed, isTrue);
  });

  testWidgets('disposes source, scaled picture and image after encoding', (
    tester,
  ) async {
    final source = _emptyPicture();
    final disposedPictures = <ui.Picture>[];
    final disposedImages = <ui.Image>[];
    final previousPictureDispose = ui.Picture.onDispose;
    final previousImageDispose = ui.Image.onDispose;
    ui.Picture.onDispose = disposedPictures.add;
    ui.Image.onDispose = disposedImages.add;
    addTearDown(() {
      ui.Picture.onDispose = previousPictureDispose;
      ui.Image.onDispose = previousImageDispose;
    });
    final encoder = SvgIllustratedRoomArtworkEncoder(
      loadPicture: (_) async => IllustratedRoomLoadedPicture(
        picture: source,
        size: const ui.Size(1200, 800),
      ),
    );

    final png = await tester.runAsync(
      () => encoder.encodePng(_distinctDraft()),
    );

    expect(png, isNotNull);
    expect(source.debugDisposed, isTrue);
    expect(disposedPictures, hasLength(2));
    expect(disposedPictures, contains(source));
    expect(disposedImages, hasLength(1));
    expect(disposedImages.single.debugDisposed, isTrue);
  });
}

IllustratedRoomDraft _distinctDraft() {
  var draft = IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study);
  for (final entry in <IllustratedRoomSurface, String>{
    IllustratedRoomSurface.wall: '#D11111',
    IllustratedRoomSurface.ceiling: '#11D111',
    IllustratedRoomSurface.floor: '#1111D1',
    IllustratedRoomSurface.furniture: '#D1A111',
  }.entries) {
    draft = draft.setSurfaceColor(entry.key, RgbColor.fromHex(entry.value));
  }
  return draft;
}

ui.Picture _emptyPicture() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1200, 800),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  return recorder.endRecording();
}

Future<Object> _failureOf(Future<void> future) async {
  try {
    await future;
  } catch (error) {
    return error;
  }
  throw StateError('Expected the future to fail');
}

void _expectRgb(image.Image decoded, (int, int) anchor, String hex) {
  final expected = RgbColor.fromHex(hex);
  final pixel = decoded.getPixel(anchor.$1, anchor.$2);
  expect(
    [pixel.r, pixel.g, pixel.b],
    [
      closeTo(expected.red, 1),
      closeTo(expected.green, 1),
      closeTo(expected.blue, 1),
    ],
    reason: 'anchor $anchor should render $hex',
  );
}
