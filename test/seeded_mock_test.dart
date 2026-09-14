import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'documented subset is repeatable and every returned value validates',
    () {
      final schemas = <AcanthisType>[
        literal('fixed'),
        string().min(3).max(12),
        string().email(),
        string().exact('fixed'),
        integer().gte(-10).lte(10),
        doubleType().gte(1).lte(2),
        boolean(),
        string().min(1).nullable(),
        string().min(1).list().length(3),
        tuple([string().min(2), integer()]),
        object({
          'a/b': string().min(1),
          '0': integer().gte(0),
          'optional': string().nullable(),
        }),
      ];
      for (final schema in schemas) {
        for (var seed = 0; seed < 100; seed++) {
          final value = schema.mockSeeded(seed: seed);
          expect(schema.tryParse(value).success, isTrue);
          expect(schema.mockSeeded(seed: seed), value);
        }
      }
    },
  );
  test(
    'contradictions, opaque callbacks and resource limits explain failure',
    () {
      var calls = 0;
      final opaque = string().refine(
        onCheck: (_) {
          calls++;
          return false;
        },
        error: 'no',
        name: 'opaque',
      );
      for (final schema in <AcanthisType>[
        string().min(10).max(2),
        integer().gte(10).lte(2),
        string().exact('x').min(3),
        opaque,
        string().transform((s) {
          calls++;
          return s;
        }),
        string().min(100000),
        boolean().list().length(3).unique(),
      ]) {
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
      expect(calls, 0);
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
    },
  );
  test('legacy finite domains no longer spin indefinitely', () {
    expect(boolean().list().length(4).mock(0), hasLength(4));
    expect(
      () => boolean().list().length(4).unique().mock(0),
      throwsA(isA<AcanthisMockException>()),
    );
  });
}
