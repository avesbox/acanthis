import 'package:acanthis/src/operations/operation.dart';
import 'package:meta/meta.dart';

/// A class that represents a check operation
@immutable
abstract class AcanthisCheck<O> extends AcanthisOperation<O> {
  /// The error message of the check
  final String error;

  /// The name of the check
  final String name;

  /// The constructor of the class
  const AcanthisCheck({this.error = '', this.name = ''});

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

  /// The constructor of the class
  const AcanthisAsyncCheck(
      {this.error = '', this.name = ''});

  @override
  Future<bool> call(O value);
}

/// A class that represents a custom check operation
final class CustomCheck<T> extends AcanthisCheck<T> {
  
  /// The function that will be used to check the value
  final bool Function(T) check;

  /// The constructor of the class
  const CustomCheck(this.check, {super.error = '', super.name = ''});

  @override
  bool call(T value) {
    try {
      return check(value);
    } catch (e) {
      return false;
    }
  }
}

/// A class that represents a custom async check operation
final class CustomAsyncCheck<T> extends AcanthisAsyncCheck<T> {

  /// The function that will be used to check the value
  final Future<bool> Function(T) check;

  /// The constructor of the class
  const CustomAsyncCheck(this.check, {super.error = '', super.name = ''});

  @override
  Future<bool> call(T value) async {
    try {
      return await check(value);
    } catch (e) {
      return false;
    }
  }
}