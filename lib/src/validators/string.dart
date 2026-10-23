import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:email_validator/email_validator.dart';

import '../common/issue.dart' show freezeIssueParameters;
import '../common/operations.dart';

/// Built-in predicates have a direct execution path without a context on success.
/// Custom checks implement [Check] and receive the normal diagnostic context.
sealed class StringCheck implements Check<String> {
  StringCheck(this.code, {Map<String, Object?> parameters = const {}})
    : parameters = freezeIssueParameters(parameters);

  final String code;
  final Map<String, Object?> parameters;

  bool test(String value);

  @override
  void evaluate(String value, CheckContext context) {
    if (!test(value)) context.addIssue(code, parameters: parameters);
  }
}

final class EmailStringCheck extends StringCheck {
  EmailStringCheck() : super('email');
  @override
  bool test(String value) => EmailValidator.validate(value);
}

final class MinStringLengthCheck extends StringCheck {
  MinStringLengthCheck(this.value)
    : super('minLength', parameters: {'value': value});
  final int value;
  @override
  bool test(String value) => value.length >= this.value;
}

final class MaxStringLengthCheck extends StringCheck {
  MaxStringLengthCheck(this.value)
    : super('maxLength', parameters: {'value': value});
  final int value;
  @override
  bool test(String value) => value.length <= this.value;
}

final class ExactStringLengthCheck extends StringCheck {
  ExactStringLengthCheck(this.value)
    : super('exactLength', parameters: {'value': value});
  final int value;
  @override
  bool test(String value) => value.length == this.value;
}

final class UriStringCheck extends StringCheck {
  UriStringCheck() : super('uri');
  @override
  bool test(String value) => Uri.tryParse(value) != null;
}

final class UrlStringCheck extends StringCheck {
  UrlStringCheck() : super('url');
  @override
  bool test(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}

class _RegexStringCheck extends StringCheck {
  _RegexStringCheck(super.code, this.regExp, {super.parameters});
  final RegExp regExp;
  @override
  bool test(String value) => regExp.hasMatch(value);
}

final class PatternLettersStringChecks extends _RegexStringCheck {
  PatternLettersStringChecks({this.strict = true})
    : super(
        'letters',
        RegExp(strict ? r'^[a-zA-Z]+$' : r'[a-zA-Z]+'),
        parameters: {'strict': strict},
      );
  final bool strict;
}

final class PatternDigitsStringChecks extends _RegexStringCheck {
  PatternDigitsStringChecks({this.strict = true})
    : super(
        'digits',
        RegExp(strict ? r'^[0-9]+$' : r'[0-9]+'),
        parameters: {'strict': strict},
      );
  final bool strict;
}

final class PatternAlphanumericStringChecks extends _RegexStringCheck {
  PatternAlphanumericStringChecks({this.strict = true})
    : super(
        'alphanumeric',
        RegExp(strict ? r'^[a-zA-Z0-9]+$' : r'[a-zA-Z0-9]+'),
        parameters: {'strict': strict},
      );
  final bool strict;
}

final class PatternAlphanumericWithSpacesStringChecks
    extends _RegexStringCheck {
  PatternAlphanumericWithSpacesStringChecks({this.strict = true})
    : super(
        'alphanumericWithSpaces',
        RegExp(strict ? r'^[a-zA-Z0-9 ]+$' : r'[a-zA-Z0-9 ]+'),
        parameters: {'strict': strict},
      );
  final bool strict;
}

final class PatternSpecialCharactersStringChecks extends _RegexStringCheck {
  PatternSpecialCharactersStringChecks({this.strict = true})
    : super(
        'specialCharacters',
        RegExp(
          strict ? r'^[!@#\$%^&*(),.?":{}|<>]+$' : r'[!@#\$%^&*(),.?":{}|<>]+',
        ),
        parameters: {'strict': strict},
      );
  final bool strict;
}

final class PatternAllCharactersStringChecks extends _RegexStringCheck {
  PatternAllCharactersStringChecks({this.strict = true})
    : super(
        'allCharacters',
        RegExp(
          strict
              ? r'^[a-zA-Z0-9!@#\$%^&*(),.?":{}\(\)\[\];_\-\?\!\£\|<> ]+$'
              : r'[a-zA-Z0-9!@#\$%^&*(),.?":{}\(\)\[\];_\-\?\!\£\|<> ]+',
        ),
        parameters: {'strict': strict},
      );
  final bool strict;
}

final class PatternCuidStringChecks extends _RegexStringCheck {
  PatternCuidStringChecks()
    : super('cuid', RegExp(r'^c[^\s-]{8,}$', caseSensitive: false));
}

final class PatternCuid2StringChecks extends _RegexStringCheck {
  PatternCuid2StringChecks()
    : super('cuid2', RegExp(r'^[0-9a-z]+$', caseSensitive: false));
}

final class PatternUlidStringChecks extends _RegexStringCheck {
  PatternUlidStringChecks()
    : super('ulid', RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$', caseSensitive: false));
}

final class PatternUuidStringChecks extends _RegexStringCheck {
  PatternUuidStringChecks()
    : super(
        'uuid',
        RegExp(
          r'^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$',
          caseSensitive: false,
        ),
      );
}

final class PatternNanoidStringChecks extends _RegexStringCheck {
  PatternNanoidStringChecks()
    : super('nanoid', RegExp(r'^[a-z0-9_-]{21}$', caseSensitive: false));
}

final class PatternJwtStringChecks extends _RegexStringCheck {
  PatternJwtStringChecks()
    : super(
        'jwt',
        RegExp(
          r'^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]*$',
          caseSensitive: false,
        ),
      );
}

final class PatternBase64StringChecks extends _RegexStringCheck {
  PatternBase64StringChecks()
    : super(
        'base64',
        RegExp(
          r'^([0-9a-zA-Z+/]{4})*(([0-9a-zA-Z+/]{2}==)|([0-9a-zA-Z+/]{3}=))?$',
          caseSensitive: false,
        ),
      );
}

final class PatternTimeStringChecks extends _RegexStringCheck {
  PatternTimeStringChecks()
    : super(
        'time',
        RegExp(
          r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9](?::([0-5]\d))?$',
          caseSensitive: false,
        ),
      );
}

final class PatternHexColorStringChecks extends StringCheck {
  PatternHexColorStringChecks() : super('hexColor');
  static final _pattern = RegExp(r'^#[0-9a-fA-F]{6}$');
  @override
  bool test(String value) => value.length == 7 && _pattern.hasMatch(value);
}

final class PatternStringCheck extends _RegexStringCheck {
  PatternStringCheck(Pattern pattern)
    : super('pattern', _compile(pattern), parameters: {'regExp': pattern});

  static RegExp _compile(Pattern pattern) => switch (pattern) {
    RegExp() => pattern,
    String() => RegExp(pattern),
    _ => throw ArgumentError.value(
      pattern,
      'pattern',
      'Expected String or RegExp',
    ),
  };
}

final class EnumeratedStringCheck<T extends Enum> extends StringCheck {
  factory EnumeratedStringCheck({
    required List<T> enumValues,
    String Function(String)? nameTransformer,
  }) {
    final entries = List<T>.unmodifiable(enumValues);
    if (entries.isEmpty) {
      throw ArgumentError('Enumeration values cannot be empty');
    }
    final names = List<String>.unmodifiable([
      for (final entry in entries)
        nameTransformer?.call(entry.name) ?? entry.name,
    ]);
    return EnumeratedStringCheck._(entries, names);
  }

  EnumeratedStringCheck._(this.enumValues, this.values)
    : _allowed = Set.unmodifiable(values),
      super('enumerated', parameters: {'values': values});
  final List<T> enumValues;
  final List<String> values;
  final Set<String> _allowed;
  @override
  bool test(String value) => _allowed.contains(value);
}

final class ContainedStringCheck extends StringCheck {
  factory ContainedStringCheck({required Iterable<String> values}) {
    final entries = List<String>.unmodifiable(values);
    if (entries.isEmpty) throw ArgumentError('Values cannot be empty');
    return ContainedStringCheck._(entries);
  }
  ContainedStringCheck._(this.values)
    : _allowed = Set.unmodifiable(values),
      super('enumerated', parameters: {'values': values});
  final List<String> values;
  final Set<String> _allowed;
  @override
  bool test(String value) => _allowed.contains(value);
}

final class RequiredStringCheck extends StringCheck {
  RequiredStringCheck() : super('required');
  @override
  bool test(String value) => value.isNotEmpty;
}

final class NotEmptyStringCheck extends StringCheck {
  NotEmptyStringCheck() : super('notEmpty');
  @override
  bool test(String value) => value.isNotEmpty;
}

final class ContainsStringCheck extends StringCheck {
  ContainsStringCheck(this.value)
    : super('contains', parameters: {'value': value});
  final String value;
  @override
  bool test(String value) => value.contains(this.value);
}

final class StartsWithStringCheck extends StringCheck {
  StartsWithStringCheck(this.value)
    : super('startsWith', parameters: {'value': value});
  final String value;
  @override
  bool test(String value) => value.startsWith(this.value);
}

final class EndsWithStringCheck extends StringCheck {
  EndsWithStringCheck(this.value)
    : super('endsWith', parameters: {'value': value});
  final String value;
  @override
  bool test(String value) => value.endsWith(this.value);
}

final class CardStringCheck extends StringCheck {
  CardStringCheck() : super('card');
  static final _nonDigits = RegExp(r'\D');
  @override
  bool test(String value) {
    final number = value.replaceAll(_nonDigits, '');
    if (number.length < 13 || number.length > 19) return false;
    var sum = 0;
    var alternate = false;
    for (var index = number.length - 1; index >= 0; index--) {
      var digit = number.codeUnitAt(index) - 48;
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }
}

final class UpperCaseStringCheck extends StringCheck {
  UpperCaseStringCheck() : super('upperCase');
  @override
  bool test(String value) => value == value.toUpperCase();
}

final class LowerCaseStringCheck extends StringCheck {
  LowerCaseStringCheck() : super('lowerCase');
  @override
  bool test(String value) => value == value.toLowerCase();
}

final class MixedCaseStringCheck extends StringCheck {
  MixedCaseStringCheck() : super('mixedCase');
  @override
  bool test(String value) =>
      value != value.toUpperCase() && value != value.toLowerCase();
}

final class DateTimeStringCheck extends StringCheck {
  DateTimeStringCheck() : super('dateTime');
  @override
  bool test(String value) => DateTime.tryParse(value) != null;
}

/// Returns HIBP range response text for a five-character SHA-1 prefix.
/// Supplying a lookup makes the check usable with a cached/offline provider.
typedef PasswordRangeLookup = Future<String> Function(String prefix);

final class UncompromisedStringCheck implements AsyncCheck<String> {
  UncompromisedStringCheck({PasswordRangeLookup? lookup})
    : _lookup = lookup ?? _lookupRange;
  final PasswordRangeLookup _lookup;
  static final _row = RegExp(r'^([0-9A-Fa-f]{35}):([0-9]+)$');

  @override
  Future<void> evaluate(String value, CheckContext context) async {
    final hash = sha1.convert(utf8.encode(value)).toString().toUpperCase();
    final body = await _lookup(hash.substring(0, 5));
    var compromised = false;
    var hasRow = false;
    for (final line in const LineSplitter().convert(body)) {
      final match = _row.firstMatch(line);
      final count = match == null ? null : int.tryParse(match[2]!);
      if (match == null || count == null) {
        throw const FormatException('Malformed password range response');
      }
      hasRow = true;
      if (count > 0 && match[1]!.toUpperCase() == hash.substring(5)) {
        compromised = true;
      }
    }
    if (!hasRow) throw const FormatException('Empty password range response');
    if (compromised) context.addIssue('uncompromised');
  }

  static Future<String> _lookupRange(String prefix) async {
    const timeout = Duration(seconds: 10);
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.https('api.pwnedpasswords.com', '/range/$prefix'))
          .timeout(timeout);
      request.headers.set('Add-Padding', 'true');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Password range service returned ${response.statusCode}',
        );
      }
      return await response.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}
