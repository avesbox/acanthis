import 'types.dart';

/// A class to validate date types
extension AcanthisDateExt on AcanthisType<DateTime> {
  /// Add a check to the date to check if it is before or equal to [value]
  AcanthisType<DateTime> min(DateTime value) {
    return withCheck(DateChecks.min(value));
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisType<DateTime> differsFromNow(Duration difference) {
    return withCheck(DateChecks.differsFromNow(difference));
  }

  /// Add a check to the date to check if it is less than or equal to [value]
  AcanthisType<DateTime> max(DateTime value) {
    return withCheck(DateChecks.max(value));
  }
}

/// Create a new date type
AcanthisType<DateTime> date() => AcanthisType<DateTime>();

abstract class DateChecks extends BaseAcanthisCheck<DateTime> {
  const DateChecks();
  const factory DateChecks.min(DateTime value) = _MinCheck;
  const factory DateChecks.max(DateTime value) = _MaxCheck;
  const factory DateChecks.differsFromNow(Duration difference) =
      _DifferenceCheck;
}

class _MinCheck extends DateChecks {
  final DateTime value;

  const _MinCheck(this.value);
  @override
  bool onCheck(DateTime toTest) =>
      toTest.isAfter(value) || toTest.isAtSameMomentAs(value);

  @override
  String get error => 'The date must be greater than or equal to $value';

  @override
  String get name => 'min';
}

class _MaxCheck extends DateChecks {
  final DateTime value;

  const _MaxCheck(this.value);

  @override
  bool onCheck(DateTime toTest) =>
      toTest.isBefore(value) || toTest.isAtSameMomentAs(value);

  @override
  String get error => 'The date must be less than or equal to $value';

  @override
  String get name => 'max';
}

class _DifferenceCheck extends DateChecks {
  final Duration difference;

  const _DifferenceCheck(this.difference);

  @override
  bool onCheck(DateTime toTest) {
    return toTest.difference(DateTime.now()).abs() >= difference;
  }

  @override
  String get error => 'The date must differ from now by $difference or more';

  @override
  String get name => 'differsFromNow';
}
