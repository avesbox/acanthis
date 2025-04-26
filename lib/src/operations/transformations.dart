import 'package:acanthis/src/operations/operation.dart';
import 'package:meta/meta.dart';

/// A class that represents a transformation operation
@immutable
class AcanthisTransformation<O> extends AcanthisOperation<O> {
  /// The transformation function
  final O Function(O value) transformation;

  /// The constructor of the class
  const AcanthisTransformation({required this.transformation});

  /// The call method to create a Callable class
  @override
  O call(O value) {
    return transformation(value);
  }
}
