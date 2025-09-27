import 'package:acanthis/src/operations/checks.dart';

/// Common checks for Exact values.
class ExactCheck<T> extends AcanthisCheck<T> {
  final T value;

  ExactCheck({
    required this.value,
    String? message,
    String Function(T value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be exactly $value',
         name: 'exact',
       );

  @override
  bool call(T value) {
    return value == this.value;
  }
}
