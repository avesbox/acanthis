import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/validators/common.dart';
import 'package:acanthis/src/validators/string.dart';
import 'package:nanoid2/nanoid2.dart' as n;

import 'dart:convert' as convert;
import '../registries/metadata_registry.dart';
import 'types.dart';

/// A class to validate string types
class AcanthisString extends AcanthisType<String> {
  const AcanthisString({
    super.isAsync,
    super.operations,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  });

  /// Add a check to the string to check if it is a valid email
  AcanthisString email({String? message}) {
    return withCheck(EmailStringCheck(message: message));
  }

  /// Add a check to the string to check if its length is at least [length]
  AcanthisString min(
    int length, {
    String? message,
    String Function(int value)? messageBuilder,
  }) {
    return withCheck(
      MinStringLengthCheck(
        length,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if its length is at most [length]
  AcanthisString max(
    int length, {
    String? message,
    String Function(int value)? messageBuilder,
  }) {
    return withCheck(
      MaxStringLengthCheck(
        length,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if follows the pattern [pattern]
  AcanthisString pattern(Pattern pattern, {String? message}) {
    return withCheck(PatternStringCheck(pattern, message: message));
  }

  /// Add a check to the string to check if it contains letters
  AcanthisString letters({bool strict = true, String? message}) {
    return withCheck(
      PatternLettersStringChecks(strict: strict, message: message),
    );
  }

  /// Add a check to the string to check if it contains digits
  AcanthisString digits({bool strict = true, String? message}) {
    return withCheck(
      PatternDigitsStringChecks(strict: strict, message: message),
    );
  }

  /// Add a check to the string to check if it contains alphanumeric characters
  AcanthisString alphanumeric({bool strict = true, String? message}) {
    return withCheck(
      PatternAlphanumericStringChecks(strict: strict, message: message),
    );
  }

  /// Add a check to the string to check if it contains alphanumeric characters and spaces
  AcanthisString alphanumericWithSpaces({bool strict = true, String? message}) {
    return withCheck(
      PatternAlphanumericWithSpacesStringChecks(
        strict: strict,
        message: message,
      ),
    );
  }

  /// Add a check to the string to check if it contains special characters
  AcanthisString specialCharacters({bool strict = true, String? message}) {
    return withCheck(
      PatternSpecialCharactersStringChecks(strict: strict, message: message),
    );
  }

  /// Add a check to the string to check if it contains all characters
  AcanthisString allCharacters({bool strict = true, String? message}) {
    return withCheck(
      PatternAllCharactersStringChecks(strict: strict, message: message),
    );
  }

  /// Add a check to the string to check if it is in uppercase
  AcanthisString upperCase({String? message}) {
    return withCheck(UpperCaseStringCheck(message: message));
  }

  /// Add a check to the string to check if it is in lowercase
  AcanthisString lowerCase({String? message}) {
    return withCheck(LowerCaseStringCheck(message: message));
  }

  /// Add a check to the string to check if it is in mixed case
  AcanthisString mixedCase({String? message}) {
    return withCheck(MixedCaseStringCheck(message: message));
  }

  /// Add a check to the string to check if it is a valid date time
  AcanthisString dateTime({String? message}) {
    return withCheck(DateTimeStringCheck(message: message));
  }

  AcanthisString time({String? message}) {
    return withCheck(PatternTimeStringChecks(message: message));
  }

  AcanthisString hexColor({String? message}) {
    return withCheck(PatternHexColorStringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid uri
  AcanthisString uri({String? message}) {
    return withCheck(UriStringCheck(message: message));
  }

  AcanthisString url({String? message}) {
    return withCheck(UrlStringCheck(message: message));
  }

  AcanthisString uncompromised({String? message}) {
    return withAsyncCheck(UncompromisedStringCheck(message: message));
  }

  /// Add a check to the string to check if it is not empty
  @Deprecated(
    'Use notEmpty() instead; required() will be removed in a future release.',
  )
  AcanthisString required({String? message}) {
    return withCheck(RequiredStringCheck(message: message));
  }

  /// Add a check to the string to check if it is not empty
  AcanthisString notEmpty({String? message}) {
    return withCheck(NotEmptyStringCheck(message: message));
  }

  /// Add a check to the string to check if it's length is exactly [length]
  AcanthisString length(
    int length, {
    String? message,
    String Function(int value)? messageBuilder,
  }) {
    return withCheck(
      ExactStringLengthCheck(
        length,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if it contains [value]
  AcanthisString contains(
    String value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) {
    return withCheck(
      ContainsStringCheck(
        value,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if it starts with [value]
  AcanthisString startsWith(
    String value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) {
    return withCheck(
      StartsWithStringCheck(
        value,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if it ends with [value]
  AcanthisString endsWith(
    String value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) {
    return withCheck(
      EndsWithStringCheck(
        value,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if it is a valid card number
  AcanthisString card({String? message}) {
    return withCheck(CardStringCheck(message: message));
  }

  /// Add a check to the string to check if it is a value in the [enumValues].
  /// uses [enumvalues[index].name] for the comparison, but you can provide a [nameTransformer] to transform the name property of any item on the list.
  ///
  /// - [nameTransformer] A function to transform the name property of every item on the list.
  ///                     If not provided, the name property of the item will be used as the name of the enum value.
  ///                     TIP: use conditional logic on [name] to perform different validations on different enum values.
  AcanthisString enumerated<T extends Enum>(
    List<T> enumValues, {
    String? message,
    String Function(String name)? nameTransformer,
  }) {
    if (enumValues.isEmpty) {
      throw ArgumentError('Enumeration values cannot be empty');
    }
    return withCheck(
      EnumeratedStringCheck(
        enumValues: enumValues,
        nameTransformer: nameTransformer,
        message: message,
      ),
    );
  }

  /// Add a check to the string to check if it is a value in the [enumValues]
  AcanthisString contained(
    Iterable<String> values, {
    String? message,
    String Function(Iterable<String> value)? messageBuilder,
  }) {
    if (values.isEmpty) {
      throw ArgumentError('Values cannot be empty');
    }
    return withCheck(
      ContainedStringCheck(
        values: values,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the string to check if it is a valid cuid
  AcanthisString cuid({String? message}) {
    return withCheck(PatternCuidStringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid cuid2
  AcanthisString cuid2({String? message}) {
    return withCheck(PatternCuid2StringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid ulid
  AcanthisString ulid({String? message}) {
    return withCheck(PatternUlidStringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid uuid
  AcanthisString uuid({String? message}) {
    return withCheck(PatternUuidStringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid nanoid
  AcanthisString nanoid({String? message}) {
    return withCheck(PatternNanoidStringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid jwt
  AcanthisString jwt({String? message}) {
    return withCheck(PatternJwtStringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid base64 string
  AcanthisString base64({String? message}) {
    return withCheck(PatternBase64StringChecks(message: message));
  }

  /// Add a check to the string to check if it is a valid hex color
  AcanthisString exact(
    String value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) {
    return withCheck(
      ExactCheck<String>(
        value: value,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a transformation to the string to encode it to base64
  AcanthisString encode() {
    return withTransformation(
      AcanthisTransformation<String>(
        transformation: (value) => convert.base64.encode(value.codeUnits),
      ),
    );
  }

  /// Add a transformation to the string to decode it from base64
  AcanthisString decode() {
    return withTransformation(
      AcanthisTransformation<String>(
        transformation:
            (value) => convert.utf8.decode(convert.base64.decode(value)),
      ),
    );
  }

  /// Add a transformation to the string to transform it to uppercase
  AcanthisString toUpperCase() {
    return withTransformation(
      AcanthisTransformation<String>(
        transformation: (value) => value.toUpperCase(),
      ),
    );
  }

  /// Add a transformation to the string to transform it to lowercase
  AcanthisString toLowerCase() {
    return withTransformation(
      AcanthisTransformation<String>(
        transformation: (value) => value.toLowerCase(),
      ),
    );
  }

  // AcanthisDate date() {
  //   addTransformation(AcanthisTransformation(transformation: (value) => DateTime.parse(value)));
  //   return AcanthisDate();
  // }

  @override
  AcanthisString withAsyncCheck(AcanthisAsyncCheck<String> check) {
    return AcanthisString(
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisString withCheck(AcanthisCheck<String> check) {
    return AcanthisString(
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisString withTransformation(
    AcanthisTransformation<String> transformation,
  ) {
    return AcanthisString(
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final lengthChecksMap = _getConstraints();
    final patternChecksMap = _getPattern();
    final enumeratedChecksMap = _getEnumeratedChecks();
    final exactChecksMap = _getExactChecks();
    if (exactChecksMap.isNotEmpty) {
      return {
        'const': exactChecksMap['const'],
        if (metadataEntry != null) ...metadataEntry!.toJson(),
      };
    }
    if (enumeratedChecksMap.isNotEmpty) {
      return {
        'enum': enumeratedChecksMap['enum'],
        if (metadataEntry != null) ...metadataEntry!.toJson(),
      };
    }
    return {
      'type': 'string',
      if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
      if (metadataEntry != null) ...metadataEntry!.toJson(),
      if (patternChecksMap.isNotEmpty) ...patternChecksMap,
    };
  }

  Map<String, dynamic> _getExactChecks() {
    final exactChecks = operations.whereType<ExactCheck>();
    final exactChecksMap = <String, dynamic>{};
    for (var check in exactChecks) {
      exactChecksMap['const'] = check.value;
    }
    return exactChecksMap;
  }

  Map<String, dynamic> _getEnumeratedChecks() {
    final enumeratedChecks = operations.whereType<EnumeratedStringCheck>();
    final enumeratedChecksMap = <String, dynamic>{};
    for (var check in enumeratedChecks) {
      enumeratedChecksMap['enum'] =
          check.enumValues.map((e) => e.name).toList();
    }
    return enumeratedChecksMap;
  }

  Map<String, dynamic> _getConstraints() {
    final lengthChecks = operations.whereType<AcanthisCheck>();
    final lengthChecksMap = <String, dynamic>{};

    for (var check in lengthChecks) {
      if (check is MaxStringLengthCheck) {
        lengthChecksMap['maxLength'] = check.value;
      } else if (check is MinStringLengthCheck) {
        lengthChecksMap['minLength'] = check.value;
      } else if (check is ExactStringLengthCheck) {
        lengthChecksMap['maxLength'] = check.value;
        lengthChecksMap['minLength'] = check.value;
      }
    }
    return lengthChecksMap;
  }

  Map<String, dynamic> _getPattern() {
    final patternChecks = operations.whereType<AcanthisCheck>();
    final patternChecksMap = <String, dynamic>{};
    for (var check in patternChecks) {
      patternChecksMap['pattern'] = switch (check) {
        PatternLettersStringChecks() => check.regExp.pattern,
        PatternDigitsStringChecks() => check.regExp.pattern,
        PatternAlphanumericStringChecks() => check.regExp.pattern,
        PatternAlphanumericWithSpacesStringChecks() => check.regExp.pattern,
        PatternSpecialCharactersStringChecks() => check.regExp.pattern,
        PatternAllCharactersStringChecks() => check.regExp.pattern,
        PatternTimeStringChecks() => check.regExp.pattern,
        PatternCuidStringChecks() => check.regExp.pattern,
        PatternCuid2StringChecks() => check.regExp.pattern,
        PatternUlidStringChecks() => check.regExp.pattern,
        PatternUuidStringChecks() => check.regExp.pattern,
        PatternNanoidStringChecks() => check.regExp.pattern,
        PatternJwtStringChecks() => check.regExp.pattern,
        PatternBase64StringChecks() => check.regExp.pattern,
        PatternStringCheck() =>
          check.regExp is RegExp
              ? (check.regExp as RegExp).pattern
              : check.regExp,
        _ => null,
      };
      if (patternChecksMap['pattern'] == null) {
        patternChecksMap.remove('pattern');
      }
    }
    return patternChecksMap;
  }

  @override
  AcanthisString meta(MetadataEntry<String> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = n.nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisString(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisType<String> withDefault(String value) {
    return AcanthisString(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }
}

/// Create a new AcanthisString instance
AcanthisString string() => AcanthisString();
