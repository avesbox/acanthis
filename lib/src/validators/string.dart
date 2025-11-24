import 'dart:convert' as convert;
import 'dart:io';

import 'package:acanthis/src/operations/checks.dart';
import 'package:crypto/crypto.dart';
import 'package:email_validator/email_validator.dart';

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

/// String Check for Email validation.
class EmailStringCheck extends AcanthisCheck<String> {
  const EmailStringCheck({String? message})
    : super(
        error: message ?? 'Value must be a valid email address',
        name: 'email',
      );

  @override
  bool call(String value) {
    return EmailValidator.validate(value);
  }
}

/// String Check for Maximum String Length validation.
class MaxStringLengthCheck extends AcanthisCheck<String> {
  final int value;

  MaxStringLengthCheck(
    this.value, {
    String? message,
    String Function(int value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be less than or equal to $value characters long',
         name: 'maxLength',
       );

  @override
  bool call(String value) {
    return value.length <= this.value;
  }
}

/// String Check for Minimum String Length validation.
class MinStringLengthCheck extends AcanthisCheck<String> {
  final int value;

  MinStringLengthCheck(
    this.value, {
    String? message,
    String Function(int value)? messageBuilder,
  }) : super(
         error:
             message ??
             messageBuilder?.call(value) ??
             'Value must be greater than or equal to $value characters long',
         name: 'minLength',
       );

  @override
  bool call(String value) {
    return value.length >= this.value;
  }
}

/// String Check for Exact String Length validation.
class ExactStringLengthCheck extends AcanthisCheck<String> {
  final int value;

  ExactStringLengthCheck(
    this.value, {
    String? message,
    String Function(int value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be exactly $value characters long',
         name: 'exactLength',
       );

  @override
  bool call(String value) {
    return value.length == this.value;
  }
}

/// String Check for URI validation.
class UriStringCheck extends AcanthisCheck<String> {
  const UriStringCheck({String? message})
    : super(error: message ?? 'Value must be a valid uri', name: 'uri');

  @override
  bool call(String value) {
    return Uri.tryParse(value) != null;
  }
}

/// String Check for URL validation.
class UrlStringCheck extends AcanthisCheck<String> {
  const UrlStringCheck({String? message})
    : super(error: message ?? 'Value must be a valid url', name: 'url');

  @override
  bool call(String value) {
    if (value.isEmpty) return false;
    final uriValue = Uri.tryParse(value);
    if (uriValue == null) return false;
    return uriValue.hasScheme && uriValue.host.isNotEmpty;
  }
}

/// Async String Check for Uncompromised String validation.
class UncompromisedStringCheck extends AcanthisAsyncCheck<String> {
  const UncompromisedStringCheck({String? message})
    : super(
        error: message ?? 'Value must not be compromised',
        name: 'uncompromised',
      );

  @override
  Future<bool> call(String value) async {
    final bytes = convert.utf8.encode(value);
    final sha = sha1.convert(bytes);
    final hexString = sha.toString().toUpperCase();
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse(
        'https://api.pwnedpasswords.com/range/${hexString.substring(0, 5)}',
      ),
    );
    final response = await request.close();
    final body = await response.transform(convert.utf8.decoder).join();
    final lines = body.split('\n');
    return !lines.any((element) => element.startsWith(hexString.substring(5)));
  }
}

/// String Check for Full Letters String validation.
class PatternLettersStringChecks extends AcanthisCheck<String> {
  final bool strict;

  final RegExp regExp;

  PatternLettersStringChecks({this.strict = true, String? message})
    : regExp = strict ? RegExp(_lettersStrict) : RegExp(_letters),
      super(
        error: message ?? 'Value must contain ${strict ? 'only ' : ''}letters',
        name: 'letters',
      );

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Digits String validation.
class PatternDigitsStringChecks extends AcanthisCheck<String> {
  final bool strict;

  final RegExp regExp;

  PatternDigitsStringChecks({this.strict = true, String? message})
    : regExp = strict ? RegExp(_digitsStrict) : RegExp(_digits),
      super(
        error: message ?? 'Value must contain ${strict ? 'only ' : ''}digits',
        name: 'digits',
      );

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Alphanumeric String validation.
class PatternAlphanumericStringChecks extends AcanthisCheck<String> {
  final bool strict;

  final RegExp regExp;

  PatternAlphanumericStringChecks({this.strict = true, String? message})
    : regExp = strict ? RegExp(_alphanumericStrict) : RegExp(_alphanumeric),
      super(
        error:
            message ??
            'Value must contain ${strict ? 'only ' : ''}alphanumeric',
        name: 'alphanumeric',
      );

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Alphanumeric with Spaces String validation.
class PatternAlphanumericWithSpacesStringChecks extends AcanthisCheck<String> {
  final bool strict;

  final RegExp regExp;

  PatternAlphanumericWithSpacesStringChecks({
    this.strict = true,
    String? message,
  }) : regExp = strict
           ? RegExp(_alphanumericWithSpacesStrict)
           : RegExp(_alphanumericWithSpaces),
       super(
         error:
             message ??
             'Value must contain ${strict ? 'only ' : ''}alphanumeric with spaces',
         name: 'alphanumericWithSpaces',
       );

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Special Characters String validation.
class PatternSpecialCharactersStringChecks extends AcanthisCheck<String> {
  final bool strict;

  final RegExp regExp;

  PatternSpecialCharactersStringChecks({this.strict = true, String? message})
    : regExp = strict
          ? RegExp(_specialCharactersStrict)
          : RegExp(_specialCharacters),
      super(
        error:
            message ??
            'Value must contain ${strict ? 'only ' : ''}special characters',
        name: 'specialCharacters',
      );

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full All Characters String validation.
class PatternAllCharactersStringChecks extends AcanthisCheck<String> {
  final bool strict;

  final RegExp regExp;

  PatternAllCharactersStringChecks({this.strict = true, String? message})
    : regExp = strict ? RegExp(_allCharactersStrict) : RegExp(_allCharacters),
      super(
        error:
            message ??
            'Value must contain ${strict ? 'only ' : ''}all characters',
        name: 'allCharacters',
      );

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full CUID String validation.
class PatternCuidStringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_cuidRegex, caseSensitive: false);

  PatternCuidStringChecks({String? message})
    : super(error: message ?? 'Value must be a valid cuid', name: 'cuid');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full CUID2 String validation.
class PatternCuid2StringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_cuid2Regex, caseSensitive: false);

  PatternCuid2StringChecks({String? message})
    : super(error: message ?? 'Value must be a valid cuid2', name: 'cuid2');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full ULID String validation.
class PatternUlidStringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_ulidRegex, caseSensitive: false);

  PatternUlidStringChecks({String? message})
    : super(error: message ?? 'Value must be a valid ulid', name: 'ulid');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full UUID String validation.
class PatternUuidStringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_uuidRegex, caseSensitive: false);

  PatternUuidStringChecks({String? message})
    : super(error: message ?? 'Value must be a valid uuid', name: 'uuid');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Nanoid String validation.
class PatternNanoidStringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_nanoidRegex, caseSensitive: false);

  PatternNanoidStringChecks({String? message})
    : super(error: message ?? 'Value must be a valid nanoid', name: 'nanoid');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full JWT String validation.
class PatternJwtStringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_jwtRegex, caseSensitive: false);

  PatternJwtStringChecks({String? message})
    : super(error: message ?? 'Value must be a valid jwt', name: 'jwt');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Base64 String validation.
class PatternBase64StringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_base64Regex, caseSensitive: false);

  PatternBase64StringChecks({String? message})
    : super(error: message ?? 'Value must be a valid base64', name: 'base64');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Time String validation.
class PatternTimeStringChecks extends AcanthisCheck<String> {
  final RegExp regExp = RegExp(_timeRegex, caseSensitive: false);

  PatternTimeStringChecks({String? message})
    : super(error: message ?? 'Value must be a valid time', name: 'time');

  @override
  bool call(String value) {
    return regExp.hasMatch(value);
  }
}

/// String Check for Full Hex Color String validation.
class PatternHexColorStringChecks extends AcanthisCheck<String> {
  const PatternHexColorStringChecks({String? message})
    : super(
        error: message ?? 'Value must be a valid hex color',
        name: 'hexColor',
      );

  @override
  bool call(String value) {
    if (value.length != 7) return false;
    if (value[0] != '#') return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(value.substring(1));
  }
}

/// String Check for enumerated String validation.
class EnumeratedStringCheck<T extends Enum> extends AcanthisCheck<String> {
  final List<T> enumValues;
  final String Function(String name)? nameTransformer;

  EnumeratedStringCheck({
    required this.enumValues,
    this.nameTransformer,
    String? message,
    String Function(List<T> enumValues)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(enumValues) ??
             message ??
             'Value must be one of the enumerated values',
         name: 'enumerated',
       );

  @override
  bool call(String value) {
    return enumValues.any(
      (entry) => value == (nameTransformer?.call(entry.name) ?? entry.name),
    );
  }
}

/// String Check for contained String validation.
class ContainedStringCheck extends AcanthisCheck<String> {
  final Iterable<String> values;

  ContainedStringCheck({
    required this.values,
    String? message,
    String Function(Iterable<String> values)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(values) ??
             message ??
             'Value must be one of the enumerated values',
         name: 'enumerated',
       );

  @override
  bool call(String value) {
    return values.contains(value);
  }
}

/// String Check for non-empty String validation.
class RequiredStringCheck extends AcanthisCheck<String> {
  const RequiredStringCheck({String? message})
    : super(error: message ?? 'Value must not be empty', name: 'required');

  @override
  bool call(String value) {
    return value.isNotEmpty;
  }
}

/// String Check for non-empty String validation.
class NotEmptyStringCheck extends AcanthisCheck<String> {
  const NotEmptyStringCheck({String? message})
    : super(error: message ?? 'Value must not be empty', name: 'notEmpty');

  @override
  bool call(String value) {
    return value.isNotEmpty;
  }
}

/// String check for containing a specific substring.
class ContainsStringCheck extends AcanthisCheck<String> {
  final String value;

  ContainsStringCheck(
    this.value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must contain $value',
         name: 'contains',
       );

  @override
  bool call(String value) {
    return value.contains(this.value);
  }
}

/// String check for starting with a specific substring.
class StartsWithStringCheck extends AcanthisCheck<String> {
  final String value;

  StartsWithStringCheck(
    this.value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must start with $value',
         name: 'startsWith',
       );

  @override
  bool call(String value) {
    return value.startsWith(this.value);
  }
}

/// String check for ending with a specific substring.
class EndsWithStringCheck extends AcanthisCheck<String> {
  final String value;

  EndsWithStringCheck(
    this.value, {
    String? message,
    String Function(String value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must end with $value',
         name: 'endsWith',
       );

  @override
  bool call(String value) {
    return value.endsWith(this.value);
  }
}

/// String check for a valid card number using the Luhn algorithm.
class CardStringCheck extends AcanthisCheck<String> {
  const CardStringCheck({String? message})
    : super(
        error: message ?? 'Value must be a valid card number',
        name: 'card',
      );

  bool _isValidLuhn(String number) {
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

  @override
  bool call(String value) {
    final sanitized = value.replaceAll(RegExp(r'\D'), '');
    if (sanitized.length < 13 || sanitized.length > 19) return false;
    if (!RegExp(r'^\d+$').hasMatch(sanitized)) return false;
    return _isValidLuhn(sanitized);
  }
}

/// String check for Uppercase String validation.
class UpperCaseStringCheck extends AcanthisCheck<String> {
  const UpperCaseStringCheck({String? message})
    : super(error: message ?? 'Value must be uppercase', name: 'upperCase');

  @override
  bool call(String value) {
    return value == value.toUpperCase();
  }
}

/// String check for Lowercase String validation.
class LowerCaseStringCheck extends AcanthisCheck<String> {
  const LowerCaseStringCheck({String? message})
    : super(error: message ?? 'Value must be lowercase', name: 'lowerCase');

  @override
  bool call(String value) {
    return value == value.toLowerCase();
  }
}

/// String check for Mixed Case String validation.
class MixedCaseStringCheck extends AcanthisCheck<String> {
  const MixedCaseStringCheck({String? message})
    : super(error: message ?? 'Value must be mixed case', name: 'mixedCase');

  @override
  bool call(String value) {
    return value != value.toUpperCase() && value != value.toLowerCase();
  }
}

/// String check for a valid date time format.
class DateTimeStringCheck extends AcanthisCheck<String> {
  const DateTimeStringCheck({String? message})
    : super(
        error: message ?? 'Value must be a valid date time',
        name: 'dateTime',
      );

  @override
  bool call(String value) {
    return DateTime.tryParse(value) != null;
  }
}

/// String check fo a generic pattern using a regular expression.
class PatternStringCheck extends AcanthisCheck<String> {
  final Pattern regExp;

  PatternStringCheck(
    this.regExp, {
    String? message,
    String Function(Pattern regExp)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(regExp) ??
             message ??
             'Value must match the pattern',
         name: 'pattern',
       );

  @override
  bool call(String value) {
    if (regExp is RegExp) {
      return (regExp as RegExp).hasMatch(value);
    } else if (regExp is String) {
      return RegExp(regExp as String).hasMatch(value);
    } else {
      throw ArgumentError('Invalid pattern type: ${regExp.runtimeType}');
    }
  }
}
