import 'package:acanthis/src/operations/checks.dart';

/// Nullable check for Enumerated values.
class EnumeratedNullableCheck<T> extends AcanthisCheck<T> {
  final List<T> values;

  EnumeratedNullableCheck(this.values);

  @override
  bool call(T? value) {
    if (value == null) return true;
    return values.contains(value);
  }
}
