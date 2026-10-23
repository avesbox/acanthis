import 'dart:collection';

import 'package:meta/meta.dart';

import 'schema.dart';

/// Built-in composition exposes definition edges without recursively asking
/// descendants for capabilities. Third-party leaves retain their async hook.
@internal
abstract interface class SchemaGraphNode {
  bool get hasLocalAsync;
  Iterable<Schema<Object?, Object?>> get schemaChildren;
}

/// Export introspection for a bound lazy definition; validation stays private.
@internal
abstract interface class ResolvedSchema {
  Schema<Object?, Object?> get resolvedSchema;
  bool get hasWrapperOperations;
  bool get hasOwnDefault;
}

/// Resolve a root's capability without treating a back edge as proof that a
/// descendant is synchronous. Built-in callers cache their completed result.
@internal
bool schemaGraphIsAsync(Schema<Object?, Object?> root) {
  if (root is! SchemaGraphNode) {
    return root is AsyncSchema<Object?, Object?> && root.isAsync;
  }
  final rootNode = root as SchemaGraphNode;
  var async = rootNode.hasLocalAsync;
  List<Schema<Object?, Object?>>? pending;
  for (final child in rootNode.schemaChildren) {
    if (child is SchemaGraphNode) {
      (pending ??= []).add(child);
    } else if (child is AsyncSchema<Object?, Object?>) {
      async = child.isAsync || async;
    }
  }
  if (pending == null) return async;
  final seen = HashSet<Schema<Object?, Object?>>.identity()..add(root);
  while (pending.isNotEmpty) {
    final schema = pending.removeLast();
    if (schema is SchemaGraphNode) {
      if (!seen.add(schema)) continue;
      final node = schema as SchemaGraphNode;
      async = node.hasLocalAsync || async;
      pending.addAll(node.schemaChildren);
    } else if (schema is AsyncSchema<Object?, Object?>) {
      async = schema.isAsync || async;
    }
  }
  return async;
}
