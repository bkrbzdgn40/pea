/// Canonical identifiers for metrics produced or summarized by workout
/// analysis.
///
/// IDs are intentionally stable and UI-agnostic. Concrete metadata such as
/// value type, unit, family, and supported scopes belongs to
/// [ExerciseMetricRegistry].
enum ExerciseMetricId {
  repetitionCount,
  holdDuration,
  primaryMovement,
  form,
  rangeOfMotion,
  tempo,
  symmetry,
  stability,
  repDuration,
}

/// Broad metric families used by engines and presentation code to reason about
/// measurements without relying on exercise-specific field names.
enum ExerciseMetricFamily {
  repetition,
  jointAngle,
  form,
  rangeOfMotion,
  tempo,
  symmetry,
  stability,
  duration,
}

/// Lifecycle level at which a metric value is meaningful.
enum ExerciseMetricScope { frame, repetition, session }

/// Canonical display/storage unit carried by a metric definition.
enum ExerciseMetricUnit { count, degrees, milliseconds, score }

/// Non-generic contract used when heterogeneous metric definitions need to be
/// stored or resolved together.
///
/// The registry intentionally stores this base contract instead of
/// `ExerciseMetricDefinition<dynamic>`. Dart generic types are invariant, so a
/// heterogeneous collection expressed through a bounded `dynamic` type can be
/// normalized to the bound (`Object`) and fail compilation when definitions
/// with concrete type arguments are inserted.
abstract interface class ExerciseMetricDefinitionBase {
  ExerciseMetricId get id;
  String get key;
  ExerciseMetricFamily get family;
  ExerciseMetricUnit get unit;
  Set<ExerciseMetricScope> get scopes;
  Type get valueType;

  bool supportsScope(ExerciseMetricScope scope);
}

/// Typed definition of one registered exercise metric.
///
/// The generic type is the canonical in-memory value type. Code that keeps a
/// typed reference to a metric definition gets compile-time checking when
/// writing values through [ExerciseMetricSnapshotBuilder].
class ExerciseMetricDefinition<T extends Object>
    implements ExerciseMetricDefinitionBase {
  const ExerciseMetricDefinition({
    required this.id,
    required this.key,
    required this.family,
    required this.unit,
    required this.scopes,
  });

  @override
  final ExerciseMetricId id;
  @override
  final String key;
  @override
  final ExerciseMetricFamily family;
  @override
  final ExerciseMetricUnit unit;
  @override
  final Set<ExerciseMetricScope> scopes;

  @override
  Type get valueType => T;

  @override
  bool supportsScope(ExerciseMetricScope scope) => scopes.contains(scope);
}

/// One typed metric value at a known lifecycle scope.
class ExerciseMetricValue<T extends Object> {
  const ExerciseMetricValue({
    required this.definition,
    required this.value,
    required this.scope,
  });

  final ExerciseMetricDefinition<T> definition;
  final T value;
  final ExerciseMetricScope scope;
}

/// Immutable heterogeneous metric payload shared between analysis layers.
///
/// Values remain type-safe at the API boundary because callers read and write
/// them through a typed [ExerciseMetricDefinition].
class ExerciseMetricSnapshot {
  ExerciseMetricSnapshot._({
    required this.scope,
    required Map<ExerciseMetricId, Object> values,
  }) : _values = Map<ExerciseMetricId, Object>.unmodifiable(values);

  final ExerciseMetricScope scope;
  final Map<ExerciseMetricId, Object> _values;

  bool get isEmpty => _values.isEmpty;

  bool get isNotEmpty => _values.isNotEmpty;

  Set<ExerciseMetricId> get metricIds =>
      Set<ExerciseMetricId>.unmodifiable(_values.keys);

  bool contains<T extends Object>(ExerciseMetricDefinition<T> definition) {
    return _values.containsKey(definition.id);
  }

  T? valueFor<T extends Object>(ExerciseMetricDefinition<T> definition) {
    final value = _values[definition.id];
    if (value == null) {
      return null;
    }
    return value as T;
  }

  Object? valueForId(ExerciseMetricId id) => _values[id];
}

/// Mutable construction helper for an immutable [ExerciseMetricSnapshot].
class ExerciseMetricSnapshotBuilder {
  ExerciseMetricSnapshotBuilder({required this.scope});

  final ExerciseMetricScope scope;
  final Map<ExerciseMetricId, Object> _values = <ExerciseMetricId, Object>{};

  void set<T extends Object>(ExerciseMetricDefinition<T> definition, T value) {
    if (!definition.supportsScope(scope)) {
      throw StateError(
        'Metric ${definition.key} does not support ${scope.name} scope.',
      );
    }
    _values[definition.id] = value;
  }

  void add<T extends Object>(ExerciseMetricValue<T> metricValue) {
    if (metricValue.scope != scope) {
      throw StateError(
        'Metric ${metricValue.definition.key} belongs to '
        '${metricValue.scope.name} scope, not ${scope.name}.',
      );
    }
    set(metricValue.definition, metricValue.value);
  }

  ExerciseMetricSnapshot build() {
    return ExerciseMetricSnapshot._(scope: scope, values: _values);
  }
}

/// Single source of truth for metric identity and value contracts.
abstract final class ExerciseMetricRegistry {
  static const ExerciseMetricDefinition<int> repetitionCount =
      ExerciseMetricDefinition<int>(
        id: ExerciseMetricId.repetitionCount,
        key: 'repetition_count',
        family: ExerciseMetricFamily.repetition,
        unit: ExerciseMetricUnit.count,
        scopes: <ExerciseMetricScope>{ExerciseMetricScope.session},
      );

  static const ExerciseMetricDefinition<Duration> holdDuration =
      ExerciseMetricDefinition<Duration>(
        id: ExerciseMetricId.holdDuration,
        key: 'hold_duration',
        family: ExerciseMetricFamily.duration,
        unit: ExerciseMetricUnit.milliseconds,
        scopes: <ExerciseMetricScope>{ExerciseMetricScope.session},
      );

  static const ExerciseMetricDefinition<double> primaryMovement =
      ExerciseMetricDefinition<double>(
        id: ExerciseMetricId.primaryMovement,
        key: 'primary_movement',
        family: ExerciseMetricFamily.jointAngle,
        unit: ExerciseMetricUnit.degrees,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.frame,
          ExerciseMetricScope.repetition,
        },
      );

  static const ExerciseMetricDefinition<double> form =
      ExerciseMetricDefinition<double>(
        id: ExerciseMetricId.form,
        key: 'form_metric',
        family: ExerciseMetricFamily.form,
        unit: ExerciseMetricUnit.degrees,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.frame,
          ExerciseMetricScope.repetition,
          ExerciseMetricScope.session,
        },
      );

  static const ExerciseMetricDefinition<double> rangeOfMotion =
      ExerciseMetricDefinition<double>(
        id: ExerciseMetricId.rangeOfMotion,
        key: 'range_of_motion',
        family: ExerciseMetricFamily.rangeOfMotion,
        unit: ExerciseMetricUnit.degrees,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.repetition,
          ExerciseMetricScope.session,
        },
      );

  static const ExerciseMetricDefinition<Duration> tempo =
      ExerciseMetricDefinition<Duration>(
        id: ExerciseMetricId.tempo,
        key: 'tempo',
        family: ExerciseMetricFamily.tempo,
        unit: ExerciseMetricUnit.milliseconds,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.repetition,
          ExerciseMetricScope.session,
        },
      );

  static const ExerciseMetricDefinition<double> symmetry =
      ExerciseMetricDefinition<double>(
        id: ExerciseMetricId.symmetry,
        key: 'symmetry_difference',
        family: ExerciseMetricFamily.symmetry,
        unit: ExerciseMetricUnit.degrees,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.frame,
          ExerciseMetricScope.repetition,
          ExerciseMetricScope.session,
        },
      );

  static const ExerciseMetricDefinition<double> stability =
      ExerciseMetricDefinition<double>(
        id: ExerciseMetricId.stability,
        key: 'stability_score',
        family: ExerciseMetricFamily.stability,
        unit: ExerciseMetricUnit.score,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.frame,
          ExerciseMetricScope.repetition,
          ExerciseMetricScope.session,
        },
      );

  static const ExerciseMetricDefinition<Duration> repDuration =
      ExerciseMetricDefinition<Duration>(
        id: ExerciseMetricId.repDuration,
        key: 'rep_duration',
        family: ExerciseMetricFamily.duration,
        unit: ExerciseMetricUnit.milliseconds,
        scopes: <ExerciseMetricScope>{
          ExerciseMetricScope.repetition,
          ExerciseMetricScope.session,
        },
      );

  static final List<ExerciseMetricDefinitionBase> _definitions =
      List<ExerciseMetricDefinitionBase>.unmodifiable(
        <ExerciseMetricDefinitionBase>[
          repetitionCount,
          holdDuration,
          primaryMovement,
          form,
          rangeOfMotion,
          tempo,
          symmetry,
          stability,
          repDuration,
        ],
      );

  static final Map<ExerciseMetricId, ExerciseMetricDefinitionBase> _byId =
      _buildDefinitionsById(_definitions);

  static List<ExerciseMetricDefinitionBase> get definitions => _definitions;

  static bool contains(ExerciseMetricId id) => _byId.containsKey(id);

  static ExerciseMetricDefinitionBase definitionFor(ExerciseMetricId id) {
    final definition = _byId[id];
    if (definition == null) {
      throw StateError('Missing metric definition for ${id.name}.');
    }
    return definition;
  }

  static Map<ExerciseMetricId, ExerciseMetricDefinitionBase>
  _buildDefinitionsById(List<ExerciseMetricDefinitionBase> definitions) {
    final definitionsById = <ExerciseMetricId, ExerciseMetricDefinitionBase>{};
    for (final definition in definitions) {
      final previous = definitionsById[definition.id];
      if (previous != null) {
        throw StateError(
          'Duplicate metric definition registered for ${definition.id.name}.',
        );
      }
      definitionsById[definition.id] = definition;
    }

    final missingIds = ExerciseMetricId.values
        .where((id) => !definitionsById.containsKey(id))
        .map((id) => id.name)
        .toList(growable: false);
    if (missingIds.isNotEmpty) {
      throw StateError(
        'Missing metric definitions for: ${missingIds.join(', ')}.',
      );
    }

    return Map<ExerciseMetricId, ExerciseMetricDefinitionBase>.unmodifiable(
      definitionsById,
    );
  }
}
