import 'dart:io';

void main(List<String> arguments) {
  exitCode = checkPlanCoverage(arguments, out: stdout, err: stderr);
}

int checkPlanCoverage(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
}) {
  final parsed = _parseArguments(arguments, err);
  if (parsed == null) return 64;

  try {
    final requirements = _extractRequirements(
      File(parsed.specPath).readAsStringSync(),
    );
    if (requirements.isEmpty) {
      err.writeln('The spec contains no requirement IDs.');
      return 65;
    }

    final invalidAllowed = parsed.allowedIds.where((id) {
      final classification = requirements[id];
      return classification != RequirementClassification.postLaunch &&
          classification != RequirementClassification.deferred;
    }).toList()..sort();
    if (invalidAllowed.isNotEmpty) {
      final labels = invalidAllowed
          .map((id) {
            final classification = requirements[id];
            return '$id (${classification?.label ?? 'not present in spec'})';
          })
          .join(', ');
      err.writeln(
        '--allow may only exempt Post-launch or Deferred requirement IDs: '
        '$labels',
      );
      return 64;
    }

    final plannedIds = <String>{};
    for (final path in parsed.planPaths) {
      plannedIds.addAll(_extractIds(File(path).readAsStringSync()));
    }

    final missingByClassification = <RequirementClassification, List<String>>{
      for (final classification in RequirementClassification.values)
        classification: <String>[],
    };
    for (final entry in requirements.entries) {
      if (!plannedIds.contains(entry.key) &&
          !parsed.allowedIds.contains(entry.key)) {
        missingByClassification[entry.value]!.add(entry.key);
      }
    }

    final missingCount = missingByClassification.values.fold<int>(
      0,
      (total, ids) => total + ids.length,
    );
    if (missingCount > 0) {
      for (final classification in RequirementClassification.values) {
        final ids = missingByClassification[classification]!..sort();
        if (ids.isNotEmpty) {
          err.writeln(
            'Missing ${classification.label} requirement IDs: '
            '${ids.join(', ')}',
          );
        }
      }
      return 1;
    }

    final allowedOmissions = parsed.allowedIds
        .where((id) => !plannedIds.contains(id))
        .length;
    out.writeln(
      'Coverage OK: ${requirements.length} unique requirement IDs; '
      '$allowedOmissions explicitly allowed omissions.',
    );
    return 0;
  } on FileSystemException catch (error) {
    err.writeln('Could not read ${error.path ?? 'an input file'}.');
    return 66;
  }
}

enum RequirementClassification {
  launch('Launch'),
  conditional('Conditional v1'),
  postLaunch('Post-launch'),
  deferred('Deferred');

  const RequirementClassification(this.label);

  final String label;
}

final RegExp _requirementId = RegExp(r'\b[A-Z][A-Z0-9]*-\d{2}\b');

Map<String, RequirementClassification> _extractRequirements(String source) {
  final requirements = <String, RequirementClassification>{};
  var sectionClassification = RequirementClassification.launch;

  for (final line in source.split('\n')) {
    final isHeading = line.trimLeft().startsWith('#');
    if (isHeading) {
      sectionClassification =
          _explicitClassification(line, isHeading: true) ??
          RequirementClassification.launch;
    }
    final explicitClassification = _explicitClassification(
      line,
      isHeading: isHeading,
    );
    final classification = explicitClassification ?? sectionClassification;
    for (final id in _extractIds(line)) {
      final existing = requirements[id];
      if (existing == null || explicitClassification != null) {
        requirements[id] = classification;
      }
    }
  }
  return requirements;
}

RequirementClassification? _explicitClassification(
  String text, {
  required bool isHeading,
}) {
  final normalized = text.toLowerCase();
  final trimmed = normalized.trimLeft();
  if (normalized.contains('[post-launch]') ||
      trimmed.startsWith('- **post-launch:**') ||
      (isHeading && normalized.contains('post-launch'))) {
    return RequirementClassification.postLaunch;
  }
  if (normalized.contains('[deferred]') ||
      trimmed.startsWith('- **deferred:**') ||
      (isHeading && normalized.contains('deferred'))) {
    return RequirementClassification.deferred;
  }
  if (normalized.contains('[conditional v1]') ||
      trimmed.startsWith('- **conditional v1:**') ||
      (isHeading && normalized.contains('conditional v1'))) {
    return RequirementClassification.conditional;
  }
  return null;
}

Set<String> _extractIds(String source) =>
    _requirementId.allMatches(source).map((match) => match.group(0)!).toSet();

_Arguments? _parseArguments(List<String> arguments, StringSink err) {
  String? specPath;
  final allowedIds = <String>{};
  final planPaths = <String>[];

  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--spec') {
      if (specPath != null || index + 1 >= arguments.length) {
        _usage(err);
        return null;
      }
      specPath = arguments[++index];
      continue;
    }
    if (argument == '--allow') {
      if (index + 1 >= arguments.length) {
        _usage(err);
        return null;
      }
      allowedIds.add(arguments[++index]);
      continue;
    }
    if (argument.startsWith('--')) {
      _usage(err);
      return null;
    }
    planPaths.add(argument);
  }

  if (specPath == null && planPaths.length >= 2) {
    specPath = planPaths.removeAt(0);
  }
  if (specPath == null || planPaths.isEmpty) {
    _usage(err);
    return null;
  }
  return _Arguments(
    specPath: specPath,
    planPaths: planPaths,
    allowedIds: allowedIds,
  );
}

void _usage(StringSink err) {
  err.writeln(
    'Usage: dart run tool/check_plan_coverage.dart '
    'SPEC [--allow ID ...] PLAN [PLAN ...] '
    '(or --spec SPEC [--allow ID ...] PLAN [PLAN ...])',
  );
}

final class _Arguments {
  const _Arguments({
    required this.specPath,
    required this.planPaths,
    required this.allowedIds,
  });

  final String specPath;
  final List<String> planPaths;
  final Set<String> allowedIds;
}
