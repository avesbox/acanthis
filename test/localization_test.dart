import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('English and Italian cover the complete built-in code vocabulary', () {
    for (final code in AcanthisIssueCodes.values) {
      final parameters = <String, Object?>{
        'value': code == 'min' || code == 'max'
            ? '2025-01-01T00:00:00.000Z'
            : 3,
        'expected': 'tag',
        'min': 1,
        'max': 5,
        'minItems': 2,
        'maxItems': 5,
        'length': 3,
        'constraintValue': 2,
        'difference': 1000,
        'fromDate': '2025-01-01T00:00:00.000Z',
        'values': ['a', 'b'],
        'items': ['a', 'b'],
        'item': 'a',
        'strict': true,
      };
      for (final catalog in [
        AcanthisMessageCatalogs.english,
        AcanthisMessageCatalogs.italian,
      ]) {
        final message = catalog.resolve(code, parameters);
        expect(message, isNotNull, reason: code);
        expect(message, isNotEmpty, reason: code);
        expect(message, isNot(code), reason: code);
      }
    }
  });

  test('date diagnostics format frozen bounds and microseconds in either locale', () {
    final bound = DateTime.utc(2025);
    final issues = [
      ...date().min(bound).tryParse(DateTime.utc(2024)).issues,
      ...date().max(bound).tryParse(DateTime.utc(2026)).issues,
      ...date()
          .differsFrom(bound, const Duration(microseconds: 1))
          .tryParse(bound)
          .issues,
      ...date()
          .differsFromNow(const Duration(days: 1))
          .tryParse(DateTime.now())
          .issues,
    ];
    expect(issues.map((issue) => issue.code), [
      'min',
      'max',
      'differsFrom',
      'differsFromNow',
    ]);
    expect(issues[2].parameters, {
      'fromDate': bound.toIso8601String(),
      'difference': 1,
    });
    final transport = issues.toTransport();
    expect(
      issues[0].message,
      'The date must be on or after ${bound.toIso8601String()}',
    );
    expect(
      issues[1].message,
      'The date must be on or before ${bound.toIso8601String()}',
    );
    expect(
      issues[2].message,
      'The date must differ from ${bound.toIso8601String()} by at least 1 microsecond',
    );
    AcanthisI18n.runWith(AcanthisLocaleConfig.forLocale('it-IT'), () {
      final messages = issues.formatTree().messages;
      expect(messages, [
        'La data deve essere successiva o uguale a ${bound.toIso8601String()}',
        'La data deve essere precedente o uguale a ${bound.toIso8601String()}',
        'La data deve differire da ${bound.toIso8601String()} di almeno 1 microsecondo',
        'La data deve differire da adesso di almeno 86400000000 microsecondi',
      ]);
      expect(issues.formatFields(), {'': messages});
    });
    expect(issues.toTransport(), transport);
  });

  test('Italian covers native literals and imported contract diagnostics', () {
    final issues = [
      ...literal('tag').tryParse('other').issues,
      ...fromJsonSchema(false).tryParse(true).issues,
      ...fromJsonSchema({
        'not': {'type': 'string'},
      }).tryParse('text').issues,
      ...fromJsonSchema({
        'contains': {'type': 'boolean'},
      }).tryParse([1]).issues,
    ];
    expect(issues.map((issue) => issue.code), [
      'literal',
      'jsonSchema.false',
      'jsonSchema.not',
      'contains',
    ]);
    expect(
      issues.formatTree(catalog: AcanthisMessageCatalogs.italian).messages,
      [
        'Il valore deve essere uguale a tag',
        'Il valore non è consentito da questo contratto',
        'Il valore corrisponde a un contratto escluso',
        'La lista deve contenere almeno un elemento corrispondente',
      ],
    );
    expect(issues.last.message, 'The list must contain a matching item');
  });

  test('locale overrides snapshot normalized exact/base catalogs and preserve fallbacks', () {
    var formats = 0;
    final fallback = AcanthisMessageCatalog({
      'app.fallback': (_) => 'Catalog fallback',
    });
    final overrides = {
      ' IT_it ': AcanthisMessageCatalog({
        'required': (_) {
          formats++;
          return '';
        },
        'type': (_) => null,
      }, fallback: fallback),
      'IT': AcanthisMessageCatalog({
        'type': (_) => 'Tipo personalizzato',
        'minLength': (_) => null,
      }),
    };
    final config = AcanthisLocaleConfig.forLocale(
      'it-IT',
      overrides: overrides,
    );
    overrides.clear();
    expect(formats, 0);
    AcanthisI18n.runWith(config, () {
      expect(AcanthisIssue(path: [], code: 'required').message, '');
      expect(
        AcanthisIssue(path: [], code: 'type').message,
        'Tipo personalizzato',
      );
      expect(
        AcanthisIssue(path: [], code: 'app.fallback').message,
        'Catalog fallback',
      );
      expect(
        string().min(3).tryParse('a').issues.single.message,
        'Il valore deve contenere almeno 3 caratteri',
      );
      expect(
        AcanthisIssue(path: [], code: 'app.unknown').message,
        'app.unknown',
      );
    });
    expect(formats, 1);
    final spanish = AcanthisMessageCatalogs.forLocale(
      'es-MX',
      overrides: {
        'es': AcanthisMessageCatalog({'required': (_) => 'Obligatorio'}),
      },
    );
    expect(spanish.format('required', {}), 'Obligatorio');
    expect(spanish.resolve('app.unknown', {}), isNull);
  });

  test('malformed date metadata declines translation instead of throwing', () {
    for (final catalog in [
      AcanthisMessageCatalogs.english,
      AcanthisMessageCatalogs.italian,
    ]) {
      for (final code in ['min', 'max', 'differsFrom', 'differsFromNow']) {
        expect(catalog.resolve(code, {}), isNull);
        expect(
          catalog.resolve(code, {
            'value': 'bad',
            'fromDate': 'bad',
            'difference': 'bad',
          }),
          isNull,
        );
      }
    }
  });

  test('locale normalization and regional fallback select initial Italian messages', () {
    final issue = string().min(3).tryParse('a').issues.single;
    for (final locale in ['it', 'it-IT', ' IT_it ']) {
      final text = AcanthisI18n.runWith(
        AcanthisLocaleConfig.forLocale(locale),
        () => issue.message,
      );
      expect(text, 'Il valore deve contenere almeno 3 caratteri');
    }
    expect(issue.message, 'Value must contain at least 3 characters');
    expect(AcanthisMessageCatalogs.italian.resolve('app.unknown', {}), isNull);
    expect(
      AcanthisMessageCatalogs.italian.resolve('minLength', {'value': 'bad'}),
      isNull,
    );
  });

  test(
    'locale, schema and English fallback preserve custom application messages',
    () {
      final schema = object({'a': boolean()}).checkFields(
        ['a'],
        at: 'a',
        name: 'app.rule',
        error: 'Schema message',
        check: (_) => false,
      );
      final issue = schema.tryParse({'a': true}).issues.single;
      final italian = AcanthisLocaleConfig.forLocale('it');
      expect(
        AcanthisI18n.runWith(italian, () => issue.message),
        'Schema message',
      );
      final custom = AcanthisLocaleConfig(
        locale: 'it',
        catalog: AcanthisMessageCatalogs.italian.extend({
          'app.rule': (_) => 'Messaggio locale',
        }),
      );
      expect(
        AcanthisI18n.runWith(custom, () => issue.message),
        'Messaggio locale',
      );
      expect(
        AcanthisI18n.runWith(
          AcanthisLocaleConfig.forLocale('fr'),
          () => issue.message,
        ),
        'Schema message',
      );
      final untranslated = AcanthisIssue(path: [], code: 'upperCase');
      expect(
        AcanthisI18n.runWith(
          AcanthisLocaleConfig(
            locale: 'it',
            catalog: AcanthisMessageCatalog({}),
          ),
          () => untranslated.message,
        ),
        'Value must be uppercase',
      );
      expect(
        AcanthisI18n.runWith(
          italian,
          () => issue.formatMessage(
            catalog: AcanthisMessageCatalog({'app.rule': (_) => 'Explicit'}),
          ),
        ),
        'Explicit',
      );
    },
  );

  test('concurrent async locales, nested scopes and thrown callbacks restore settings', () async {
    final issue = AcanthisIssue(path: [], code: 'required');
    final results = await Future.wait([
      for (final locale in ['it', 'en'])
        AcanthisI18n.runWith(AcanthisLocaleConfig.forLocale(locale), () async {
          await Future<void>.delayed(Duration.zero);
          final outer = issue.message;
          AcanthisI18n.runWith(AcanthisLocaleConfig.forLocale('unknown'), () {
            expect(AcanthisI18n.current.locale, 'unknown');
          });
          expect(issue.message, outer);
          return outer;
        }),
    ]);
    expect(results, ['È richiesto un valore', 'A value is required']);
    final previous = AcanthisI18n.current;
    expect(
      () => AcanthisI18n.runWith(
        AcanthisLocaleConfig.forLocale('it'),
        () => throw StateError('failure'),
      ),
      throwsStateError,
    );
    expect(AcanthisI18n.current, same(previous));
  });

  test('application defaults can be configured and reset while explicit scopes win', () {
    final previous = AcanthisI18n.configure(
      AcanthisLocaleConfig.forLocale('it'),
    );
    try {
      expect(
        AcanthisIssue(path: [], code: 'type').message,
        'Tipo di valore non valido',
      );
      expect(
        AcanthisI18n.runWith(
          AcanthisLocaleConfig.forLocale('en'),
          () => AcanthisIssue(path: [], code: 'type').message,
        ),
        'Invalid value type',
      );
    } finally {
      AcanthisI18n.configure(previous);
    }
    expect(AcanthisI18n.current, same(previous));
  });

  test('parsing, rule evaluation, equality and transport never format translations', () {
    var formats = 0;
    final custom = AcanthisMessageCatalog({
      'mismatch': (_) {
        formats++;
        return 'Diversi';
      },
    });
    final schema = object({'a': boolean()})
        .checkFields(['a'], at: 'a', name: 'mismatch', check: (_) => false);
    final result = AcanthisI18n.runWith(
      AcanthisLocaleConfig(locale: 'it', catalog: custom),
      () {
        final result = schema.tryParse({'a': true});
        final issue = result.issues.single;
        expect(issue, AcanthisIssue(path: ['a'], code: 'mismatch'));
        issue.hashCode;
        issue.toTransport();
        expect(formats, 0);
        return result;
      },
    );
    expect(formats, 0);
    expect(result.issues.single.formatMessage(catalog: custom), 'Diversi');
    expect(formats, 1);
  });

  test(
    'nested branches and throwing errors format at the presentation boundary',
    () {
      final schema = union<Object?>([
        boolean(),
        object({'a': string()}),
      ]);
      final issue = schema.tryParse(1).issues.single;
      final transport = issue.toTransport();
      AcanthisI18n.runWith(AcanthisLocaleConfig.forLocale('it'), () {
        final json = issue.toJson();
        expect(
          json['message'],
          'Il valore non corrisponde ad alcuna alternativa',
        );
        expect(
          ((json['branches'] as List).first as List).first['message'],
          'Tipo di valore non valido',
        );
        expect(issue.toTransport(), transport);
        expect(
          () => boolean().parse(1),
          throwsA(
            isA<ValidationError>().having(
              (e) => e.message,
              'message',
              'Tipo di valore non valido',
            ),
          ),
        );
      });
    },
  );
}
