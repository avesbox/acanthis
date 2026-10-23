import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'pretty JSON exports the same contract with configurable mode and spacing',
    () {
      final schema = object({'enabled': boolean().withDefault(true)});
      for (final mode in AcanthisSchemaMode.values) {
        for (final indent in [0, 2, 4]) {
          final pretty = schema.toPrettyJsonSchema(indent: indent, mode: mode);
          expect(jsonDecode(pretty), schema.toJsonSchema(mode: mode));
          expect(
            pretty,
            JsonEncoder.withIndent(' ' * indent)
                .convert(schema.toJsonSchema(mode: mode)),
          );
        }
      }
      expect(jsonDecode(schema.toPrettyJsonSchema()), schema.toJsonSchema());
      expect(() => schema.toPrettyJsonSchema(indent: -1), throwsArgumentError);
    },
  );

  test(
    'pretty export preserves native export failures without invoking callbacks',
    () {
      var calls = 0;
      final schema = object({
        'a/b~': string().refine(
          onCheck: (_) {
            calls++;
            return true;
          },
        ),
      });
      expect(
        () => schema.toPrettyJsonSchema(),
        throwsA(
          isA<AcanthisSchemaExportException>().having(
            (e) => e.path,
            'path',
            '/properties/a~1b~0',
          ),
        ),
      );
      expect(calls, 0);
    },
  );

  test('public issue constants cover actual V2 diagnostic codes', () {
    final cases = <(Schema<Object?, Object?>, Object?)>[
      (string().min(3), 'x'),
      (integer().gte(1), 0),
      (boolean().isTrue(), false),
      (literal('expected'), 'other'),
      (object({'required': string()}), {}),
      (object({}).unknownKeys(AcanthisUnknownKeys.reject), {'extra': 1}),
      (list(string()).contains('required'), <String>[]),
      (record(string().toLowerCase(), boolean()), {'A': true, 'a': false}),
      (importJsonSchema(false), 'anything'),
      (importJsonSchema({'not': <String, Object?>{}}), 'anything'),
    ];
    final actual = <String>{};
    for (final (schema, input) in cases) {
      final result = schema.tryParse(input);
      expect(result.isValid, isFalse);
      for (final issue in result.issues) {
        actual.add(issue.code);
        expect(AcanthisIssueCodes.values, contains(issue.code));
      }
    }
    expect(
      actual,
      containsAll([
        AcanthisIssueCodes.minLength,
        AcanthisIssueCodes.gte,
        AcanthisIssueCodes.isTrue,
        AcanthisIssueCodes.literal,
        AcanthisIssueCodes.required,
        AcanthisIssueCodes.unknownKey,
        AcanthisIssueCodes.containsItem,
        AcanthisIssueCodes.duplicateKey,
        AcanthisIssueCodes.jsonSchemaFalse,
        AcanthisIssueCodes.jsonSchemaNot,
      ]),
    );
  });

  test(
    'legacy code names remain available and custom application codes stay open',
    () {
      const legacy = [
        AcanthisIssueCodes.doubleType,
        AcanthisIssueCodes.contains,
        AcanthisIssueCodes.passthrough,
        AcanthisIssueCodes.date,
        AcanthisIssueCodes.differsFromNow,
        AcanthisIssueCodes.templateLiteral,
      ];
      expect(legacy, [
        'double',
        'contains',
        'passthrough',
        'date',
        'differsFromNow',
        'templateLiteral',
      ]);
      final issue = string()
          .refine(onCheck: (_) => false, name: 'app.rule')
          .tryParse('x')
          .issues
          .single;
      expect(issue.code, 'app.rule');
      expect(AcanthisIssueCodes.values, isNot(contains(issue.code)));
    },
  );
}
