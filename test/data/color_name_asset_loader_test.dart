import 'dart:convert';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/assets/color_name_asset_loader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.json);
  final String? json;
  int reads = 0;

  @override
  Future<ByteData> load(String key) async {
    reads++;
    if (json == null) throw StateError('Missing asset');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(json!)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the complete bundled dataset and finds an exact red match',
    () async {
      final namer = await ColorNameAssetLoader().load();
      expect(namer.colors, hasLength(31943));
      final red = RgbColor(255, 0, 0);
      final nearest = namer.nearest(red);
      expect(nearest.color, red);
      expect(deltaE76(nearest.lab, red.toLab()), 0);
    },
  );

  test('loads upstream schema from injected bundle once', () async {
    final bundle = _StringBundle('[{"name":"Ocean Blue","hex":"#0044ff"}]');
    final loader = ColorNameAssetLoader(bundle: bundle);
    final names = await Future.wait([loader.load(), loader.load()]);
    expect(names.first.nearest(RgbColor(0, 68, 255)).name, 'Ocean Blue');
    expect(identical(names.first, names.last), isTrue);
    expect(bundle.reads, 1);
  });

  test(
    'missing, empty and malformed assets return useful offline fallback',
    () async {
      for (final json in [null, 'not json', '[]', '[{}]']) {
        final namer = await ColorNameAssetLoader(
          bundle: _StringBundle(json),
        ).load();
        expect(namer.nearest(RgbColor(255, 0, 0)).name, 'Red');
        expect(namer.nearest(RgbColor(0, 0, 0)).name, 'Black');
        expect(namer.nearest(RgbColor(255, 255, 255)).name, 'White');
      }
    },
  );
}
