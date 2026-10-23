import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _Opaque extends Schema<Object?, String> {
  const _Opaque();
  @override
  String parse(Object? input) => tryParse(input).value;
  @override
  AcanthisOutcome<String> tryParse(Object? input) => input is String
      ? AcanthisValid(input)
      : AcanthisInvalid.withoutValue(const []);
}

final class _Name {
  const _Name(this.value);
  final String value;
}

void main() {
  test(
    'nested pipelines preserve typed output and convert each input once',
    () {
      var first = 0, second = 0;
      final child = string()
          .exact('42')
          .pipe(
            integer(),
            transform: (s) {
              first++;
              return int.parse(s);
            },
          )
          .pipe(
            string(),
            transform: (i) {
              second++;
              return 'answer:$i';
            },
          );
      final schema = object({
        'list': list(child).length(3),
        'tuple': tuple([child]),
        'extra': object({}).passthrough(type: child).lengthProperties(1),
      });
      expect(schema.mockSeeded(), {
        'list': ['answer:42', 'answer:42', 'answer:42'],
        'tuple': ['answer:42'],
        'extra': {'extra_0': 'answer:42'},
      });
      expect([first, second], [5, 5]);
      expect(list(child).length(1).mockSeeded(), isA<List<String>>());

      final key = string().min(1).pipe(integer(), transform: (s) => s.length);
      final entries = record(key, child).mockSeeded(seed: 42);
      expect(entries, isA<Map<int, String>>());
      expect(entries.values, everyElement('answer:42'));
      expect(child.nullable().list().mockSeeded(), isA<List<String?>>());
    },
  );

  test(
    'nested output inspection never reruns converters in union containers',
    () {
      var calls = 0;
      final child = string()
          .exact('Ada')
          .pipe(
            instance<_Name>().field('value', (v) => v.value, string().min(1)),
            transform: (s) {
              calls++;
              return _Name(s);
            },
          );
      final schema = union<Object?>([
        object({'names': list(child).length(2)}),
        boolean(),
      ]);
      for (var seed = 0; seed < 20; seed++) {
        calls = 0;
        final sample = schema.mockSeeded(seed: seed);
        if (sample is Map) {
          expect((sample['names'] as List).map((n) => (n as _Name).value), [
            'Ada',
            'Ada',
          ]);
          expect(calls, 2);
        } else {
          expect(calls, 0);
        }
      }
      final oversized = string()
          .exact('Ada')
          .pipe(
            instance<_Name>().field('value', (v) => v.value, string()),
            transform: (_) => _Name('x' * 257),
          );
      expect(
        () => union<Object?>([
          object({'name': oversized}),
        ]).mockSeeded(seed: 0),
        throwsA(isA<AcanthisMockException>()),
      );
      final ambiguous = string().pipe(
        union<_Name>([
          instance<_Name>(),
          instance<_Name>().field('value', (v) => v.value, string()),
        ]),
        transform: (_) => _Name('x' * 257),
      );
      expect(
        () => ambiguous.mockSeeded(),
        throwsA(isA<AcanthisMockException>()),
      );
    },
  );

  test('nested invalid outputs share the outer retry limit', () {
    var calls = 0;
    final child = string()
        .exact('x')
        .pipe(
          integer().gte(1),
          transform: (_) {
            calls++;
            return 0;
          },
        );
    expect(
      () => object({'value': list(child).length(1)}).mockSeeded(maxAttempts: 3),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(calls, 3);
    calls = 0;
    final async = string()
        .pipe(integer(), transform: (_) => ++calls)
        .refineAsync(
          CallbackAsyncCheck((_, _) async {
            calls++;
          }),
        );
    expect(
      () => list(async).mockSeeded(),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(calls, 0);
  });

  test('common formats are seeded, validated and length bounded', () {
    final schemas = [
      string().uuid(),
      string().uuid().length(36),
      string().url(),
      string().url().min(25).max(30),
      string().uri(),
      string().dateTime(),
      string().base64(),
      string().base64().length(12),
      string().email().length(13),
    ];
    for (final schema in schemas) {
      final samples = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final sample = schema.mockSeeded(seed: seed);
        expect(schema.validate(sample), isTrue, reason: sample);
        expect(schema.mockSeeded(seed: seed), sample);
        expect(sample.length, lessThanOrEqualTo(256));
        samples.add(sample);
      }
      expect(samples.length, greaterThan(1));
    }
    expect(
      base64Decode(string().base64().length(12).mockSeeded()).length,
      inInclusiveRange(7, 9),
    );
    for (final schema in [
      string().uuid(),
      string().dateTime(),
      string().url(),
      string().base64().min(12),
    ]) {
      expect(
        () => schema.mockSeeded(maxCollectionLength: 8),
        throwsA(isA<AcanthisMockException>()),
      );
    }
    expect(
      () => string().base64().length(5).mockSeeded(maxAttempts: 2),
      throwsA(isA<AcanthisMockException>()),
    );
  });

  test(
    'explicit generators use the shared seeded stream and validate raw inputs',
    () {
      final code = string().pattern(RegExp(r'^SKU-\d{3}$'));
      final schema = object({'codes': list(code).length(3)});
      final generators = <Schema<Object?, Object?>, AcanthisMockGenerator>{
        code: (random) => 'SKU-${100 + random.nextInt(900)}',
      };
      final sample = schema.mockSeeded(seed: 42, generators: generators);
      expect(schema.validate(sample), isTrue);
      expect(schema.mockSeeded(seed: 42, generators: generators), sample);
      expect(
        schema.mockSeeded(seed: 43, generators: generators),
        isNot(sample),
      );
      expect(() => schema.mockSeeded(), throwsA(isA<AcanthisMockException>()));

      const custom = _Opaque();
      expect(
        custom.mockSeeded(generators: {custom: (_) => 'custom'}),
        'custom',
      );
      final converted = code.pipe(
        integer(),
        transform: (s) => int.parse(s.substring(4)),
      );
      expect(
        list(converted)
            .length(1)
            .mockSeeded(generators: {code: (_) => 'SKU-123'}),
        [123],
      );
      expect(
        converted.mockSeeded(generators: {converted: (_) => 'SKU-123'}),
        123,
      );
      final transformed = string().transform((s) => s.length.toString());
      expect(
        transformed.mockSeeded(generators: {transformed: (_) => 'Ada'}),
        '3',
      );
    },
  );

  test('explicit subtrees validate rules and guards once, without mutating schemas', () {
    var calls = 0;
    final guarded = union<String>([
      variant(
        guard: (_) {
          calls++;
          return true;
        },
        schema: string(),
      ),
    ]);
    final schema = object({'code': guarded}).checkFields(
      ['code'],
      at: 'code',
      name: 'code',
      check: (_) {
        calls++;
        return true;
      },
    );
    expect(
      schema.mockSeeded(
        generators: {
          schema: (_) => {'code': 'x'},
        },
      ),
      {'code': 'x'},
    );
    expect(calls, 2);
    expect(() => schema.mockSeeded(), throwsA(isA<AcanthisMockException>()));
    expect(calls, 2);

    final code = string().pattern(RegExp('x'));
    final generators = <Schema<Object?, Object?>, AcanthisMockGenerator>{};
    generators[code] = (_) {
      generators.clear();
      return 'x';
    };
    expect(list(code).length(3).mockSeeded(generators: generators), [
      'x',
      'x',
      'x',
    ]);
    expect(generators, isEmpty);
    expect(
      () => code.max(5).mockSeeded(generators: {code: (_) => 'x'}),
      throwsA(isA<AcanthisMockException>()),
    );
  });

  test(
    'generator failures, cancellation and retry budgets remain explicit',
    () {
      var calls = 0;
      final schema = string().pattern(RegExp(r'^ok$'));
      expect(
        () => schema.mockSeeded(
          maxAttempts: 3,
          generators: {
            schema: (_) {
              calls++;
              return 'bad';
            },
          },
        ),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(calls, 3);
      calls = 0;
      expect(
        schema.mockSeeded(
          maxAttempts: 3,
          generators: {schema: (_) => ++calls == 3 ? 'ok' : 'bad'},
        ),
        'ok',
      );
      expect(calls, 3);
      expect(
        () => schema.mockSeeded(
          generators: {schema: (_) => throw StateError('provider')},
        ),
        throwsStateError,
      );
      final signal = AcanthisCancellationSignal();
      expect(
        () => AcanthisValidationScope(cancellation: signal).run(
          () => schema.mockSeeded(
            generators: {
              schema: (_) {
                signal.cancel();
                return 'ok';
              },
            },
          ),
        ),
        throwsA(isA<AcanthisValidationCancelled>()),
      );
    },
  );

  test('preflight rejects unsupported siblings before calling generators', () {
    var calls = 0;
    final code = string().pattern(RegExp('x'));
    final bad = string().refine(
      onCheck: (_) {
        calls++;
        return true;
      },
    );
    expect(
      () => object({'code': code, 'bad': bad}).mockSeeded(
        generators: {
          code: (_) {
            calls++;
            return 'x';
          },
        },
      ),
      throwsA(isA<AcanthisMockException>()),
    );
    final async = code.refineAsync(
      CallbackAsyncCheck((_, _) async {
        calls++;
      }),
    );
    expect(
      () => async.mockSeeded(
        generators: {
          async: (_) {
            calls++;
            return 'x';
          },
        },
      ),
      throwsA(isA<AcanthisMockException>()),
    );
    final lazyChild = lazy((_) {
      calls++;
      return string();
    });
    final recursive = object({'child': lazyChild});
    expect(
      () => recursive.mockSeeded(
        generators: {
          recursive: (_) {
            calls++;
            return {'child': 'x'};
          },
        },
      ),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(calls, 0);
  });

  test(
    'generator candidates are audited before validation and outputs after it',
    () {
      var checks = 0;
      final schema = list(string()).refine(
        onCheck: (_) {
          checks++;
          return true;
        },
      );
      final cyclic = <Object?>[];
      cyclic.add(cyclic);
      for (final candidate in [
        List.filled(257, 'x'),
        ['x' * 257],
        cyclic,
      ]) {
        expect(
          () => schema.mockSeeded(generators: {schema: (_) => candidate}),
          throwsA(isA<AcanthisMockException>()),
        );
      }
      expect(checks, 0);
      final mapped = string().transform((_) => 'x' * 257);
      expect(
        () => mapped.mockSeeded(generators: {mapped: (_) => 'x'}),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(
        () => list(schema).mockSeeded(
          maxNodes: 1,
          generators: {
            schema: (_) {
              checks++;
              return ['x'];
            },
          },
        ),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(checks, 0);
    },
  );
}
