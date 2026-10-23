import '../registries/metadata_registry.dart';
import '../common/fast_schema.dart';
import '../common/issue.dart' show singleIssueParameter;
import '../common/issue_sink.dart';
import '../common/results.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';

/// Runtime type checking followed by Dart equality, without coercion.
final class AcanthisLiteral<T> extends ValueSchemaBase<T, AcanthisLiteral<T>>
    implements FastSchema<T> {
  AcanthisLiteral(this.value, {T? defaultValue})
    : super(configuredDefault: defaultValue, ownDefault: defaultValue != null);
  AcanthisLiteral._(
    this.value,
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );
  final T value;
  late final Map<String, Object?> _parameters = singleIssueParameter(
    'expected',
    value,
  );
  @override
  AcanthisLiteral<T> rebuild(
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisLiteral._(value, operations, defaultValue, hasDefault),
  );
  @override
  AcanthisOutcome<T> parseValue(Object? input, bool collect) {
    if (input is! T) {
      return AcanthisInvalid<T>.withoutValue(
        IssueSink.single('type', parameters: {'expected': '$T'}).takeIssues(),
      );
    }
    if (input != value) {
      return AcanthisInvalid<T>(
        IssueSink.single('literal', parameters: _parameters).takeIssues(),
        value: input,
      );
    }
    return AcanthisValid<T>(input);
  }

  /// JSON numeric equality cannot distinguish Dart int and double values.
  bool get hasJsonNumericEquality => 1 is T && 1.0 is T;
  @override
  bool get canFast =>
      !hasOperations &&
      value != null &&
      (value is String || value is bool || value is num);
  @override
  T? tryFast(Object? input) {
    if (!canFast) return null;
    if (input == null && hasDefault) input = defaultValue;
    return input is T && input == value ? input : null;
  }
}

AcanthisLiteral<T> literal<T>(T value) => AcanthisLiteral<T>(value);
