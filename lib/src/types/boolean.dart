import '../registries/metadata_registry.dart';
import '../common/fast_schema.dart';
import '../common/issue_sink.dart';
import '../common/results.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';
import '../validators/boolean.dart';

final class AcanthisBoolean extends ValueSchemaBase<bool, AcanthisBoolean>
    implements FastSchema<bool> {
  AcanthisBoolean({this.coercionEnabled = false, bool? defaultValue})
    : super(configuredDefault: defaultValue, ownDefault: defaultValue != null);
  AcanthisBoolean._(
    this.coercionEnabled,
    SchemaOperations<bool> operations,
    bool? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );
  final bool coercionEnabled;
  bool get isIdentity => !hasOperations && !coercionEnabled && !hasDefault;
  AcanthisBoolean coerce() => copySchemaMetadata(
    this,
    AcanthisBoolean._(true, operations, configuredDefault, ownDefault),
  );
  AcanthisBoolean isTrue() => withCheck(const IsTrueCheck());
  AcanthisBoolean isFalse() => withCheck(const IsFalseCheck());
  @override
  AcanthisBoolean rebuild(
    SchemaOperations<bool> operations,
    bool? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisBoolean._(coercionEnabled, operations, defaultValue, hasDefault),
  );

  bool? _decode(Object? input) {
    if (input is bool) return input;
    if (coercionEnabled) {
      if (input is num) {
        if (input == 1) return true;
        if (input == 0) return false;
      } else if (input is String) {
        return switch (input.trim().toLowerCase()) {
          'true' || '1' => true,
          'false' || '0' => false,
          _ => null,
        };
      }
    }
    return null;
  }

  @override
  AcanthisOutcome<bool> parseValue(Object? input, bool collect) {
    final value = _decode(input);
    return value == null
        ? AcanthisInvalid<bool>.withoutValue(
            IssueSink.single(
              'type',
              parameters: const {'expected': 'bool'},
            ).takeIssues(),
          )
        : AcanthisValid(value);
  }

  late final bool _fastChecks =
      !coercionEnabled &&
      !isAsync &&
      transformations.isEmpty &&
      checks.every((check) => check is BooleanCheck);
  @override
  bool get canFast => isIdentity || _fastChecks;
  @override
  bool? tryFast(Object? input) {
    if (!canFast) return null;
    input ??= defaultValue;
    if (input is! bool) return null;
    for (final check in checks) {
      if (!(check as BooleanCheck).test(input)) return null;
    }
    return input;
  }
}

AcanthisBoolean boolean() => AcanthisBoolean();
