import '../registries/metadata_registry.dart';

import 'package:meta/meta.dart';

import '../common/map_schema.dart';
import '../common/object_evaluation.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/fast_schema.dart';
import '../validators/object.dart';
import '../rules.dart';
import '../common/validation_scope.dart';
import '../common/issue.dart';
import '../common/i18n.dart';
import 'list.dart';
import 'nullable.dart';
import 'tuple.dart';
import 'lazy.dart';
import 'number.dart';
import 'string.dart';
import 'boolean.dart';

/// Handling of fields not declared in an object schema.
enum AcanthisUnknownKeys { strip, preserve, reject }

/// A fixed shape with heterogeneous, named fields.
/// Missing required fields fail even if their child schema accepts null.
/// Unchanged typed input maps are reused, including their insertion order.
final class ObjectSchema extends MapSchemaBase<String, Object?, ObjectSchema>
    implements SchemaGraphNode, FastSchema<Map<String, Object?>> {
  ObjectSchema(Map<String, Schema<Object?, Object?>> fields)
    : fields = Map.unmodifiable(fields),
      optionalFields = const {},
      unknownKeyPolicy = AcanthisUnknownKeys.strip,
      isPatch = false,
      additionalValueType = null,
      rules = const [],
      _dependencies = const [],
      _bindingScope = null;

  ObjectSchema._(
    this.fields,
    this.optionalFields,
    this.unknownKeyPolicy,
    this.isPatch,
    MapOperations<String, Object?> operations,
    Map<String, Object?>? defaultValue, [
    this._bindingScope,
    this.additionalValueType,
    this.rules = const [],
    this._dependencies = const [],
  ]) : super(operations: operations, defaultValue: defaultValue) {
    for (final rule in rules) {
      _validateRulePaths(rule);
    }
  }

  final Map<String, Schema<Object?, Object?>> fields;
  final Set<String> optionalFields;
  final AcanthisUnknownKeys unknownKeyPolicy;
  final bool isPatch;
  final List<AcanthisRule<dynamic>> rules;
  final List<AcanthisFieldDependency> _dependencies;
  @internal
  bool get hasCrossFieldDependencies => _dependencies.isNotEmpty;
  bool get hasCrossFieldRules => rules.isNotEmpty || _dependencies.isNotEmpty;

  /// The schema for undeclared values, when typed passthrough is enabled.
  final Schema<Object?, Object?>? additionalValueType;
  @internal
  late final Schema<Object?, Object?>? resolvedAdditionalValueType =
      additionalValueType is LazyEntry<Object?>
      ? (additionalValueType as LazyEntry<Object?>).bindForExecution(
          lazyBinding,
        )
      : additionalValueType;
  final LazyBinding? _bindingScope;
  @internal
  late final LazyBinding lazyBinding = _bindingScope ?? LazyBinding(this);
  late final Map<String, Schema<Object?, Object?>> _resolvedFields =
      fields.values.any((child) => child is LazyEntry)
      ? {
          for (final entry in fields.entries)
            entry.key: entry.value is LazyEntry
                ? (entry.value as LazyEntry<Object?>).bindForExecution(
                    lazyBinding,
                  )
                : entry.value,
        }
      : fields;
  late final List<String> _keys = fields.keys.toList(growable: false);
  late final List<Schema<Object?, Object?>> _children = _resolvedFields.values
      .toList(growable: false);
  late final List<int> _kinds = _children
      .map(_primitiveKind)
      .toList(growable: false);
  late final bool _requiredPrimitives =
      !isPatch && optionalFields.isEmpty && _kinds.every((kind) => kind != 0);
  late final bool _canFastChildren = _children.every(
    (child) =>
        child is FastSchema<Object?> && (child as FastSchema<Object?>).canFast,
  );

  @internal
  ObjectSchema bindTo(LazyBinding scope) => copySchemaMetadata(
    this,
    ObjectSchema._(
      fields,
      optionalFields,
      unknownKeyPolicy,
      isPatch,
      operations,
      defaultValue,
      scope,
      additionalValueType,
      rules,
      _dependencies,
    ),
  );

  @override
  bool get hasLocalAsync =>
      operations.isAsync || rules.any((rule) => rule.isAsync);
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren =>
      additionalValueType == null
      ? _resolvedFields.values
      : [..._resolvedFields.values, resolvedAdditionalValueType!];
  @override
  late final bool isAsync = schemaGraphIsAsync(this);

  @override
  bool get childrenAreAsync => schemaGraphIsAsync(this);
  @override
  ObjectSchema rebuild(
    MapOperations<String, Object?> operations,
    Map<String, Object?>? defaultValue,
  ) => copySchemaMetadata(
    this,
    ObjectSchema._(
      fields,
      optionalFields,
      unknownKeyPolicy,
      isPatch,
      operations,
      defaultValue,
      _bindingScope,
      additionalValueType,
      rules,
      _dependencies,
    ),
  );

  ObjectSchema unknownKeys(AcanthisUnknownKeys policy) => copySchemaMetadata(
    this,
    ObjectSchema._(
      fields,
      optionalFields,
      policy,
      isPatch,
      operations,
      defaultValue,
      _bindingScope,
      policy == AcanthisUnknownKeys.preserve ? additionalValueType : null,
      rules,
      _dependencies,
    ),
  );

  /// Optional fields are omitted when absent; explicit null is still parsed.
  /// A child default, when configured, is applied before optional omission.
  ObjectSchema optionals(List<String> names) {
    for (final name in names) {
      if (!fields.containsKey(name)) {
        throw ArgumentError.value(name, 'names', 'Unknown field');
      }
    }
    return copySchemaMetadata(
      this,
      ObjectSchema._(
        fields,
        Set.unmodifiable({...optionalFields, ...names}),
        unknownKeyPolicy,
        isPatch,
        operations,
        defaultValue,
        _bindingScope,
        additionalValueType,
        rules,
        _dependencies,
      ),
    );
  }

  /// Omission-preserving partial input: absent fields never materialize defaults.
  /// With [deep], also makes directly nested ObjectSchema fields partial.
  /// Collection and nullable wrappers keep their original child schemas.
  ObjectSchema partial({bool deep = false}) => copySchemaMetadata(
    this,
    ObjectSchema._(
      deep
          ? Map.unmodifiable({
              for (final entry in fields.entries)
                entry.key: entry.value is ObjectSchema
                    ? (entry.value as ObjectSchema).partial(deep: true)
                    : entry.value,
            })
          : fields,
      optionalFields,
      unknownKeyPolicy,
      true,
      operations,
      defaultValue,
      _bindingScope,
      additionalValueType,
      rules,
      _dependencies,
    ),
  );

  ObjectSchema patch({bool deep = false}) => partial(deep: deep);

  /// Appends new fields; existing definitions win on collisions.
  ObjectSchema extend(Map<String, Schema<Object?, Object?>> additions) =>
      _shape({
        ...fields,
        for (final entry in additions.entries)
          if (!fields.containsKey(entry.key)) entry.key: entry.value,
      });

  /// Appends new fields and replaces existing definitions on collisions.
  ObjectSchema merge(Map<String, Schema<Object?, Object?>> additions) =>
      _shape({...fields, ...additions});

  /// Selects known fields in the requested order; unknown names are ignored.
  ObjectSchema pick(Iterable<String> names) => _shape({
    for (final name in names)
      if (fields.containsKey(name)) name: fields[name]!,
  });

  ObjectSchema omit(Iterable<String> names) {
    final excluded = names.toSet();
    return _shape({
      for (final entry in fields.entries)
        if (!excluded.contains(entry.key)) entry.key: entry.value,
    });
  }

  ObjectSchema _shape(Map<String, Schema<Object?, Object?>> shape) =>
      copySchemaMetadata(
        this,
        ObjectSchema._(
          Map.unmodifiable(shape),
          Set.unmodifiable(optionalFields.where(shape.containsKey)),
          unknownKeyPolicy,
          isPatch,
          operations,
          defaultValue,
          _bindingScope,
          additionalValueType,
          rules,
          _dependencies,
        ),
      );

  /// Preserves undeclared keys, optionally parsing their values with [type].
  /// Omitting [type] resets typed passthrough to unvalidated preservation.
  ObjectSchema passthrough({Schema<Object?, Object?>? type}) =>
      copySchemaMetadata(
        this,
        ObjectSchema._(
          fields,
          optionalFields,
          AcanthisUnknownKeys.preserve,
          isPatch,
          operations,
          defaultValue,
          _bindingScope,
          type,
          rules,
          _dependencies,
        ),
      );

  ObjectSchema minProperties(int count) => withCheck(MinPropertiesCheck(count));
  ObjectSchema maxProperties(int count) => withCheck(MaxPropertiesCheck(count));
  ObjectSchema lengthProperties(int count) =>
      withCheck(LengthPropertiesCheck(count));

  bool isOptionalField(String name) => isPatch || optionalFields.contains(name);

  ObjectSchema rule<C>(AcanthisRule<C> rule) {
    if (rule.id.isEmpty || rules.any((other) => other.id == rule.id)) {
      throw ArgumentError('Rule IDs must be nonempty and unique');
    }
    return copySchemaMetadata(
      this,
      ObjectSchema._(
        fields,
        optionalFields,
        unknownKeyPolicy,
        isPatch,
        operations,
        defaultValue,
        _bindingScope,
        additionalValueType,
        List.unmodifiable([...rules, rule]),
        _dependencies,
      ),
    );
  }

  ObjectSchema checkFields(
    Iterable<Object> fields, {
    required Object at,
    required String name,
    String? error,
    required bool Function(AcanthisRuleInputs) check,
    bool allowMissing = false,
    bool Function(AcanthisRuleInputs)? when,
  }) {
    final target = AcanthisPath.from(at);
    final issue = AcanthisIssue(
      path: target.segments,
      code: name,
      defaultCatalog: error == null
          ? null
          : AcanthisMessageCatalog({name: (_) => error}),
    );
    return rule(
      AcanthisRule<void>(
        id: name,
        inputs: fields,
        outputs: [target],
        allowMissing: allowMissing,
        when: when == null ? null : (values, _) => when(values),
        check: (values, _) => check(values) ? const [] : [issue],
      ),
    );
  }

  ObjectSchema checkFieldsAsync(
    Iterable<Object> fields, {
    required Object at,
    required String name,
    String? error,
    required Future<bool> Function(AcanthisRuleInputs) check,
    bool allowMissing = false,
    bool Function(AcanthisRuleInputs)? when,
  }) {
    final target = AcanthisPath.from(at);
    final issue = AcanthisIssue(
      path: target.segments,
      code: name,
      defaultCatalog: error == null
          ? null
          : AcanthisMessageCatalog({name: (_) => error}),
    );
    return rule(
      AcanthisRule<void>.async(
        id: name,
        inputs: fields,
        outputs: [target],
        allowMissing: allowMissing,
        when: when == null ? null : (values, _) => when(values),
        check: (values, _) async => await check(values) ? const [] : [issue],
      ),
    );
  }

  ObjectSchema addFieldDependency({
    required String dependent,
    required String dependendsOn,
    required bool Function(dynamic, dynamic) dependency,
  }) => copySchemaMetadata(
    this,
    ObjectSchema._(
      fields,
      optionalFields,
      unknownKeyPolicy,
      isPatch,
      operations,
      defaultValue,
      _bindingScope,
      additionalValueType,
      rules,
      List.unmodifiable([
        ..._dependencies,
        AcanthisFieldDependency(dependent, dependendsOn, dependency),
      ]),
    ),
  );

  void _validateRulePaths(AcanthisRule<dynamic> rule) {
    for (final path in [...rule.inputs, ...rule.outputs]) {
      Schema<Object?, Object?> current = this;
      for (final segment in path.segments) {
        while (current is AcanthisNullable<Object?>) {
          current = current.element;
        }
        if (current is LazyEntry || current is ResolvedSchema) break;
        if (current is ObjectSchema && segment is String) {
          final child = current.fields[segment];
          if (child == null) throw ArgumentError('Unknown rule field $segment');
          current = child;
        } else if (current is AcanthisList<Object?> && segment is int) {
          current = current.element;
        } else if (current is AcanthisTuple &&
            segment is int &&
            current.elements.isNotEmpty &&
            (segment < current.elements.length || current.isVariadic)) {
          current =
              current.elements[segment < current.elements.length
                  ? segment
                  : current.elements.length - 1];
        } else {
          throw ArgumentError('Rule path cannot be resolved statically');
        }
      }
    }
  }

  bool _skipMissing(
    String name,
    Schema<Object?, Object?> child,
    MapParseState<String, Object?> run,
  ) {
    if (isPatch) return true;
    if (child is DefaultSchema<Object?, Object?> && child.hasDefault) {
      return false;
    }
    if (!optionalFields.contains(name)) {
      run.sink.addIssue('required', path: [name]);
      run.hasValue = false;
    }
    return true;
  }

  bool _accepts(Object? input) =>
      input is Map<String, Object?> ||
      (input is Map<Object?, Object?> &&
          input.keys.every((key) => key is String));

  // Only final built-in primitives without behavior can bypass child outcomes.
  // Failed preconditions fall back to ordinary parsing for identical diagnostics.
  static int _primitiveKind(Schema<Object?, Object?> child) {
    if (child is AcanthisString && child.isIdentity) {
      return 1;
    }
    if (child is AcanthisNumeric<num> && child.isIdentity) {
      return child is AcanthisNumeric<int>
          ? 2
          : child is AcanthisNumeric<double>
          ? 3
          : 4;
    }
    if (child is AcanthisBoolean && child.isIdentity) return 5;
    return 0;
  }

  static bool _matches(int kind, Object? value) => switch (kind) {
    1 => value is String,
    2 => value is int,
    3 => value is double,
    4 => value is num,
    5 => value is bool,
    _ => false,
  };

  bool _acceptsPrimitives(Map<Object?, Object?> raw) {
    if (hasCrossFieldRules ||
        !_requiredPrimitives ||
        (additionalValueType != null && raw.length != _keys.length) ||
        (unknownKeyPolicy == AcanthisUnknownKeys.reject &&
            raw.length != _keys.length)) {
      return false;
    }
    for (var i = 0; i < _keys.length; i++) {
      if (!_matches(_kinds[i], raw[_keys[i]])) return false;
    }
    return true;
  }

  Map<String, Object?> _primitiveOutput(Map<Object?, Object?> raw) {
    // Reuse unchanged typed maps. Opaque root operations need their own map;
    // use the native clone when it preserves schema-first output order.
    if (raw is Map<String, Object?> &&
        (raw.length == _keys.length ||
            unknownKeyPolicy == AcanthisUnknownKeys.preserve)) {
      if (!hasOperations) return raw;
      var index = 0;
      var ordered = true;
      for (final key in raw.keys) {
        if (index == _keys.length) break;
        if (key != _keys[index++]) {
          ordered = false;
          break;
        }
      }
      if (ordered) return Map<String, Object?>.of(raw);
    }
    return {
      for (final key in _keys) key: raw[key],
      if (unknownKeyPolicy == AcanthisUnknownKeys.preserve)
        for (final entry in raw.entries) entry.key as String: entry.value,
    };
  }

  @override
  bool get canFast =>
      !hasCrossFieldRules &&
      !hasOperations &&
      !isPatch &&
      optionalFields.isEmpty;
  @override
  Map<String, Object?>? tryFast(Object? input) {
    if (!canFast || isAsync) return null;
    return _fastChildren(input ?? defaultValue);
  }

  Map<String, Object?>? _fastChildren(Object? input) {
    if (hasCrossFieldRules ||
        isPatch ||
        optionalFields.isNotEmpty ||
        input is! Map<String, Object?> ||
        (additionalValueType != null && input.length != _keys.length) ||
        (input.length != _keys.length &&
            unknownKeyPolicy != AcanthisUnknownKeys.preserve)) {
      return null;
    }
    if (_requiredPrimitives) {
      if (_keys.length >= 4 && input.length == _keys.length) {
        final keys = _keys;
        final kinds = _kinds;
        var index = 0;
        var accepted = true;
        input.forEach((key, value) {
          if (key != keys[index] || !_matches(kinds[index], value)) {
            accepted = false;
          }
          index++;
        });
        if (accepted) {
          return hasOperations ? Map<String, Object?>.of(input) : input;
        }
        return null;
      }
      for (var i = 0; i < _keys.length; i++) {
        if (!_matches(_kinds[i], input[_keys[i]])) return null;
      }
      return hasOperations ? _primitiveOutput(input) : input;
    }
    if (!_canFastChildren) return null;
    if (_keys.length <= 3 && input.length == _keys.length) {
      return _fastSmall(input);
    }
    Object? preparedFirst;
    if (_keys.isNotEmpty && _kinds[0] == 0 && _children[0] is AcanthisString) {
      preparedFirst = (_children[0] as AcanthisString).tryFast(input[_keys[0]]);
      if (preparedFirst == null) return null;
    }
    final keys = input.keys.iterator;
    final values = input.values.iterator;
    Map<String, Object?>? output;
    for (var i = 0; i < _keys.length; i++) {
      if (!keys.moveNext() || keys.current != _keys[i] || !values.moveNext()) {
        return null;
      }
      final raw = values.current;
      final child = _children[i];
      final Object? value;
      if (_kinds[i] != 0) {
        if (!_matches(_kinds[i], raw)) return null;
        value = raw;
      } else {
        if (child is! FastSchema<Object?>) return null;
        value = i == 0 && preparedFirst != null
            ? preparedFirst
            : (child as FastSchema<Object?>).tryFast(raw);
        if (value == null) return null;
      }
      if (!identical(value, raw)) {
        (output ??= Map<String, Object?>.of(input))[_keys[i]] = value;
      }
    }
    return output ?? (hasOperations ? Map<String, Object?>.of(input) : input);
  }

  Object? _fastValue(int index, Object? value) {
    final kind = _kinds[index];
    return kind != 0
        ? (_matches(kind, value) ? value : null)
        : (_children[index] as FastSchema<Object?>).tryFast(value);
  }

  // Small objects avoid allocating key/value iterators and then cloning a map
  // only to overwrite transformed children. Unchanged inputs are reused;
  // literals retain schema order when a child changes.
  Map<String, Object?>? _fastSmall(Map<String, Object?> input) {
    final k0 = _keys[0];
    final r0 = input[k0];
    if (r0 == null && !input.containsKey(k0)) return null;
    final v0 = _fastValue(0, r0);
    if (v0 == null) return null;
    if (_keys.length == 1) {
      return !hasOperations && identical(v0, r0) ? input : {k0: v0};
    }
    final k1 = _keys[1];
    final r1 = input[k1];
    if (r1 == null && !input.containsKey(k1)) return null;
    final v1 = _fastValue(1, r1);
    if (v1 == null) return null;
    if (_keys.length == 2) {
      return !hasOperations && identical(v0, r0) && identical(v1, r1)
          ? input
          : {k0: v0, k1: v1};
    }
    final k2 = _keys[2];
    final r2 = input[k2];
    if (r2 == null && !input.containsKey(k2)) return null;
    final v2 = _fastValue(2, r2);
    if (v2 == null) return null;
    return !hasOperations &&
            identical(v0, r0) &&
            identical(v1, r1) &&
            identical(v2, r2)
        ? input
        : {k0: v0, k1: v1, k2: v2};
  }

  @override
  AcanthisOutcome<Map<String, Object?>> parseChildren(
    Object? input,
    bool collect,
  ) {
    final fast = _fastChildren(input);
    if (fast != null) return AcanthisValid(fast);
    return _parseChildrenOrdinary(input, collect);
  }

  @internal
  AcanthisOutcome<Map<String, Object?>> evaluateObject(
    Map<String, Object?> input,
    ObjectEvaluation evaluation,
  ) {
    if (isAsync) throw StateError('This schema requires an async parse method');
    return operations.execute(
      _parseChildrenOrdinary(input, true, evaluation),
      true,
    );
  }

  @internal
  Future<AcanthisOutcome<Map<String, Object?>>> evaluateObjectAsync(
    Map<String, Object?> input,
    ObjectEvaluation evaluation,
  ) async => operations.executeAsync(
    await _parseChildrenAsync(input, true, evaluation),
    true,
  );

  AcanthisOutcome<Map<String, Object?>> _parseChildrenOrdinary(
    Object? input,
    bool collect, [
    ObjectEvaluation? evaluation,
  ]) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    if (!_accepts(input)) return _invalidInput();
    final raw = input as Map<Object?, Object?>;
    if (evaluation == null && _acceptsPrimitives(raw)) {
      return AcanthisValid(_primitiveOutput(raw));
    }
    final run = MapParseState<String, Object?>();
    for (var i = 0; i < _keys.length; i++) {
      scope.throwIfCancelled();
      final name = _keys[i];
      final child = _children[i];
      final value = raw[name];
      if (evaluation == null && _matches(_kinds[i], value)) {
        run.output[name] = value;
        continue;
      }
      if (value == null &&
          !raw.containsKey(name) &&
          _skipMissing(name, child, run)) {
        evaluation?.settleMissing(name);
        if (stop && run.sink.isNotEmpty) return run.finish(complete: false);
        continue;
      }
      final result =
          evaluation?.fields[name] ??
          (collect ? child.tryParse(value) : child.parseOutcome(value));
      evaluation?.settle(name, result);
      AcanthisValidationScope.current.throwIfCancelled();
      if (run.addChild(name, result)) run.output[name] = result.value;
      if (stop && !result.isValid) return run.finish(complete: false);
    }
    return _finishUnknown(raw, run, collect, evaluation);
  }

  @override
  Future<AcanthisOutcome<Map<String, Object?>>> parseChildrenAsync(
    Object? input,
    bool collect,
  ) => _parseChildrenAsync(input, collect);

  Future<AcanthisOutcome<Map<String, Object?>>> _parseChildrenAsync(
    Object? input,
    bool collect, [
    ObjectEvaluation? evaluation,
  ]) async {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    if (!_accepts(input)) return _invalidInput();
    final raw = input as Map<Object?, Object?>;
    if (evaluation == null && _acceptsPrimitives(raw)) {
      return AcanthisValid(_primitiveOutput(raw));
    }
    final run = MapParseState<String, Object?>();
    for (var i = 0; i < _keys.length; i++) {
      scope.throwIfCancelled();
      final name = _keys[i];
      final child = _children[i];
      final value = raw[name];
      if (evaluation == null && _matches(_kinds[i], value)) {
        run.output[name] = value;
        continue;
      }
      if (value == null &&
          !raw.containsKey(name) &&
          _skipMissing(name, child, run)) {
        evaluation?.settleMissing(name);
        if (stop && run.sink.isNotEmpty) return run.finish(complete: false);
        continue;
      }
      final result =
          evaluation?.fields[name] ??
          await parseMapChildAsync(child, value, collect);
      evaluation?.settle(name, result);
      AcanthisValidationScope.current.throwIfCancelled();
      if (run.addChild(name, result)) run.output[name] = result.value;
      if (stop && !result.isValid) return run.finish(complete: false);
    }
    return _finishUnknownAsync(raw, run, collect, evaluation);
  }

  AcanthisOutcome<Map<String, Object?>> _finishUnknown(
    Map<Object?, Object?> raw,
    MapParseState<String, Object?> run,
    bool collect, [
    ObjectEvaluation? evaluation,
  ]) {
    final stop =
        !collect ||
        AcanthisValidationScope.current.objectPolicy ==
            AcanthisCollectionPolicy.first;
    if (unknownKeyPolicy != AcanthisUnknownKeys.strip) {
      for (final entry in raw.entries) {
        final name = entry.key as String;
        if (fields.containsKey(name)) continue;
        if (unknownKeyPolicy == AcanthisUnknownKeys.preserve) {
          final child = resolvedAdditionalValueType;
          if (child == null) {
            run.output[name] = entry.value;
          } else {
            final result = collect
                ? child.tryParse(entry.value)
                : child.parseOutcome(entry.value);
            AcanthisValidationScope.current.throwIfCancelled();
            if (run.addChild(name, result)) run.output[name] = result.value;
            if (stop && !result.isValid) return run.finish(complete: false);
          }
        } else {
          run.sink.addIssue('unknownKey', path: [name]);
          if (stop) return run.finish(complete: false);
        }
      }
    }
    return _finishRules(raw, run, collect, evaluation);
  }

  Future<AcanthisOutcome<Map<String, Object?>>> _finishUnknownAsync(
    Map<Object?, Object?> raw,
    MapParseState<String, Object?> run,
    bool collect, [
    ObjectEvaluation? evaluation,
  ]) async {
    final scope = AcanthisValidationScope.current;
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    final child = resolvedAdditionalValueType;
    if (unknownKeyPolicy != AcanthisUnknownKeys.strip) {
      for (final entry in raw.entries) {
        scope.throwIfCancelled();
        final name = entry.key as String;
        if (fields.containsKey(name)) continue;
        if (unknownKeyPolicy == AcanthisUnknownKeys.reject) {
          run.sink.addIssue('unknownKey', path: [name]);
          if (stop) return run.finish(complete: false);
        } else if (child == null) {
          run.output[name] = entry.value;
        } else {
          final result = await parseMapChildAsync(child, entry.value, collect);
          scope.throwIfCancelled();
          if (run.addChild(name, result)) run.output[name] = result.value;
          if (stop && !result.isValid) return run.finish(complete: false);
        }
      }
    }
    if (!hasCrossFieldRules) {
      return run.finish(reuseInput: hasOperations ? null : raw);
    }
    final childIssues = run.sink.issues;
    for (final rule in rules) {
      scope.throwIfCancelled();
      var issues = evaluation?.rules[rule.id];
      if (issues == null) {
        evaluation?.executedRules.add(rule.id);
        issues = await rule.evaluateAsync(raw, run.ruleOutput, childIssues);
        if (evaluation != null) evaluation.rules[rule.id] = issues;
      }
      run.sink.addAll(issues);
      if (stop && run.sink.isNotEmpty) return run.finish();
    }
    return _finishDependencies(raw, run, collect);
  }

  AcanthisOutcome<Map<String, Object?>> _finishRules(
    Map<Object?, Object?> raw,
    MapParseState<String, Object?> run,
    bool collect, [
    ObjectEvaluation? evaluation,
  ]) {
    final scope = AcanthisValidationScope.current;
    if (!hasCrossFieldRules) {
      return run.finish(reuseInput: hasOperations ? null : raw);
    }
    final childIssues = run.sink.issues;
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    for (final rule in rules) {
      scope.throwIfCancelled();
      var issues = evaluation?.rules[rule.id];
      if (issues == null) {
        evaluation?.executedRules.add(rule.id);
        issues = rule.evaluate(raw, run.ruleOutput, childIssues);
        if (evaluation != null) evaluation.rules[rule.id] = issues;
      }
      run.sink.addAll(issues);
      if (stop && run.sink.isNotEmpty) return run.finish();
    }
    return _finishDependencies(raw, run, collect);
  }

  AcanthisOutcome<Map<String, Object?>> _finishDependencies(
    Map<Object?, Object?> raw,
    MapParseState<String, Object?> run,
    bool collect,
  ) {
    final scope = AcanthisValidationScope.current;
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    for (final dependency in _dependencies) {
      scope.throwIfCancelled();
      run.sink.addAll(dependency.evaluate(raw));
      if (stop && run.sink.isNotEmpty) break;
    }
    scope.throwIfCancelled();
    return run.finish(reuseInput: hasOperations ? null : raw);
  }

  AcanthisOutcome<Map<String, Object?>> _invalidInput() {
    final run = MapParseState<String, Object?>();
    run.sink.addIssue(
      'type',
      parameters: const {'expected': 'Map<String, Object?>'},
    );
    return run.finish(complete: false);
  }
}

ObjectSchema object(Map<String, Schema<Object?, Object?>> fields) =>
    ObjectSchema(fields);
