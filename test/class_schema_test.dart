import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

class _User {
  const _User(this.name, this.age);
  final String name;
  final int age;
}

class _CustomOutput extends Schema<Object?, _User> {
  @override
  _User parse(Object? input) => tryParse(input).valueOrThrow;
  @override
  AcanthisOutcome<_User> tryParse(Object? input) => input is _User
      ? AcanthisValid(input)
      : AcanthisInvalid<_User>.withoutValue([
          AcanthisIssue(path: [], code: 'type'),
        ]);
}

ClassSchemaBuilder<Map<String, Object?>, _User> _builder() =>
    classSchema<Map<String, Object?>, _User>()
        .input(
          object({'name': string().trim().min(1), 'age': integer().gte(0)}),
        )
        .map((p) => _User(p['name'] as String, p['age'] as int));

void main() {
  test('build requires input and mapper', () {
    expect(
      () => classSchema<String, _User>().build(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('input()'),
        ),
      ),
    );
    expect(
      () => classSchema<String, _User>().input(string()).build(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('map()'),
        ),
      ),
    );
  });

  test(
    'default output validator supports raw parsing and boolean validation',
    () async {
      final AcanthisPipeline<Map<String, Object?>, _User> schema = _builder()
          .build();
      final _User user = schema.parse({'name': ' Ada ', 'age': 21});
      expect(user.name, 'Ada');
      expect(user.age, 21);
      expect(schema.validate({'name': '', 'age': 21}), isFalse);
      expect(await schema.validateAsync({'name': 'Ada', 'age': 21}), isTrue);
    },
  );

  test(
    'output fields and refinements retain typed recovery and issue paths',
    () async {
      final schema = _builder()
          .validateWith(
            instance<_User>()
                .field('name', (u) => u.name, string().min(2))
                .field('age', (u) => u.age, integer()),
          )
          .refine(
            onCheck: (u) => u.age >= 18,
            name: 'adult',
            error: 'Must be an adult',
          )
          .build();
      for (final async in [false, true]) {
        final result = async
            ? await schema.tryParseAsync({'name': 'A', 'age': 16})
            : schema.tryParse({'name': 'A', 'age': 16});
        expect(result, isA<AcanthisInvalid<_User>>());
        expect(result.value.name, 'A');
        expect(result.issues.map((i) => i.code), ['minLength', 'adult']);
        expect(result.issues.map((i) => i.path), [
          ['name'],
          [],
        ]);
        expect(result.issues.last.message, 'Must be an adult');
      }
    },
  );

  test(
    'invalid input never calls the mapper or fabricates default recovery',
    () async {
      var calls = 0;
      final schema = classSchema<String, _User>()
          .input(string().min(2))
          .map((name) {
            calls++;
            return _User(name, 21);
          })
          .defaultOutput(const _User('Fallback', 30))
          .build();
      for (final input in ['x', 1]) {
        final result = schema.tryParse(input) as AcanthisInvalid<_User>;
        expect(result.hasValue, isFalse);
        final async =
            await schema.tryParseAsync(input) as AcanthisInvalid<_User>;
        expect(async.hasValue, isFalse);
      }
      expect(calls, 0);
    },
  );

  test('default outputs bypass mapping but still validate', () async {
    var calls = 0;
    const fallback = _User('Fallback', 30);
    final builder = Acanthis.classSchema<String, _User>()
        .input(string())
        .map((name) {
          calls++;
          return _User(name, 21);
        })
        .validateWith(
          instance<_User>().field('age', (u) => u.age, integer().gte(18)),
        )
        .defaultOutput(fallback);
    final schema = builder.build();
    expect(schema.parse(null), same(fallback));
    expect(await schema.parseAsync(null), same(fallback));
    expect(object({'user': schema}).parse({})['user'], same(fallback));
    expect(calls, 0);
    final invalid = builder.defaultOutput(const _User('Young', 1)).build();
    expect(invalid.tryParse(null).issues.single.path, ['age']);
  });

  test(
    'explicit null defaults and nullable output types remain precise',
    () async {
      final schema = classSchema<String, _User?>()
          .input(string())
          .map((name) => _User(name, 21))
          .defaultOutput(null)
          .build();
      final _User? output = schema.parse(null);
      expect(output, isNull);
      expect(await schema.parseAsync(null), isNull);
      expect(object({'user': schema}).parse({}), {'user': null});
    },
  );

  test('built pipelines snapshot every mutable builder setting', () {
    final builder = classSchema<String, String>()
        .input(string())
        .map((v) => '${v}1')
        .validateWith(string().min(2))
        .defaultOutput('default');
    final built = builder.build();
    builder
        .input(string().min(10))
        .map((v) => '${v}2')
        .validateWith(string().min(20))
        .defaultOutput('new');
    expect(built.parse('a'), 'a1');
    expect(built.parse(null), 'default');
    expect(builder.build().validate('a'), isFalse);
  });

  test('validateWith replaces previous output refinements as in V1', () {
    final schema = classSchema<String, String>()
        .input(string())
        .map((v) => v)
        .refine(onCheck: (_) => false, name: 'replaced')
        .validateWith(string())
        .refine(onCheck: (_) => false, name: 'current')
        .build();
    expect(schema.tryParse('ok').issues.single.code, 'current');
  });

  test('third-party output schemas support subsequent refinements', () async {
    final schema = _builder()
        .validateWith(_CustomOutput())
        .refine(onCheck: (u) => u.age >= 18, name: 'adult')
        .build();
    expect(
      schema.tryParse({'name': 'Ada', 'age': 17}).issues.single.code,
      'adult',
    );
    expect(await schema.validateAsync({'name': 'Ada', 'age': 21}), isTrue);
  });

  test(
    'async input and output stages retain context and execution order',
    () async {
      final order = <String>[];
      final schema = classSchema<String, _User>()
          .input(
            string().refineAsync(
              CallbackAsyncCheck((v, c) async {
                order.add('input:${c.contextAs<String>()}');
              }),
            ),
          )
          .map((name) {
            order.add('map');
            return _User(name, 21);
          })
          .validateWith(
            instance<_User>().field(
              'name',
              (u) => u.name,
              string().refineAsync(
                CallbackAsyncCheck((v, c) async {
                  order.add('output:${c.contextAs<String>()}');
                }),
              ),
            ),
          )
          .build();
      expect(schema.isAsync, isTrue);
      expect(() => schema.parse('Ada'), throwsStateError);
      final user = await const AcanthisValidationScope(context: 'tenant')
          .run(() => schema.parseAsync('Ada'));
      expect(user.name, 'Ada');
      expect(order, ['input:tenant', 'map', 'output:tenant']);
    },
  );

  test(
    'cancellation after mapping prevents output getters and checks',
    () async {
      final signal = AcanthisCancellationSignal();
      var getters = 0;
      final schema = _builder()
          .map((p) {
            signal.cancel();
            return _User(p['name'] as String, p['age'] as int);
          })
          .validateWith(
            instance<_User>().field('name', (u) {
              getters++;
              return u.name;
            }, string()),
          )
          .build();
      expect(
        () =>
            AcanthisValidationScope(cancellation: signal)
                .run(() => schema.parse({'name': 'Ada', 'age': 21})),
        throwsA(isA<AcanthisValidationCancelled>()),
      );
      expect(getters, 0);
    },
  );

  test(
    'mapper format failures become issues and programming errors propagate',
    () async {
      final format = _builder()
          .map((_) => throw const FormatException('mapper'))
          .build();
      expect(
        format.tryParse({'name': 'Ada', 'age': 21}).issues.single.code,
        'transform',
      );
      final programming = _builder()
          .map((_) => throw StateError('mapper'))
          .build();
      await expectLater(
        programming.tryParseAsync({'name': 'Ada', 'age': 21}),
        throwsStateError,
      );
    },
  );

  test(
    'class pipelines compose with lists, objects, metadata, and registries',
    () {
      final schema = _builder().build().meta(
        const MetadataEntry<_User>(title: 'User'),
      );
      const key =
          SchemaKey<_User, AcanthisPipeline<Map<String, Object?>, _User>>(
            'user',
          );
      final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
      expect(registry.get(key), same(schema));
      expect(schema.metadataEntry!.title, 'User');
      expect(
        object({'user': schema}).parse({
          'user': {'name': 'Ada', 'age': 21},
        })['user'],
        isA<_User>(),
      );
      expect(
        schema
            .list()
            .parse([
              {'name': 'Ada', 'age': 21},
            ])
            .single
            .name,
        'Ada',
      );
      expect(schema.nullable().parse(null), isNull);
    },
  );

  test('opaque class mapping cannot export without executing it', () {
    var maps = 0;
    final schema = _builder().map((p) {
      maps++;
      return const _User('Ada', 21);
    }).build();
    expect(
      () => schema.toJsonSchema(),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    expect(maps, 0);
  });
}
