import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/validators/date.dart';
import 'package:test/test.dart';

enum _Values { first, second }

final class _Opaque extends Schema<Object?, String> {
  _Opaque(this.called);
  final void Function() called;
  @override
  String parse(Object? input) {
    called();
    return 'x';
  }

  @override
  AcanthisOutcome<String> tryParse(Object? input) {
    called();
    return const AcanthisValid('x');
  }
}

void main() {
  test(
    'native mock values are typed, reproducible and valid when reparsed',
    () {
      final schemas = <Schema<Object?, Object?>>[
        string(),
        string().min(3).max(12),
        string().exact('fixed'),
        string().email(),
        string().enumerated(
          _Values.values,
          nameTransformer: (s) => s.toUpperCase(),
        ),
        string().min(2).upperCase(),
        string().min(2).mixedCase(),
        integer().gte(-10).lte(10),
        integer().gt(0).lt(3),
        integer().gte(1000000),
        doubleType().gte(1).lte(2),
        number().between(-10, 10).multipleOf(2),
        number().integer().nonNegative(),
        number().double().negative(),
        number().enumerated([1, 2, 3]),
        integer().exact(123),
        boolean(),
        boolean().isTrue(),
        boolean().isFalse(),
        literal('tag'),
        literal(null),
        boolean().nullable(),
        boolean().nullable().withDefault(false),
        boolean().nullable().enumerated([true]),
        date().min(DateTime.utc(2020)).max(DateTime.utc(2021)),
        date()
            .min(DateTime.utc(2020, 1, 1, 0, 0, 0, 0, 1))
            .max(DateTime.utc(2020, 1, 1, 0, 0, 0, 0, 1)),
        date().max(DateTime.utc(1800)),
        date().min(DateTime.utc(2050)),
        list(string().min(1)).length(3),
        list(boolean()).length(2).unique(),
        list(string()).contains('a').length(2),
        list(string()).anyOf(['a', 'b']).length(2),
        list(string()).everyOf(['a', 'b']).length(3),
        list(boolean()).everyOf([]),
        object({'name': string().min(1), 'age': integer().positive()}),
        object({'default': boolean().withDefault(true), 'a': boolean()})
            .optionals(['default'])
            .lengthProperties(2),
        object({'a': boolean(), 'b': boolean()}).patch().lengthProperties(1),
        object({}).passthrough(type: boolean()).lengthProperties(2),
        record(string().min(1), integer()),
        tuple([string().min(2), boolean()]),
        tuple([literal('prefix'), boolean()]).variadic(),
        union<Object?>([string(), boolean()]),
        template(['prefix-', boolean()]),
        string().min(1).meta(const MetadataEntry(title: 'Metadata')),
      ];
      for (final schema in schemas) {
        for (var seed = 0; seed < 40; seed++) {
          final value = schema.mockSeeded(seed: seed);
          expect(
            schema.tryParse(value).isValid,
            isTrue,
            reason: '${schema.runtimeType}, seed $seed, $value',
          );
          expect(schema.mockSeeded(seed: seed), value);
          expect(schema.mock(seed), value);
        }
      }
      final int i = integer().mock();
      final double d = doubleType().mock();
      final List<bool> values = list(boolean()).mockSeeded();
      final Map<String, int> entries = record(string(), integer()).mockSeeded();
      expect(i, isA<int>());
      expect(d, isA<double>());
      expect(values, isA<List<bool>>());
      expect(entries, isA<Map<String, int>>());
    },
  );

  test('opaque schemas, callbacks, async operations and lazy resolvers never execute', () {
    var calls = 0;
    final opaque = _Opaque(() => calls++);
    final lazyField = lazy((_) {
      calls++;
      return string();
    });
    final schemas = <Schema<Object?, Object?>>[
      opaque,
      opaque.meta(const MetadataEntry(title: 'Opaque')),
      string().refine(
        onCheck: (_) {
          calls++;
          return true;
        },
      ),
      string().transform((v) {
        calls++;
        return v;
      }),
      string().refineAsync(
        CallbackAsyncCheck((_, _) async {
          calls++;
        }),
      ),
      boolean().transformAsync(
        CallbackAsyncTransform((v) async {
          calls++;
          return v;
        }),
      ),
      object({'x': lazyField}),
      lazyField,
      object({'x': boolean()}).checkFields(
        ['x'],
        at: 'x',
        name: 'rule',
        check: (_) {
          calls++;
          return true;
        },
      ),
      object({'x': boolean()}).addFieldDependency(
        dependent: 'x',
        dependendsOn: 'x',
        dependency: (_, _) {
          calls++;
          return true;
        },
      ),
      object({}).passthrough(type: opaque),
      union<Object?>([
        variant(
          guard: (_) {
            calls++;
            return true;
          },
          schema: boolean(),
        ),
      ]),
      date().withCheck(DiffersFromNowCheck(const Duration(days: 1))),
      literal(Object()),
      literal([1]),
    ];
    for (final schema in schemas) {
      expect(
        () => schema.mockSeeded(maxAttempts: 2),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(() => schema.mock(1), throwsA(isA<AcanthisMockException>()));
    }
    expect(calls, 0);
  });

  test(
    'contradictions and finite-domain exhaustion fail within attempt bounds',
    () {
      final schemas = <Schema<Object?, Object?>>[
        string().min(10).max(2),
        string().exact('x').min(3),
        integer().gte(10).lte(2),
        integer().gt(0).lt(1),
        integer().multipleOf(-9223372036854775808),
        boolean().isTrue().isFalse(),
        list(boolean()).length(3).unique(),
        list(string()).length(-1),
        list(string()).anyOf([]),
        object({'x': boolean()}).maxProperties(0),
        union<Object?>([]),
        string().min(100000),
      ];
      for (final schema in schemas) {
        expect(
          () => schema.mockSeeded(maxAttempts: 3),
          throwsA(
            isA<AcanthisMockException>().having(
              (e) => e.reason,
              'reason',
              isNotEmpty,
            ),
          ),
        );
      }
    },
  );

  test(
    'budgets cover schema size, generated values, defaults and recursion depth',
    () {
      expect(
        () => object({'x': string()}).mockSeeded(maxNodes: 1),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(
        () => object({
          'nested': object({'x': string()}),
        }).mockSeeded(maxDepth: 1),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(
        () => list(boolean()).length(20).mockSeeded(maxCollectionLength: 10),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(
        () => string().exact('long').mockSeeded(maxCollectionLength: 2),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(
        () => literal('long').mockSeeded(maxCollectionLength: 2),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(
        () => boolean()
            .list()
            .withDefault(List.filled(50, true))
            .mockSeeded(maxCollectionLength: 10),
        throwsA(isA<AcanthisMockException>()),
      );
      final cyclic = <Object?>[];
      cyclic.add(cyclic);
      expect(
        () => literal<Object?>(null).withDefault(cyclic).mockSeeded(),
        throwsA(isA<AcanthisMockException>()),
      );
      for (final invalid in <Object? Function()>[
        () => boolean().mockSeeded(maxAttempts: 0),
        () => boolean().mockSeeded(maxDepth: 129),
        () => boolean().mockSeeded(maxDepth: 0),
        () => boolean().mockSeeded(maxNodes: 0),
        () => boolean().mockSeeded(maxCollectionLength: 0),
      ]) {
        expect(invalid, throwsArgumentError);
      }
    },
  );

  test(
    'metadata and registry lookup do not consume randomness or change results',
    () {
      final base = object({
        'a': integer().gte(0),
        'b': list(boolean()).length(2),
      });
      final annotated = base.meta(const MetadataEntry(title: 'Object'));
      const key = SchemaKey<Map<String, Object?>, ObjectSchema>('mockable');
      final registered = (SchemaRegistryBuilder()..add(key, annotated)).build();
      for (var seed = 0; seed < 30; seed++) {
        final expected = jsonEncode(base.mockSeeded(seed: seed));
        expect(jsonEncode(annotated.mockSeeded(seed: seed)), expected);
        expect(
          jsonEncode(registered.get(key).mockSeeded(seed: seed)),
          expected,
        );
      }
      final signal = AcanthisCancellationSignal();
      AcanthisValidationScope(cancellation: signal).run(() {
        signal.cancel();
        expect(
          () => base.mockSeeded(),
          throwsA(isA<AcanthisValidationCancelled>()),
        );
      });
    },
  );
}
