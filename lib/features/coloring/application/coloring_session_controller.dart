import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/color/color_models.dart';
import '../domain/coloring_project.dart';
import '../domain/coloring_project_repository.dart';
import '../domain/drawing_definition.dart';

enum ProjectSaveStatus { saved, saving, failed }

final class ColoringSession {
  const ColoringSession({
    required this.durable,
    required this.visible,
    required this.saveStatus,
    this.saveError,
    this.focusedRegionId,
  });

  final ColoringProject durable;
  final ColoringProject visible;
  final ProjectSaveStatus saveStatus;
  final Object? saveError;
  final String? focusedRegionId;

  ColoringSession copyWith({
    ColoringProject? durable,
    ColoringProject? visible,
    ProjectSaveStatus? saveStatus,
    Object? saveError,
    bool clearSaveError = false,
    String? focusedRegionId,
    bool clearFocus = false,
  }) => ColoringSession(
    durable: durable ?? this.durable,
    visible: visible ?? this.visible,
    saveStatus: saveStatus ?? this.saveStatus,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
    focusedRegionId: clearFocus
        ? null
        : focusedRegionId ?? this.focusedRegionId,
  );
}

/// Immediate visible edits plus serialized acknowledged persistence.
final class ColoringSessionController extends ChangeNotifier {
  ColoringSessionController({
    required ColoringProjectRepository repository,
    required this.definition,
    required ColoringProject project,
    void Function(ColoringProject project)? onAcknowledged,
  }) : _repository = repository,
       _onAcknowledged = onAcknowledged,
       _session = ColoringSession(
         durable: project,
         visible: project,
         saveStatus: ProjectSaveStatus.saved,
       ) {
    if (project.drawingId != definition.id ||
        project.drawingRevision != definition.revision) {
      throw ArgumentError('Project and drawing revision do not match.');
    }
  }

  final ColoringProjectRepository _repository;
  final void Function(ColoringProject project)? _onAcknowledged;
  final DrawingDefinition definition;
  ColoringSession _session;
  Future<void> _pending = Future.value();
  int _revision = 0;
  bool _disposed = false;

  ColoringSession get session => _session;

  int get requiredCount =>
      definition.regionRules.values.where((rule) => rule.required).length;

  int get filledRequiredCount => definition.regionRules.values
      .where(
        (rule) =>
            rule.required &&
            _session.visible.assignments.containsKey(rule.regionId),
      )
      .length;

  double get progress =>
      requiredCount == 0 ? 1 : filledRequiredCount / requiredCount;

  bool guidedColorAccepted(String regionId, RgbColor color) {
    final rule = definition.regionRules[regionId];
    if (rule == null || rule.targetSlotId == null) return false;
    return definition.slotById(rule.targetSlotId!).color == color;
  }

  Future<bool> fillRegion(String regionId, RgbColor color) async {
    final rule = definition.regionRules[regionId];
    if (rule == null) return false;
    final guided = _session.visible.mode == ColoringMode.guided;
    if (guided && !guidedColorAccepted(regionId, color)) return false;
    final next = _session.visible.fill(regionId, color, guided: guided);
    if (identical(next, _session.visible)) return true;
    _publishVisible(next, focusedRegionId: _nextRequiredAfter(regionId, next));
    await _enqueueSave(next);
    return true;
  }

  Future<void> undo() async {
    final next = _session.visible.undo();
    if (identical(next, _session.visible)) return;
    _publishVisible(next);
    await _enqueueSave(next);
  }

  Future<void> redo() async {
    final next = _session.visible.redo();
    if (identical(next, _session.visible)) return;
    _publishVisible(next);
    await _enqueueSave(next);
  }

  String? findNextRegion() {
    final id = _firstUnfilled(_session.visible);
    _session = _session.copyWith(focusedRegionId: id, clearFocus: id == null);
    _notify();
    return id;
  }

  void focusRegion(String regionId) {
    if (!definition.regionRules.containsKey(regionId)) return;
    _session = _session.copyWith(focusedRegionId: regionId);
    _notify();
  }

  Future<bool> finish() async {
    if (_session.visible.mode == ColoringMode.guided &&
        filledRequiredCount != requiredCount) {
      findNextRegion();
      return false;
    }
    if (_session.visible.assignments.isEmpty) return false;
    final next = _session.visible.copyWith(
      completed: true,
      updatedAt: DateTime.now().toUtc(),
    );
    _publishVisible(next, clearFocus: true);
    final completionRevision = _revision + 1;
    await _enqueueSave(next);
    return _revision == completionRevision &&
        _session.saveStatus == ProjectSaveStatus.saved &&
        _session.visible.completed &&
        _session.visible.updatedAt == next.updatedAt &&
        _session.durable.completed &&
        _session.durable.updatedAt == next.updatedAt;
  }

  Future<void> retrySave() async {
    if (_session.saveStatus != ProjectSaveStatus.failed) return;
    await _enqueueSave(_session.visible);
  }

  Future<void> flush() => _pending;

  void _publishVisible(
    ColoringProject project, {
    String? focusedRegionId,
    bool clearFocus = false,
  }) {
    _session = _session.copyWith(
      visible: project,
      saveStatus: ProjectSaveStatus.saving,
      clearSaveError: true,
      focusedRegionId: focusedRegionId,
      clearFocus: clearFocus,
    );
    _notify();
  }

  Future<void> _enqueueSave(ColoringProject project) {
    final completer = Completer<void>();
    final token = ++_revision;
    _pending = _pending
        .then((_) async {
          try {
            final saved = await _repository.save(project);
            _onAcknowledged?.call(saved);
            if (!_disposed && token <= _revision) {
              _session = _session.copyWith(
                durable: saved,
                saveStatus: token == _revision
                    ? ProjectSaveStatus.saved
                    : ProjectSaveStatus.saving,
                clearSaveError: true,
              );
              _notify();
            }
            completer.complete();
          } catch (error, stackTrace) {
            if (!_disposed && token == _revision) {
              _session = _session.copyWith(
                saveStatus: ProjectSaveStatus.failed,
                saveError: error,
              );
              _notify();
            }
            completer.completeError(error, stackTrace);
          }
        })
        .catchError((Object _, StackTrace _) {
          // The queue stays usable after a retained save failure.
        });
    return completer.future;
  }

  String? _firstUnfilled(ColoringProject project) {
    for (final region in definition.artwork.regions) {
      final rule = definition.regionRules[region.id]!;
      if (rule.required && !project.assignments.containsKey(region.id)) {
        return region.id;
      }
    }
    return null;
  }

  String? _nextRequiredAfter(String regionId, ColoringProject project) {
    final regions = definition.artwork.regions;
    final start = regions.indexWhere((region) => region.id == regionId);
    for (var offset = 1; offset <= regions.length; offset++) {
      final candidate = regions[(start + offset) % regions.length].id;
      final rule = definition.regionRules[candidate]!;
      if (rule.required && !project.assignments.containsKey(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
