import 'issue.dart';
import 'issue_sink.dart' show freezeIssues;

import 'package:meta/meta.dart';

sealed class AcanthisOutcome<T> {
  const AcanthisOutcome();

  bool get isValid;

  /// Parsed output. On failure this is best-effort output and may not satisfy
  /// the schema. Check [isValid] or match the outcome before trusting it.
  /// Throws [StateError] if a failed outcome has no typed recovery value.
  T get value;

  List<AcanthisIssue> get issues;

  /// Return the successfully parsed value, or throw its validation failure.
  /// A recovery value on an invalid outcome is never returned by this method.
  T get valueOrThrow {
    if (this case AcanthisValid<T>(:final value)) return value;
    throw ValidationError(this as AcanthisInvalid<T>);
  }
}

/// A failed throwing parse, retaining immutable issues and typed recovery.
/// Programming errors from callbacks propagate separately.
final class ValidationError extends Error {
  ValidationError(this.failure);

  final AcanthisInvalid<Object?> failure;
  List<AcanthisIssue> get issues => failure.issues;
  AcanthisIssue? get issue => issues.isEmpty ? null : issues.first;
  String get message => issue?.message ?? 'Validation failed';

  @override
  String toString() => 'ValidationError: $message';
}

final class AcanthisValid<T> extends AcanthisOutcome<T> {
  const AcanthisValid(this.value);

  @override
  final T value;

  @override
  bool get isValid => true;

  @override
  List<AcanthisIssue> get issues => const [];
}

final class AcanthisInvalid<T> extends AcanthisOutcome<T> {
  AcanthisInvalid(List<AcanthisIssue> issues, {required T this._value})
    : hasValue = true,
      partialValue = null,
      issues = freezeIssues(issues);

  /// A failure for which no value of type [T] can be recovered.
  AcanthisInvalid.withoutValue(List<AcanthisIssue> issues, {this.partialValue})
    : _value = null,
      hasValue = false,
      issues = freezeIssues(issues);

  final T? _value;
  final bool hasValue;

  /// Incomplete container state for rules; never a value of the promised type.
  @internal
  final Object? partialValue;

  @override
  final List<AcanthisIssue> issues;

  @override
  T get value {
    if (!hasValue) {
      throw StateError('Validation failed without a recovery value');
    }
    return _value as T;
  }

  @override
  bool get isValid => false;
}
