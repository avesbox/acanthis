import 'package:acanthis/acanthis.dart';

// Preserve the outcome-shaped oracle assertions while exercising the public
// raw-value/throwing parse APIs. This never calls the internal outcome methods.
AcanthisOutcome<T> _failure<T>(ValidationError error) {
  if (error.failure case AcanthisOutcome<T> failure) return failure;
  return AcanthisInvalid<T>.withoutValue(error.issues);
}

extension ParseResult<I, O> on Schema<I, O> {
  AcanthisOutcome<O> parseResult(Object? input, [ObjectSchema? parent]) {
    try {
      return AcanthisValid(
        this is LazyEntry<O>
            ? (this as LazyEntry<O>).parse(input, parent)
            : parse(input),
      );
    } on ValidationError catch (error) {
      return _failure<O>(error);
    }
  }
}

extension ParseAsyncResult<I, O> on AsyncSchema<I, O> {
  Future<AcanthisOutcome<O>> parseResultAsync(
    Object? input, [
    ObjectSchema? parent,
  ]) async {
    try {
      return AcanthisValid(
        await (this is LazyEntry<O>
            ? (this as LazyEntry<O>).parseAsync(input, parent)
            : parseAsync(input)),
      );
    } on ValidationError catch (error) {
      return _failure<O>(error);
    }
  }
}
