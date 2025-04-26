import 'package:acanthis/src/operations/checks.dart';

/// Common checks for Exact values.
class ExactCheck<T> extends AcanthisCheck<T> {
  final T value;

  const ExactCheck({required this.value})
      : super(error: 'Value must be exactly $value', name: 'exact');

  @override
  bool call(T value) {
    return value == this.value;
  }
}
