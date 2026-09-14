import 'package:acanthis/src/operations/operation.dart';
import 'package:meta/meta.dart';

/// A class that represents a check operation
@immutable
abstract class AcanthisCheck<O> extends AcanthisOperation<O> {
  /// The error message of the check
  final String error;

  /// The name of the check
  final String name;

  /// Stable diagnostic code; custom checks can override independently of name.
  String get code => name.isEmpty ? 'custom' : name;

  /// Schema constraints only. Never include the value being validated.
  final Map<String, Object?> parameters;

  /// The constructor of the class
  const AcanthisCheck({
    this.error = '',
    this.name = '',
    this.parameters = const {},
  });

  @override
  bool call(O value);
}

/// A class that represents an async check operation
@immutable
abstract class AcanthisAsyncCheck<O> extends AcanthisOperation<O> {
  /// The error message of the check
  final String error;

  /// The name of the check
  final String name;

  /// Stable diagnostic code; custom checks can override independently of name.
  String get code => name.isEmpty ? 'custom' : name;

  /// Schema constraints only. Never include the value being validated.
  final Map<String, Object?> parameters;

  /// The constructor of the class
  const AcanthisAsyncCheck({
    this.error = '',
    this.name = '',
    this.parameters = const {},
  });

  @override
  Future<bool> call(O value);
}

/// A class that represents a custom check operation
final class CustomCheck<T> extends AcanthisCheck<T> {
  /// The function that will be used to check the value
  final bool Function(T) check;

  /// The constructor of the class
  const CustomCheck(
    this.check, {
    super.error = '',
    super.name = '',
    super.parameters,
  });

  @override
  bool call(T value) {
    try {
      return check(value);
    } catch (e) {
      return false;
    }
  }
}

/// A class that represents a custom check operation that returns a cause message on failure
final class CustomCauseCheck<T> extends AcanthisCheck<T> {
  /// The function that will be used to check the value
  final String? Function(T) check;

  /// The constructor of the class
  const CustomCauseCheck(this.check, {super.name = '', super.parameters});

  @override
  bool call(T value) {
    try {
      return check(value) == null;
    } catch (e) {
      return false;
    }
  }

  /// Calls the check function and returns the error message if the check fails
  String? cause(T value) {
    try {
      return check(value);
    } catch (e) {
      return error.isNotEmpty ? error : 'Check failed';
    }
  }
}

/// A class that represents a custom async check operation
final class CustomAsyncCheck<T> extends AcanthisAsyncCheck<T> {
  /// The function that will be used to check the value
  final Future<bool> Function(T) check;

  /// The constructor of the class
  const CustomAsyncCheck(
    this.check, {
    super.error = '',
    super.name = '',
    super.parameters,
  });

  @override
  Future<bool> call(T value) async {
    try {
      return await check(value);
    } catch (e) {
      return false;
    }
  }
}
