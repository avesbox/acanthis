import 'package:meta/meta.dart';

/// A class that represents an operation
@immutable
abstract class AcanthisOperation<O> {
  /// The constructor of the class
  const AcanthisOperation();

  /// The call method to create a Callable class
  dynamic call(O value);
}
