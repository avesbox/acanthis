import 'support/parse_result.dart';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/acanthis.dart' as acanthis;
import 'package:acanthis/src/common/issue_sink.dart';
import 'package:test/test.dart';

void main() {
  test(
    'the requested named number refinement works through every entry point',
    () async {
      final number = acanthis.number().refine(
        onCheck: (value) => value == 1,
        error: 'Value must be 1',
        name: 'custom',
      );
      for (final input in [1, 2]) {
        for (final result in [
          number.parseResult(input),
          number.tryParse(input),
          await number.parseResultAsync(input),
          await number.tryParseAsync(input),
        ]) {
          expect(result.isValid, input == 1);
          expect(result.value, input);
          if (input == 2) {
            final issue = result.issues.single;
            expect(issue.code, 'custom');
            expect(issue.message, 'Value must be 1');
            expect(issue.parameters, isEmpty);
            expect(issue.toJson()['message'], 'Value must be 1');
            expect(issue.toTransport(), {
              'path': <Object>[],
              'code': 'custom',
              'parameters': <String, Object?>{},
            });
          }
        }
      }
    },
  );

  test(
    'named refinements retain concrete types, coercion and fluent settings',
    () {
      final AcanthisInt whole = integer()
          .coerce()
          .withDefault(1)
          .refine(onCheck: (value) => value.isOdd)
          .positive();
      final AcanthisDouble decimal = doubleType()
          .refine(onCheck: (value) => value.ceilToDouble() == value)
          .finite();
      final AcanthisString text = string()
          .trim()
          .refine(onCheck: (value) => value.startsWith('a'))
          .min(1);
      expect(whole.parseResult('1').value, 1);
      expect(whole.parseResult(null).value, 1);
      expect(whole.parseResult(2).issues.single.message, 'Invalid value');
      expect(decimal.parseResult(1.0).isValid, isTrue);
      expect(decimal.parseResult(1.5).isValid, isFalse);
      expect(text.parseResult(' abc ').value, 'abc');
      expect(text.parseResult('b').isValid, isFalse);
      expect(() => text.checks.clear(), throwsUnsupportedError);
      final CheckableSchema<num, num> abstraction = number();
      expect(
        abstraction
            .refine(onCheck: (value) => value == 1)
            .parseResult(1)
            .isValid,
        isTrue,
      );
      expect(
        abstraction
            .withCheck(PredicateCheck((value) => value == 1))
            .parseResult(2)
            .isValid,
        isFalse,
      );
    },
  );

  test(
    'check catalogs are isolated, localizable and preserved when prefixed',
    () async {
      final first = number().refine(
        onCheck: (_) => false,
        error: 'First',
        name: 'gte',
      );
      final second = number().refine(
        onCheck: (_) => false,
        error: 'Second',
        name: 'gte',
      );
      final results = await Future.wait([
        first.tryParseAsync(1),
        second.tryParseAsync(1),
      ]);
      expect(results.map((r) => r.issues.single.message), ['First', 'Second']);
      expect(
        number().gte(2).parseResult(1).issues.single.message,
        'Value must be greater than or equal to 2',
      );
      final issue = results.first.issues.single;
      final localized = AcanthisMessageCatalog({'gte': (_) => 'Deve essere 1'});
      expect(issue.formatMessage(catalog: localized), 'Deve essere 1');
      expect(issue.message, 'First');
      final child = IssueSink.fromIssues([issue]);
      final parent = IssueSink()..addChild('field', child);
      final prefixed = parent.issues.single;
      expect(prefixed.path, ['field']);
      expect(prefixed.message, 'First');
      expect(prefixed.toJson(catalog: localized)['message'], 'Deve essere 1');
      final equal = AcanthisIssue(path: ['field'], code: 'gte');
      expect(prefixed, equal);
      expect(prefixed.hashCode, equal.hashCode);
    },
  );

  test(
    'refinement ordering, fail-fast and transformation gating stay intact',
    () {
      var calls = 0;
      var transformed = false;
      final schema = integer()
          .gte(10)
          .refine(
            onCheck: (value) {
              calls++;
              return value == 1;
            },
            name: 'one',
            error: 'One only',
          )
          .lte(0)
          .withTransform(
            CallbackTransform((value) {
              transformed = true;
              return value;
            }),
          );
      expect(schema.parseResult(5).issues.map((i) => i.code), ['gte']);
      expect(calls, 0);
      final result = schema.tryParse(5);
      expect(result.issues.map((i) => i.code), ['gte', 'one', 'lte']);
      expect(result.issues[1].message, 'One only');
      expect(calls, 1);
      expect(transformed, isFalse);
      expect(result.value, 5);
      schema.parseResult('5');
      expect(calls, 1);
    },
  );

  test(
    'predicate exceptions propagate and definition does not execute callbacks',
    () async {
      var calls = 0;
      final failure = StateError('predicate failed');
      final schema = number().refine(
        onCheck: (_) {
          calls++;
          throw failure;
        },
      );
      expect(schema.checks, hasLength(1));
      expect(calls, 0);
      expect(() => schema.parseResult(1), throwsA(same(failure)));
      await expectLater(schema.tryParseAsync(1), throwsA(same(failure)));
      expect(calls, 2);
    },
  );

  test(
    'omitting error uses code lookup and an empty name normalizes to custom',
    () {
      final issue = number()
          .refine(onCheck: (_) => false, name: 'app.one')
          .parseResult(2)
          .issues
          .single;
      expect(issue.message, 'app.one');
      expect(
        issue.formatMessage(
          catalog: AcanthisMessageCatalog({'app.one': (_) => 'One'}),
        ),
        'One',
      );
      final empty = number()
          .refine(onCheck: (_) => false, name: '', error: 'Failed')
          .parseResult(2)
          .issues
          .single;
      expect(empty.code, 'custom');
      expect(empty.message, 'Failed');
    },
  );
}
