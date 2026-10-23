import '../common/issue.dart' show freezeIssueParameters;
import '../common/operations.dart';

/// Built-in predicates have a direct execution path without a context on success.
/// Custom checks implement [Check] and receive the normal diagnostic context.
sealed class DateCheck implements Check<DateTime> {
  DateCheck(this.code, {Map<String, Object?> parameters = const {}})
    : parameters = freezeIssueParameters(parameters);

  final String code;
  final Map<String, Object?> parameters;

  bool test(DateTime value);

  @override
  void evaluate(DateTime value, CheckContext context) {
    if (!test(value)) context.addIssue(code, parameters: parameters);
  }
}

/// Date checks for Min Date
class MinDateCheck extends DateCheck {
  final DateTime value;

  MinDateCheck(this.value) : super('min', parameters: {'value': value});

  @override
  bool test(DateTime value) {
    return value.isAfter(this.value) || value.isAtSameMomentAs(this.value);
  }
}

/// Date checks for Max Date
class MaxDateCheck extends DateCheck {
  final DateTime value;

  MaxDateCheck(this.value) : super('max', parameters: {'value': value});

  @override
  bool test(DateTime value) {
    return value.isBefore(this.value) || value.isAtSameMomentAs(this.value);
  }
}

/// Date checks for difference from now
class DiffersFromNowCheck extends DateCheck {
  @override
  Map<String, Object?> get parameters => {'difference': difference};

  final Duration difference;

  DiffersFromNowCheck(this.difference)
    : super('differsFromNow', parameters: {'difference': difference});

  @override
  bool test(DateTime value) {
    return value.difference(DateTime.now()).abs() >= difference;
  }
}

/// Date checks for difference from a specific date
class DiffersFromCheck extends DateCheck {
  @override
  Map<String, Object?> get parameters => {
    'fromDate': fromDate,
    'difference': difference,
  };

  final DateTime fromDate;
  final Duration difference;

  DiffersFromCheck(this.fromDate, this.difference)
    : super(
        'differsFrom',
        parameters: {'fromDate': fromDate, 'difference': difference},
      );

  @override
  bool test(DateTime value) {
    return value.difference(fromDate).abs() >= difference;
  }
}
