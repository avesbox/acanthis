import 'package:acanthis/src/common/issue_sink.dart';

import 'i18n.dart';
import 'validation_scope.dart';
import 'issue.dart' show AcanthisIssue, freezeIssueParameters;

abstract interface class Check<T> {
  void evaluate(T value, CheckContext context);
}

abstract interface class Transform<I, O> {
  O apply(I value);
}

abstract interface class AsyncCheck<T> {
  Future<void> evaluate(T value, CheckContext context);
}

abstract interface class AsyncTransform<I, O> {
  Future<O> apply(I value);
}

/// A typed custom predicate. Callback exceptions are programming errors.
final class PredicateCheck<T> implements Check<T> {
  PredicateCheck(
    this.predicate, {
    this.code = 'custom',
    Map<String, Object?> parameters = const {},
    this.catalog,
  }) : parameters = freezeIssueParameters(parameters);

  /// Named fluent refinement; message lookup stays at presentation time.
  factory PredicateCheck.refinement({
    required bool Function(T) onCheck,
    String? error,
    String name = 'custom',
  }) {
    final code = name.isEmpty ? 'custom' : name;
    return PredicateCheck<T>(
      onCheck,
      code: code,
      catalog: error == null
          ? null
          : AcanthisMessageCatalog({code: (_) => error}),
    );
  }

  final bool Function(T) predicate;
  final String code;
  final Map<String, Object?> parameters;
  final AcanthisMessageCatalog? catalog;

  @override
  void evaluate(T value, CheckContext context) {
    if (!predicate(value)) {
      context.addIssue(code, parameters: parameters, catalog: catalog);
    }
  }
}

final class CallbackCheck<T> implements Check<T> {
  const CallbackCheck(this.callback);
  final void Function(T, CheckContext) callback;

  @override
  void evaluate(T value, CheckContext context) => callback(value, context);
}

final class CallbackAsyncCheck<T> implements AsyncCheck<T> {
  const CallbackAsyncCheck(this.callback);
  final Future<void> Function(T, CheckContext) callback;

  @override
  Future<void> evaluate(T value, CheckContext context) =>
      callback(value, context);
}

final class CallbackTransform<I, O> implements Transform<I, O> {
  const CallbackTransform(this.callback);
  final O Function(I) callback;

  @override
  O apply(I value) => callback(value);
}

final class CallbackAsyncTransform<I, O> implements AsyncTransform<I, O> {
  const CallbackAsyncTransform(this.callback);
  final Future<O> Function(I) callback;

  @override
  Future<O> apply(I value) => callback(value);
}

final class _CheckContext implements CheckContext {
  _CheckContext(this._sink);

  final IssueSink _sink;

  @override
  void addIssue(
    String code, {
    List<Object> path = const [],
    Map<String, Object?> parameters = const {},
    AcanthisMessageCatalog? catalog,
  }) {
    if (catalog == null) {
      _sink.addIssue(code, path: path, parameters: parameters);
    } else {
      _sink.add(
        AcanthisIssue(
          code: code.isEmpty ? 'custom' : code,
          path: path,
          parameters: parameters,
          defaultCatalog: catalog,
        ),
      );
    }
  }
}

abstract interface class CheckContext {
  void addIssue(
    String code, {
    List<Object> path = const [],
    Map<String, Object?> parameters = const {},
    AcanthisMessageCatalog? catalog,
  });

  factory CheckContext.createContext(IssueSink sink) => _CheckContext(sink);
}

extension ContextualCheckContext on CheckContext {
  Object? get context => AcanthisValidationScope.current.context;
  T contextAs<T>() => AcanthisValidationScope.current.contextAs<T>();
  AcanthisCancellationSignal? get cancellation =>
      AcanthisValidationScope.current.cancellation;
  void throwIfCancelled() => AcanthisValidationScope.current.throwIfCancelled();
}
