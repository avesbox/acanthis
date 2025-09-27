import 'package:acanthis/src/operations/checks.dart';

/// Map checks for Max Properties
class MaxPropertiesCheck<V> extends AcanthisCheck<Map<String, V>> {
  final int constraintValue;

  MaxPropertiesCheck({
    required this.constraintValue,
    String? message,
    String Function(int constraintValue)? messageBuilder,
  }) : super(
          error: messageBuilder?.call(constraintValue) ??
              message ??
              'The map has more than $constraintValue fields',
          name: 'maxProperties',
        );

  @override
  bool call(Map<String, V> value) {
    return value.length <= constraintValue;
  }
}

/// Map checks for Min Properties
class MinPropertiesCheck<V> extends AcanthisCheck<Map<String, V>> {
  final int constraintValue;

  MinPropertiesCheck({
    required this.constraintValue,
    String? message,
    String Function(int constraintValue)? messageBuilder,
  }) : super(
          error: messageBuilder?.call(constraintValue) ??
              message ??
              'The map has less than $constraintValue fields',
          name: 'minProperties',
        );

  @override
  bool call(Map<String, V> value) {
    return value.length >= constraintValue;
  }
}

/// Map checks for Length Properties
class LengthPropertiesCheck<V> extends AcanthisCheck<Map<String, V>> {
  final int constraintValue;

  LengthPropertiesCheck({
    required this.constraintValue,
    String? message,
    String Function(int constraintValue)? messageBuilder,
  }) : super(
          error: messageBuilder?.call(constraintValue) ??
              message ??
              'The map has not $constraintValue fields',
          name: 'lengthProperties',
        );

  @override
  bool call(Map<String, V> value) {
    return value.length == constraintValue;
  }
}
