import '../common/operations.dart';

sealed class ObjectCheck implements Check<Map<String, Object?>> {
  const ObjectCheck(this.code, this.constraintValue);
  final String code;
  final int constraintValue;
  bool test(Map<String, Object?> value);
  @override
  void evaluate(Map<String, Object?> value, CheckContext context) {
    if (!test(value)) {
      context.addIssue(code, parameters: {'constraintValue': constraintValue});
    }
  }
}

final class MinPropertiesCheck extends ObjectCheck {
  const MinPropertiesCheck(int count) : super('minProperties', count);
  @override
  bool test(Map<String, Object?> value) => value.length >= constraintValue;
}

final class MaxPropertiesCheck extends ObjectCheck {
  const MaxPropertiesCheck(int count) : super('maxProperties', count);
  @override
  bool test(Map<String, Object?> value) => value.length <= constraintValue;
}

final class LengthPropertiesCheck extends ObjectCheck {
  const LengthPropertiesCheck(int count) : super('lengthProperties', count);
  @override
  bool test(Map<String, Object?> value) => value.length == constraintValue;
}
