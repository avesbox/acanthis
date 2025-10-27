import 'package:acanthis/src/types/types.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';

import '../operations/operation.dart';

/// Definition of a validated field on an instance
class _InstanceField<T, P> {
  final String name;
  final P Function(T object) getter;
  final AcanthisType<P> validator;
  final bool optional;
  const _InstanceField({
    required this.name,
    required this.getter,
    required this.validator,
    required this.optional,
  });
}

class InstanceRefsBuilder<T> {
  final Map<String, Object Function(T)> _refs = {};

  InstanceRefsBuilder<T> ref<R extends Object>(
    String name,
    R Function(T) getter,
  ) {
    _refs[name] = (t) => getter(t);
    return this;
  }
}

class RefAccessor<T> {
  final Map<String, Object Function(T)> _refs;
  final T _value;
  RefAccessor(this._refs, this._value);

  /// Retrieve a reference by name and cast to the expected type.
  R call<R extends Object>(String name) {
    final getter = _refs[name];
    if (getter == null) {
      throw ArgumentError('Reference "$name" not found');
    }
    return getter(_value) as R;
  }
}

/// A validator for already constructed objects of type T.
/// It validates properties (via getters) using existing AcanthisType validators
/// and returns the original instance (no transformation performed).
class InstanceType<T> extends AcanthisType<T> {
  final List<_InstanceField<T, dynamic>> _fields;

  final Map<String, Object Function(T)> _refs;

  const InstanceType._({
    super.operations,
    List<_InstanceField<T, dynamic>> fields = const [],
    Map<String, Object Function(T)> refs = const {},
    super.isAsync,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  }) : _fields = fields,
       _refs = refs;

  /// Create an empty instance validator
  const InstanceType() : this._();

  /// Add a field validator.
  /// getter extracts the property from the instance.
  /// optional skips validation when the extracted value is null.
  InstanceType<T> field<P>(
    String name,
    P Function(T object) getter,
    AcanthisType<P> validator, {
    bool optional = false,
  }) {
    final newFields = [
      ..._fields,
      _InstanceField<T, P>(
        name: name,
        getter: getter,
        validator: validator,
        optional: optional,
      ),
    ];

    final newOps = <AcanthisOperation<T>>[...operations];

    for (final op in validator.operations) {
      switch (op) {
        case AcanthisCheck<P>():
          newOps.add(
            CustomCheck<T>(
              (t) {
                final value = getter(t);
                if (optional && value == null) return true;
                return op(value);
              },
              error: op.error,
              name: '$name.${op.name}',
            ),
          );
          break;
        case AcanthisAsyncCheck<P>():
          newOps.add(
            CustomAsyncCheck<T>(
              (t) async {
                final value = getter(t);
                if (optional && value == null) return true;
                return await op(value);
              },
              error: op.error,
              name: '$name.${op.name}',
            ),
          );
          break;
        case AcanthisTransformation<P>():
          // For now ignore nested transformations: instance validator is non-transforming.
          // (Future enhancement: allow caching transformed property values.)
          throw UnimplementedError('Nested transformations are not supported');
        default:
          break;
      }
    }

    final anyAsync =
        isAsync || validator.operations.any((o) => o is AcanthisAsyncCheck);

    return InstanceType._(
      operations: newOps,
      fields: newFields,
      isAsync: anyAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  InstanceType<T> withCheck(AcanthisCheck<T> check) {
    return InstanceType._(
      operations: [...operations, check],
      fields: _fields,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  InstanceType<T> withAsyncCheck(AcanthisAsyncCheck<T> check) {
    return InstanceType._(
      operations: [...operations, check],
      fields: _fields,
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  InstanceType<T> withTransformation(AcanthisTransformation<T> transformation) {
    // Instance validator does not change the object; allow transformation though if user wants.
    return InstanceType._(
      operations: [...operations, transformation],
      fields: _fields,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final properties = <String, dynamic>{};
    final required = <String>[];
    for (final f in _fields) {
      properties[f.name] = f.validator.toJsonSchema();
      if (!f.optional) required.add(f.name);
    }
    final schema = <String, dynamic>{
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    };
    if (metadataEntry != null) {
      schema.addAll(metadataEntry!.toJson());
    }
    return schema;
  }

  @override
  InstanceType<T> meta(MetadataEntry<T> metadata) {
    var newKey = key;
    if (newKey.isEmpty) {
      newKey = 'instance_${T.toString()}';
    }
    MetadataRegistry().add(newKey, metadata);
    return InstanceType._(
      operations: operations,
      fields: _fields,
      isAsync: isAsync,
      key: newKey,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  /// Add references that can be used in refineWithRefs and refineWithCause
  InstanceType<T> withRefs(
    InstanceRefsBuilder<T> Function(InstanceRefsBuilder<T>) build,
  ) {
    final builder = InstanceRefsBuilder<T>();
    final configured = build(builder);
    return InstanceType._(
      operations: operations,
      fields: _fields,
      isAsync: isAsync,
      key: key,
      refs: {..._refs, ...configured._refs},
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  /// Add a custom check that can use other fields as references
  InstanceType<T> refineWithRefs(
    bool Function(T value, RefAccessor<T> refs) onCheck,
    String error, {
    String name = 'refineWithRefs',
  }) {
    final check = CustomCheck<T>(
      (t) => onCheck(t, RefAccessor<T>(_refs, t)),
      name: name,
      error: error,
    );
    return withCheck(check);
  }

  /// Add a custom check that can use other fields as references and returns a cause message on failure
  InstanceType<T> refineWithCause(
    String? Function(T value, RefAccessor<T> refs) onCheck, {
    String name = 'refineWithCause',
  }) {
    return withCheck(
      CustomCauseCheck((t) => onCheck(t, RefAccessor<T>(_refs, t)), name: name),
    );
  }

  /// Convert the instance to a map using the defined fields.
  Map<String, dynamic> toMap(T value) {
    final map = <String, dynamic>{};
    for (final f in _fields) {
      map[f.name] = f.getter(value);
    }
    return map;
  }

  @override
  InstanceType<T> withDefault(T value) {
    return InstanceType._(
      operations: operations,
      fields: _fields,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }
}

/// Factory function to create an instance validator.
InstanceType<T> instance<T>() => InstanceType<T>();
