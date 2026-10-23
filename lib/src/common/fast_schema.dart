import 'package:meta/meta.dart';

/// Callback-free built-in evaluation. Null means use the ordinary parser;
/// implementations return the exact typed output and preserve container ownership.
@internal
abstract interface class FastSchema<T> {
  bool get canFast;
  T? tryFast(Object? input);
}
