import 'list.dart';
import 'types.dart';
import 'union.dart';

class AcanthisBoolean extends AcanthisType<bool> {
  const AcanthisBoolean({
    super.operations,
    super.isAsync,
  });

  /// Add a check to the boolean to check if it is true
  AcanthisBoolean isTrue() {
    return withCheck(BooleanChecks.isTrue);
  }

  /// Add a check to the boolean to check if it is false
  AcanthisBoolean isFalse() {
    return withCheck(BooleanChecks.isFalse);
  }

  /// Create a list of booleans
  AcanthisList<bool> list() {
    return AcanthisList(this);
  }

  /// Create a union from the nullable
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  @override
  AcanthisBoolean withAsyncCheck(BaseAcanthisAsyncCheck<bool> check) {
    return AcanthisBoolean(
      operations: operations.add(check),
      isAsync: true,
    );
  }

  @override
  AcanthisBoolean withCheck(BaseAcanthisCheck<bool> check) {
    return AcanthisBoolean(
      operations: operations.add(check),
    );
  }

  @override
  AcanthisBoolean withTransformation(
      BaseAcanthisTransformation<bool> transformation) {
    return AcanthisBoolean(
      operations: operations.add(transformation),
    );
  }
}

/// Create a boolean validator
AcanthisBoolean boolean() => AcanthisBoolean();

abstract class BooleanChecks extends BaseAcanthisCheck<bool> {
  const BooleanChecks();
  static bool _isTrueCheck(bool value) => value;
  static const isTrue = AcanthisCheck<bool>(
      name: 'isTrue', error: 'Value must be true', onCheck: _isTrueCheck);
  static bool _isFalseCheck(bool value) => !value;
  static const isFalse = AcanthisCheck<bool>(
      name: 'isFalse', error: 'Value must be false', onCheck: _isFalseCheck);
}
