import '../common/operations.dart';

sealed class BooleanCheck implements Check<bool> {
  const BooleanCheck(this.code);
  final String code;
  bool test(bool value);
  @override
  void evaluate(bool value, CheckContext context) {
    if (!test(value)) context.addIssue(code);
  }
}

final class IsTrueCheck extends BooleanCheck {
  const IsTrueCheck() : super('isTrue');
  @override
  bool test(bool value) => value;
}

final class IsFalseCheck extends BooleanCheck {
  const IsFalseCheck() : super('isFalse');
  @override
  bool test(bool value) => !value;
}
