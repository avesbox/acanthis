/// Error thrown when a validation fails.
class ValidationError extends Error {
  final String message;

  final String key;

  ValidationError(this.message, {this.key = ''});

  @override
  String toString() {
    return "ValidationError: $message${key.isNotEmpty ? ' ($key)' : ''}";
  }
}
