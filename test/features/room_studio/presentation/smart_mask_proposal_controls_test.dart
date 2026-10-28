import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/smart_mask_proposal_controller.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/smart_mask_proposal.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_fullscreen_editor.dart';
import 'package:color_lab/features/room_studio/presentation/smart_mask_proposal_controls.dart';
import 'package:color_lab/features/room_studio/refine/smart_mask_proposal_service.dart';
import 'package:color_lab/features/room_studio/segmentation/room_wall_depth_protection.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../application/smart_mask_proposal_controller_test.dart'
    show Harness, FakeProposals;

void main() {
  test(
    'production binding is disabled and disabled service abstains on unaligned data',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(smartMaskAvailabilityProvider),
        SmartMaskAvailability.disabledByEvidence,
      );
      final service = container.read(smartMaskProposalServiceProvider);
      expect(service, isA<DisabledSmartMaskProposalService>());
      expect(
        await service.propose(
          key: SmartMaskProposalKey(
            projectId: 'p',
            photoId: 'f',
            maskRevision: 0,
            layer: RoomLayer.wall,
            action: SmartMaskAction.add,
          ),
          normalizedSeed: const Offset(double.nan, double.infinity),
          photo: PreparedPhoto(
            width: 1,
            height: 1,
            rgbaBytes: Uint8List(4),
            previewBytes: Uint8List(0),
            palette: [],
          ),
          aiMasks: MaskBitmap(width: 2, height: 1, labels: Uint8List(2)),
          currentMasks: MaskBitmap(width: 3, height: 1, labels: Uint8List(3)),
          intent: MaskIntentBitmap.untouched(width: 4, height: 1),
          depth: RoomDepthFrame(
            width: 1,
            height: 1,
            inverseDepth: Float32List.fromList([1]),
          ),
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'disabled controls and actual editor expose no smart semantics; manual actions remain',
    (tester) async {
      final fake = FakeProposals();
      final h = Harness(service: fake);
      addTearDown(h.container.dispose);
      // Provider futures created in the widget test zone need pumping while
      // the photo decoder completes outside that zone, as in editor tests.
      var opened = false;
      final opening = h.editor
          .openProject('project-1')
          .then((value) => opened = value);
      for (var attempt = 0; attempt < 200 && !opened; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(opened, isTrue);
      await opening;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: const MaterialApp(
              home: Scaffold(body: SmartMaskProposalControls()),
            ),
          ),
        );
        expect(find.byType(Text), findsNothing);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: const MaterialApp(
              home: RoomMaskFullscreenEditor(photoId: 'photo-1'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        expect(
          find.bySemanticsLabel(
            RegExp('Smart (Add|Remove|Cleanup)', caseSensitive: false),
          ),
          findsNothing,
        );
        expect(
          find.textContaining(RegExp('smart', caseSensitive: false)),
          findsNothing,
        );
        for (final value in ['add', 'erase']) {
          expect(
            find.byKey(ValueKey('room-mask-fullscreen-tool-$value')),
            findsOneWidget,
          );
        }
        expect(find.byTooltip('Undo'), findsOneWidget);
        expect(find.byTooltip('Redo'), findsOneWidget);
        expect(fake.requests, isEmpty);
        expect(h.saves, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );

  test(
    'app About and localized marketing copy contain no smart mask correction claim',
    () {
      final claim = RegExp(
        r'\bsmart[ -]?(?:mask|add|remove|cleanup|correction)',
        caseSensitive: false,
      );
      for (final root in ['lib/l10n', 'lib/features/settings/presentation']) {
        final directory = Directory(root);
        expect(directory.existsSync(), isTrue);
        for (final file
            in directory.listSync(recursive: true).whereType<File>()) {
          expect(
            file.readAsStringSync(),
            isNot(matches(claim)),
            reason: file.path,
          );
        }
      }
    },
  );
}
