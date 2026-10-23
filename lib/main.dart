import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  for (final asset in const [
    ('Plus Jakarta Sans', 'assets/licenses/PlusJakartaSans-OFL.txt'),
    ('JetBrains Mono', 'assets/licenses/JetBrainsMono-OFL.txt'),
    ('color-name-list', 'assets/licenses/color-name-list-LICENSE.txt'),
    ('MOSAIC R4 room model', 'assets/licenses/room-model-LICENSE.txt'),
    ('MOSAIC R4 room model', 'assets/licenses/room-model-NOTICE.txt'),
    ('MiDaS room depth model', 'assets/licenses/room-depth-LICENSE.txt'),
    ('MiDaS room depth model', 'assets/licenses/room-depth-NOTICE.txt'),
  ]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        asset.$1,
      ], await rootBundle.loadString(asset.$2));
    });
  }
  runApp(const ProviderScope(child: ColorLabApp()));
}
