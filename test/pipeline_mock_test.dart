import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _User {
  const _User(this.name, this.age);
  final String name;
  final int age;
}

ClassSchemaBuilder<Map<String, Object?>, _User> _builder() =>
    classSchema<Map<String, Object?>, _User>()
        .input(
          object({
            'name': string().min(1).max(12),
            'age': integer().gte(18).lte(80),
          }),
        )
        .map((f) => _User(f['name'] as String, f['age'] as int));

void main() {
  test('class mocks use the mapper without needing an instance factory', () {
    final schema = _builder().build();
    final _User sample = schema.mock();
    expect(sample.age, inInclusiveRange(18, 80));
    final Schema<Object?, _User> widened = schema;
    for (var seed = 0; seed < 20; seed++) {
      final first = schema.mockSeeded(seed: seed);
      final second = widened.mock(seed);
      expect([first.name, first.age], [second.name, second.age]);
    }
  });

  test(
    'mocking validates the mapped output and retries within one attempt budget',
    () {
      var maps = 0;
      final schema = _builder()
          .map((f) {
            maps++;
            return _User(f['name'] as String, f['age'] as int);
          })
          .validateWith(
            instance<_User>().field('age', (u) => u.age, integer().gte(40)),
          )
          .refine(onCheck: (u) => u.age >= 50, name: 'adult')
          .build();
      final sample = schema.mockSeeded(seed: 42, maxAttempts: 64);
      expect(sample.age, greaterThanOrEqualTo(50));
      expect(maps, inInclusiveRange(1, 64));
      var invalidCalls = 0;
      final invalid = _builder()
          .map((f) {
            invalidCalls++;
            return const _User('Wrong', 1);
          })
          .validateWith(
            instance<_User>().field('age', (u) => u.age, integer().gte(18)),
          )
          .build();
      expect(
        () => invalid.mockSeeded(maxAttempts: 3),
        throwsA(isA<AcanthisMockException>()),
      );
      expect(invalidCalls, 3);
    },
  );

  test('chained pipelines convert each parsed source exactly once', () {
    var first = 0, second = 0, output = 0, root = 0;
    final source = string()
        .exact('42')
        .pipe(
          integer(),
          transform: (s) {
            first++;
            return int.parse(s);
          },
        );
    final schema = source
        .pipe(
          string().refine(
            onCheck: (_) {
              output++;
              return true;
            },
          ),
          transform: (i) {
            second++;
            return 'age:$i';
          },
        )
        .transform((s) {
          root++;
          return s.toUpperCase();
        });
    expect(schema.mockSeeded(), 'AGE:42');
    expect([first, second, output, root], [1, 1, 1, 1]);
  });

  test('output inspection does not rerun converters inside union branches', () {
    var maps = 0;
    final child = classSchema<String, _User>().input(string().exact('Ada')).map(
      (name) {
        maps++;
        return _User(name, 21);
      },
    ).build();
    final schema = string()
        .exact('Ada')
        .pipe(union<Object?>([child, boolean()]), transform: (s) => s);
    expect(schema.mockSeeded(), isA<_User>());
    expect(maps, 1);
  });

  test('invalid generated inputs never reach the mapper', () {
    var calls = 0;
    final schema = string()
        .exact('x')
        .min(2)
        .pipe(
          integer(),
          transform: (s) {
            calls++;
            return s.length;
          },
        );
    expect(
      () => schema.mockSeeded(maxAttempts: 3),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(calls, 0);
  });

  test('mapper format failures retry, while programming errors propagate', () {
    var calls = 0;
    final format = string()
        .exact('bad')
        .pipe(
          integer(),
          transform: (s) {
            calls++;
            return int.parse(s);
          },
        );
    expect(
      () => format.mockSeeded(maxAttempts: 3),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(calls, 3);
    final bad = string().pipe(
      integer(),
      transform: (s) => throw StateError('mapper'),
    );
    expect(() => bad.mock(), throwsStateError);
  });

  test('output bounds inspect actual described class fields', () {
    final schema = _builder()
        .map((f) => _User('x' * 257, 21))
        .validateWith(instance<_User>().field('name', (u) => u.name, string()))
        .build();
    expect(
      () => schema.mockSeeded(maxCollectionLength: 256),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(
      () => _builder().build().mockSeeded(maxNodes: 1),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(
      () => _builder().build().mockSeeded(maxDepth: 1),
      throwsA(isA<AcanthisMockException>()),
    );
  });

  test(
    'opaque input checks and async stages fail before invoking the mapper',
    () {
      var calls = 0;
      final opaque = string()
          .refine(
            onCheck: (_) {
              calls++;
              return true;
            },
          )
          .pipe(
            integer(),
            transform: (s) {
              calls++;
              return s.length;
            },
          );
      expect(() => opaque.mockSeeded(), throwsA(isA<AcanthisMockException>()));
      final async = string().pipe(
        integer().refineAsync(
          CallbackAsyncCheck((v, c) async {
            calls++;
          }),
        ),
        transform: (s) {
          calls++;
          return s.length;
        },
      );
      expect(() => async.mockSeeded(), throwsA(isA<AcanthisMockException>()));
      expect(calls, 0);
    },
  );

  test('operation budgets reject pipelines before running callbacks', () {
    var calls = 0;
    int convert(String value) {
      calls++;
      return value.length;
    }

    var outputChecks = integer();
    var outputTransforms = integer();
    var rootChecks = string().pipe(integer(), transform: convert);
    var rootTransforms = string().pipe(integer(), transform: convert);
    for (var i = 0; i < 6; i++) {
      outputChecks = outputChecks.refine(onCheck: (_) => ++calls > 0);
      outputTransforms = outputTransforms.transform((v) => v + ++calls);
      rootChecks = rootChecks.refine(onCheck: (_) => ++calls > 0);
      rootTransforms = rootTransforms.transform((v) => v + ++calls);
    }
    for (final schema in [
      string().pipe(outputChecks, transform: convert),
      string().pipe(outputTransforms, transform: convert),
      rootChecks,
      rootTransforms,
    ]) {
      expect(
        () => schema.mockSeeded(maxNodes: 5),
        throwsA(isA<AcanthisMockException>()),
      );
    }
    expect(calls, 0);
  });

  test('cancellation after construction stops output checks', () {
    var outputCalls = 0;
    final signal = AcanthisCancellationSignal();
    final schema = string().pipe(
      integer().refine(
        onCheck: (_) {
          outputCalls++;
          return true;
        },
      ),
      transform: (s) {
        signal.cancel();
        return s.length;
      },
    );
    expect(
      () =>
          AcanthisValidationScope(cancellation: signal)
              .run(() => schema.mockSeeded()),
      throwsA(isA<AcanthisValidationCancelled>()),
    );
    expect(outputCalls, 0);
  });

  test('class defaults and metadata do not replace generated samples', () {
    var maps = 0;
    final schema = _builder()
        .map((f) {
          maps++;
          return _User(f['name'] as String, f['age'] as int);
        })
        .defaultOutput(const _User('Default', 0))
        .build()
        .meta(const MetadataEntry(title: 'User'));
    expect(schema.mockSeeded().age, greaterThanOrEqualTo(18));
    expect(maps, 1);
    expect(schema.metadataEntry!.title, 'User');
  });
}
