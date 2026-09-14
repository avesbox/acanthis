import 'package:acanthis/src/seeded_mock.dart';
import 'package:acanthis/src/issue_sink.dart';

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
    bool isAsync = false,
    bool isPure = true,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  }) : _localPure = isPure,
       super(isAsync: isAsync || element.isAsync);

  @override
  List<T> parseInternal(covariant dynamic value) {
    value ??= defaultValue;
    final raw = value as List<dynamic>;
    if (isPure) {
      List<T>? changed;
      for (var i = 0; i < raw.length; i++) {
        final parsed = element.parseInternal(raw[i]);
        if (!identical(parsed, raw[i])) {
          (changed ??= List<T>.from(raw))[i] = parsed;
        }
      }
      return super.parseInternal(
        changed ?? (raw is List<T> ? raw : raw.cast<T>()),
      );
    }
    final parsed = List<T?>.filled(raw.length, null);
    for (var i = 0; i < raw.length; i++) {
      parsed[i] = element.parseInternal(raw[i]);
    }
    return super.parseInternal(parsed.cast<T>());
  }

  @override
  List<T> valueOnFailure(dynamic value) => defaultValue ?? <T>[];

  List<T> _reuseUnchangedInput(dynamic input, List<T> output) {
    if (!isPure || input is! List<T> || input.length != output.length) {
      return output;
    }
    for (var i = 0; i < output.length; i++) {
      if (!identical(input[i], output[i])) return output;
    }
    return input;
  }

  @override
  List<T> tryParseInternal(
    covariant dynamic value, {
    required Map<String, dynamic> errors,
  }) {
    value ??= defaultValue;
    if (value is! List) {
      errors.addIssue(
        inputErrorKey,
        'Invalid type: ${value.runtimeType}, expected List',
      );
      return valueOnFailure(value);
    }
    final raw = value;
    if (isPure) {
      List<dynamic>? changed;
      final elementErrors = IssueSink();
      for (var i = 0; i < raw.length; i++) {
        final parsed = element.tryParseInternal(raw[i], errors: elementErrors);
        if (!identical(parsed, raw[i])) {
          (changed ??= List<dynamic>.of(raw))[i] = parsed;
        }
        if (elementErrors.isNotEmpty) {
          errors.addChild(i, elementErrors);
          elementErrors.clear();
        }
      }
      return super.tryParseInternal(
        changed?.cast<T>() ?? (raw is List<T> ? raw : raw.cast<T>()),
        errors: errors,
      );
    }
    final parsed = List<T?>.filled(raw.length, null);
    final elementErrors = IssueSink();
    for (var i = 0; i < raw.length; i++) {
      parsed[i] = element.tryParseInternal(raw[i], errors: elementErrors);
      if (elementErrors.isNotEmpty) {
        errors.addChild(i, elementErrors);
        elementErrors.clear();
      }
    }
    return super.tryParseInternal(parsed.cast<T>(), errors: errors);
  }

  @override
  Future<AcanthisParseResult<List<T>>> parseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return parse(value);
    final raw = value as List<dynamic>;
    final parsed = <T>[];
    for (var i = 0; i < raw.length; i++) {
      final parsedElement = await element.parseAsync(raw[i]);
      parsed.add(parsedElement.value);
    }
    final result = await super.parseAsync(parsed);
    return AcanthisParseResult(
      value: _reuseUnchangedInput(value, result.value),
      metadata: result.metadata,
    );
  }

  @override
  Future<AcanthisParseResult<List<T>>> tryParseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return tryParse(value);
    if (value is! List) {
      return AcanthisParseResult(
        value: valueOnFailure(value),
        errors: IssueSink.single(
          inputErrorKey,
          'Invalid type: ${value.runtimeType}, expected List',
        ),
        success: false,
        metadata: metadataEntry,
      );
    }
    final raw = value;
    final parsed = <T>[];
    final errors = IssueSink();
    for (var i = 0; i < raw.length; i++) {
      final parsedElement = await element.tryParseAsync(raw[i]);
      parsed.add(parsedElement.value);
      if (parsedElement.errors.isNotEmpty) {
        errors.addChild(i, parsedElement.errors);
      }
    }
    final result = await super.tryParseAsyncOperations(parsed);
    final mergedErrors = IssueSink.of(errors)..addAll(result.errors);
    final success = mergedErrors.isEmpty;
    return AcanthisParseResult(
      value: success
          ? _reuseUnchangedInput(value, result.value)
          : defaultValue ?? _reuseUnchangedInput(value, result.value),
      errors: mergedErrors,
      metadata: result.metadata,
      success: success,
    );
  }

  /// Override of [parse] from [AcanthisType]
  @override
  AcanthisParseResult<List<T>> parse(dynamic value) {
    value ??= defaultValue;
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
  AcanthisParseResult<List<T>> tryParse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    if (value is! List) {
      return AcanthisParseResult(
        value: valueOnFailure(value),
        errors: IssueSink.single(
          inputErrorKey,
          'Invalid type: ${value.runtimeType}, expected List',
        ),
        success: false,
        metadata: metadataEntry,
      );
    }
    final errors = IssueSink();
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
    if (minLength < 0 || maxLength < minLength || minLength > 10000) {
      throw const AcanthisMockException(
        'Invalid or excessive list length bounds',
      );
    }
    final unique = operations.any((op) => op is UniqueItemsListCheck<T>);
    final result = <T>[];
    final pool = possibleValues.toList();
    for (
      var attempt = 0;
      result.length < minLength && attempt < 10000;
      attempt++
    ) {
      final candidate = pool.isEmpty
          ? element.mock(random.nextInt(1 << 30))
          : pool[random.nextInt(pool.length)];
      if (!unique || !result.contains(candidate)) result.add(candidate);
    }
    if (result.length != minLength || !tryParse(result).success) {
      throw const AcanthisMockException(
        'Unable to generate a valid list within 10000 attempts; use mockSeeded for the documented safe subset',
      );
    }
    return result;
  }
}

AcanthisList<T> list<T>(AcanthisType<T> element) {
  return AcanthisList<T>(element);
}
