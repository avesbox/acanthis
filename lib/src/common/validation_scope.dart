import 'dart:async';

import 'package:meta/meta.dart';

enum AcanthisCollectionPolicy { all, first }

/// Cooperative cancellation; an already running callback can finish its work.
final class AcanthisCancellationSignal {
  final _done = Completer<void>();
  final _listeners = <void Function()>{};
  bool get isCancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;
  void cancel() {
    if (isCancelled) return;
    _done.complete();
    final listeners = _listeners.toList(growable: false);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  void throwIfCancelled() {
    if (isCancelled) throw const AcanthisValidationCancelled();
  }
}

/// Cancellation is control flow, never an invalid field or a failed union branch.
final class AcanthisValidationCancelled implements Exception {
  const AcanthisValidationCancelled();
  @override
  String toString() => 'Validation cancelled';
}

final class AcanthisValidationScope {
  const AcanthisValidationScope({
    this.context,
    this.fieldPolicy = AcanthisCollectionPolicy.all,
    this.objectPolicy = AcanthisCollectionPolicy.all,
    this.cancellation,
  });
  final Object? context;
  final AcanthisCollectionPolicy fieldPolicy;
  final AcanthisCollectionPolicy objectPolicy;
  final AcanthisCancellationSignal? cancellation;
  static final _key = Object();
  static AcanthisValidationScope get current =>
      Zone.current[_key] as AcanthisValidationScope? ??
      const AcanthisValidationScope();
  T contextAs<T>() => context as T;
  void throwIfCancelled() => cancellation?.throwIfCancelled();
  R run<R>(R Function() action) => runZoned(() {
    throwIfCancelled();
    return action();
  }, zoneValues: {_key: this});
}

/// Link a revision without retaining finished revisions on the parent signal.
@internal
void Function() linkCancellation(
  AcanthisCancellationSignal? parent,
  AcanthisCancellationSignal child,
) {
  if (parent == null) return () {};
  if (parent.isCancelled) {
    child.cancel();
    return () {};
  }
  final cancel = child.cancel;
  parent._listeners.add(cancel);
  return () {
    parent._listeners.remove(cancel);
  };
}
