import '../registries/metadata_registry.dart';
import '../common/fast_schema.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';
import '../validators/nullable.dart';

final class AcanthisNullable<T> extends ValueSchemaBase<T?, AcanthisNullable<T>>
    implements FastSchema<T?> {
  AcanthisNullable(this.element, {T? defaultValue, bool hasDefault = false})
    : super(
        configuredDefault: defaultValue,
        ownDefault: hasDefault || defaultValue != null,
      );
  AcanthisNullable._(
    this.element,
    SchemaOperations<T?> operations,
    T? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );
  final Schema<Object?, T> element;
  Schema<Object?, T> unwrap() => element;
  @override
  bool get hasDefault =>
      ownDefault ||
      (element is DefaultSchema<Object?, T> &&
          (element as DefaultSchema<Object?, T>).hasDefault);
  @override
  T? get defaultValue => ownDefault
      ? configuredDefault
      : element is DefaultSchema<Object?, T>
      ? (element as DefaultSchema<Object?, T>).defaultValue
      : null;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [element];
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  AcanthisNullable<T> rebuild(
    SchemaOperations<T?> operations,
    T? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisNullable._(element, operations, defaultValue, hasDefault),
  );
  AcanthisNullable<T> enumerated(List<T?> values) =>
      withCheck(EnumeratedNullableCheck<T>(values));
  @override
  AcanthisOutcome<T?> parseValue(Object? input, bool collect) => input == null
      ? AcanthisValid<T?>(null)
      : collect
      ? element.tryParse(input)
      : element.parseOutcome(input);
  @override
  Future<AcanthisOutcome<T?>> parseValueAsync(
    Object? input,
    bool collect,
  ) async {
    if (input == null) return AcanthisValid<T?>(null);
    final child = element;
    if (child is AsyncSchema<Object?, T>) {
      return collect
          ? child.tryParseAsync(input)
          : child.parseOutcomeAsync(input);
    }
    return collect ? child.tryParse(input) : child.parseOutcome(input);
  }

  @override
  bool get canFast =>
      !hasOperations &&
      element is FastSchema<T> &&
      (element as FastSchema<T>).canFast;
  @override
  T? tryFast(Object? input) {
    if (!canFast || isAsync) return null;
    if (input == null && hasDefault) input = defaultValue;
    if (input == null) return null; // The fast protocol falls back on null.
    return (element as FastSchema<T>).tryFast(input);
  }
}

/// Compose nullable construction with any other Schema mixins.
mixin NullableSchema<I, O> on Schema<I, O> {
  AcanthisNullable<O> nullable({O? defaultValue}) =>
      AcanthisNullable<O>(this, defaultValue: defaultValue);
}

extension NullableSchemaComposition<I, O> on Schema<I, O> {
  AcanthisNullable<O> nullable({O? defaultValue}) =>
      AcanthisNullable<O>(this, defaultValue: defaultValue);
}

AcanthisNullable<T> nullable<T>(
  Schema<Object?, T> element, {
  T? defaultValue,
}) => AcanthisNullable<T>(element, defaultValue: defaultValue);
