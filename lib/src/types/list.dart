import 'dart:math' as math;

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

  final bool _localPure;

  @override
  bool get isPure =>
      _localPure &&
      element.isPure &&
      element.defaultValue == null &&
      defaultValue == null &&
      super.isPure;

  /// Constructor of the list type
  AcanthisList(
    this.element, {
    super.operations,
    super.isAsync,
    bool isPure = true,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  }) : _localPure = isPure;

  @override
  List<T> parseInternal(covariant dynamic value) {
    final raw = value as List<dynamic>;
    if (isPure) {
      for (var i = 0; i < raw.length; i++) {
        element.parseInternal(raw[i]);
      }
      return super.parseInternal(raw.cast<T>());
    }
    final parsed = List<T?>.filled(raw.length, null);
    for (var i = 0; i < raw.length; i++) {
      parsed[i] = element.parseInternal(raw[i]);
    }
    return super.parseInternal(parsed.cast<T>());
  }

  @override
  List<T> tryParseInternal(
    covariant dynamic value, {
    required Map<String, dynamic> errors,
  }) {
    final raw = value as List<dynamic>;
    if (isPure) {
      for (var i = 0; i < raw.length; i++) {
        final elementErrors = <String, dynamic>{};
        element.tryParseInternal(raw[i], errors: elementErrors);
        if (elementErrors.isNotEmpty) {
          errors[i.toString()] = elementErrors;
        }
      }
      return super.tryParseInternal(raw.cast<T>(), errors: errors);
    }
    final parsed = List<T?>.filled(raw.length, null);
    for (var i = 0; i < raw.length; i++) {
      final elementErrors = <String, dynamic>{};
      parsed[i] = element.tryParseInternal(raw[i], errors: elementErrors);
      if (elementErrors.isNotEmpty) {
        errors[i.toString()] = elementErrors;
      }
    }
    return super.tryParseInternal(parsed.cast<T>(), errors: errors);
  }

  @override
  Future<AcanthisParseResult<List<T>>> parseAsync(
    covariant List<dynamic> value,
  ) async {
    final parsed = <T>[];
    for (var i = 0; i < value.length; i++) {
      final parsedElement = await element.parseAsync(value[i]);
      parsed.add(parsedElement.value);
    }
    return await super.parseAsync(parsed);
  }

  @override
  Future<AcanthisParseResult<List<T>>> tryParseAsync(
    covariant List<dynamic> value,
  ) async {
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
    final mergedErrors = {...errors, ...result.errors};
    final success = mergedErrors.isEmpty;
    return AcanthisParseResult(
      value: success ? result.value : defaultValue ?? result.value,
      errors: mergedErrors,
      metadata: result.metadata,
      success: success,
    );
  }

  /// Override of [parse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> parse(covariant List<dynamic> value) {
    if (isAsync) {
      throw AsyncValidationException('Cannot use parse with async operations');
    }
    return AcanthisParseResult<List<T>>(
      value: parseInternal(value),
      metadata: metadataEntry,
    );
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> tryParse(covariant List<dynamic> value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    final errors = <String, dynamic>{};
    final parsed = tryParseInternal(value, errors: errors);
    final success = errors.isEmpty;
    return AcanthisParseResult(
      value: success ? parsed : defaultValue ?? parsed,
      errors: errors,
      success: success,
      metadata: metadataEntry,
    );
  }

  /// Add a check to the list to check if it is at least [length] elements long
  AcanthisList<T> min(
    int length, {
    String? message,
    String Function(int minItems)? messageBuilder,
  }) {
    return withCheck(
      MinItemsListCheck(
        length,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the list to check if it contains at least one of the [values]
  AcanthisList<T> anyOf(
    List<T> values, {
    String? message,
    String Function(List<T> items)? messageBuilder,
  }) {
    return withCheck(
      AnyOfListCheck<T>(
        values,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the list to check if it contains all of the [values]
  AcanthisList<T> everyOf(
    List<T> values, {
    String? message,
    String Function(List<T> items)? messageBuilder,
  }) {
    return withCheck(
      EveryOfListCheck<T>(
        values,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the list to check if it is at most [length] elements long
  AcanthisList<T> max(
    int length, {
    String? message,
    String Function(int maxItems)? messageBuilder,
  }) {
    return withCheck(
      MaxItemsListCheck<T>(
        length,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the list to check if all elements are unique
  ///
  /// In Zod is the same as creating a set.
  AcanthisList<T> unique({String? message}) {
    return withCheck(UniqueItemsListCheck<T>(message: message));
  }

  /// Add a check to the list to check if it has exactly [value] elements
  AcanthisList<T> length(
    int value, {
    String? message,
    String Function(int length)? messageBuilder,
  }) {
    return withCheck(
      LengthListCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  /// Returns the element type of the list
  AcanthisType<T> unwrap() {
    return element;
  }

  @override
  AcanthisList<T> withAsyncCheck(AcanthisAsyncCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: [...operations, check],
      isAsync: true,
      isPure: _localPure,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisList<T> withCheck(AcanthisCheck<List<T>> check) {
    return AcanthisList(
      element,
      operations: [...operations, check],
      isAsync: isAsync,
      isPure: _localPure,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisList<T> withTransformation(
    AcanthisTransformation<List<T>> transformation,
  ) {
    return AcanthisList(
      element,
      operations: [...operations, transformation],
      isAsync: isAsync,
      isPure: false,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisList<T> withDefault(List<T> value) {
    return AcanthisList(
      element,
      operations: operations,
      isAsync: isAsync,
      isPure: _localPure,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
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
      isPure: _localPure,
      key: key,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
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
      if (metadataEntry != null) ...metadataEntry!.toJson(),
      'items': element.toJsonSchema(),
      if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
      if (uniqueItems) 'uniqueItems': true,
    };
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
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
    final everyOf = operations.whereType<EveryOfListCheck<T>>().firstOrNull;
    if (everyOf != null) {
      return {
        'type': 'array',
        'items': element.toOpenApiSchema(),
        if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
        if (uniqueItems) 'uniqueItems': true,
      };
    }
    final anyOf = operations.whereType<AnyOfListCheck<T>>().firstOrNull;
    if (anyOf != null) {
      return {
        'type': 'array',
        'items': {
          'oneOf': anyOf.items.map((e) => element.toOpenApiSchema()).toList(),
        },
        if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
        if (uniqueItems) 'uniqueItems': true,
      };
    }
    return {
      'type': 'array',
      'items': element.toOpenApiSchema(),
      if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
      if (uniqueItems) 'uniqueItems': true,
    };
  }

  @override
  List<T> mock([int? seed]) {
    final random = math.Random(seed);
    final lengthChecks = operations.whereType<MinItemsListCheck>().toList();
    int minLength = 0;
    for (var check in lengthChecks) {
      if (check.minItems > minLength) {
        minLength = check.minItems;
      }
    }
    final maxLengthChecks = operations.whereType<MaxItemsListCheck>().toList();
    int maxLength = minLength + 10; // Default max length
    for (var check in maxLengthChecks) {
      if (check.maxItems < maxLength) {
        maxLength = check.maxItems;
      }
    }
    final lengthCheck = operations.whereType<LengthListCheck>().firstOrNull;
    if (lengthCheck != null) {
      minLength = lengthCheck.length;
      maxLength = lengthCheck.length;
    }
    final anyOf = operations.whereType<AnyOfListCheck<T>>().firstOrNull;
    final everyOf = operations.whereType<EveryOfListCheck<T>>().firstOrNull;
    final possibleValues = <T>{};
    if (anyOf != null) {
      possibleValues.addAll(anyOf.items);
    }
    if (everyOf != null) {
      possibleValues.addAll(everyOf.items);
    }
    while (possibleValues.length < maxLength) {
      possibleValues.add(element.mock(seed));
    }
    final valuesList = possibleValues.toList();
    valuesList.shuffle(random);
    return valuesList
        .sublist(0, math.min(maxLength, valuesList.length))
        .sublist(0, minLength);
  }
}

AcanthisList<T> list<T>(AcanthisType<T> element) {
  return AcanthisList<T>(element);
}
