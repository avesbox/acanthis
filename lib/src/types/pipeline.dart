import '../common/issue.dart';

import 'package:meta/meta.dart';

import '../common/map_schema.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/validation_scope.dart';
import '../common/value_schema.dart';
import '../registries/metadata_registry.dart';

/// Validate the source, convert its output, then validate the converted value.
final class AcanthisPipeline<A, B>
    extends ValueSchemaBase<B, AcanthisPipeline<A, B>> {
  AcanthisPipeline({
    required this.inType,
    required this.outType,
    required B Function(A) transform,
    B? defaultValue,
  }) : transformFn = transform,
       super(configuredDefault: defaultValue, ownDefault: defaultValue != null);

  AcanthisPipeline._(
    this.inType,
    this.outType,
    this.transformFn,
    SchemaOperations<B> operations,
    B? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );

  final Schema<Object?, A> inType;
  final Schema<Object?, B> outType;
  final B Function(A) transformFn;

  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [inType, outType];
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  AcanthisPipeline<A, B> rebuild(
    SchemaOperations<B> operations,
    B? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisPipeline._(
      inType,
      outType,
      transformFn,
      operations,
      defaultValue,
      hasDefault,
    ),
  );

  @override
  AcanthisOutcome<B> parseInput(Object? input, bool collect) =>
      input == null && hasDefault
      ? _output(defaultValue, collect)
      : parseValue(input, collect);

  @override
  Future<AcanthisOutcome<B>> parseInputAsync(Object? input, bool collect) =>
      input == null && hasDefault
      ? parseMapChildAsync(outType, defaultValue, collect)
      : parseValueAsync(input, collect);

  AcanthisOutcome<B> _output(Object? input, bool collect) =>
      collect ? outType.tryParse(input) : outType.parseOutcome(input);

  /// Mock inputs are already parsed; converting them must not parse them twice.
  @internal
  AcanthisOutcome<B> mockFromParsedInput(Object? input) {
    final converted = _convert(AcanthisValid(input as A));
    return applyOperations(
      converted.isValid ? _output(converted.value, true) : converted,
      true,
    );
  }

  AcanthisOutcome<B> _convert(AcanthisOutcome<A> source) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    if (!source.isValid) return AcanthisInvalid<B>.withoutValue(source.issues);
    try {
      final converted = transformFn(source.value);
      scope.throwIfCancelled();
      return AcanthisValid(converted);
    } on FormatException {
      return AcanthisInvalid<B>.withoutValue([
        AcanthisIssue(path: const [], code: 'transform'),
      ]);
    }
  }

  @override
  AcanthisOutcome<B> parseValue(Object? input, bool collect) {
    final converted = _convert(
      collect ? inType.tryParse(input) : inType.parseOutcome(input),
    );
    return converted.isValid ? _output(converted.value, collect) : converted;
  }

  @override
  Future<AcanthisOutcome<B>> parseValueAsync(
    Object? input,
    bool collect,
  ) async {
    final converted = _convert(
      await parseMapChildAsync(inType, input, collect),
    );
    return converted.isValid
        ? parseMapChildAsync(outType, converted.value, collect)
        : converted;
  }
}

extension PipelineSchemaComposition<I, O> on Schema<I, O> {
  AcanthisPipeline<O, T> pipe<T>(
    Schema<Object?, T> type, {
    required T Function(O value) transform,
    T? defaultValue,
  }) => AcanthisPipeline(
    inType: this,
    outType: type,
    transform: transform,
    defaultValue: defaultValue,
  );
}
