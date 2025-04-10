import 'dart:convert' as convert;
import 'package:acanthis/acanthis.dart';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:email_validator/email_validator.dart';

/// A class to validate string types
class AcanthisString extends AcanthisType<String> {
  const AcanthisString({super.isAsync, super.operations});

  /// Add a check to the string to check if it is a valid email
  AcanthisString email() {
    return withCheck(StringChecks.email);
  }

  /// Add a check to the string to check if its length is at least [length]
  AcanthisString min(int length) {
    return withCheck(StringChecks.min(length));
  }

  /// Add a check to the string to check if its length is at most [length]
  AcanthisString max(int length) {
    return withCheck(StringChecks.max(length));
  }

  /// Add a check to the string to check if follows the pattern [pattern]
  AcanthisString pattern(RegExp pattern) {
    return withCheck(StringChecks.pattern(pattern));
  }

  /// Add a check to the string to check if it contains letters
  AcanthisString letters({bool strict = true}) {
    return withCheck(switch (strict) {
      true => StringChecks.strictLetters,
      false => StringChecks.letters,
    });
  }

  /// Add a check to the string to check if it contains digits
  AcanthisString digits({bool strict = true}) {
    return withCheck(switch (strict) {
      true => StringChecks.strictDigits,
      false => StringChecks.digits
    });
  }

  /// Add a check to the string to check if it contains alphanumeric characters
  AcanthisString alphanumeric({bool strict = true}) {
    return withCheck(switch (strict) {
      true => StringChecks.strictAlphanumeric,
      false => StringChecks.alphanumeric
    });
  }

  /// Add a check to the string to check if it contains alphanumeric characters and spaces
  AcanthisString alphanumericWithSpaces({bool strict = true}) {
    return withCheck(switch (strict) {
      true => StringChecks.strictAlphanumericWithSpaces,
      false => StringChecks.alphanumericWithSpaces,
    });
  }

  /// Add a check to the string to check if it contains special characters
  AcanthisString specialCharacters({bool strict = true}) {
    return withCheck(switch (strict) {
      true => StringChecks.strictSpecialCharacters,
      false => StringChecks.specialCharacters
    });
  }

  /// Add a check to the string to check if it contains all characters
  AcanthisString allCharacters({bool strict = true}) {
    return withCheck(switch (strict) {
      true => StringChecks.strictAllCharacters,
      false => StringChecks.allCharacters
    });
  }

  /// Add a check to the string to check if it is in uppercase
  AcanthisString upperCase() {
    return withCheck(StringChecks.upperCase);
  }

  /// Add a check to the string to check if it is in lowercase
  AcanthisString lowerCase() {
    return withCheck(StringChecks.lowerCase);
  }

  /// Add a check to the string to check if it is in mixed case
  AcanthisString mixedCase() {
    return withCheck(StringChecks.mixedCase);
  }

  /// Add a check to the string to check if it is a valid date time
  AcanthisString dateTime() {
    return withCheck(StringChecks.dateTime);
  }

  AcanthisString time() {
    return withCheck(StringChecks.time);
  }

  AcanthisString hexColor() {
    return withCheck(StringChecks.hexColor);
  }

  /// Add a check to the string to check if it is a valid uri
  AcanthisString uri() {
    return withCheck(StringChecks.uri);
  }

  AcanthisString url() {
    return withCheck(StringChecks.url);
  }

  AcanthisString uncompromised() {
    return withAsyncCheck(StringChecks.uncompromised);
  }

  /// Add a check to the string to check if it is not empty
  AcanthisString required() {
    return withCheck(StringChecks.required);
  }

  /// Add a check to the string to check if it's length is exactly [length]
  AcanthisString length(int length) {
    return withCheck(StringChecks.length(length));
  }

  /// Add a check to the string to check if it contains [value]
  AcanthisString contains(String value) {
    return withCheck(StringChecks.contains(value));
  }

  /// Add a check to the string to check if it starts with [value]
  AcanthisString startsWith(String value) {
    return withCheck(StringChecks.startsWith(value));
  }

  /// Add a check to the string to check if it ends with [value]
  AcanthisString endsWith(String value) {
    return withCheck(StringChecks.endsWith(value));
  }

  AcanthisString card() {
    return withCheck(StringChecks.card);
  }

  AcanthisString cuid() {
    return withCheck(StringChecks.cuid);
  }

  AcanthisString cuid2() {
    return withCheck(StringChecks.cuid2);
  }

  AcanthisString ulid() {
    return withCheck(StringChecks.ulid);
  }

  AcanthisString uuid() {
    return withCheck(StringChecks.uuid);
  }

  AcanthisString nanoid() {
    return withCheck(StringChecks.nanoid);
  }

  AcanthisString jwt() {
    return withCheck(StringChecks.jwt);
  }

  AcanthisString base64() {
    return withCheck(StringChecks.base64);
  }

  /// Create a list of strings
  AcanthisList<String> list() {
    return AcanthisList<String>(this);
  }

  /// Add a transformation to the string to encode it to base64
  AcanthisString encode() {
    return withTransformation(StringTransforms.base64Encode);
  }

  /// Add a transformation to the string to decode it from base64
  AcanthisString decode() {
    return withTransformation(StringTransforms.base64Decode);
  }

  /// Add a transformation to the string to transform it to uppercase
  AcanthisString toUpperCase() {
    return withTransformation(StringTransforms.toUpperCase);
  }

  /// Add a transformation to the string to transform it to lowercase
  AcanthisString toLowerCase() {
    return withTransformation(StringTransforms.toLowerCase);
  }

  /// Create a union from the string
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  // AcanthisDate date() {
  //   addTransformation(AcanthisTransformation(transformation: (value) => DateTime.parse(value)));
  //   return AcanthisDate();
  // }

  @override
  AcanthisString withAsyncCheck(BaseAcanthisAsyncCheck<String> check) {
    return AcanthisString(operations: operations.add(check), isAsync: true);
  }

  @override
  AcanthisString withCheck(BaseAcanthisCheck<String> check) {
    return AcanthisString(operations: operations.add(check));
  }

  @override
  AcanthisString withTransformation(
      BaseAcanthisTransformation<String> transformation) {
    return AcanthisString(operations: operations.add(transformation));
  }
}

/// Create a new AcanthisString instance
AcanthisString string() => AcanthisString();

// Checks for Strings

const _lettersStrict = r'^[a-zA-Z]+$';
const _digitsStrict = r'^[0-9]+$';
const _alphanumericStrict = r'^[a-zA-Z0-9]+$';
const _alphanumericWithSpacesStrict = r'^[a-zA-Z0-9 ]+$';
const _specialCharactersStrict = r'^[!@#\$%^&*(),.?":{}|<>]+$';
const _allCharactersStrict =
    r'^[a-zA-Z0-9!@#\$%^&*(),.?":{}\(\)\[\];_\-\?\!\£\|<> ]+$';
const _letters = r'[a-zA-Z]+';
const _digits = r'[0-9]+';
const _alphanumeric = r'[a-zA-Z0-9]+';
const _alphanumericWithSpaces = r'[a-zA-Z0-9 ]+';
const _specialCharacters = r'[!@#\$%^&*(),.?":{}|<>]+';
const _allCharacters = r'[a-zA-Z0-9!@#\$%^&*(),.?":{}\(\)\[\];_\-\?\!\£\|<> ]+';
const _cuidRegex = r'^c[^\s-]{8,}$';
const _cuid2Regex = r'^[0-9a-z]+$';
const _ulidRegex = r'^[0-9A-HJKMNP-TV-Z]{26}$';
// const uuidRegex =
//   /^([a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[a-f0-9]{4}-[a-f0-9]{12}|00000000-0000-0000-0000-000000000000)$/i;
const _uuidRegex =
    r'^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$';
const _nanoidRegex = r'^[a-z0-9_-]{21}$';
const _jwtRegex = r'^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]*$';
const _base64Regex =
    r'^([0-9a-zA-Z+/]{4})*(([0-9a-zA-Z+/]{2}==)|([0-9a-zA-Z+/]{3}=))?$';
const _timeRegex = r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9](?::([0-5]\d))?$';

abstract class StringChecks extends BaseAcanthisCheck<String> {
  const StringChecks();

  const factory StringChecks.min(int length) = _MinCheck;
  const factory StringChecks.max(int length) = _MaxCheck;
  const factory StringChecks.pattern(RegExp pattern) = _PatternCheck;
  const factory StringChecks.length(int length) = _LengthCheck;
  const factory StringChecks.contains(String value) = _ContainsCheck;
  const factory StringChecks.startsWith(String value) = _StartsWithCheck;
  const factory StringChecks.endsWith(String value) = _EndsWithCheck;

  static const email = AcanthisCheck<String>(
      onCheck: EmailValidator.validate,
      error: 'Invalid email format',
      name: 'email');

  static bool _letterCheck(String toTest) => RegExp(_letters).hasMatch(toTest);
  static const letters = AcanthisCheck<String>(
      onCheck: _letterCheck,
      error: 'Value must contain letters',
      name: 'letters');

  static bool _strictLetterCheck(String toTest) =>
      RegExp(_lettersStrict).hasMatch(toTest);
  static const strictLetters = AcanthisCheck<String>(
      onCheck: _strictLetterCheck,
      error: 'Value must contain only letters',
      name: 'letters');

  static bool _digitCheck(String toTest) => RegExp(_digits).hasMatch(toTest);
  static const digits = AcanthisCheck<String>(
      onCheck: _digitCheck, error: 'Value must contain digits', name: 'digits');

  static bool _strictDigitCheck(String toTest) =>
      RegExp(_digitsStrict).hasMatch(toTest);
  static const strictDigits = AcanthisCheck<String>(
      onCheck: _strictDigitCheck,
      error: 'Value must contain only digits',
      name: 'digits');

  static bool _alphanumericCheck(String toTest) =>
      RegExp(_alphanumeric).hasMatch(toTest);
  static const alphanumeric = AcanthisCheck<String>(
      onCheck: _alphanumericCheck,
      error: 'Value must contain alphanumeric characters',
      name: 'alphanumeric');

  static bool _strictAlphanumericCheck(String toTest) =>
      RegExp(_alphanumericStrict).hasMatch(toTest);
  static const strictAlphanumeric = AcanthisCheck<String>(
      onCheck: _strictAlphanumericCheck,
      error: 'Value must contain only alphanumeric characters',
      name: 'alphanumeric');

  static bool _alphanumericWithSpacesCheck(String toTest) =>
      RegExp(_alphanumericWithSpaces).hasMatch(toTest);
  static const alphanumericWithSpaces = AcanthisCheck<String>(
      onCheck: _alphanumericWithSpacesCheck,
      error: 'Value must contain alphanumeric or spaces characters',
      name: 'alphanumericWithSpaces');

  static bool _strictAlphanumericWithSpacesCheck(String toTest) =>
      RegExp(_alphanumericWithSpacesStrict).hasMatch(toTest);
  static const strictAlphanumericWithSpaces = AcanthisCheck<String>(
      onCheck: _strictAlphanumericWithSpacesCheck,
      error: 'Value must contain only alphanumeric or spaces characters',
      name: 'alphanumericWithSpaces');

  static bool _specialCharactersCheck(String toTest) =>
      RegExp(_specialCharacters).hasMatch(toTest);
  static const specialCharacters = AcanthisCheck<String>(
      onCheck: _specialCharactersCheck,
      error: 'Value must contain special characters',
      name: 'specialCharacters');

  static bool _strictSpecialCharactersCheck(String toTest) =>
      RegExp(_specialCharactersStrict).hasMatch(toTest);
  static const strictSpecialCharacters = AcanthisCheck<String>(
      onCheck: _strictSpecialCharactersCheck,
      error: 'Value must contain only special characters',
      name: 'specialCharacters');

  static bool _allCharactersCheck(String toTest) =>
      RegExp(_allCharacters).hasMatch(toTest);
  static const allCharacters = AcanthisCheck<String>(
      onCheck: _allCharactersCheck,
      error: 'Value must contain characters',
      name: 'allCharacters');

  static bool _strictAllCharactersCheck(String toTest) =>
      RegExp(_allCharactersStrict).hasMatch(toTest);
  static const strictAllCharacters = AcanthisCheck<String>(
      onCheck: _strictAllCharactersCheck,
      error: 'Value must contain only characters',
      name: 'allCharacters');

  static bool _uppercaseCheck(String toTest) => toTest == toTest.toUpperCase();
  static const upperCase = AcanthisCheck<String>(
      onCheck: _uppercaseCheck,
      error: 'Value must be uppercase',
      name: 'upperCase');

  static bool _lowercaseCheck(String toTest) => toTest == toTest.toLowerCase();
  static const lowerCase = AcanthisCheck<String>(
      onCheck: _lowercaseCheck,
      error: 'Value must be lowercase',
      name: 'lowerCase');

  static bool _mixedcaseCheck(String toTest) =>
      toTest != toTest.toUpperCase() && toTest != toTest.toLowerCase();
  static const mixedCase = AcanthisCheck<String>(
      onCheck: _mixedcaseCheck,
      error: 'Value must be mixed case',
      name: 'mixedCase');

  static bool _datetimeCheck(String toTest) =>
      DateTime.tryParse(toTest) != null;
  static const dateTime = AcanthisCheck<String>(
      onCheck: _datetimeCheck,
      error: 'Value must be a valid date time',
      name: 'dateTime');

  static bool _timeCheck(String toTest) =>
      (RegExp(_timeRegex)).hasMatch(toTest);
  static const time = AcanthisCheck<String>(
      onCheck: _timeCheck,
      error: 'Value must be a valid time format',
      name: 'time');

  static bool _uriCheck(String toTest) => Uri.tryParse(toTest) != null;
  static const uri = AcanthisCheck<String>(
      onCheck: _uriCheck, error: 'Value must be a valid uri', name: 'uri');

  static bool _requiredCheck(String toTest) => toTest.isNotEmpty;
  static const required = AcanthisCheck<String>(
      onCheck: _requiredCheck, error: 'Value is required', name: 'required');

  static bool _cuidCheck(String toTest) =>
      RegExp(_cuidRegex, caseSensitive: false).hasMatch(toTest);
  static const cuid = AcanthisCheck<String>(
      onCheck: _cuidCheck, error: 'Value must be a valid cuid', name: 'cuid');

  static bool _cuid2Check(String toTest) =>
      RegExp(_cuid2Regex, caseSensitive: false).hasMatch(toTest);
  static const cuid2 = AcanthisCheck<String>(
      onCheck: _cuid2Check,
      error: 'Value must be a valid cuid2',
      name: 'cuid2');

  static bool _ulidCheck(String toTest) =>
      RegExp(_ulidRegex, caseSensitive: false).hasMatch(toTest);
  static const ulid = AcanthisCheck<String>(
      onCheck: _ulidCheck, error: 'Value must be a valid ulid', name: 'ulid');

  static bool _uuidCheck(String toTest) =>
      RegExp(_uuidRegex, caseSensitive: false).hasMatch(toTest);
  static const uuid = AcanthisCheck<String>(
      onCheck: _uuidCheck, error: 'Value must be a valid uuid', name: 'uuid');

  static bool _nanoidCheck(String toTest) =>
      RegExp(_nanoidRegex, caseSensitive: false).hasMatch(toTest);
  static const nanoid = AcanthisCheck<String>(
      onCheck: _nanoidCheck,
      error: 'Value must be a valid nanoid',
      name: 'nanoid');

  static bool _jwtCheck(String toTest) =>
      RegExp(_jwtRegex, caseSensitive: false).hasMatch(toTest);
  static const jwt = AcanthisCheck<String>(
      onCheck: _jwtCheck, error: 'Value must be a valid jwt', name: 'jwt');

  static bool _base64Check(String toTest) =>
      RegExp(_base64Regex, caseSensitive: false).hasMatch(toTest);
  static const base64 = AcanthisCheck<String>(
      onCheck: _base64Check,
      error: 'Value must be a valid base64',
      name: 'base64');

  static bool _hexColorCheck(String toTest) {
    if (toTest.length != 7) return false;
    if (toTest[0] != '#') return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(toTest.substring(1));
  }

  static const hexColor = AcanthisCheck<String>(
      onCheck: _hexColorCheck,
      error: 'Value must be a valid hex color',
      name: 'hexColor');

  static bool _urlCheck(String toTest) {
    if (toTest.isEmpty) return false;
    final uriValue = Uri.tryParse(toTest);
    if (uriValue == null) return false;
    return uriValue.hasScheme && uriValue.host.isNotEmpty;
  }

  static const url = AcanthisCheck<String>(
      onCheck: _urlCheck, error: 'Value must be a valid url', name: 'url');

  static bool _cardCheck(String toTest) {
    final sanitized = toTest.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length < 13 || sanitized.length > 19) return false;
    if (!RegExp(r'^\d+$').hasMatch(sanitized)) return false;
    return _isValidLuhn(sanitized);
  }

  static bool _isValidLuhn(String number) {
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static const card = AcanthisCheck<String>(
      onCheck: _cardCheck,
      error: 'Value must be a valid card number',
      name: 'card');

  static Future<bool> _uncompromisedCheck(String toTest) async {
    final bytes = convert.utf8.encode(toTest);
    final sha = sha1.convert(bytes);
    final hexString = sha.toString().toUpperCase();
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse(
          'https://api.pwnedpasswords.com/range/${hexString.substring(0, 5)}'),
    );
    final response = await request.close();
    final body = await response.transform(convert.utf8.decoder).join();
    final lines = body.split('\n');
    client.close();
    return !lines.any((element) => element.startsWith(hexString.substring(5)));
  }

  static const uncompromised = AcanthisAsyncCheck<String>(
      onCheck: _uncompromisedCheck,
      error: 'Value is compromised',
      name: 'uncompromised');
}

class _MinCheck extends StringChecks {
  final int length;
  const _MinCheck(this.length);

  @override
  bool onCheck(String toTest) => toTest.length >= length;
  @override
  String get error => 'Value must be at least $length characters long';
  @override
  String get name => 'min';
}

class _MaxCheck extends StringChecks {
  final int length;

  const _MaxCheck(
    this.length,
  );

  @override
  bool onCheck(String toTest) => toTest.length <= length;
  @override
  String get error => 'Value must be at most $length characters long';
  @override
  String get name => 'max';
}

class _PatternCheck extends StringChecks {
  final RegExp pattern;
  const _PatternCheck(
    this.pattern,
  );

  @override
  bool onCheck(String toTest) => pattern.hasMatch(toTest);
  @override
  String get error => 'Value does not match the pattern $pattern';
  @override
  String get name => 'pattern';
}

class _LengthCheck extends StringChecks {
  final int length;
  const _LengthCheck(
    this.length,
  );

  @override
  bool onCheck(String toTest) => toTest.length == length;
  @override
  String get error => 'Value must be $length characters long';
  @override
  String get name => 'length';
}

class _ContainsCheck extends StringChecks {
  final String value;
  const _ContainsCheck(
    this.value,
  );

  @override
  bool onCheck(String toTest) => toTest.contains(value);
  @override
  String get error => 'Value must contain $value';
  @override
  String get name => 'contains';
}

class _StartsWithCheck extends StringChecks {
  final String value;
  const _StartsWithCheck(
    this.value,
  );

  @override
  bool onCheck(String toTest) => toTest.startsWith(value);
  @override
  String get error => 'Value must start with $value';
  @override
  String get name => 'startsWith';
}

class _EndsWithCheck extends StringChecks {
  final String value;
  const _EndsWithCheck(
    this.value,
  );

  @override
  bool onCheck(String toTest) => toTest.endsWith(value);
  @override
  String get error => 'Value must end with $value';
  @override
  String get name => 'endsWith';
}

abstract class StringTransforms extends BaseAcanthisTransformation<String> {
  const StringTransforms();

  static String _base64EncodeTransformation(String toTransform) =>
      convert.base64.encode(toTransform.codeUnits);
  static const base64Encode =
      AcanthisTransformation(transformation: _base64EncodeTransformation);

  static String _base64DecodeTransformation(String toTransform) =>
      String.fromCharCodes(convert.base64.decode(toTransform));
  static const base64Decode =
      AcanthisTransformation(transformation: _base64DecodeTransformation);

  static String _toUpperCaseTransformation(String toTransform) =>
      toTransform.toUpperCase();
  static const toUpperCase =
      AcanthisTransformation(transformation: _toUpperCaseTransformation);

  static String _toLowerCaseTransformation(String toTransform) =>
      toTransform.toLowerCase();
  static const toLowerCase =
      AcanthisTransformation(transformation: _toLowerCaseTransformation);
  static String _stringTrimTransformation(String toTransform) =>
      toTransform.trim();
  static const trim =
      AcanthisTransformation(transformation: _stringTrimTransformation);
}
