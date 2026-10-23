import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';
import '../common/issue.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';

final class AcanthisTuple
    extends ValueSchemaBase<List<Object?>, AcanthisTuple> {
  AcanthisTuple(List<Schema<Object?, Object?>> elements)
    : this._(
        List.unmodifiable(elements),
        false,
        SchemaOperations<List<Object?>>(),
        null,
        false,
      );
  AcanthisTuple._(
    this.elements,
    this.isVariadic,
    SchemaOperations<List<Object?>> operations,
    List<Object?>? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );
  final List<Schema<Object?, Object?>> elements;
  final bool isVariadic;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => elements;
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  AcanthisTuple rebuild(
    SchemaOperations<List<Object?>> operations,
    List<Object?>? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisTuple._(
      elements,
      isVariadic,
      operations,
      defaultValue == null ? null : List.unmodifiable(defaultValue),
      hasDefault,
    ),
  );

  /// Repeat the last element zero or more times after the fixed prefix.
  AcanthisTuple variadic() {
    if (elements.isEmpty) {
      throw StateError('A variadic tuple needs a last element');
    }
    return copySchemaMetadata(
      this,
      AcanthisTuple._(
        elements,
        true,
        operations,
        configuredDefault,
        ownDefault,
      ),
    );
  }

  AcanthisOutcome<List<Object?>>? _shape(Object? input) {
    if (input is! List) {
      return AcanthisInvalid<List<Object?>>.withoutValue([
        AcanthisIssue(path: [], code: 'type'),
      ]);
    }
    final min = isVariadic ? elements.length - 1 : elements.length;
    if (input.length < min ||
        (!isVariadic && input.length != elements.length)) {
      return AcanthisInvalid([
        AcanthisIssue(
          path: [],
          code: 'tuple',
          parameters: {'length': min, 'variadic': isVariadic},
        ),
      ], value: List<Object?>.of(input));
    }
    return null;
  }

  AcanthisOutcome<List<Object?>> _finish(
    List<Object?> output,
    List<AcanthisIssue> issues,
    bool recovery,
  ) => issues.isEmpty
      ? AcanthisValid(output)
      : recovery
      ? AcanthisInvalid(issues, value: output)
      : AcanthisInvalid<List<Object?>>.withoutValue(
          issues,
          partialValue: output,
        );
  @override
  AcanthisOutcome<List<Object?>> parseValue(Object? input, bool collect) {
    final failure = _shape(input);
    if (failure != null) return failure;
    final raw = input as List;
    final output = <Object?>[];
    final issues = <AcanthisIssue>[];
    var recovery = true;
    for (var i = 0; i < raw.length; i++) {
      AcanthisValidationScope.current.throwIfCancelled();
      final child = elements[i < elements.length ? i : elements.length - 1];
      final result = collect
          ? child.tryParse(raw[i])
          : child.parseOutcome(raw[i]);
      AcanthisValidationScope.current.throwIfCancelled();
      issues.addAll(result.issues.map((issue) => issue.prefixed(i)));
      if (result is AcanthisInvalid && !result.hasValue) {
        recovery = false;
        output.add(result.partialValue);
      } else {
        output.add(result.value);
      }
      if (!collect && issues.isNotEmpty) {
        return AcanthisInvalid<List<Object?>>.withoutValue(issues);
      }
    }
    return _finish(output, issues, recovery);
  }

  @override
  Future<AcanthisOutcome<List<Object?>>> parseValueAsync(
    Object? input,
    bool collect,
  ) async {
    final failure = _shape(input);
    if (failure != null) return failure;
    final raw = input as List;
    final output = <Object?>[];
    final issues = <AcanthisIssue>[];
    var recovery = true;
    for (var i = 0; i < raw.length; i++) {
      AcanthisValidationScope.current.throwIfCancelled();
      final child = elements[i < elements.length ? i : elements.length - 1];
      final result = child is AsyncSchema<Object?, Object?>
          ? await (collect
                ? child.tryParseAsync(raw[i])
                : child.parseOutcomeAsync(raw[i]))
          : collect
          ? child.tryParse(raw[i])
          : child.parseOutcome(raw[i]);
      AcanthisValidationScope.current.throwIfCancelled();
      issues.addAll(result.issues.map((issue) => issue.prefixed(i)));
      if (result is AcanthisInvalid && !result.hasValue) {
        recovery = false;
        output.add(result.partialValue);
      } else {
        output.add(result.value);
      }
      if (!collect && issues.isNotEmpty) {
        return AcanthisInvalid<List<Object?>>.withoutValue(issues);
      }
    }
    return _finish(output, issues, recovery);
  }
}

AcanthisTuple tuple(List<Schema<Object?, Object?>> elements) =>
    AcanthisTuple(elements);

extension TupleComposition<I, O> on Schema<I, O> {
  AcanthisTuple and(List<Schema<Object?, Object?>> elements) =>
      AcanthisTuple([this, ...elements]);
}
