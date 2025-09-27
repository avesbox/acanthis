import 'package:acanthis/src/operations/checks.dart';

/// Nullable check for Enumerated values.
class EnumeratedNullableCheck<T> extends AcanthisCheck<T> {
  final List<T> values;

  EnumeratedNullableCheck(
    this.values, {
    String? message,
    String Function(List<T> values)? messageBuilder,
  }) : super(
          error: messageBuilder?.call(values) ??
              message ??
              'Value must be one of the enumerated values',
          name: 'enumerated',
        );

  @override
  bool call(T? value) {
    if (value == null) return true;
    return values.contains(value);
  }
}
