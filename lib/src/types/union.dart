import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';
import '../common/issue.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';
import 'variant.dart';

final class AcanthisUnion<T> extends ValueSchemaBase<T, AcanthisUnion<T>> {
  factory AcanthisUnion(List<Object?> elements) {
    final types = <Schema<Object?, T>>[];
    final variants = <AcanthisVariant<T>>[];
    for (final element in elements) {
      if (element is AcanthisVariant<T>) {
        variants.add(element);
      } else if (element is Schema<Object?, T>) {
        types.add(element);
      } else {
        throw ArgumentError.value(
          element,
          'elements',
          'Expected a schema or guarded variant of $T',
        );
      }
    }
    return AcanthisUnion._(
      List.unmodifiable(types),
      List.unmodifiable(variants),
      SchemaOperations<T>(),
      null,
      false,
    );
  }
  AcanthisUnion._(
    this.alternatives,
    this.variants,
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );
  final List<Schema<Object?, T>> alternatives;
  final List<AcanthisVariant<T>> variants;
  bool get hasGuards => variants.isNotEmpty;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [
    ...variants.map((v) => v.schema),
    ...alternatives,
  ];
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  AcanthisUnion<T> rebuild(
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisUnion._(
      alternatives,
      variants,
      operations,
      defaultValue,
      hasDefault,
    ),
  );
  Iterable<Schema<Object?, T>> _candidates(
    Object? input,
    List<List<AcanthisIssue>> branches,
  ) sync* {
    for (final v in variants) {
      AcanthisValidationScope.current.throwIfCancelled();
      final accepted = v.guard(input);
      AcanthisValidationScope.current.throwIfCancelled();
      if (accepted) {
        yield v.schema;
      } else {
        branches.add([
          AcanthisIssue(
            path: [],
            code: 'variantGuard',
            parameters: {'name': v.name},
          ),
        ]);
      }
    }
    yield* alternatives;
  }

  AcanthisOutcome<T> _failure(
    Object? input,
    List<List<AcanthisIssue>> branches,
  ) {
    final issues = [AcanthisIssue(path: [], code: 'union', branches: branches)];
    return input is T
        ? AcanthisInvalid(issues, value: input)
        : AcanthisInvalid<T>.withoutValue(issues);
  }

  @override
  AcanthisOutcome<T> parseValue(Object? input, bool collect) {
    final branches = <List<AcanthisIssue>>[];
    for (final child in _candidates(input, branches)) {
      AcanthisValidationScope.current.throwIfCancelled();
      final result = child.tryParse(input);
      AcanthisValidationScope.current.throwIfCancelled();
      if (result.isValid) return result;
      branches.add(result.issues);
    }
    return _failure(input, branches);
  }

  @override
  Future<AcanthisOutcome<T>> parseValueAsync(
    Object? input,
    bool collect,
  ) async {
    final branches = <List<AcanthisIssue>>[];
    for (final child in _candidates(input, branches)) {
      AcanthisValidationScope.current.throwIfCancelled();
      final result = child is AsyncSchema<Object?, T>
          ? await child.tryParseAsync(input)
          : child.tryParse(input);
      AcanthisValidationScope.current.throwIfCancelled();
      if (result.isValid) return result;
      branches.add(result.issues);
    }
    return _failure(input, branches);
  }
}

AcanthisUnion<T> union<T>(List<Object?> elements) => AcanthisUnion<T>(elements);

extension UnionComposition<I, O> on Schema<I, O> {
  AcanthisUnion<T> or<T>(List<Object?> elements) =>
      AcanthisUnion<T>([this, ...elements]);
}
