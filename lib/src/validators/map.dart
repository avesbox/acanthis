import 'package:acanthis/src/operations/checks.dart';

/// Map checks for Max Properties
class MaxPropertiesCheck<V> extends AcanthisCheck<Map<String, V>> {
  final int constraintValue;

  const MaxPropertiesCheck({
    required this.constraintValue,
  }): super(
          error: 'The map has more than $constraintValue fields',
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

  const MinPropertiesCheck({
    required this.constraintValue,
  }): super(
          error: 'The map has less than $constraintValue fields',
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

  const LengthPropertiesCheck({
    required this.constraintValue,
  }): super(
          error: 'The map has not $constraintValue fields',
          name: 'lengthProperties',
        );

  @override
  bool call(Map<String, V> value) {
    return value.length == constraintValue;
  }
}