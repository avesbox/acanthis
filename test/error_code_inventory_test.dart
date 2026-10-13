import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/validators/list.dart';
import 'package:acanthis/src/validators/common.dart';
import 'package:test/test.dart';

enum _Choice { first }

void main() {
  final cases = <(AcanthisType, dynamic, String, Map<String, Object?>)>[
    (string().min(3), 'x', 'minLength', {'value': 3}),
    (string().max(1), 'xx', 'maxLength', {'value': 1}),
    (string().length(3), 'x', 'exactLength', {'value': 3}),
    (string().email(), '!', 'email', {}),
    (string().url(), '!', 'url', {}),
    (string().cuid(), '!', 'cuid', {}),
    (string().cuid2(), '!', 'cuid2', {}),
    (string().ulid(), '!', 'ulid', {}),
    (string().uuid(), '!', 'uuid', {}),
    (string().nanoid(), '!', 'nanoid', {}),
    (string().jwt(), '!', 'jwt', {}),
    (string().base64(), '!', 'base64', {}),
    (string().time(), '!', 'time', {}),
    (string().hexColor(), '!', 'hexColor', {}),
    (string().card(), '!', 'card', {}),
    (string().dateTime(), '!', 'dateTime', {}),
    (string().uri(), 'http://[', 'uri', {}),
    (string().letters(), '!', 'letters', {'strict': true}),
    (string().digits(), '!', 'digits', {'strict': true}),
    (string().alphanumeric(), '!', 'alphanumeric', {'strict': true}),
    (
      string().alphanumericWithSpaces(),
      '!',
      'alphanumericWithSpaces',
      {'strict': true},
    ),
    (
      string().specialCharacters(),
      'abc',
      'specialCharacters',
      {'strict': true},
    ),
    (string().allCharacters(), '\n', 'allCharacters', {'strict': true}),
    (string().required(), '', 'required', {}),
    (string().notEmpty(), '', 'notEmpty', {}),
    (string().contains('a'), 'b', 'contains', {'value': 'a'}),
    (string().startsWith('a'), 'b', 'startsWith', {'value': 'a'}),
    (string().endsWith('a'), 'b', 'endsWith', {'value': 'a'}),
    (string().upperCase(), 'a', 'upperCase', {}),
    (string().lowerCase(), 'A', 'lowerCase', {}),
    (string().mixedCase(), 'a', 'mixedCase', {}),
    (string().pattern(RegExp('^a')), 'b', 'pattern', {'regExp': '^a'}),
    (
      string().contained(['a']),
      'b',
      'enumerated',
      {
        'values': ['a'],
      },
    ),
    (
      string().enumerated(
        _Choice.values,
        nameTransformer: (s) => s.toUpperCase(),
      ),
      'other',
      'enumerated',
      {
        'enumValues': ['first'],
        'values': ['FIRST'],
      },
    ),
    (number().lte(1), 2, 'lte', {'value': 1}),
    (number().lt(1), 2, 'lt', {'value': 1}),
    (number().gte(3), 2, 'gte', {'value': 3}),
    (number().gt(3), 2, 'gt', {'value': 3}),
    (number().between(2, 4), 1, 'between', {'min': 2, 'max': 4}),
    (number().positive(), 0, 'positive', {}),
    (number().negative(), 0, 'negative', {}),
    (number().nonPositive(), 1, 'nonpositive', {}),
    (number().nonNegative(), -1, 'nonnegative', {}),
    (number().integer(), 1.5, 'integer', {}),
    (number().double(), 1, 'double', {}),
    (number().finite(), double.infinity, 'finite', {}),
    (number().infinite(), 1, 'infinite', {}),
    (number().nan(), 1, 'nan', {}),
    (number().notNaN(), double.nan, 'notNaN', {}),
    (number().multipleOf(2), 3, 'multipleOf', {'value': 2}),
    (
      number().enumerated([1]),
      2,
      'enumerated',
      {
        'values': [1],
      },
    ),
    (boolean().isTrue(), false, 'isTrue', {}),
    (boolean().isFalse(), true, 'isFalse', {}),
    (string().exact('a'), 'b', 'exact', {'value': 'a'}),
    (
      boolean().withCheck(ExactCheck<bool>(value: true)),
      false,
      'exact',
      {'value': true},
    ),
    (number().exact(1), 2, 'exact', {'value': 1}),
    (number().list().min(2), [1], 'minItems', {'minItems': 2}),
    (number().list().max(1), [1, 2], 'maxItems', {'maxItems': 1}),
    (number().list().length(2), [1], 'length', {'length': 2}),
    (number().list().unique(), [1, 1], 'uniqueItems', {}),
    (
      number().list().withCheck(ContainsListCheck<num>(1)),
      [2],
      'contains',
      {'item': 1},
    ),
    (
      number().list().anyOf([1]),
      [2],
      'anyOf',
      {
        'items': [1],
      },
    ),
    (
      number().list().everyOf([1]),
      [2],
      'everyOf',
      {
        'items': [1],
      },
    ),
    (
      object({}).minProperties(1),
      <String, dynamic>{},
      'minProperties',
      {'constraintValue': 1},
    ),
    (
      object({'x': string()}).maxProperties(0),
      {'x': 'a'},
      'maxProperties',
      {'constraintValue': 0},
    ),
    (
      object({}).lengthProperties(1),
      <String, dynamic>{},
      'lengthProperties',
      {'constraintValue': 1},
    ),
    (
      date().min(DateTime.utc(2026)),
      DateTime.utc(2025),
      'min',
      {'value': DateTime.utc(2026).toIso8601String()},
    ),
    (
      date().max(DateTime.utc(2026)),
      DateTime.utc(2027),
      'max',
      {'value': DateTime.utc(2026).toIso8601String()},
    ),
    (
      date().differsFrom(DateTime.utc(2026), const Duration(seconds: 1)),
      DateTime.utc(2026),
      'differsFrom',
      {'fromDate': DateTime.utc(2026).toIso8601String(), 'difference': 1000000},
    ),
    (
      date().differsFromNow(const Duration(days: 1)),
      DateTime.now(),
      'differsFromNow',
      {'difference': 86400000000},
    ),
    (
      string().nullable().enumerated(['a']),
      'b',
      'enumerated',
      {
        'values': ['a', null],
      },
    ),
    (string(), 42, 'type', {}),
    (date().coerce(), 'bad', 'date', {}),
    (object({'x': string()}), <String, dynamic>{}, 'required', {}),
    (
      object({}).unknownKeys(AcanthisUnknownKeys.reject),
      {'x': 1},
      'unknownKey',
      {},
    ),
    (literal('a'), 'b', 'literal', {'expected': 'a'}),
    (tuple([string()]), [], 'tuple', {'length': 1}),
    (
      string().refine(onCheck: (_) => false, error: 'fallback', name: ''),
      'a',
      'custom',
      {},
    ),
  ];
  for (var index = 0; index < cases.length; index++) {
    final (schema, input, code, parameters) = cases[index];
    test(
      'producer $index $code preserves metadata and catalog parity',
      () async {
        final sync = schema.tryParse(input);
        final async = await schema.tryParseAsync(input);
        expect(sync.isValid, isFalse);
        expect(async.issues, sync.issues);
        final issue = sync.issues.first;
        expect(issue.code, code);
        expect(issue.parameters, parameters);
        expect(issue.message, isNotEmpty);
        expect(AcanthisIssueCodes.values, contains(code));
        if (code != 'custom') {
          for (final resolver in [
            AcanthisMessageCatalogs.english,
            AcanthisMessageCatalogs.italian,
          ]) {
            expect(resolver(code, issue.parameters), isNotNull);
            expect(issue.formatMessage(resolver: resolver), isNotEmpty);
          }
        }
        expect(
          () => schema.parse(input),
          throwsA(
            isA<ValidationError>()
                .having((e) => e.issue!.code, 'code', code)
                .having((e) => e.issue!.parameters, 'parameters', parameters),
          ),
        );
      },
    );
  }
  test(
    'catalog rejects malformed constrained parameters and interpolates safely',
    () {
      for (final code in [
        'minLength',
        'maxLength',
        'exactLength',
        'minItems',
        'maxItems',
        'length',
        'tuple',
        'minProperties',
        'maxProperties',
        'lengthProperties',
        'lte',
        'gte',
        'lt',
        'gt',
        'multipleOf',
        'between',
        'exact',
        'literal',
        'contains',
        'startsWith',
        'endsWith',
        'enumerated',
        'anyOf',
        'everyOf',
        'pattern',
        'templateLiteral',
        'dependency',
        'variantGuard',
        'min',
        'max',
        'differsFrom',
        'differsFromNow',
        'letters',
        'digits',
        'alphanumeric',
        'alphanumericWithSpaces',
        'specialCharacters',
        'allCharacters',
      ]) {
        expect(AcanthisMessageCatalogs.english(code, {}), isNull, reason: code);
        expect(
          AcanthisMessageCatalogs.italian(code, {'invalid': Object()}),
          isNull,
          reason: code,
        );
      }
      expect(
        AcanthisMessageCatalogs.english('enumerated', {
          'enumValues': ['a'],
        }),
        isNotNull,
      );
      expect(
        AcanthisMessageCatalogs.english('minLength', {'value': 1}),
        endsWith('1 character'),
      );
      expect(
        AcanthisMessageCatalogs.english('minLength', {'value': 2}),
        endsWith('2 characters'),
      );
      expect(
        AcanthisMessageCatalogs.english('contains', {'value': r'${value}'}),
        contains(r'${value}'),
      );
      expect(AcanthisMessageCatalogs.english('app.unknown', {}), isNull);
    },
  );
}
