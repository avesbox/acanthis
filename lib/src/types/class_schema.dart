import '../common/operations.dart';
import '../common/schema.dart';
import 'instance.dart';
import 'pipeline.dart';

/// Configure a typed input-to-instance pipeline, snapshotted by [build].
final class ClassSchemaBuilder<I, T> {
  Schema<Object?, I>? _input;
  T Function(I)? _mapper;
  Schema<Object?, T>? _output;
  T? _defaultOutput;
  bool _hasDefaultOutput = false;

  ClassSchemaBuilder<I, T> input(Schema<Object?, I> schema) {
    _input = schema;
    return this;
  }

  ClassSchemaBuilder<I, T> map(T Function(I) mapper) {
    _mapper = mapper;
    return this;
  }

  ClassSchemaBuilder<I, T> validateWith(Schema<Object?, T> schema) {
    _output = schema;
    return this;
  }

  ClassSchemaBuilder<I, T> defaultOutput(T value) {
    _defaultOutput = value;
    _hasDefaultOutput = true;
    return this;
  }

  ClassSchemaBuilder<I, T> refine({
    required bool Function(T) onCheck,
    String name = 'custom',
    String? error,
  }) {
    final output = _output ?? InstanceType<T>();
    final check = PredicateCheck<T>.refinement(
      onCheck: onCheck,
      name: name,
      error: error,
    );
    _output = output is CheckableSchema<Object?, T>
        ? output.withCheck(check)
        : output.pipe(
            InstanceType<T>().withCheck(check),
            transform: (value) => value,
          );
    return this;
  }

  AcanthisPipeline<I, T> build() {
    final input = _input;
    final mapper = _mapper;
    if (input == null) {
      throw StateError('ClassSchemaBuilder: input() not provided');
    }
    if (mapper == null) {
      throw StateError('ClassSchemaBuilder: map() not provided');
    }
    final pipeline = input.pipe(
      _output ?? InstanceType<T>(),
      transform: mapper,
    );
    return _hasDefaultOutput
        ? pipeline.withDefault(_defaultOutput as T)
        : pipeline;
  }
}

ClassSchemaBuilder<I, T> classSchema<I, T>() => ClassSchemaBuilder<I, T>();
