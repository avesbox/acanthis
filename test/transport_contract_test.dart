import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'native length diagnostics retain the V1 version 1 wire shape',
    () async {
      for (final (schema, input, code, english, italian) in [
        (string().min(3), 'x', 'minLength', 'at least', 'almeno'),
        (string().max(3), 'longer', 'maxLength', 'at most', 'al massimo'),
        (string().length(3), 'x', 'exactLength', 'exactly', 'esattamente'),
      ]) {
        final nested = object({'values': list(schema)});
        final data = {
          'values': <String>[input],
        };
        final fixture = {
          'version': 1,
          'issues': [
            {
              'path': ['values', 0],
              'code': code,
              'parameters': {'value': 3},
            },
          ],
        };
        for (final result in [
          nested.tryParse(data),
          await nested.tryParseAsync(data),
        ]) {
          expect(result.issues.toTransport(), fixture);
          expect(jsonDecode(jsonEncode(result.issues.toTransport())), fixture);
          final issue = result.issues.single;
          expect(issue.message, 'Value must contain $english 3 characters');
          expect(
            issue.formatMessage(catalog: AcanthisMessageCatalogs.italian),
            'Il valore deve contenere $italian 3 caratteri',
          );
          AcanthisI18n.runWith(AcanthisLocaleConfig.forLocale('it'), () {
            expect(
              issue.message,
              'Il valore deve contenere $italian 3 caratteri',
            );
            expect(result.issues.toTransport(), fixture);
          });
        }
        expect(schema.tryParse(input).issues.single.toTransport(), {
          'path': <Object>[],
          'code': code,
          'parameters': {'value': 3},
        });
      }
    },
  );

  test(
    'imported string length diagnostics use the same value parameter',
    () async {
      for (final (code, input) in [
        ('minLength', 'x'),
        ('maxLength', 'longer'),
      ]) {
        final native = code == 'minLength' ? string().min(3) : string().max(3);
        final imported = fromJsonSchema({'type': 'string', code: 3});
        final expected = native.tryParse(input).issues.toTransport();
        expect(imported.tryParse(input).issues.toTransport(), expected);
        expect(
          (await imported.tryParseAsync(input)).issues.toTransport(),
          expected,
        );
        expect(
          imported.tryParse(input).issues.single.message,
          native.tryParse(input).issues.single.message,
        );
      }
    },
  );
}
