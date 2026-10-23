import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';

import 'package:meta/meta.dart';

import '../common/operations.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/schema_operations.dart';
import 'list.dart';
import 'object.dart';
import 'nullable.dart';

/// A parent-dependent schema definition. Place it directly in an object field
/// or use [call] to bind it explicitly before parsing it on its own.
final class LazyEntry<O> extends Schema<Object?, O>
    with
        CheckableSchema<Object?, O>,
        TransformableSchema<Object?, O>,
        ValidationSchema<Object?, O>,
        AsyncSchema<Object?, O>,
        DefaultSchema<Object?, O>,
        ListableSchema<Object?, O>,
        NullableSchema<Object?, O> {
  LazyEntry(this._resolver)
    : _operations = SchemaOperations<O>(),
      defaultValue = null,
      hasDefault = false;
  LazyEntry._(
    this._resolver,
    this._operations,
    this.defaultValue,
    this.hasDefault,
  );
  final Schema<Object?, O> Function(ObjectSchema parent) _resolver;
  final SchemaOperations<O> _operations;
  @override
  final O? defaultValue;
  @override
  final bool hasDefault;
  @override
  LazyEntry<O> meta(MetadataEntry<O> metadata) => attachSchemaMetadata(
    copySchemaMetadata(
      this,
      LazyEntry._(_resolver, _operations, defaultValue, hasDefault),
    ),
    metadata,
  );
  @override
  List<Check<O>> get checks => _operations.checks;
  @override
  List<Transform<O, O>> get transformations => _operations.transformations;
  List<AsyncCheck<O>> get asyncChecks => _operations.asyncChecks;
  @override
  bool get isAsync => throw StateError(
    'Bind the lazy schema to an ObjectSchema before inspecting async capability',
  );

  @override
  LazyEntry<O> withCheck(Check<O> check) => copySchemaMetadata(
    this,
    LazyEntry._(
      _resolver,
      _operations.withCheck(check),
      defaultValue,
      hasDefault,
    ),
  );
  @override
  LazyEntry<O> refine({
    required bool Function(O) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<O>.refinement(onCheck: onCheck, error: error, name: name),
  );
  LazyEntry<O> refineAsync(AsyncCheck<O> check) => copySchemaMetadata(
    this,
    LazyEntry._(
      _resolver,
      _operations.withAsyncCheck(check),
      defaultValue,
      hasDefault,
    ),
  );
  @override
  LazyEntry<O> transform(O Function(O) onTransform) =>
      withTransform(CallbackTransform(onTransform));
  @override
  LazyEntry<O> withTransform(Transform<O, O> transform) => copySchemaMetadata(
    this,
    LazyEntry._(
      _resolver,
      _operations.withTransform(transform),
      defaultValue,
      hasDefault,
    ),
  );
  LazyEntry<O> transformAsync(AsyncTransform<O, O> transform) =>
      copySchemaMetadata(
        this,
        LazyEntry._(
          _resolver,
          _operations.withAsyncTransform(transform),
          defaultValue,
          hasDefault,
        ),
      );
  LazyEntry<O> withDefault(O value) => copySchemaMetadata(
    this,
    LazyEntry._(_resolver, _operations, value, true),
  );

  /// Returns the stable bound wrapper, including its checks and transforms.
  Schema<Object?, O> call(ObjectSchema parent) => bindTo(parent.lazyBinding);
  @internal
  Schema<Object?, O> bindTo(LazyBinding binding) => binding._bind(this);
  @internal
  Schema<Object?, O> bindForExecution(LazyBinding binding) {
    final bound = binding._bind(this);
    return _operations.isEmpty && !hasDefault ? bound.target : bound;
  }

  Schema<Object?, O> _bound(ObjectSchema? parent) {
    if (parent == null) {
      throw StateError(
        'A lazy schema requires a parent ObjectSchema; use lazy.call(parent) or parse(input, parent)',
      );
    }
    return call(parent);
  }

  @override
  O parse(Object? input, [ObjectSchema? parent]) => _bound(parent).parse(input);
  @override
  AcanthisOutcome<O> parseOutcome(Object? input, [ObjectSchema? parent]) =>
      _bound(parent).parseOutcome(input);
  @override
  AcanthisOutcome<O> tryParse(Object? input, [ObjectSchema? parent]) =>
      _bound(parent).tryParse(input);
  @override
  Future<O> parseAsync(Object? input, [ObjectSchema? parent]) =>
      (_bound(parent) as AsyncSchema<Object?, O>).parseAsync(input);
  @override
  Future<AcanthisOutcome<O>> parseOutcomeAsync(
    Object? input, [
    ObjectSchema? parent,
  ]) => (_bound(parent) as AsyncSchema<Object?, O>).parseOutcomeAsync(input);
  @override
  Future<AcanthisOutcome<O>> tryParseAsync(
    Object? input, [
    ObjectSchema? parent,
  ]) => (_bound(parent) as AsyncSchema<Object?, O>).tryParseAsync(input);
  @override
  bool validate(Object? input, [ObjectSchema? parent]) =>
      parseOutcome(input, parent).isValid;
  @override
  bool tryValidate(Object? input, [ObjectSchema? parent]) =>
      tryParse(input, parent).isValid;
  Future<bool> validateAsync(Object? input, [ObjectSchema? parent]) async =>
      (await parseOutcomeAsync(input, parent)).isValid;
  Future<bool> tryValidateAsync(Object? input, [ObjectSchema? parent]) async =>
      (await tryParseAsync(input, parent)).isValid;
}

/// A definition-local scope shared by a parent view and any fluent variants
/// created inside its resolver. Recursive variants therefore form a finite graph.
@internal
final class LazyBinding {
  LazyBinding(ObjectSchema source) {
    parent = source.bindTo(this);
  }
  late final ObjectSchema parent;
  final _bound = Expando<Schema<Object?, Object?>>('bound lazy schema');
  _BoundLazy<T> _bind<T>(LazyEntry<T> entry) {
    final cached = _bound[entry];
    if (cached != null) return cached as _BoundLazy<T>;
    final schema = copySchemaMetadata(entry, _BoundLazy<T>(entry, this));
    _bound[entry] = schema;
    return schema;
  }
}

final class _BoundLazy<O> extends Schema<Object?, O>
    with AsyncSchema<Object?, O>, DefaultSchema<Object?, O>
    implements SchemaGraphNode, ResolvedSchema {
  _BoundLazy(this.definition, this.binding);
  final LazyEntry<O> definition;
  final LazyBinding binding;
  @override
  Schema<Object?, O> get resolvedSchema => target;
  @override
  bool get hasWrapperOperations => !definition._operations.isEmpty;
  @override
  bool get hasOwnDefault => definition.hasDefault;
  Schema<Object?, O>? _resolved;
  bool _resolving = false;
  Object? _resolutionError;
  StackTrace? _resolutionStack;

  Schema<Object?, O> get target {
    final cached = _resolved;
    if (cached != null) return cached;
    final error = _resolutionError;
    if (error != null) Error.throwWithStackTrace(error, _resolutionStack!);
    if (_resolving) {
      throw StateError(
        'Circular lazy resolution without an object or collection boundary',
      );
    }
    _resolving = true;
    try {
      final schema = definition._resolver(binding.parent);
      if (schema is LazyEntry || identical(schema, this)) {
        throw StateError(
          'Circular lazy resolution: return a concrete schema, not a LazyEntry',
        );
      }
      // Validate alias chains while retaining every wrapper's own operations.
      Schema<Object?, Object?> alias = schema;
      while (alias is AcanthisNullable<Object?>) {
        alias = alias.element;
      }
      if (alias is _BoundLazy) alias.target;
      return _resolved = schema;
    } catch (error, stack) {
      _resolutionError = error;
      _resolutionStack = stack;
      rethrow;
    } finally {
      _resolving = false;
    }
  }

  @override
  bool get hasLocalAsync => definition._operations.isAsync;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [target];
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  bool get hasDefault =>
      definition.hasDefault ||
      (target is DefaultSchema<Object?, O> &&
          (target as DefaultSchema<Object?, O>).hasDefault);
  @override
  O? get defaultValue => definition.hasDefault
      ? definition.defaultValue
      : target is DefaultSchema<Object?, O>
      ? (target as DefaultSchema<Object?, O>).defaultValue
      : null;

  @override
  O parse(Object? input) => parseOutcome(input).valueOrThrow;
  @override
  AcanthisOutcome<O> parseOutcome(Object? input) => _run(input, false);
  @override
  AcanthisOutcome<O> tryParse(Object? input) => _run(input, true);
  AcanthisOutcome<O> _run(Object? input, bool collect) {
    AcanthisValidationScope.current.throwIfCancelled();
    if (isAsync) throw StateError('This schema requires an async parse method');
    if (input == null && definition.hasDefault) input = definition.defaultValue;
    final child = target;
    return definition._operations.execute(
      collect ? child.tryParse(input) : child.parseOutcome(input),
      collect,
    );
  }

  @override
  Future<O> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;
  @override
  Future<AcanthisOutcome<O>> parseOutcomeAsync(Object? input) =>
      _runAsync(input, false);
  @override
  Future<AcanthisOutcome<O>> tryParseAsync(Object? input) =>
      _runAsync(input, true);
  Future<AcanthisOutcome<O>> _runAsync(Object? input, bool collect) async {
    AcanthisValidationScope.current.throwIfCancelled();
    if (!isAsync) return _run(input, collect);
    if (input == null && definition.hasDefault) input = definition.defaultValue;
    final child = target;
    final AcanthisOutcome<O> result;
    if (child is AsyncSchema<Object?, O>) {
      result = await (collect
          ? child.tryParseAsync(input)
          : child.parseOutcomeAsync(input));
    } else {
      result = collect ? child.tryParse(input) : child.parseOutcome(input);
    }
    return definition._operations.executeAsync(result, collect);
  }
}

LazyEntry<O> lazy<O>(
  Schema<Object?, O> Function(ObjectSchema parent) resolver,
) => LazyEntry(resolver);
