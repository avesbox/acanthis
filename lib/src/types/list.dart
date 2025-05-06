import 'package:acanthis/src/exceptions/async_exception.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/validators/list.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// A class to validate list types
class AcanthisList<T> extends AcanthisType<List<T>> {
  /// The element of the list
  final AcanthisType<T> element;

  /// Constructor of the list type
  const AcanthisList(this.element,
      {super.operations, super.isAsync, super.key});

  @override
  Future<AcanthisParseResult<List<T>>> parseAsync(List<T> value) async {
    final parsed = <T>[];
    for (var i = 0; i < value.length; i++) {
      final parsedElement = await element.parseAsync(value[i]);
      parsed.add(parsedElement.value);
    }
    return await super.parseAsync(parsed);
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
    final result = await super.tryParseAsync(parsed);
    return AcanthisParseResult(
        value: result.value, errors: result.errors, metadata: result.metadata);
  }

  /// Override of [parse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> parse(List<T> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    return super.parse(List.generate(
      value.length,
      (index) => element.parse(value[index]).value,
      growable: false,
    ));
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> tryParse(List<T> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final parsed = <T>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      final parsedElement = element.tryParse(value[i]);
      parsed.add(parsedElement.value);
      if (parsedElement.errors.isNotEmpty) {
        errors[i.toString()] = parsedElement.errors;
      }
    }
    final result = super.tryParse(parsed);
    return AcanthisParseResult(
        value: result.value,
        errors: errors..addAll(result.errors),
        success: _recursiveSuccess(errors),
        metadata: result.metadata);
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
  AcanthisList<T> min(int length,
      {String? message, String Function(int minItems)? messageBuilder}) {
    return withCheck(MinItemsListCheck(length,
        message: message, messageBuilder: messageBuilder));
  }

  /// Add a check to the list to check if it contains at least one of the [values]
  AcanthisList<T> anyOf(List<T> values,
      {String? message, String Function(List<T> items)? messageBuilder}) {
    return withCheck(AnyOfListCheck<T>(values,
        message: message, messageBuilder: messageBuilder));
  }

  /// Add a check to the list to check if it contains all of the [values]
  AcanthisList<T> everyOf(List<T> values,
      {String? message, String Function(List<T> items)? messageBuilder}) {
    return withCheck(EveryOfListCheck<T>(values,
        message: message, messageBuilder: messageBuilder));
  }

  /// Add a check to the list to check if it is at most [length] elements long
  AcanthisList<T> max(int length,
      {String? message, String Function(int maxItems)? messageBuilder}) {
    return withCheck(MaxItemsListCheck<T>(length,
        message: message, messageBuilder: messageBuilder));
  }

  /// Add a check to the list to check if all elements are unique
  ///
  /// In Zod is the same as creating a set.
  AcanthisList<T> unique({String? message}) {
    return withCheck(UniqueItemsListCheck<T>(message: message));
  }

  /// Add a check to the list to check if it has exactly [value] elements
  AcanthisList<T> length(int value,
      {String? message, String Function(int length)? messageBuilder}) {
    return withCheck(LengthListCheck(value,
        message: message, messageBuilder: messageBuilder));
  }

  /// Returns the element type of the list
  AcanthisType<T> unwrap() {
    return element;
  }

  @override
  AcanthisList<T> withAsyncCheck(AcanthisAsyncCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: [
        ...operations,
        check,
      ],
      isAsync: true,
      key: key,
    );
  }

  @override
  AcanthisList<T> withCheck(AcanthisCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: [
        ...operations,
        check,
      ],
      isAsync: isAsync,
      key: key,
    );
  }

  @override
  AcanthisList<T> withTransformation(
      AcanthisTransformation<List<T>> transformation) {
    return AcanthisList(
      element,
      operations: [
        ...operations,
        transformation,
      ],
      isAsync: isAsync,
      key: key,
    );
  }

  @override
  AcanthisList<T> meta(MetadataEntry<List<T>> metadata) {
    String key = this.key;
    if (key.isEmpty) {
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
    final checks = operations.whereType<AcanthisCheck>().toList();
    final lengthChecksMap = {};
    for (var lengthCheck in checks) {
      if (lengthCheck is MinItemsListCheck) {
        lengthChecksMap['minItems'] = lengthCheck.minItems;
      } else if (lengthCheck is MaxItemsListCheck) {
        lengthChecksMap['maxItems'] = lengthCheck.maxItems;
      } else if (lengthCheck is LengthListCheck) {
        lengthChecksMap['minItems'] = lengthCheck.length;
        lengthChecksMap['maxItems'] = lengthCheck.length;
      }
    }
    final uniqueItems = checks.whereType<UniqueItemsListCheck>().isNotEmpty;
    return {
      'type': 'array',
      if (metadata != null) ...metadata.toJson(),
      'items': element.toJsonSchema(),
      if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
      if (uniqueItems) 'uniqueItems': true,
    };
  }
}
