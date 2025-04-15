import 'types.dart';

extension AcanthisBooleanExt on AcanthisType<bool> {
  /// Add a check to the boolean to check if it is true
  AcanthisType<bool> isTrue() {
    return withCheck(BooleanChecks.isTrue);
  }

  /// Add a check to the boolean to check if it is false
  AcanthisType<bool> isFalse() {
    return withCheck(BooleanChecks.isFalse);
  }
}

/// Create a boolean validator
AcanthisType<bool> boolean() => AcanthisType<bool>();

abstract class BooleanChecks extends BaseAcanthisCheck<bool> {
  const BooleanChecks();
  static bool _isTrueCheck(bool value) => value;
  static const isTrue = AcanthisCheck<bool>(
      name: 'isTrue', error: 'Value must be true', onCheck: _isTrueCheck);
  static bool _isFalseCheck(bool value) => !value;
  static const isFalse = AcanthisCheck<bool>(
      name: 'isFalse', error: 'Value must be false', onCheck: _isFalseCheck);
}
