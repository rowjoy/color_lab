import '../../../data/schema/repository_snapshot.dart';
import 'coloring_project.dart';

abstract interface class ColoringProjectRepository {
  Future<RepositorySnapshot<ColoringProject>> loadSnapshot();
  Future<ColoringProject?> read(String projectId);
  Future<ColoringProject> save(ColoringProject project);
  Future<void> delete(String projectId);
  Future<void> close();
}

final class ColoringProjectStorageException implements Exception {
  const ColoringProjectStorageException();

  @override
  String toString() => 'Unable to access coloring projects.';
}
