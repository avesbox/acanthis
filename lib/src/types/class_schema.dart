import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';

/// Builder for class schemas (I -> T)
class ClassSchemaBuilder<I, T> {
  AcanthisType<I>? _input;
  T Function(I)? _mapper;
  AcanthisType<T>? _output;

  /// Provide the input schema (can be object(...), list(...), etc.)
  ClassSchemaBuilder<I, T> input(AcanthisType<I> schema) {
    _input = schema;
    return this;
  }

  /// Provide the mapping function from validated input (I) to T.
  ClassSchemaBuilder<I, T> map(T Function(I value) mapper) {
    _mapper = mapper;
    return this;
  }

  /// Provide an output validator.
  ClassSchemaBuilder<I, T> validateWith(AcanthisType<T> type) {
    _output = type;
    return this;
  }

  /// Add an output-level refinement (check) on T.
  ClassSchemaBuilder<I, T> refine({
    required bool Function(T value) onCheck,
    required String name,
    required String error,
  }) {
    final base = _output ?? instance<T>();
    _output = base.withCheck(CustomCheck<T>(onCheck, name: name, error: error));
    return this;
  }

  /// Build the final pipeline I -> T
  AcanthisPipeline<I, T> build() {
    if (_input == null) {
      throw StateError('ClassSchemaBuilder: input() not provided');
    }
    if (_mapper == null) {
      throw StateError('ClassSchemaBuilder: map() not provided');
    }
    final out = _output ?? instance<T>();
    return _input!.pipe<T>(out, transform: (v) => _mapper!(v));
  }
}

/// Generic factory for arbitrary input type I -> T
ClassSchemaBuilder<I, T> classSchema<I, T>() => ClassSchemaBuilder<I, T>();
