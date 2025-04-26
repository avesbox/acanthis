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
  const AcanthisString({super.isAsync, super.operations, super.key});

  /// Add a check to the string to check if it is a valid email
  AcanthisString email() {
    return withCheck(EmailStringCheck());
  }

  /// Add a check to the string to check if its length is at least [length]
  AcanthisString min(int length) {
    return withCheck(MinStringLengthCheck(length));
  }

  /// Add a check to the string to check if its length is at most [length]
  AcanthisString max(int length) {
    return withCheck(MaxStringLengthCheck(length));
  }

  /// Add a check to the string to check if follows the pattern [pattern]
  AcanthisString pattern(RegExp pattern) {
    return withCheck(PatternStringCheck(pattern));
  }

  /// Add a check to the string to check if it contains letters
  AcanthisString letters({bool strict = true}) {
    return withCheck(PatternLettersStringChecks(strict: strict));
  }

  /// Add a check to the string to check if it contains digits
  AcanthisString digits({bool strict = true}) {
    return withCheck(PatternDigitsStringChecks(strict: strict));
  }

  /// Add a check to the string to check if it contains alphanumeric characters
  AcanthisString alphanumeric({bool strict = true}) {
    return withCheck(PatternAlphanumericStringChecks(strict: strict));
  }

  /// Add a check to the string to check if it contains alphanumeric characters and spaces
  AcanthisString alphanumericWithSpaces({bool strict = true}) {
    return withCheck(PatternAlphanumericWithSpacesStringChecks(strict: strict));
  }

  /// Add a check to the string to check if it contains special characters
  AcanthisString specialCharacters({bool strict = true}) {
    return withCheck(PatternSpecialCharactersStringChecks(strict: strict));
  }

  /// Add a check to the string to check if it contains all characters
  AcanthisString allCharacters({bool strict = true}) {
    return withCheck(PatternAllCharactersStringChecks(strict: strict));
  }

  /// Add a check to the string to check if it is in uppercase
  AcanthisString upperCase() {
    return withCheck(UpperCaseStringCheck());
  }

  /// Add a check to the string to check if it is in lowercase
  AcanthisString lowerCase() {
    return withCheck(LowerCaseStringCheck());
  }

  /// Add a check to the string to check if it is in mixed case
  AcanthisString mixedCase() {
    return withCheck(MixedCaseStringCheck());
  }

  /// Add a check to the string to check if it is a valid date time
  AcanthisString dateTime() {
    return withCheck(DateTimeStringCheck());
  }

  AcanthisString time() {
    return withCheck(PatternTimeStringChecks());
  }

  AcanthisString hexColor() {
    return withCheck(PatternHexColorStringChecks());
  }

  /// Add a check to the string to check if it is a valid uri
  AcanthisString uri() {
    return withCheck(UriStringCheck());
  }

  AcanthisString url() {
    return withCheck(UrlStringCheck());
  }

  AcanthisString uncompromised() {
    return withAsyncCheck(UncompromisedStringCheck());
  }

  /// Add a check to the string to check if it is not empty
  AcanthisString required() {
    return withCheck(RequiredStringCheck());
  }

  /// Add a check to the string to check if it's length is exactly [length]
  AcanthisString length(int length) {
    return withCheck(ExactStringLengthCheck(length));
  }

  /// Add a check to the string to check if it contains [value]
  AcanthisString contains(String value) {
    return withCheck(ContainsStringCheck(value));
  }

  /// Add a check to the string to check if it starts with [value]
  AcanthisString startsWith(String value) {
    return withCheck(StartsWithStringCheck(value));
  }

  /// Add a check to the string to check if it ends with [value]
  AcanthisString endsWith(String value) {
    return withCheck(EndsWithStringCheck(value));
  }

  /// Add a check to the string to check if it is a valid card number
  AcanthisString card() {
    return withCheck(CardStringCheck());
  }

  /// Add a check to the string to check if it is a value in the [enumValues]
  AcanthisString enumerated<T extends Enum>(List<T> enumValues) {
    if (enumValues.isEmpty) {
      throw ArgumentError('Enumeration values cannot be empty');
    }
    return withCheck(EnumeratedStringCheck(enumValues: enumValues));
  }

  /// Add a check to the string to check if it is a valid cuid
  AcanthisString cuid() {
    return withCheck(PatternCuidStringChecks());
  }

  /// Add a check to the string to check if it is a valid cuid2
  AcanthisString cuid2() {
    return withCheck(PatternCuid2StringChecks());
  }

  /// Add a check to the string to check if it is a valid ulid
  AcanthisString ulid() {
    return withCheck(PatternUlidStringChecks());
  }

  /// Add a check to the string to check if it is a valid uuid
  AcanthisString uuid() {
    return withCheck(PatternUuidStringChecks());
  }

  /// Add a check to the string to check if it is a valid nanoid
  AcanthisString nanoid() {
    return withCheck(PatternNanoidStringChecks());
  }

  /// Add a check to the string to check if it is a valid jwt
  AcanthisString jwt() {
    return withCheck(PatternJwtStringChecks());
  }

  /// Add a check to the string to check if it is a valid base64 string
  AcanthisString base64() {
    return withCheck(PatternBase64StringChecks());
  }

  /// Add a check to the string to check if it is a valid hex color
  AcanthisString exact(String value) {
    return withCheck(ExactCheck<String>(value: value));
  }

  /// Add a transformation to the string to encode it to base64
  AcanthisString encode() {
    return withTransformation(AcanthisTransformation<String>(
        transformation: (value) => convert.base64.encode(value.codeUnits)));
  }

  /// Add a transformation to the string to decode it from base64
  AcanthisString decode() {
    return withTransformation(AcanthisTransformation<String>(
        transformation: (value) =>
            convert.utf8.decode(convert.base64.decode(value))));
  }

  /// Add a transformation to the string to transform it to uppercase
  AcanthisString toUpperCase() {
    return withTransformation(AcanthisTransformation<String>(
        transformation: (value) => value.toUpperCase()));
  }

  /// Add a transformation to the string to transform it to lowercase
  AcanthisString toLowerCase() {
    return withTransformation(AcanthisTransformation<String>(
        transformation: (value) => value.toLowerCase()));
  }

  // AcanthisDate date() {
  //   addTransformation(AcanthisTransformation(transformation: (value) => DateTime.parse(value)));
  //   return AcanthisDate();
  // }

  @override
  AcanthisString withAsyncCheck(AcanthisAsyncCheck<String> check) {
    return AcanthisString(operations: [
      ...operations,
      check,
    ], isAsync: true, key: key);
  }

  @override
  AcanthisString withCheck(AcanthisCheck<String> check) {
    return AcanthisString(operations: [
      ...operations,
      check,
    ], isAsync: isAsync, key: key);
  }

  @override
  AcanthisString withTransformation(
      AcanthisTransformation<String> transformation) {
    return AcanthisString(operations: [
      ...operations,
      transformation,
    ], isAsync: isAsync, key: key);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final lengthChecksMap = _getConstraints();
    final patternChecksMap = _getPattern();
    final enumeratedChecksMap = _getEnumeratedChecks();
    final metadata = MetadataRegistry().get(key);
    final exactChecksMap = _getExactChecks();
    if (exactChecksMap.isNotEmpty) {
      return {
        'const': exactChecksMap['const'],
        if (metadata != null) ...metadata.toJson(),
      };
    }
    if (enumeratedChecksMap.isNotEmpty) {
      return {
        'enum': enumeratedChecksMap['enum'],
        if (metadata != null) ...metadata.toJson(),
      };
    }
    return {
      'type': 'string',
      if (lengthChecksMap.isNotEmpty) ...lengthChecksMap,
      if (metadata != null) ...metadata.toJson(),
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
        PatternStringCheck() => check.regExp.pattern,
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
    );
  }
}

/// Create a new AcanthisString instance
AcanthisString string() => AcanthisString();
