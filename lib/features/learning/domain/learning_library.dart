import 'experiment_snapshot.dart';
import 'learning_content.dart';

final class QuestionAttempt {
  QuestionAttempt({
    required this.answerId,
    required this.correct,
    required this.explanationKey,
    required DateTime attemptedAt,
  }) : attemptedAt = attemptedAt.toUtc() {
    _id(answerId, 'answer id');
    _copyKey(explanationKey, 'explanation key');
  }

  factory QuestionAttempt.fromMap(Map<dynamic, dynamic> map) {
    final value = _map(map, 'question attempt');
    _keys(value, const {
      'answerId',
      'correct',
      'explanationKey',
      'attemptedAt',
    });
    if (value['correct'] is! bool) {
      throw const FormatException('Invalid question result.');
    }
    return QuestionAttempt(
      answerId: _id(value['answerId'], 'answer id'),
      correct: value['correct']! as bool,
      explanationKey: _string(value['explanationKey'], 'explanation key'),
      attemptedAt: _utc(value['attemptedAt'], 'attemptedAt'),
    );
  }

  final String answerId;
  final bool correct;
  final String explanationKey;
  final DateTime attemptedAt;
  Map<String, Object?> toMap() => Map.unmodifiable({
    'answerId': answerId,
    'correct': correct,
    'explanationKey': explanationKey,
    'attemptedAt': attemptedAt.toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is QuestionAttempt &&
      other.answerId == answerId &&
      other.correct == correct &&
      other.explanationKey == explanationKey &&
      other.attemptedAt == attemptedAt;
  @override
  int get hashCode =>
      Object.hash(answerId, correct, explanationKey, attemptedAt);
}

final class QuestionResponse {
  QuestionResponse({
    required this.questionId,
    required Iterable<QuestionAttempt> attempts,
  }) : attempts = List.unmodifiable(attempts) {
    _id(questionId, 'question id');
    if (this.attempts.isEmpty) {
      throw const FormatException('Question response needs an attempt.');
    }
    for (var index = 1; index < this.attempts.length; index++) {
      if (this.attempts[index].attemptedAt.isBefore(
        this.attempts[index - 1].attemptedAt,
      )) {
        throw const FormatException('Question attempts are out of order.');
      }
    }
  }

  factory QuestionResponse.fromMap(Map<dynamic, dynamic> map) {
    final value = _map(map, 'question response');
    _keys(value, const {'questionId', 'attempts'});
    final raw = value['attempts'];
    if (raw is! List || raw.any((item) => item is! Map)) {
      throw const FormatException('Invalid question attempts.');
    }
    return QuestionResponse(
      questionId: _id(value['questionId'], 'question id'),
      attempts: raw.map((item) => QuestionAttempt.fromMap(item as Map)),
    );
  }

  final String questionId;
  final List<QuestionAttempt> attempts;
  QuestionAttempt get latest => attempts.last;
  Map<String, Object?> toMap() => Map.unmodifiable({
    'questionId': questionId,
    'attempts': List.unmodifiable(attempts.map((attempt) => attempt.toMap())),
  });

  QuestionResponse add(QuestionAttempt attempt) => QuestionResponse(
    questionId: questionId,
    attempts: [...attempts, attempt],
  );

  @override
  bool operator ==(Object other) =>
      other is QuestionResponse &&
      other.questionId == questionId &&
      _listEqual(other.attempts, attempts);
  @override
  int get hashCode => Object.hash(questionId, Object.hashAll(attempts));
}

final class LessonProgress {
  LessonProgress({
    required this.lessonId,
    required this.lessonRevision,
    required this.currentStepIndex,
    required Iterable<String> completedStepIds,
    required Map<String, QuestionResponse> answers,
    required this.completed,
    required DateTime updatedAt,
  }) : completedStepIds = Set.unmodifiable(completedStepIds),
       answers = Map.unmodifiable(answers),
       updatedAt = updatedAt.toUtc() {
    _id(lessonId, 'lesson id');
    if (lessonRevision < 1 || currentStepIndex < 0) {
      throw const FormatException('Invalid lesson progress position.');
    }
    for (final id in this.completedStepIds) {
      _id(id, 'completed step id');
    }
    for (final entry in this.answers.entries) {
      if (entry.key != entry.value.questionId) {
        throw const FormatException('Question response key mismatch.');
      }
    }
  }

  factory LessonProgress.fromMap(Map<dynamic, dynamic> map) {
    final value = _map(map, 'lesson progress');
    _keys(value, const {
      'schemaVersion',
      'lessonId',
      'lessonRevision',
      'currentStepIndex',
      'completedStepIds',
      'answers',
      'completed',
      'updatedAt',
    });
    if (value['schemaVersion'] != 1 ||
        value['lessonRevision'] is! int ||
        value['currentStepIndex'] is! int ||
        value['completed'] is! bool) {
      throw const FormatException('Invalid lesson progress schema.');
    }
    final rawSteps = value['completedStepIds'];
    final rawAnswers = value['answers'];
    if (rawSteps is! List ||
        rawSteps.any((item) => item is! String) ||
        rawAnswers is! Map ||
        rawAnswers.entries.any(
          (entry) => entry.key is! String || entry.value is! Map,
        )) {
      throw const FormatException('Invalid lesson progress values.');
    }
    final steps = rawSteps.cast<String>();
    if (steps.toSet().length != steps.length) {
      throw const FormatException('Duplicate completed step ID.');
    }
    final answers = <String, QuestionResponse>{};
    for (final entry in rawAnswers.entries) {
      answers[entry.key as String] = QuestionResponse.fromMap(
        entry.value as Map,
      );
    }
    return LessonProgress(
      lessonId: _id(value['lessonId'], 'lesson id'),
      lessonRevision: value['lessonRevision']! as int,
      currentStepIndex: value['currentStepIndex']! as int,
      completedStepIds: steps,
      answers: answers,
      completed: value['completed']! as bool,
      updatedAt: _utc(value['updatedAt'], 'updatedAt'),
    );
  }

  final String lessonId;
  final int lessonRevision;
  final int currentStepIndex;
  final Set<String> completedStepIds;
  final Map<String, QuestionResponse> answers;
  final bool completed;
  final DateTime updatedAt;

  LessonProgress copyWith({
    int? currentStepIndex,
    Iterable<String>? completedStepIds,
    Map<String, QuestionResponse>? answers,
    bool? completed,
    DateTime? updatedAt,
  }) => LessonProgress(
    lessonId: lessonId,
    lessonRevision: lessonRevision,
    currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    completedStepIds: completedStepIds ?? this.completedStepIds,
    answers: answers ?? this.answers,
    completed: completed ?? this.completed,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': 1,
    'lessonId': lessonId,
    'lessonRevision': lessonRevision,
    'currentStepIndex': currentStepIndex,
    'completedStepIds': List.unmodifiable(completedStepIds),
    'answers': Map.unmodifiable(
      answers.map((key, response) => MapEntry(key, response.toMap())),
    ),
    'completed': completed,
    'updatedAt': updatedAt.toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is LessonProgress &&
      other.lessonId == lessonId &&
      other.lessonRevision == lessonRevision &&
      other.currentStepIndex == currentStepIndex &&
      _setEqual(other.completedStepIds, completedStepIds) &&
      _mapEqual(other.answers, answers) &&
      other.completed == completed &&
      other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(
    lessonId,
    lessonRevision,
    currentStepIndex,
    Object.hashAllUnordered(completedStepIds),
    _mapHash(answers),
    completed,
    updatedAt,
  );
}

final class PracticeAttempt {
  PracticeAttempt({
    required this.id,
    required this.lessonId,
    required this.activityId,
    required this.answerId,
    required this.correct,
    required this.explanationKey,
    required DateTime attemptedAt,
  }) : attemptedAt = attemptedAt.toUtc() {
    for (final entry in {
      'practice id': id,
      'lesson id': lessonId,
      'activity id': activityId,
      'answer id': answerId,
    }.entries) {
      _id(entry.value, entry.key);
    }
    _copyKey(explanationKey, 'explanation key');
  }

  factory PracticeAttempt.fromMap(Map<dynamic, dynamic> map) {
    final value = _map(map, 'practice attempt');
    _keys(value, const {
      'schemaVersion',
      'id',
      'lessonId',
      'activityId',
      'answerId',
      'correct',
      'explanationKey',
      'attemptedAt',
    });
    if (value['schemaVersion'] != 1 || value['correct'] is! bool) {
      throw const FormatException('Invalid practice attempt schema.');
    }
    return PracticeAttempt(
      id: _id(value['id'], 'practice id'),
      lessonId: _id(value['lessonId'], 'lesson id'),
      activityId: _id(value['activityId'], 'activity id'),
      answerId: _id(value['answerId'], 'answer id'),
      correct: value['correct']! as bool,
      explanationKey: _string(value['explanationKey'], 'explanation key'),
      attemptedAt: _utc(value['attemptedAt'], 'attemptedAt'),
    );
  }

  final String id;
  final String lessonId;
  final String activityId;
  final String answerId;
  final bool correct;
  final String explanationKey;
  final DateTime attemptedAt;
  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': 1,
    'id': id,
    'lessonId': lessonId,
    'activityId': activityId,
    'answerId': answerId,
    'correct': correct,
    'explanationKey': explanationKey,
    'attemptedAt': attemptedAt.toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is PracticeAttempt &&
      other.id == id &&
      other.lessonId == lessonId &&
      other.activityId == activityId &&
      other.answerId == answerId &&
      other.correct == correct &&
      other.explanationKey == explanationKey &&
      other.attemptedAt == attemptedAt;
  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    activityId,
    answerId,
    correct,
    explanationKey,
    attemptedAt,
  );
}

final class LearningLibrary {
  LearningLibrary({
    required this.schemaVersion,
    required Map<String, LessonProgress> progressByLesson,
    required Iterable<PracticeAttempt> practiceHistory,
    required Iterable<LearningTopic> topicsToRevisit,
    required Iterable<ExperimentRecord> experiments,
  }) : progressByLesson = Map.unmodifiable(progressByLesson),
       practiceHistory = List.unmodifiable(practiceHistory),
       topicsToRevisit = Set.unmodifiable(topicsToRevisit),
       experiments = List.unmodifiable(experiments) {
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported learning library version.');
    }
    for (final entry in this.progressByLesson.entries) {
      if (entry.key != entry.value.lessonId) {
        throw const FormatException('Lesson progress key mismatch.');
      }
    }
    _unique(
      this.practiceHistory.map((item) => item.id),
      'practice attempt ids',
    );
    _unique(this.experiments.map((item) => item.id), 'experiment ids');
  }

  factory LearningLibrary.empty() => LearningLibrary(
    schemaVersion: 1,
    progressByLesson: const {},
    practiceHistory: const [],
    topicsToRevisit: const {},
    experiments: const [],
  );

  factory LearningLibrary.fromMap(Map<dynamic, dynamic> map) {
    final value = _map(map, 'learning library');
    _keys(value, const {
      'schemaVersion',
      'progressByLesson',
      'practiceHistory',
      'topicsToRevisit',
      'experiments',
    });
    if (value['schemaVersion'] != 1) {
      throw const FormatException('Unsupported learning library version.');
    }
    final rawProgress = value['progressByLesson'];
    final rawPractice = value['practiceHistory'];
    final rawTopics = value['topicsToRevisit'];
    final rawExperiments = value['experiments'];
    if (rawProgress is! Map ||
        rawProgress.entries.any(
          (entry) => entry.key is! String || entry.value is! Map,
        ) ||
        rawPractice is! List ||
        rawPractice.any((item) => item is! Map) ||
        rawTopics is! List ||
        rawTopics.any((item) => item is! String) ||
        rawExperiments is! List ||
        rawExperiments.any((item) => item is! Map)) {
      throw const FormatException('Invalid learning library values.');
    }
    final progress = <String, LessonProgress>{};
    for (final entry in rawProgress.entries) {
      progress[entry.key as String] = LessonProgress.fromMap(
        entry.value as Map,
      );
    }
    final topics = rawTopics
        .map(
          (value) => _enumValue(LearningTopic.values, value, 'learning topic'),
        )
        .toList(growable: false);
    if (topics.toSet().length != topics.length) {
      throw const FormatException('Duplicate learning topic.');
    }
    return LearningLibrary(
      schemaVersion: 1,
      progressByLesson: progress,
      practiceHistory: rawPractice.map(
        (item) => PracticeAttempt.fromMap(item as Map),
      ),
      topicsToRevisit: topics,
      experiments: rawExperiments.map(
        (item) => ExperimentRecord.fromMap(item as Map),
      ),
    );
  }

  final int schemaVersion;
  final Map<String, LessonProgress> progressByLesson;
  final List<PracticeAttempt> practiceHistory;
  final Set<LearningTopic> topicsToRevisit;
  final List<ExperimentRecord> experiments;

  LearningLibrary copyWith({
    Map<String, LessonProgress>? progressByLesson,
    Iterable<PracticeAttempt>? practiceHistory,
    Iterable<LearningTopic>? topicsToRevisit,
    Iterable<ExperimentRecord>? experiments,
  }) => LearningLibrary(
    schemaVersion: schemaVersion,
    progressByLesson: progressByLesson ?? this.progressByLesson,
    practiceHistory: practiceHistory ?? this.practiceHistory,
    topicsToRevisit: topicsToRevisit ?? this.topicsToRevisit,
    experiments: experiments ?? this.experiments,
  );

  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': schemaVersion,
    'progressByLesson': Map.unmodifiable(
      progressByLesson.map((key, progress) => MapEntry(key, progress.toMap())),
    ),
    'practiceHistory': List.unmodifiable(
      practiceHistory.map((attempt) => attempt.toMap()),
    ),
    'topicsToRevisit': List.unmodifiable(
      topicsToRevisit.map((topic) => topic.name),
    ),
    'experiments': List.unmodifiable(
      experiments.map((experiment) => experiment.toMap()),
    ),
  });

  @override
  bool operator ==(Object other) =>
      other is LearningLibrary &&
      other.schemaVersion == schemaVersion &&
      _mapEqual(other.progressByLesson, progressByLesson) &&
      _listEqual(other.practiceHistory, practiceHistory) &&
      _setEqual(other.topicsToRevisit, topicsToRevisit) &&
      _listEqual(other.experiments, experiments);
  @override
  int get hashCode => Object.hash(
    schemaVersion,
    _mapHash(progressByLesson),
    Object.hashAll(practiceHistory),
    Object.hashAllUnordered(topicsToRevisit),
    Object.hashAll(experiments),
  );
}

Map<String, Object?> _map(Map<dynamic, dynamic> value, String field) {
  if (value.keys.any((key) => key is! String)) {
    throw FormatException('Invalid $field keys.');
  }
  return Map<String, Object?>.from(value);
}

void _keys(Map<String, Object?> map, Set<String> expected) {
  if (map.length != expected.length || !map.keys.every(expected.contains)) {
    throw const FormatException('Unexpected schema keys.');
  }
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty)
    throw FormatException('Invalid $field.');
  return value;
}

String _id(Object? value, String field) {
  final result = _string(value, field);
  if (!RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(result)) {
    throw FormatException('Invalid $field.');
  }
  return result;
}

void _copyKey(String value, String field) {
  if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
}

DateTime _utc(Object? value, String field) {
  if (value is! String || !value.endsWith('Z')) {
    throw FormatException('Invalid UTC $field.');
  }
  final result = DateTime.tryParse(value);
  if (result == null || !result.isUtc || result.toIso8601String() != value) {
    throw FormatException('Invalid UTC $field.');
  }
  return result;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('Invalid $field.');
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Invalid $field.');
}

void _unique(Iterable<String> values, String field) {
  final list = values.toList(growable: false);
  if (list.toSet().length != list.length)
    throw FormatException('Duplicate $field.');
}

bool _listEqual(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _setEqual(Set<Object?> a, Set<Object?> b) =>
    a.length == b.length && a.containsAll(b);

bool _mapEqual(Map<Object?, Object?> a, Map<Object?, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<Object?, Object?> value) => Object.hashAllUnordered(
  value.entries.map((entry) => Object.hash(entry.key, entry.value)),
);
