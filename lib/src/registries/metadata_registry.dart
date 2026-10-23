import 'dart:collection';

import 'package:meta/meta.dart';

final class MetadataRegistry {
  MetadataRegistry._();
  static final _instance = MetadataRegistry._();
  factory MetadataRegistry() => _instance;
  final _entries = <String, MetadataEntry<Object?>>{};
  void add(String key, MetadataEntry<Object?> metadata) =>
      _entries[key] = metadata.snapshot();
  MetadataEntry<T>? get<T>(String key) => _entries[key] as MetadataEntry<T>?;
  bool has(String key) => _entries.containsKey(key);
  void remove(String key) => _entries.remove(key);
}

final class MetadataEntry<T> {
  const MetadataEntry({
    this.description,
    this.id,
    this.title,
    this.examples,
    this.comment,
    this.deprecated,
    this.defaultValue,
    this.format,
    this.readOnly,
    this.writeOnly,
    this.otherProperties,
  });
  final String? description;
  final String? id;
  final String? title;
  final List<T>? examples;
  final String? comment;
  final bool? deprecated;
  final T? defaultValue;
  final String? format;
  final bool? readOnly;
  final bool? writeOnly;
  final Map<String, Object?>? otherProperties;
  MetadataEntry<T> snapshot() => MetadataEntry<T>(
    description: description,
    id: id,
    title: title,
    examples: examples == null ? null : List.unmodifiable(examples!),
    comment: comment,
    deprecated: deprecated,
    defaultValue: defaultValue,
    format: format,
    readOnly: readOnly,
    writeOnly: writeOnly,
    otherProperties: otherProperties == null
        ? null
        : Map.unmodifiable(otherProperties!),
  );
  Map<String, Object?> toJson() => metadataJson({
    if (description != null) 'description': description,
    if (id != null) 'id': id,
    if (title != null) 'title': title,
    if (examples != null) 'examples': examples,
    if (comment != null) r'$comment': comment,
    if (deprecated != null) 'deprecated': deprecated,
    if (defaultValue != null) 'default': defaultValue,
    if (format != null) 'format': format,
    if (readOnly != null) 'readOnly': readOnly,
    if (writeOnly != null) 'writeOnly': writeOnly,
    if (otherProperties != null) 'otherProperties': otherProperties,
  }) as Map<String, Object?>;
}

// Metadata serialization never invokes arbitrary objects' toJson callbacks.
@internal
Object? metadataJson(Object? value) {
  final active = HashSet<Object>.identity();
  var remaining = 4096;
  Object? copy(Object? value, int depth) {
    if (--remaining < 0 || depth > 32) {
      throw ArgumentError('Metadata exceeds serialization limits');
    }
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double && value.isFinite) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is! List && value is! Map<String, Object?>) {
      throw ArgumentError('Metadata must contain JSON values or dates');
    }
    if (!active.add(value)) throw ArgumentError('Cyclic metadata');
    try {
      if (value is List) {
        return [for (final item in value) copy(item, depth + 1)];
      }
      return {
        for (final entry in (value as Map<String, Object?>).entries)
          entry.key: copy(entry.value, depth + 1),
      };
    } finally {
      active.remove(value);
    }
  }

  return copy(value, 0);
}

final _metadata = Expando<(String, MetadataEntry<Object?>)>();
var _nextKey = 0;
@internal
MetadataEntry<Object?>? schemaMetadata(Object schema) => _metadata[schema]?.$2;
@internal
String schemaMetadataKey(Object schema) => _metadata[schema]?.$1 ?? '';
@internal
S copySchemaMetadata<S extends Object>(Object source, S target) {
  final binding = _metadata[source];
  if (binding != null) _metadata[target] = binding;
  return target;
}

@internal
S attachSchemaMetadata<S extends Object>(
  S schema,
  MetadataEntry<Object?> metadata,
) {
  var key = schemaMetadataKey(schema);
  final registry = MetadataRegistry();
  if (key.isEmpty) {
    do {
      key = 'schema_${_nextKey++}';
    } while (registry.has(key));
  }
  final entry = metadata.snapshot();
  _metadata[schema] = (key, entry);
  registry._entries[key] = entry;
  return schema;
}
