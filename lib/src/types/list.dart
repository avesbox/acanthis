import 'package:acanthis/src/exceptions/async_exception.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// A class to validate list types
class AcanthisList<T> extends AcanthisType<List<T>> {
  final AcanthisType<T> element;

  const AcanthisList(this.element, {super.operations, super.isAsync, super.key});

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
    return AcanthisParseResult(value: result.value, metadata: MetadataRegistry().get(key));
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
    return AcanthisParseResult(value: result.value, errors: result.errors, metadata: MetadataRegistry().get(key));
  }

  /// Override of [parse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> parse(List<T> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final parsed = _parse(value);
    return AcanthisParseResult(value: parsed, metadata: MetadataRegistry().get(key));
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
        value: parsed, errors: errors, success: _recursiveSuccess(errors), metadata: MetadataRegistry().get(key));
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
    return withCheck(AcanthisCheck<List<T>>(
        onCheck: (toTest) => toTest.length >= length,
        error: 'The list must have at least $length elements',
        name: 'min'));
  }

  /// Add a check to the list to check if it contains at least one of the [values]
  AcanthisList<T> anyOf(List<T> values) {
    return withCheck(AcanthisCheck<List<T>>(
        onCheck: (toTest) => toTest.any((element) => values.contains(element)),
        error: 'The list must have at least one of the values in $values',
        name: 'anyOf'));
  }

  /// Add a check to the list to check if it contains all of the [values]
  AcanthisList<T> everyOf(List<T> values) {
    return withCheck(AcanthisCheck<List<T>>(
        onCheck: (toTest) =>
            toTest.every((element) => values.contains(element)),
        error: 'The list must have all of the values in $values',
        name: 'allOf'));
  }

  /// Add a check to the list to check if it is at most [length] elements long
  AcanthisList<T> max(int length) {
    return withCheck(AcanthisCheck<List<T>>(
        onCheck: (toTest) => toTest.length <= length,
        error: 'The list must have at most $length elements',
        name: 'max'));
  }

  /// Add a check to the list to check if all elements are unique
  ///
  /// In Zod is the same as creating a set.
  AcanthisList<T> unique() {
    return withCheck(AcanthisCheck<List<T>>(
        onCheck: (toTest) => toTest.toSet().length == toTest.length,
        error: 'The list must have unique elements',
        name: 'unique'));
  }

  /// Add a check to the list to check if it has exactly [value] elements
  AcanthisList<T> length(int value) {
    return withCheck(AcanthisCheck<List<T>>(
        onCheck: (toTest) => toTest.length == value,
        error: 'The list must have exactly $value elements',
        name: 'length'));
  }

  @override
  AcanthisList<T> withAsyncCheck(AcanthisAsyncCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: operations.add(check),
      isAsync: true,
      key: key,
    );
  }

  @override
  AcanthisList<T> withCheck(AcanthisCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: operations.add(check),
      isAsync: isAsync,
      key: key,
    );
  }

  @override
  AcanthisList<T> withTransformation(
      AcanthisTransformation<List<T>> transformation) {
    return AcanthisList(
      element,
      operations: operations.add(transformation),
      isAsync: isAsync,
      key: key,
    );
  }

  @override
  AcanthisList<T> meta(MetadataEntry<List<T>> metadata) {
    String key = this.key;
    if(key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisList(
      element,
      operations: operations,
      isAsync: isAsync,
      key: key,
    );
  }
  
  @override
  Map<String, dynamic> toJsonSchema() {
    final metadata = MetadataRegistry().get(key);
    return {
      'type': 'array',
      if(metadata != null) ...metadata.toJson(),
      'items': element.toJsonSchema(),
    };
  }

}
