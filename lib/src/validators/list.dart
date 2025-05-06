import 'package:acanthis/src/operations/checks.dart';

/// List checks for Min Items
class MinItemsListCheck<T> extends AcanthisCheck<List<T>> {
  final int minItems;

  MinItemsListCheck(this.minItems,
      {String? message, String Function(int minItems)? messageBuilder})
      : super(
          error: messageBuilder?.call(minItems) ??
              message ??
              'The list must have at least $minItems elements',
          name: 'minItems',
        );

  @override
  bool call(List<T> value) {
    return value.length >= minItems;
  }
}

/// List checks for Max Items
class MaxItemsListCheck<T> extends AcanthisCheck<List<T>> {
  final int maxItems;

  MaxItemsListCheck(this.maxItems,
      {String? message, String Function(int maxItems)? messageBuilder})
      : super(
          error: messageBuilder?.call(maxItems) ??
              message ??
              'The list must have at most $maxItems elements',
          name: 'maxItems',
        );

  @override
  bool call(List<T> value) {
    return value.length <= maxItems;
  }
}

/// List checks for Length Items
class LengthListCheck<T> extends AcanthisCheck<List<T>> {
  final int length;

  LengthListCheck(this.length,
      {String? message, String Function(int length)? messageBuilder})
      : super(
          error: messageBuilder?.call(length) ??
              message ??
              'The list must have exactly $length elements',
          name: 'length',
        );

  @override
  bool call(List<T> value) {
    return value.length == length;
  }
}

class UniqueItemsListCheck<T> extends AcanthisCheck<List<T>> {
  const UniqueItemsListCheck({String? message})
      : super(
          error: message ?? 'The list must have unique items',
          name: 'uniqueItems',
        );

  @override
  bool call(List<T> value) {
    return value.toSet().length == value.length;
  }
}

class ContainsListCheck<T> extends AcanthisCheck<List<T>> {
  final T item;

  ContainsListCheck(this.item,
      {String? message, String Function(T item)? messageBuilder})
      : super(
          error: messageBuilder?.call(item) ??
              message ??
              'The list must contain $item',
          name: 'contains',
        );

  @override
  bool call(List<T> value) {
    return value.contains(item);
  }
}

class AnyOfListCheck<T> extends AcanthisCheck<List<T>> {
  final List<T> items;

  AnyOfListCheck(this.items,
      {String? message, String Function(List<T> items)? messageBuilder})
      : super(
          error: messageBuilder?.call(items) ??
              message ??
              'The list must have at least one of the values in $items',
          name: 'anyOf',
        );

  @override
  bool call(List<T> value) {
    return value.any((element) => items.contains(element));
  }
}

class EveryOfListCheck<T> extends AcanthisCheck<List<T>> {
  final List<T> items;

  EveryOfListCheck(this.items,
      {String? message, String Function(List<T> items)? messageBuilder})
      : super(
          error: messageBuilder?.call(items) ??
              message ??
              'The list must have all of the values in $items',
          name: 'everyOf',
        );

  @override
  bool call(List<T> value) {
    return value.every((element) => items.contains(element));
  }
}
