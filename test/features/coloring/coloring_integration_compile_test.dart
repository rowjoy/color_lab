import 'package:color_lab/features/coloring/presentation/coloring_catalog_screen.dart';
import 'package:color_lab/features/games/presentation/games_screen.dart';
import 'package:color_lab/features/learning/presentation/experiment_notebook_screen.dart';
import 'package:color_lab/features/my_work/presentation/my_work_screen.dart';
import 'package:color_lab/features/settings/application/local_data_providers.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Coloring Studio host integrations compile against canonical APIs', () {
    expect(appRouterProvider, isNotNull);
    expect(localDataManagerProvider, isNotNull);
    expect(const ColoringCatalogScreen(), isA<Widget>());
    expect(const GamesScreen(), isA<Widget>());
    expect(const ExperimentNotebookScreen(), isA<Widget>());
    expect(const MyWorkScreen(), isA<Widget>());
  });
}
