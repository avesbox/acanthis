import '../common/issue.dart' show freezeIssueParameters;
import '../common/operations.dart';

sealed class ListCheck<T> implements Check<List<T>> {
  ListCheck(this.code, {Map<String, Object?> parameters = const {}})
    : parameters = freezeIssueParameters(parameters);
  final String code;
  final Map<String, Object?> parameters;
  bool test(List<T> value);
  @override
  void evaluate(List<T> value, CheckContext context) {
    if (!test(value)) context.addIssue(code, parameters: parameters);
  }
}

final class MinItemsListCheck<T> extends ListCheck<T> {
  MinItemsListCheck(this.minItems)
    : super('minItems', parameters: {'minItems': minItems});
  final int minItems;
  @override
  bool test(List<T> value) => value.length >= minItems;
}

final class MaxItemsListCheck<T> extends ListCheck<T> {
  MaxItemsListCheck(this.maxItems)
    : super('maxItems', parameters: {'maxItems': maxItems});
  final int maxItems;
  @override
  bool test(List<T> value) => value.length <= maxItems;
}

final class LengthListCheck<T> extends ListCheck<T> {
  LengthListCheck(this.length)
    : super('length', parameters: {'length': length});
  final int length;
  @override
  bool test(List<T> value) => value.length == length;
}

final class UniqueItemsListCheck<T> extends ListCheck<T> {
  UniqueItemsListCheck() : super('uniqueItems');
  @override
  bool test(List<T> value) => value.toSet().length == value.length;
}

final class ContainsListCheck<T> extends ListCheck<T> {
  ContainsListCheck(this.item)
    : super('containsItem', parameters: {'item': item});
  final T item;
  @override
  bool test(List<T> value) => value.contains(item);
}

final class AnyOfListCheck<T> extends ListCheck<T> {
  factory AnyOfListCheck(List<T> items) =>
      AnyOfListCheck._(List<T>.unmodifiable(items));
  AnyOfListCheck._(this.items) : super('anyOf', parameters: {'items': items});
  final List<T> items;
  @override
  bool test(List<T> value) => value.any(items.contains);
}

final class EveryOfListCheck<T> extends ListCheck<T> {
  factory EveryOfListCheck(List<T> items) =>
      EveryOfListCheck._(List<T>.unmodifiable(items));
  EveryOfListCheck._(this.items)
    : super('everyOf', parameters: {'items': items});
  final List<T> items;
  // Preserve V1: every submitted element must belong to the allowed values.
  @override
  bool test(List<T> value) => value.every(items.contains);
}
