import 'package:acanthis/src/operations/checks.dart';

/// Date checks for Min Date
class MinDateCheck extends AcanthisCheck<DateTime> {
  final DateTime value;

  const MinDateCheck(this.value)
      : super(
          error: 'The date must be greater than or equal to $value',
          name: 'min',
        );

  @override
  bool call(DateTime value) {
    return value.isAfter(this.value) || value.isAtSameMomentAs(this.value);
  }
}

/// Date checks for Max Date
class MaxDateCheck extends AcanthisCheck<DateTime> {
  final DateTime value;

  const MaxDateCheck(this.value)
      : super(
          error: 'The date must be less than or equal to $value',
          name: 'max',
        );

  @override
  bool call(DateTime value) {
    return value.isBefore(this.value) || value.isAtSameMomentAs(this.value);
  }
}

/// Date checks for difference from now
class DiffersFromNowCheck extends AcanthisCheck<DateTime> {
  final Duration difference;

  const DiffersFromNowCheck(this.difference)
      : super(
          error: 'The date must differ from now by $difference or more',
          name: 'differsFromNow',
        );

  @override
  bool call(DateTime value) {
    return value.difference(DateTime.now()).abs() >= difference;
  }
}

/// Date checks for difference from a specific date
class DiffersFromCheck extends AcanthisCheck<DateTime> {
  final DateTime fromDate;
  final Duration difference;

  const DiffersFromCheck(this.fromDate, this.difference)
      : super(
          error: 'The date must differ from $fromDate by $difference or more',
          name: 'differsFrom',
        );

  @override
  bool call(DateTime value) {
    return value.difference(fromDate).abs() >= difference;
  }
}
