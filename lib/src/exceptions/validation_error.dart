import '../results.dart';

/// Error thrown when a validation fails.
class ValidationError extends Error {
  final String message;

  final String key;

  /// Structured metadata when the error originates from a native validator.
  /// Legacy custom errors may omit it and retain their original message.
  final AcanthisIssue? issue;

  ValidationError(this.message, {this.key = '', this.issue});

  ValidationError.diagnostic(
    this.message, {
    required String code,
    this.key = '',
    List<Object> path = const [],
    Map<String, Object?> parameters = const {},
    List<List<AcanthisIssue>> branches = const [],
  }) : issue = AcanthisIssue(
         path: path,
         code: code,
         message: message,
         parameters: parameters,
         branches: branches,
       );

  ValidationError prefixed(Object segment) => issue == null
      ? this
      : ValidationError(message, key: key, issue: issue!.prefixed(segment));

  String formatMessage({AcanthisMessageResolver? resolver}) =>
      issue?.formatMessage(resolver: resolver) ?? message;

  @override
  String toString() {
    return "ValidationError: $message${key.isNotEmpty ? ' ($key)' : ''}";
  }
}
