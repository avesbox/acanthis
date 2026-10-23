import 'package:acanthis/src/common/operations.dart';
import 'package:meta/meta.dart';

import 'results.dart';
import '../registries/metadata_registry.dart';
import 'schema_graph.dart';

abstract class Schema<Input, Output> {
  const Schema();

  MetadataEntry<Output>? get metadataEntry =>
      schemaMetadata(this) as MetadataEntry<Output>?;
  String get metadataKey => schemaMetadataKey(this);
  Schema<Input, Output> meta(MetadataEntry<Output> metadata) {
    final source = this;
    return attachSchemaMetadata(
      copySchemaMetadata(
        this,
        MetadataSchemaView<Input, Output>(
          source is MetadataSchemaView<Input, Output> ? source.schema : source,
        ),
      ),
      metadata,
    );
  }

  /// Return the parsed value; invalid input throws [ValidationError].
  Output parse(Object? input);

  AcanthisOutcome<Output> tryParse(Object? input);

  /// Internal fail-fast composition without exception conversion at each node.
  /// External schemas can implement just the public raw-value parse method.
  @internal
  AcanthisOutcome<Output> parseOutcome(Object? input) {
    try {
      return AcanthisValid(parse(input));
    } on ValidationError catch (error) {
      final failure = error.failure;
      return failure is AcanthisOutcome<Output>
          ? failure as AcanthisOutcome<Output>
          : AcanthisInvalid<Output>.withoutValue(error.issues);
    }
  }
}

/// A metadata-only view for third-party schemas; native types keep their type.
@internal
final class MetadataSchemaView<I, O> extends Schema<I, O>
    with AsyncSchema<I, O>, DefaultSchema<I, O>
    implements SchemaGraphNode, ResolvedSchema {
  MetadataSchemaView(this.schema);
  final Schema<I, O> schema;
  @override
  O parse(Object? input) => schema.parse(input);
  @override
  AcanthisOutcome<O> parseOutcome(Object? input) => schema.parseOutcome(input);
  @override
  AcanthisOutcome<O> tryParse(Object? input) => schema.tryParse(input);
  @override
  Future<O> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;
  @override
  Future<AcanthisOutcome<O>> parseOutcomeAsync(Object? input) async =>
      schema is AsyncSchema<I, O>
      ? (schema as AsyncSchema<I, O>).parseOutcomeAsync(input)
      : schema.parseOutcome(input);
  @override
  Future<AcanthisOutcome<O>> tryParseAsync(Object? input) async =>
      schema is AsyncSchema<I, O>
      ? (schema as AsyncSchema<I, O>).tryParseAsync(input)
      : schema.tryParse(input);
  @override
  bool get isAsync =>
      schema is AsyncSchema<I, O> && (schema as AsyncSchema<I, O>).isAsync;
  @override
  bool get hasDefault =>
      schema is DefaultSchema<I, O> &&
      (schema as DefaultSchema<I, O>).hasDefault;
  @override
  O? get defaultValue => schema is DefaultSchema<I, O>
      ? (schema as DefaultSchema<I, O>).defaultValue
      : null;
  @override
  bool get hasLocalAsync => false;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [schema];
  @override
  Schema<Object?, Object?> get resolvedSchema => schema;
  @override
  bool get hasWrapperOperations => false;
  @override
  bool get hasOwnDefault => false;
}

/// Exposes a null-substituting default to composition schemas.
/// A missing object field is still required unless it has an explicit default.
mixin DefaultSchema<Input, Output> on Schema<Input, Output> {
  Output? get defaultValue;

  bool get hasDefault => defaultValue != null;
}

mixin AsyncSchema<Input, Output> on Schema<Input, Output> {
  bool get isAsync => true;

  Future<Output> parseAsync(Object? input);

  Future<AcanthisOutcome<Output>> tryParseAsync(Object? input);

  @internal
  Future<AcanthisOutcome<Output>> parseOutcomeAsync(Object? input) async {
    try {
      return AcanthisValid(await parseAsync(input));
    } on ValidationError catch (error) {
      final failure = error.failure;
      return failure is AcanthisOutcome<Output>
          ? failure as AcanthisOutcome<Output>
          : AcanthisInvalid<Output>.withoutValue(error.issues);
    }
  }
}

mixin CheckableSchema<Input, Output> on Schema<Input, Output> {
  List<Check<Output>> get checks;

  /// Add a typed predicate, optionally defining its default catalog message.
  Schema<Input, Output> refine({
    required bool Function(Output) onCheck,
    String? error,
    String name = 'custom',
  });

  Schema<Input, Output> withCheck(Check<Output> check);
}

mixin TransformableSchema<Input, Output> on Schema<Input, Output> {
  List<Transform<Output, Output>> get transformations;

  /// Transform the current value while preserving the schema's output type.
  Schema<Input, Output> transform(Output Function(Output) onTransform);

  Schema<Input, Output> withTransform(Transform<Output, Output> transform);
}

mixin ValidationSchema<Input, Output> on Schema<Input, Output> {
  bool validate(Object? input);

  bool tryValidate(Object? input);
}
