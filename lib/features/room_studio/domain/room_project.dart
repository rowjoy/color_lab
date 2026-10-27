import 'dart:typed_data';

import 'room_layer_colors.dart';

/// Schema-v1 bounds apply before copying pixels or reading untrusted assets.
abstract final class RoomProjectLimits {
  static const maxDimension = 4096;
  static const maxPixels = 16777216;
  static const maxAssetBytes = 67108864;
  static const maxManifestBytes = 262144;
  static const maxPointerBytes = 2097152;
  static const maxVariants = 32;
  static const maxRevisions = 10000;
  static const maxRevision = 2147483647;

  static bool validId(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$').hasMatch(value);

  static bool validName(String value) =>
      value.isNotEmpty &&
      value.length <= 80 &&
      value == value.trim() &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

  static bool validRevision(int value) => value >= 0 && value <= maxRevision;
}

final class RoomColorVariant {
  RoomColorVariant({
    required this.id,
    required String name,
    required this.colors,
  }) : name = name.trim() {
    if (!RoomProjectLimits.validId(id) ||
        !RoomProjectLimits.validName(this.name)) {
      throw ArgumentError('A safe variant ID and bounded name are required.');
    }
  }

  final String id;
  final String name;
  final RoomLayerColors colors;

  RoomColorVariant copyWith({String? name, RoomLayerColors? colors}) =>
      RoomColorVariant(
        id: id,
        name: name ?? this.name,
        colors: colors ?? this.colors,
      );
}

/// Safe command failures; presentation supplies localized recovery copy.
enum RoomVariantFailure {
  invalidName,
  duplicateName,
  invalidId,
  missing,
  limit,
  finalVariant,
  unavailable,
}

final class RoomVariantException implements Exception {
  const RoomVariantException(this.failure);
  final RoomVariantFailure failure;
}

/// Lightweight visible metadata. No photo, mask, or undo data is copied here.
final class RoomVariantSet {
  RoomVariantSet({
    required List<RoomColorVariant> variants,
    required this.activeVariantId,
    this.comparisonBaselineVariantId,
  }) : variants = List.unmodifiable(variants) {
    if (variants.isEmpty || variants.length > RoomProjectLimits.maxVariants) {
      throw const RoomVariantException(RoomVariantFailure.limit);
    }
    if (variants.map((v) => v.id).toSet().length != variants.length) {
      throw const RoomVariantException(RoomVariantFailure.invalidId);
    }
    if (variants.map((v) => v.name.toLowerCase()).toSet().length !=
        variants.length) {
      throw const RoomVariantException(RoomVariantFailure.duplicateName);
    }
    _require(activeVariantId);
    if (comparisonBaselineVariantId != null) {
      _require(comparisonBaselineVariantId!);
    }
  }
  final List<RoomColorVariant> variants;
  final String activeVariantId;
  final String? comparisonBaselineVariantId;
  RoomColorVariant get active => _require(activeVariantId);
  RoomColorVariant? get baseline => comparisonBaselineVariantId == null
      ? null
      : _require(comparisonBaselineVariantId!);

  RoomColorVariant _require(String id) {
    for (final variant in variants) {
      if (variant.id == id) return variant;
    }
    throw const RoomVariantException(RoomVariantFailure.missing);
  }

  String _name(String value, [String? excluding]) {
    final name = value.trim();
    if (!RoomProjectLimits.validName(name)) {
      throw const RoomVariantException(RoomVariantFailure.invalidName);
    }
    if (variants.any(
      (v) => v.id != excluding && v.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const RoomVariantException(RoomVariantFailure.duplicateName);
    }
    return name;
  }

  RoomVariantSet create(String id, String name) {
    final normalized = _name(name);
    if (variants.length == RoomProjectLimits.maxVariants) {
      throw const RoomVariantException(RoomVariantFailure.limit);
    }
    if (!RoomProjectLimits.validId(id) || variants.any((v) => v.id == id)) {
      throw const RoomVariantException(RoomVariantFailure.invalidId);
    }
    return RoomVariantSet(
      variants: [
        ...variants,
        RoomColorVariant(id: id, name: normalized, colors: active.colors),
      ],
      activeVariantId: id,
      comparisonBaselineVariantId: comparisonBaselineVariantId,
    );
  }

  RoomVariantSet rename(String id, String name) {
    _require(id);
    final normalized = _name(name, id);
    return RoomVariantSet(
      variants: [
        for (final v in variants) v.id == id ? v.copyWith(name: normalized) : v,
      ],
      activeVariantId: activeVariantId,
      comparisonBaselineVariantId: comparisonBaselineVariantId,
    );
  }

  RoomVariantSet select(String id) {
    _require(id);
    return RoomVariantSet(
      variants: variants,
      activeVariantId: id,
      comparisonBaselineVariantId: comparisonBaselineVariantId,
    );
  }

  RoomVariantSet updateColors(RoomLayerColors colors) => RoomVariantSet(
    variants: [
      for (final v in variants)
        v.id == activeVariantId ? v.copyWith(colors: colors) : v,
    ],
    activeVariantId: activeVariantId,
    comparisonBaselineVariantId: comparisonBaselineVariantId,
  );

  /// Deleting the active variant selects the first survivor in persisted order.
  RoomVariantSet delete(String id) {
    _require(id);
    if (variants.length == 1) {
      throw const RoomVariantException(RoomVariantFailure.finalVariant);
    }
    final remaining = variants.where((v) => v.id != id).toList();
    return RoomVariantSet(
      variants: remaining,
      activeVariantId: activeVariantId == id
          ? remaining.first.id
          : activeVariantId,
      comparisonBaselineVariantId: comparisonBaselineVariantId == id
          ? null
          : comparisonBaselineVariantId,
    );
  }

  RoomVariantSet pin(String id) {
    _require(id);
    return RoomVariantSet(
      variants: variants,
      activeVariantId: activeVariantId,
      comparisonBaselineVariantId: id,
    );
  }

  RoomVariantSet clearComparison() =>
      RoomVariantSet(variants: variants, activeVariantId: activeVariantId);
}

/// One immutable working-resolution aggregate. Storage revision is independent
/// of mask/color revisions. Explicit correction intent belongs to schema v2.
final class RoomProjectSnapshot {
  factory RoomProjectSnapshot({
    required String projectId,
    required String photoId,
    required String name,
    required int revision,
    required int width,
    required int height,
    required Uint8List photoPng,
    required Uint8List aiMaskBytes,
    required Uint8List maskBytes,
    required int maskRevision,
    required int colorRevision,
    required List<RoomColorVariant> variants,
    required String activeVariantId,
    String? comparisonBaselineVariantId,
    Uint8List? thumbnailPng,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final normalizedName = name.trim();
    if (!RoomProjectLimits.validId(projectId) ||
        !RoomProjectLimits.validId(photoId) ||
        !RoomProjectLimits.validName(normalizedName) ||
        !RoomProjectLimits.validRevision(revision) ||
        !RoomProjectLimits.validRevision(maskRevision) ||
        !RoomProjectLimits.validRevision(colorRevision) ||
        width < 1 ||
        height < 1 ||
        width > RoomProjectLimits.maxDimension ||
        height > RoomProjectLimits.maxDimension ||
        width * height > RoomProjectLimits.maxPixels ||
        photoPng.isEmpty ||
        photoPng.length > RoomProjectLimits.maxAssetBytes ||
        (thumbnailPng != null &&
            (thumbnailPng.isEmpty ||
                thumbnailPng.length > RoomProjectLimits.maxAssetBytes)) ||
        aiMaskBytes.length != width * height ||
        maskBytes.length != width * height ||
        aiMaskBytes.any((label) => label > 4) ||
        maskBytes.any((label) => label > 4) ||
        variants.isEmpty ||
        variants.length > RoomProjectLimits.maxVariants ||
        variants.map((v) => v.id).toSet().length != variants.length ||
        variants.map((v) => v.name.toLowerCase()).toSet().length !=
            variants.length ||
        !variants.any((v) => v.id == activeVariantId) ||
        (comparisonBaselineVariantId != null &&
            !variants.any((v) => v.id == comparisonBaselineVariantId)) ||
        updatedAt.isBefore(createdAt)) {
      throw ArgumentError(
        'Invalid Room project dimensions, identity, or metadata.',
      );
    }
    return RoomProjectSnapshot._(
      projectId,
      photoId,
      normalizedName,
      revision,
      width,
      height,
      Uint8List.fromList(photoPng).asUnmodifiableView(),
      Uint8List.fromList(aiMaskBytes).asUnmodifiableView(),
      Uint8List.fromList(maskBytes).asUnmodifiableView(),
      maskRevision,
      colorRevision,
      List.unmodifiable(variants),
      activeVariantId,
      comparisonBaselineVariantId,
      thumbnailPng == null
          ? null
          : Uint8List.fromList(thumbnailPng).asUnmodifiableView(),
      createdAt.toUtc(),
      updatedAt.toUtc(),
    );
  }

  const RoomProjectSnapshot._(
    this.projectId,
    this.photoId,
    this.name,
    this.revision,
    this.width,
    this.height,
    this.photoPng,
    this.aiMaskBytes,
    this.maskBytes,
    this.maskRevision,
    this.colorRevision,
    this.variants,
    this.activeVariantId,
    this.comparisonBaselineVariantId,
    this.thumbnailPng,
    this.createdAt,
    this.updatedAt,
  );

  int get schemaVersion => 1;
  final String projectId;
  final String photoId;
  final String name;
  final int revision;
  final int width;
  final int height;
  final Uint8List photoPng;
  final Uint8List aiMaskBytes;
  final Uint8List maskBytes;
  final int maskRevision;
  final int colorRevision;
  final List<RoomColorVariant> variants;
  final String activeVariantId;
  final String? comparisonBaselineVariantId;
  final Uint8List? thumbnailPng;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomLayerColors get colors =>
      variants.firstWhere((v) => v.id == activeVariantId).colors;

  static const _unchanged = Object();
  RoomProjectSnapshot copyWith({
    String? projectId,
    String? photoId,
    String? name,
    int? revision,
    int? width,
    int? height,
    Uint8List? photoPng,
    Uint8List? aiMaskBytes,
    Uint8List? maskBytes,
    int? maskRevision,
    int? colorRevision,
    List<RoomColorVariant>? variants,
    String? activeVariantId,
    Object? comparisonBaselineVariantId = _unchanged,
    Object? thumbnailPng = _unchanged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RoomProjectSnapshot(
    projectId: projectId ?? this.projectId,
    photoId: photoId ?? this.photoId,
    name: name ?? this.name,
    revision: revision ?? this.revision,
    width: width ?? this.width,
    height: height ?? this.height,
    photoPng: photoPng ?? this.photoPng,
    aiMaskBytes: aiMaskBytes ?? this.aiMaskBytes,
    maskBytes: maskBytes ?? this.maskBytes,
    maskRevision: maskRevision ?? this.maskRevision,
    colorRevision: colorRevision ?? this.colorRevision,
    variants: variants ?? this.variants,
    activeVariantId: activeVariantId ?? this.activeVariantId,
    comparisonBaselineVariantId:
        identical(comparisonBaselineVariantId, _unchanged)
        ? this.comparisonBaselineVariantId
        : comparisonBaselineVariantId as String?,
    thumbnailPng: identical(thumbnailPng, _unchanged)
        ? this.thumbnailPng
        : thumbnailPng as Uint8List?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum RoomProjectRecoveryReason { earlierRevision, thumbnailUnavailable }

final class RoomProjectRecoveryWarning {
  RoomProjectRecoveryWarning({
    required this.reason,
    required this.acknowledgedRevision,
    required this.recoveredRevision,
    List<int> rejectedRevisions = const [],
    this.thumbnailUnavailable = false,
  }) : rejectedRevisions = List.unmodifiable(rejectedRevisions);
  final RoomProjectRecoveryReason reason;
  final int acknowledgedRevision;
  final int recoveredRevision;
  final List<int> rejectedRevisions;
  final bool thumbnailUnavailable;
}

final class RoomProjectReadResult {
  const RoomProjectReadResult({
    required this.snapshot,
    required this.acknowledgedRevision,
    this.warning,
  });
  final RoomProjectSnapshot snapshot;

  /// CAS uses this revision even when [snapshot] recovered an earlier revision.
  final int acknowledgedRevision;
  final RoomProjectRecoveryWarning? warning;
}

final class RoomProjectSummary {
  RoomProjectSummary.fromReadResult(RoomProjectReadResult result)
    : projectId = result.snapshot.projectId,
      photoId = result.snapshot.photoId,
      name = result.snapshot.name,
      revision = result.snapshot.revision,
      acknowledgedRevision = result.acknowledgedRevision,
      width = result.snapshot.width,
      height = result.snapshot.height,
      createdAt = result.snapshot.createdAt,
      updatedAt = result.snapshot.updatedAt,
      thumbnailPng = result.snapshot.thumbnailPng,
      warning = result.warning;
  final String projectId;
  final String photoId;
  final String name;
  final int revision;
  final int acknowledgedRevision;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Uint8List? thumbnailPng;
  final RoomProjectRecoveryWarning? warning;
}
