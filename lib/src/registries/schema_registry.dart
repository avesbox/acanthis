import '../types/types.dart';

/// A canonical token owned by the library defining a schema contract.
/// Import and reuse it: a different token with the same ID conflicts.
/// [T] is the parsed value type, including nested generic arguments.
/// [S] preserves the concrete schema type and its composition methods.
final class SchemaKey<T, S extends AcanthisType<T>> {
  const SchemaKey(this.id);
  final String id;

  // Uses both original type arguments even when callers widen the key.
  bool _accepts(AcanthisType<Object?> schema) =>
      schema is AcanthisType<T> && schema is S;
}

enum SchemaRegistryError {
  invalidId,
  duplicateToken,
  duplicateId,
  duplicateSchema,
  missingBinding,
  tokenConflict,
  incompatibleSchema,
}

/// A setup error, separate from validation issues in application input.
final class SchemaRegistryException implements Exception {
  const SchemaRegistryException(this.reason, this.id, this.message);
  final SchemaRegistryError reason;
  final String id;
  final String message;

  @override
  String toString() =>
      'SchemaRegistryException(${reason.name}, "$id"): $message';
}

/// One binding in the insertion-ordered, read-only catalog.
final class SchemaRegistryEntry {
  const SchemaRegistryEntry._(this.key, this.schema);
  final SchemaKey<Object?, AcanthisType<Object?>> key;
  final AcanthisType<Object?> schema;
  String get id => key.id;
}

/// Builds explicitly owned registries during application setup.
/// Bindings must have unique tokens, IDs, and schema identities. Registration
/// and lookup do not parse, mock, export, or execute user callbacks.
final class SchemaRegistryBuilder {
  final Map<String, SchemaRegistryEntry> _bindings = {};
  static final _idPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]*$');

  void add<T, S extends AcanthisType<T>>(SchemaKey<T, S> key, S schema) {
    _add(_bindings, SchemaRegistryEntry._(key, schema));
  }

  /// Imports an entire module or leaves this builder unchanged on failure.
  void addAll(SchemaRegistry module) {
    final merged = Map<String, SchemaRegistryEntry>.of(_bindings);
    for (final entry in module.entries) {
      _add(merged, entry);
    }
    _bindings
      ..clear()
      ..addAll(merged);
  }

  static void _add(
    Map<String, SchemaRegistryEntry> bindings,
    SchemaRegistryEntry entry,
  ) {
    final id = entry.id;
    final match = _idPattern.firstMatch(id);
    if (match == null || match.end != id.length) {
      throw SchemaRegistryException(
        SchemaRegistryError.invalidId,
        id,
        'IDs must match [A-Za-z_][A-Za-z0-9_.-]*.',
      );
    }
    final existing = bindings[id];
    if (existing != null) {
      throw SchemaRegistryException(
        identical(existing.key, entry.key)
            ? SchemaRegistryError.duplicateToken
            : SchemaRegistryError.duplicateId,
        id,
        'A binding with this ID already exists.',
      );
    }
    if (!entry.key._accepts(entry.schema)) {
      throw SchemaRegistryException(
        SchemaRegistryError.incompatibleSchema,
        id,
        'The schema is incompatible with the canonical token.',
      );
    }
    for (final existing in bindings.values) {
      if (identical(existing.schema, entry.schema)) {
        throw SchemaRegistryException(
          SchemaRegistryError.duplicateSchema,
          id,
          'The same schema instance is already bound to "${existing.id}".',
        );
      }
    }
    bindings[id] = entry;
  }

  /// Copies bindings; later builder changes do not affect this snapshot.
  SchemaRegistry build() => SchemaRegistry._(_bindings);
}

/// An immutable snapshot of bindings to the original schema instances.
/// Only the bindings are frozen. Schema internals, metadata, and state captured
/// by callbacks are not deep-frozen. Each application or isolate owns its
/// registry; there is no global registry or automatic metadata registration.
final class SchemaRegistry {
  SchemaRegistry._(Map<String, SchemaRegistryEntry> bindings)
    : _bindings = Map.unmodifiable(bindings),
      entries = List.unmodifiable(bindings.values);

  final Map<String, SchemaRegistryEntry> _bindings;
  final List<SchemaRegistryEntry> entries;

  /// Tests canonical token identity, not just the string ID.
  bool contains(SchemaKey<Object?, AcanthisType<Object?>> key) =>
      identical(_bindings[key.id]?.key, key);

  S get<S extends AcanthisType<Object?>>(SchemaKey<Object?, S> key) {
    final schema = find(key);
    if (schema != null) return schema;
    throw SchemaRegistryException(
      SchemaRegistryError.missingBinding,
      key.id,
      'No schema is registered for this token.',
    );
  }

  /// Returns null only for an absent ID. Conflicting tokens remain errors.
  S? find<S extends AcanthisType<Object?>>(SchemaKey<Object?, S> key) {
    final entry = _bindings[key.id];
    if (entry == null) return null;
    if (!identical(entry.key, key)) {
      throw SchemaRegistryException(
        SchemaRegistryError.tokenConflict,
        key.id,
        'Import the canonical token for this ID.',
      );
    }
    final schema = entry.schema;
    if (!key._accepts(schema) || schema is! S) {
      throw SchemaRegistryException(
        SchemaRegistryError.incompatibleSchema,
        key.id,
        'The registered schema is incompatible with this token.',
      );
    }
    return schema;
  }
}
