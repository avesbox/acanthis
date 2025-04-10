import 'list.dart';
import 'types.dart';
import 'union.dart';

/// A class to validate date types
class AcanthisDate extends AcanthisType<DateTime> {
  const AcanthisDate({
    super.operations,
    super.isAsync,
  });

  /// Add a check to the date to check if it is before or equal to [value]
  AcanthisDate min(DateTime value) {
    return withCheck(DateChecks.min(value));
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFromNow(Duration difference) {
    return withCheck(DateChecks.differsFromNow(difference));
  }

  /// Add a check to the date to check if it is less than or equal to [value]
  AcanthisDate max(DateTime value) {
    return withCheck(DateChecks.max(value));
  }

  /// Create a list of dates
  AcanthisList<DateTime> list() {
    return AcanthisList<DateTime>(this);
  }

  /// Create a union from the string
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  @override
  AcanthisDate withAsyncCheck(BaseAcanthisAsyncCheck<DateTime> check) {
    return AcanthisDate(
      operations: operations.add(check),
      isAsync: true,
    );
  }

  @override
  AcanthisDate withCheck(BaseAcanthisCheck<DateTime> check) {
    return AcanthisDate(
      operations: operations.add(check),
    );
  }

  @override
  AcanthisDate withTransformation(
      BaseAcanthisTransformation<DateTime> transformation) {
    return AcanthisDate(
      operations: operations.add(transformation),
    );
  }
}

/// Create a new date type
AcanthisDate date() => AcanthisDate();

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
