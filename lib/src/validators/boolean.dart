import 'package:acanthis/src/operations/checks.dart';

/// Boolean checks for True
class IsTrueCheck extends AcanthisCheck<bool> {
  const IsTrueCheck({String? message})
      : super(
          error: message ?? 'Value must be true',
          name: 'isTrue',
        );

  @override
  bool call(bool value) {
    return value;
  }
}

/// Boolean checks for False
class IsFalseCheck extends AcanthisCheck<bool> {
  const IsFalseCheck({String? message})
      : super(
          error: message ?? 'Value must be false',
          name: 'isFalse',
        );

  @override
  bool call(bool value) {
    return !value;
  }
}
