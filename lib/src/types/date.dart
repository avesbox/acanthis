import 'list.dart';
import 'types.dart';
import 'union.dart';

/// A class to validate date types
class AcanthisDate extends AcanthisType<DateTime> {
  AcanthisDate();

  /// Add a check to the date to check if it is before or equal to [value]
  AcanthisDate min(DateTime value) {
    addCheck(AcanthisCheck<DateTime>(
        onCheck: (toTest) =>
            toTest.isAfter(value) || toTest.isAtSameMomentAs(value),
        error: 'The date must be greater than or equal to $value',
        name: 'min'));
    return this;
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFromNow(Duration difference) {
    addCheck(AcanthisCheck<DateTime>(
        onCheck: (toTest) =>
            toTest.difference(DateTime.now()).abs() >= difference,
        error: 'The date must differ from now by $difference or more',
        name: 'differsFromNow'));
    return this;
  }

  /// Add a check to the date to check if it is less than or equal to [value]
  AcanthisDate max(DateTime value) {
    addCheck(AcanthisCheck<DateTime>(
        onCheck: (toTest) =>
            toTest.isBefore(value) || toTest.isAtSameMomentAs(value),
        error: 'The date must be less than or equal to $value',
        name: 'max'));
    return this;
  }

  /// Create a list of dates
  AcanthisList<DateTime> list() {
    return AcanthisList<DateTime>(this);
  }

  /// Create a union from the string
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }
}

/// Create a new date type
AcanthisDate date() => AcanthisDate();
