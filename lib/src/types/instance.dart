import 'package:meta/meta.dart';

import '../common/i18n.dart';
import '../common/issue.dart';
import '../common/operations.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';
import '../registries/metadata_registry.dart';

final class InstanceRefsBuilder<T> {
  final _refs = <String, Object Function(T)>{};

  InstanceRefsBuilder<T> ref<R extends Object>(
    String name,
    R Function(T) getter,
  ) {
    _refs[name] = getter;
    return this;
  }
}

final class RefAccessor<T> {
  RefAccessor(this._refs, this._value);
  final Map<String, Object Function(T)> _refs;
  final T _value;

  R call<R extends Object>(String name) {
    final getter = _refs[name];
    if (getter == null) throw ArgumentError('Reference "$name" not found');
    return getter(_value) as R;
  }
}

/// Validate getter values without reconstructing or modifying an instance.
final class InstanceType<T> extends ValueSchemaBase<T, InstanceType<T>> {
  InstanceType() : _fields = const [], _refs = const {}, mockFactory = null;

  InstanceType._(
    this._fields,
    this._refs,
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
    this.mockFactory,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );

  final List<InstanceField<T>> _fields;

  @internal
  List<InstanceField<T>> get fieldDefinitions => _fields;
  @internal
  final T Function(Map<String, Object?>)? mockFactory;

  /// Construct mock instances from generated, parsed field values.
  InstanceType<T> withFactory(T Function(Map<String, Object?>) factory) =>
      copySchemaMetadata(
        this,
        InstanceType._(
          _fields,
          _refs,
          operations,
          configuredDefault,
          ownDefault,
          factory,
        ),
      );
  final Map<String, Object Function(T)> _refs;

  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren =>
      _fields.map((field) => field.schema);
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  InstanceType<T> rebuild(
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    InstanceType._(
      _fields,
      _refs,
      operations,
      defaultValue,
      hasDefault,
      mockFactory,
    ),
  );

  /// Optional getters returning null skip the child, including its default.
  /// Child transforms validate their result but never write it to the instance.
  InstanceType<T> field<P>(
    String name,
    P Function(T) getter,
    Schema<Object?, P> validator, {
    bool optional = false,
  }) => copySchemaMetadata(
    this,
    InstanceType._(
      List.unmodifiable([
        ..._fields,
        InstanceField(name, getter, validator, optional),
      ]),
      _refs,
      operations.withField(name, getter, validator, optional: optional),
      configuredDefault,
      ownDefault,
      mockFactory,
    ),
  );

  InstanceType<T> withRefs(
    InstanceRefsBuilder<T> Function(InstanceRefsBuilder<T>) build,
  ) {
    final configured = build(InstanceRefsBuilder<T>());
    return copySchemaMetadata(
      this,
      InstanceType._(
        _fields,
        Map.unmodifiable({..._refs, ...configured._refs}),
        operations,
        configuredDefault,
        ownDefault,
        mockFactory,
      ),
    );
  }

  InstanceType<T> refineWithRefs(
    bool Function(T, RefAccessor<T>) onCheck,
    String error, {
    String name = 'refineWithRefs',
  }) => refine(
    onCheck: (value) => onCheck(value, RefAccessor(_refs, value)),
    name: name,
    error: error,
  );

  InstanceType<T> refineWithCause(
    String? Function(T, RefAccessor<T>) onCheck, {
    String name = 'refineWithCause',
  }) => withCheck(
    CallbackCheck((value, context) {
      final cause = onCheck(value, RefAccessor(_refs, value));
      if (cause != null) {
        final code = name.isEmpty ? 'custom' : name;
        context.addIssue(
          code,
          catalog: AcanthisMessageCatalog({code: (_) => cause}),
        );
      }
    }),
  );

  /// Extract original getter values; this does not validate or serialize them.
  Map<String, Object?> toMap(T value) => {
    for (final field in _fields) field.name: field.read(value),
  };

  @override
  AcanthisOutcome<T> parseValue(Object? input, bool collect) => input is T
      ? AcanthisValid(input)
      : AcanthisInvalid<T>.withoutValue([
          AcanthisIssue(
            path: const [],
            code: 'type',
            parameters: {'expected': '$T'},
          ),
        ]);
}

@internal
final class InstanceField<T> {
  const InstanceField(this.name, this._getter, this.schema, this.optional);
  final bool optional;
  final String name;
  final Object? Function(T) _getter;
  Object? read(Object? value) => _getter(value as T);
  final Schema<Object?, Object?> schema;
}

InstanceType<T> instance<T>() => InstanceType<T>();
