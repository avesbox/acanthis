import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

class _User {
  const _User(this.name, this.age, {this.nickname});
  final String name;
  final int age;
  final String? nickname;
}

class _Admin extends _User {
  const _Admin() : super('Admin', 30);
}

class _Box {
  const _Box(this.value);
  final Object? value;
}

InstanceType<_User> _user() => instance<_User>()
    .field('name', (u) => u.name, string().min(2))
    .field('age', (u) => u.age, integer().gte(18));

void main() {
  test(
    'factory checks runtime type and returns the original instance',
    () async {
      final schema = Acanthis.instance<_User>();
      const admin = _Admin();
      expect(schema.parse(admin), same(admin));
      expect(await schema.parseAsync(admin), same(admin));
      for (final input in [
        null,
        'user',
        {'name': 'Ada'},
      ]) {
        final sync = schema.tryParse(input) as AcanthisInvalid<_User>;
        final async =
            await schema.tryParseAsync(input) as AcanthisInvalid<_User>;
        expect(sync.hasValue, isFalse);
        expect(async.hasValue, isFalse);
        expect(sync.issues, async.issues);
        expect(sync.issues.single.code, 'type');
        expect(() => sync.value, throwsStateError);
        expect(() => schema.parse(input), throwsA(isA<ValidationError>()));
      }
    },
  );

  test('complete nested fields run getters and transformations once', () async {
    var getters = 0;
    var transforms = 0;
    final child = object({
      'a/b~': string()
          .transform((s) {
            transforms++;
            return s.trim();
          })
          .min(3)
          .min(4),
    });
    final schema = instance<_Box>().field('value', (box) {
      getters++;
      return box.value;
    }, child);
    const box = _Box({'a/b~': ' x '});
    for (final async in [false, true]) {
      getters = transforms = 0;
      final result = async
          ? await schema.tryParseAsync(box)
          : schema.tryParse(box);
      expect(result.value, same(box));
      expect(result.issues.map((i) => i.code), ['minLength', 'minLength']);
      expect(result.issues.map((i) => i.parameters['value']), [3, 4]);
      expect(result.issues.first.jsonPointer, '/value/a~1b~0');
      expect(getters, 1);
      expect(transforms, 1);
    }
    expect(
      () => schema.parse(box),
      throwsA(
        isA<ValidationError>().having((e) => e.issues.length, 'issue count', 1),
      ),
    );
    expect((box.value as Map)['a/b~'], ' x ');
  });

  test('typed recovery retains the object even when a child has none', () {
    const box = _Box(1);
    final schema = instance<_Box>().field('value', (b) => b.value, string());
    final result = schema.tryParse(box) as AcanthisInvalid<_Box>;
    expect(result.hasValue, isTrue);
    expect(result.value, same(box));
    expect(result.issues.single.path, ['value']);
    expect(schema.validate(box), isFalse);
  });

  test('fields, refinements and transforms preserve fluent order', () async {
    final order = <String>[];
    final schema = instance<_User>()
        .refine(
          onCheck: (u) {
            order.add('before');
            return true;
          },
        )
        .field('first', (u) {
          order.add('first:${u.name}');
          return u.name;
        }, string())
        .transform((u) {
          order.add('transform');
          return _User('Grace', u.age);
        })
        .field('second', (u) {
          order.add('second:${u.name}');
          return u.name;
        }, string())
        .refine(
          onCheck: (u) {
            order.add('after:${u.name}');
            return true;
          },
        );
    for (final async in [false, true]) {
      order.clear();
      final result = async
          ? await schema.parseAsync(const _User('Ada', 20))
          : schema.parse(const _User('Ada', 20));
      expect(result.name, 'Grace');
      expect(order, [
        'before',
        'first:Ada',
        'transform',
        'second:Grace',
        'after:Grace',
      ]);
    }
  });

  test('collecting failures keep order and prevent later transformations', () {
    var transforms = 0;
    final schema = _user()
        .refine(onCheck: (_) => false, name: 'root')
        .transform((u) {
          transforms++;
          return u;
        })
        .field('late', (_) => '', string().min(1));
    final result = schema.tryParse(const _User('', 1));
    expect(result.issues.map((i) => i.code), ['minLength', 'gte', 'root']);
    expect(result.issues.map((i) => i.path), [
      ['name'],
      ['age'],
      [],
    ]);
    expect(transforms, 0);
    expect(
      () => schema.parse(const _User('', 1)),
      throwsA(
        isA<ValidationError>().having((e) => e.issues.length, 'issue count', 1),
      ),
    );
  });

  test(
    'optional null skips child defaults and toMap returns original values',
    () async {
      var calls = 0;
      final child = string().withDefault('default').transform((s) {
        calls++;
        return s.trim();
      });
      final optional = instance<_User>().field(
        'nickname',
        (u) => u.nickname,
        child,
        optional: true,
      );
      final required = instance<_User>().field(
        'nickname',
        (u) => u.nickname,
        child,
      );
      const user = _User('Ada', 21);
      expect(optional.parse(user), same(user));
      expect(await optional.parseAsync(user), same(user));
      expect(calls, 0);
      expect(required.parse(user), same(user));
      expect(calls, 1);
      expect(required.toMap(user), {'nickname': null});
      final raw = optional.toMap(const _User('Ada', 21, nickname: ' x '));
      expect(raw['nickname'], ' x ');
    },
  );

  test('defaults replace null only and are validated normally', () async {
    const fallback = _User('Fallback', 30);
    final schema = _user().withDefault(fallback);
    expect(schema.parse(null), same(fallback));
    expect(await schema.parseAsync(null), same(fallback));
    expect(object({'user': schema}).parse({})['user'], same(fallback));
    final wrong = schema.tryParse('user') as AcanthisInvalid<_User>;
    expect(wrong.hasValue, isFalse);
    expect(schema.withDefault(const _User('', 1)).validate(null), isFalse);
    expect(instance<_User?>().withDefault(null).parse(null), isNull);
  });

  test('refs are snapshotted and extend without mutating prior schemas', () {
    late InstanceRefsBuilder<_User> builder;
    final base = _user().withRefs((refs) {
      builder = refs;
      return refs.ref('age', (u) => u.age);
    });
    final schema = base.refineWithRefs(
      (u, refs) => refs.call<int>('age') == u.age,
      'Age changed',
      name: 'consistent',
    );
    builder.ref('age', (_) => -1);
    expect(schema.validate(const _User('Ada', 20)), isTrue);
    final changed = base
        .withRefs((refs) => refs.ref('age', (_) => -1))
        .refineWithRefs(
          (u, refs) => refs.call<int>('age') == u.age,
          'Age changed',
        );
    expect(
      changed.tryParse(const _User('Ada', 20)).issues.single.message,
      'Age changed',
    );
    final missing = base.refineWithRefs(
      (u, refs) => refs.call<int>('missing') > 0,
      'Missing',
    );
    expect(() => missing.parse(const _User('Ada', 20)), throwsArgumentError);
  });

  test(
    'cause messages are invocation-local and can be localized by code',
    () async {
      final schema = instance<_User>()
          .withRefs((r) => r.ref('name', (u) => u.name))
          .refineWithCause(
            (u, refs) =>
                u.age < 18 ? 'Too young: ${refs.call<String>('name')}' : null,
            name: 'app.age',
          );
      final results = await Future.wait([
        schema.tryParseAsync(const _User('Ada', 10)),
        schema.tryParseAsync(const _User('Grace', 11)),
      ]);
      expect(results.map((r) => r.issues.single.message), [
        'Too young: Ada',
        'Too young: Grace',
      ]);
      expect(
        results.first.issues.single.formatMessage(
          catalog: AcanthisMessageCatalog({'app.age': (_) => 'Underage'}),
        ),
        'Underage',
      );
      expect(schema.validate(const _User('Ada', 18)), isTrue);
    },
  );

  test(
    'async child schemas preflight and preserve fail-fast behavior',
    () async {
      var remoteCalls = 0;
      final child = string()
          .min(3)
          .refineAsync(
            CallbackAsyncCheck((v, c) async {
              remoteCalls++;
              c.addIssue('remote');
            }),
          );
      var getters = 0;
      final schema = instance<_Box>().field('value', (b) {
        getters++;
        return b.value;
      }, child.list());
      expect(schema.isAsync, isTrue);
      expect(() => schema.parse(const _Box(['x'])), throwsStateError);
      expect(getters, 0);
      await expectLater(
        schema.parseAsync(const _Box(['x'])),
        throwsA(isA<ValidationError>()),
      );
      expect(remoteCalls, 0);
      final result = await schema.tryParseAsync(const _Box(['x']));
      expect(remoteCalls, 1);
      expect(result.issues.map((i) => i.code), ['minLength', 'remote']);
      expect(result.issues.last.path, ['value', 0]);
    },
  );

  test(
    'async operations retain order around synchronous and async fields',
    () async {
      final order = <String>[];
      final schema = instance<_User>()
          .transformAsync(
            CallbackAsyncTransform((u) async {
              order.add('transform');
              return u;
            }),
          )
          .field(
            'name',
            (u) {
              order.add('getter');
              return u.name;
            },
            string().refineAsync(
              CallbackAsyncCheck((v, c) async {
                order.add('child');
              }),
            ),
          )
          .refineAsync(
            CallbackAsyncCheck((u, c) async {
              order.add('root');
            }),
          );
      expect(await schema.validateAsync(const _User('Ada', 20)), isTrue);
      expect(order, ['transform', 'getter', 'child', 'root']);
    },
  );

  test('field and object collection policies remain independent', () async {
    final schema = instance<_Box>()
        .field('a', (_) => '', string().min(2).min(3))
        .field('b', (_) => '', string().min(4));
    const box = _Box(null);
    for (final async in [false, true]) {
      final fieldFirst =
          await const AcanthisValidationScope(
            fieldPolicy: AcanthisCollectionPolicy.first,
          ).run(
            () async =>
                async ? await schema.tryParseAsync(box) : schema.tryParse(box),
          );
      expect(fieldFirst.issues.map((i) => i.path), [
        ['a'],
        ['b'],
      ]);
      final objectFirst =
          await const AcanthisValidationScope(
            objectPolicy: AcanthisCollectionPolicy.first,
          ).run(
            () async =>
                async ? await schema.tryParseAsync(box) : schema.tryParse(box),
          );
      expect(objectFirst.issues.map((i) => i.path), [
        ['a'],
        ['a'],
      ]);
    }
  });

  test(
    'context, cancellation and callback errors pass through fields',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final signal = AcanthisCancellationSignal();
      var later = 0;
      final schema = instance<_User>()
          .field(
            'name',
            (u) => u.name,
            string().refineAsync(
              CallbackAsyncCheck((v, c) async {
                expect(c.contextAs<String>(), 'tenant');
                entered.complete();
                await release.future;
              }),
            ),
          )
          .field('age', (u) {
            later++;
            return u.age;
          }, integer());
      final future = AcanthisValidationScope(
        context: 'tenant',
        cancellation: signal,
      ).run(() => schema.tryParseAsync(const _User('Ada', 20)));
      final assertion = expectLater(
        future,
        throwsA(isA<AcanthisValidationCancelled>()),
      );
      await entered.future;
      signal.cancel();
      release.complete();
      await assertion;
      expect(later, 0);
      final throwsGetter = instance<_User>().field(
        'name',
        (_) => throw StateError('getter'),
        string(),
      );
      expect(
        () => throwsGetter.tryParse(const _User('Ada', 20)),
        throwsStateError,
      );
      await expectLater(
        throwsGetter.tryParseAsync(const _User('Ada', 20)),
        throwsStateError,
      );
    },
  );

  test(
    'fluent metadata, composition and registries preserve the concrete type',
    () {
      final original = _user();
      final InstanceType<_User> schema = original
          .meta(const MetadataEntry<_User>(title: 'User'))
          .withDefault(const _User('Default', 20))
          .withRefs((refs) => refs.ref('age', (u) => u.age))
          .field('nickname', (u) => u.nickname, string().nullable());
      expect(original.metadataEntry, isNull);
      expect(schema.metadataEntry!.title, 'User');
      const user = _User('Ada', 20);
      expect(schema.list().parse([user]), [same(user)]);
      expect(schema.nullable().parse(null), same(schema.defaultValue));
      const key = SchemaKey<_User, InstanceType<_User>>('user');
      final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
      final InstanceType<_User> found = registry.get(key);
      expect(found, same(schema));
      expect(schema.toMap(user), {'name': 'Ada', 'age': 20, 'nickname': null});
    },
  );

  test(
    'unions continue past unrelated instance branches, sync and async',
    () async {
      final sync = union<Object>([instance<_User>(), instance<_Box>()]);
      const box = _Box('value');
      expect(sync.parse(box), same(box));
      final async = union<Object>([
        instance<_User>().refineAsync(CallbackAsyncCheck((u, c) async {})),
        instance<_Box>(),
      ]);
      expect(await async.parseAsync(box), same(box));
      expect(
        (await async.tryParseAsync(1)).issues.single.branches,
        hasLength(2),
      );
    },
  );

  test(
    'field export avoids getters and mocks require a construction factory',
    () {
      var calls = 0;
      final schema = instance<_User>().field('name', (u) {
        calls++;
        return u.name;
      }, string());
      for (final mode in AcanthisSchemaMode.values) {
        expect(schema.toJsonSchema(mode: mode)['required'], ['name']);
      }
      expect(() => schema.mockSeeded(), throwsA(isA<AcanthisMockException>()));
      expect(calls, 0);
    },
  );
}
