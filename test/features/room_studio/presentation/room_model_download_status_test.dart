import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/presentation/room_model_download_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, RoomModelDownloadStage stage) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomModelDownloadStatus(
            progress: RoomModelDownloadProgress(
              stage: stage,
              receivedBytes: 512,
              totalBytes: 1024,
              modelName: 'room_depth.tflite',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows actual fraction and explains private offline setup', (
    tester,
  ) async {
    await show(tester, RoomModelDownloadStage.downloading);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
    expect(find.textContaining('50%'), findsOneWidget);
    expect(
      find.textContaining('Your photo stays on this device'),
      findsOneWidget,
    );
  });

  testWidgets('verification is not presented as download complete', (
    tester,
  ) async {
    await show(tester, RoomModelDownloadStage.verifying);
    expect(find.text('Verifying AI models…'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('idle store does not show download UI', (tester) async {
    await show(tester, RoomModelDownloadStage.idle);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
