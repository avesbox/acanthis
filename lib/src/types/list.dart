import 'package:acanthis/src/exceptions/async_exception.dart';

import 'types.dart';

/// A class to validate list types
class AcanthisList<T> extends AcanthisType<List<T>> {
  final AcanthisType<T> element;

  const AcanthisList(this.element, {super.operations, super.isAsync});

  List<T> _parse(List<T> value) {
    final parsed = <T>[];
    for (var i = 0; i < value.length; i++) {
      final parsedElement = element.parse(value[i]);
      parsed.add(parsedElement.value);
    }
    final result = super.parse(value);
    return result.value;
  }

  (List<T> parsed, Map<String, dynamic> errors) _tryParse(List<T> value) {
    final parsed = <T>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      final parsedElement = element.tryParse(value[i]);
      parsed.add(parsedElement.value);
      if (parsedElement.errors.isNotEmpty) {
        errors[i.toString()] = parsedElement.errors;
      }
    }
    final result = super.tryParse(value);
    return (result.value, errors..addAll(result.errors));
  }

  @override
  Future<AcanthisParseResult<List<T>>> parseAsync(List<T> value) async {
    final parsed = <T>[];
    for (var i = 0; i < value.length; i++) {
      final parsedElement = await element.parseAsync(value[i]);
      parsed.add(parsedElement.value);
    }
    final result = await super.parseAsync(value);
    return AcanthisParseResult(value: result.value);
  }

  @override
  Future<AcanthisParseResult<List<T>>> tryParseAsync(List<T> value) async {
    final parsed = <T>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      final parsedElement = await element.tryParseAsync(value[i]);
      parsed.add(parsedElement.value);
      if (parsedElement.errors.isNotEmpty) {
        errors[i.toString()] = parsedElement.errors;
      }
    }
    final result = await super.tryParseAsync(value);
    return AcanthisParseResult(value: result.value, errors: result.errors);
  }

  /// Override of [parse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> parse(List<T> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final parsed = _parse(value);
    return AcanthisParseResult(value: parsed);
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> tryParse(List<T> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final (parsed, errors) = _tryParse(value);
    return AcanthisParseResult(
        value: parsed, errors: errors, success: _recursiveSuccess(errors));
  }

  bool _recursiveSuccess(Map<String, dynamic> errors) {
    List<bool> results = [];
    for (var error in errors.values) {
      results.add(error is Map<String, dynamic>
          ? _recursiveSuccess(error)
          : error.isEmpty);
    }
    return results.every((element) => element);
  }

  /// Add a check to the list to check if it is at least [length] elements long
  AcanthisList<T> min(int length) {
    return withCheck(ListChecks.min(length));
  }

  /// Add a check to the list to check if it contains at least one of the [values]
  AcanthisList<T> anyOf(List<T> values) {
    return withCheck(ListChecks.anyOf(values));
  }

  /// Add a check to the list to check if it contains all of the [values]
  AcanthisList<T> everyOf(List<T> values) {
    return withCheck(ListChecks.everyOf(values));
  }

  /// Add a check to the list to check if it is at most [length] elements long
  AcanthisList<T> max(int length) {
    return withCheck(ListChecks.max(length));
  }

  /// Add a check to the list to check if all elements are unique
  ///
  /// In Zod is the same as creating a set.
  AcanthisList<T> unique() {
    return withCheck(ListChecks.unique());
  }

  /// Add a check to the list to check if it has exactly [value] elements
  AcanthisList<T> length(int value) {
    return withCheck(ListChecks.length(value));
  }

  @override
  AcanthisList<T> withAsyncCheck(BaseAcanthisAsyncCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: operations.add(check),
      isAsync: true,
    );
  }

  @override
  AcanthisList<T> withCheck(BaseAcanthisCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: operations.add(check),
    );
  }

  @override
  AcanthisList<T> withTransformation(
      BaseAcanthisTransformation<List<T>> transformation) {
    return AcanthisList(
      element,
      operations: operations.add(transformation),
    );
  }
}

// Checks for lists

abstract class ListChecks<T> extends BaseAcanthisCheck<List<T>> {
  const ListChecks();
  const factory ListChecks.min(int length) = _MinCheck<T>;
  const factory ListChecks.max(int length) = _MaxCheck<T>;
  const factory ListChecks.unique() = _UniqueCheck<T>;
  const factory ListChecks.length(int length) = _LengthCheck<T>;
  const factory ListChecks.everyOf(
    List<T> values,
  ) = _EveryOfCheck<T>;
  const factory ListChecks.anyOf(
    List<T> values,
  ) = _AnyOfCheck<T>;
}

class _MinCheck<T> extends ListChecks<T> {
  final int length;

  const _MinCheck(this.length);

  @override
  bool onCheck(List<T> toTest) => toTest.length >= length;

  @override
  String get error => 'The list must have at least $length elements';
  @override
  String get name => 'min';
}

class _MaxCheck<T> extends ListChecks<T> {
  final int length;

  const _MaxCheck(this.length);

  @override
  bool onCheck(List<T> toTest) => toTest.length <= length;
  @override
  String get error => 'The list must have at most $length elements';
  @override
  String get name => 'max';
}

class _UniqueCheck<T> extends ListChecks<T> {
  const _UniqueCheck();

  @override
  bool onCheck(List<T> toTest) => toTest.toSet().length == toTest.length;
  @override
  String get error => 'The list must have unique elements';
  @override
  String get name => 'unique';
}

class _LengthCheck<T> extends ListChecks<T> {
  final int length;

  const _LengthCheck(this.length);

  @override
  bool onCheck(List<T> toTest) => toTest.length == length;
  @override
  String get error => 'The list must have exactly $length elements';
  @override
  String get name => 'length';
}

class _EveryOfCheck<T> extends ListChecks<T> {
  final List<T> values;

  const _EveryOfCheck(this.values);

  @override
  bool onCheck(List<T> toTest) =>
      toTest.every((element) => values.contains(element));
  @override
  String get error => 'The list must have all of the values in $values';
  @override
  String get name => 'allOf';
}

class _AnyOfCheck<T> extends ListChecks<T> {
  final List<T> values;

  const _AnyOfCheck(this.values);

  @override
  bool onCheck(List<T> toTest) =>
      toTest.any((element) => values.contains(element));

  @override
  String get error =>
      'The list must have at least one of the values in $values';
  @override
  String get name => 'anyOf';
}
