import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _User {
  const _User(
    this.name,
    this.score, {
    this.nickname,
    this.tags = const [],
    this.child,
  });
  final String name;
  final num score;
  final String? nickname;
  final List<int> tags;
  final _User? child;
}

InstanceType<_User> _described() => instance<_User>()
    .field('name', (u) => u.name, string())
    .field('score', (u) => u.score, number().gte(0).lte(10))
    .field('nickname', (u) => u.nickname, string(), optional: true);

InstanceType<_User> _generated() => _described().withFactory(
  (fields) => _User(
    fields['name'] as String,
    fields['score'] as num,
    nickname: fields['nickname'] as String?,
  ),
);

void main() {
  test(
    'instance fields export JSON Schema and OpenAPI without invoking callbacks',
    () {
      var getters = 0, factories = 0;
      final schema = instance<_User>()
          .field('name', (u) {
            getters++;
            return u.name;
          }, string())
          .field('score', (u) {
            getters++;
            return u.score;
          }, number().gte(0))
          .field(
            'nickname',
            (u) {
              getters++;
              return u.nickname;
            },
            string(),
            optional: true,
          )
          .withFactory((fields) {
            factories++;
            return const _User('Ada', 1);
          })
          .meta(
            const MetadataEntry<_User>(title: 'User', description: 'A user'),
          );
      for (final mode in AcanthisSchemaMode.values) {
        final json = schema.toJsonSchema(mode: mode);
        final openapi = schema.toOpenApiSchema(mode: mode);
        expect(
          json[r'$schema'],
          'https://json-schema.org/draft/2020-12/schema',
        );
        expect(openapi.containsKey(r'$schema'), isFalse);
        expect(openapi['type'], 'object');
        expect(openapi['properties'], {
          'name': {'type': 'string'},
          'score': {
            'type': 'number',
            'allOf': [
              {'minimum': 0},
            ],
          },
          'nickname': {'type': 'string'},
        });
        expect(openapi['required'], ['name', 'score']);
        expect(openapi['title'], 'User');
        expect(openapi['description'], 'A user');
        expect(jsonDecode(jsonEncode(json)), json);
        final contract = fromJsonSchema(json);
        expect(contract.validate({'name': 'Ada', 'score': 1}), isTrue);
        expect(contract.validate({'name': 'Ada'}), isFalse);
        expect(contract.validate({'name': 'Ada', 'score': -1}), isFalse);
      }
      expect(getters, 0);
      expect(factories, 0);
    },
  );

  test(
    'nested instance fields participate in normal schema graphs and snapshots',
    () {
      final child = _described();
      final schema = object({'users': child.list(), 'maybe': child.nullable()});
      final first = schema.toJsonSchema();
      ((first['properties'] as Map)['users'] as Map).clear();
      final next = schema.toJsonSchema();
      expect(
        (next['properties'] as Map)['users'],
        containsPair('type', 'array'),
      );
      final contract = fromJsonSchema(next);
      expect(
        contract.validate({
          'users': [
            {'name': 'Ada', 'score': 1},
          ],
          'maybe': null,
        }),
        isTrue,
      );
      expect(instance<_User>().toJsonSchema()['properties'], isEmpty);
    },
  );

  test(
    'optional flags survive fluent rebuilds and defaults do not invoke getters',
    () {
      final schema = _described()
          .withDefault(const _User('Default', 1))
          .withFactory((f) => _User(f['name'] as String, f['score'] as num))
          .withRefs((r) => r.ref('score', (u) => u.score))
          .meta(const MetadataEntry<_User>(title: 'User'));
      expect(schema.toJsonSchema()['required'], ['name', 'score']);
      final properties = schema.toJsonSchema()['properties'] as Map;
      expect(properties.keys, ['name', 'score', 'nickname']);
      expect(schema.toJsonSchema().containsKey('anyOf'), isFalse);
    },
  );

  test('duplicate required names are deduplicated and latest property describes the field', () {
    final schema = instance<_User>()
        .field('score', (u) => u.score, number().gte(0))
        .field('score', (u) => u.score, number().lte(10));
    final json = schema.toJsonSchema();
    expect(json['required'], ['score']);
    expect((json['properties'] as Map)['score'], {
      'type': 'number',
      'allOf': [
        {'maximum': 10},
      ],
    });
    expect(fromJsonSchema(json).validate({'score': 5}), isTrue);
  });

  test('export still rejects opaque operations and unsupported children at their paths', () {
    var calls = 0;
    final root = _described().refine(
      onCheck: (_) {
        calls++;
        return true;
      },
    );
    expect(
      () => root.toJsonSchema(),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    final child = instance<_User>().field(
      'a/b~',
      (u) => u.name,
      string().refine(
        onCheck: (_) {
          calls++;
          return true;
        },
      ),
    );
    expect(
      () => child.toJsonSchema(),
      throwsA(
        isA<AcanthisSchemaExportException>().having(
          (e) => e.path,
          'path',
          '/properties/a~1b~0',
        ),
      ),
    );
    expect(
      () => _described().transform((u) {
        calls++;
        return u;
      }).toJsonSchema(),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    expect(
      () => instance<_User>()
          .field('score', (u) => u.score, integer())
          .toJsonSchema(),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    expect(calls, 0);
  });

  test(
    'seeded factories construct typed instances from valid reproducible fields',
    () {
      final schema = _generated();
      for (var seed = 0; seed < 30; seed++) {
        final _User first = schema.mockSeeded(seed: seed);
        final second = schema.mock(seed);
        expect(schema.toMap(first), schema.toMap(second));
        expect(schema.validate(first), isTrue);
        expect(first.score, inInclusiveRange(0, 10));
      }
    },
  );

  test('factory inputs are parsed to typed lists and nested instances', () {
    final child = _generated();
    final schema = instance<_User>()
        .field('name', (u) => u.name, string().exact('Parent'))
        .field('score', (u) => u.score, number().exact(1))
        .field('tags', (u) => u.tags, integer().list().length(2))
        .field('child', (u) => u.child, child)
        .withFactory((fields) {
          expect(fields['tags'], isA<List<int>>());
          expect(fields['child'], isA<_User>());
          expect(() => fields.clear(), throwsUnsupportedError);
          return _User(
            fields['name'] as String,
            fields['score'] as num,
            tags: fields['tags'] as List<int>,
            child: fields['child'] as _User,
          );
        });
    final value = schema.mockSeeded(seed: 42);
    expect(value.tags, hasLength(2));
    expect(value.child, isNotNull);
    expect(schema.validate(value), isTrue);
  });

  test('nested mock collections retain their domain and container types', () {
    final item = _generated();
    final list = item.list().length(2).mockSeeded(seed: 42);
    expect(list, isA<List<_User>>());
    final schema = object({
      'one': item,
      'nullable': item.nullable(),
      'items': item.list().length(2),
      'tuple': tuple([item]),
      'record': record(string(), item),
      'union': union<Object?>([item, boolean()]),
    });
    final value = schema.mockSeeded(seed: 42);
    expect(schema.validate(value), isTrue);
    expect(value['one'], isA<_User>());
    expect(value['items'], isA<List<_User>>());
    expect(value['record'], isA<Map<String, _User>>());
  });

  test('factory capability survives metadata, refs, fields and defaults', () {
    final schema = _generated()
        .meta(const MetadataEntry<_User>(title: 'User'))
        .withDefault(const _User('Default', 1))
        .withRefs((r) => r.ref('score', (u) => u.score))
        .field('tags', (u) => u.tags, integer().list());
    expect(schema.mockSeeded(), isA<_User>());
    expect(schema.metadataEntry!.title, 'User');
  });

  test('missing factory and unsupported children fail before construction', () {
    expect(
      () => _described().mockSeeded(),
      throwsA(
        isA<AcanthisMockException>().having(
          (e) => e.reason,
          'reason',
          contains('withFactory'),
        ),
      ),
    );
    var factories = 0, checks = 0;
    final schema = instance<_User>()
        .field(
          'name',
          (u) => u.name,
          string().refine(
            onCheck: (_) {
              checks++;
              return true;
            },
          ),
        )
        .withFactory((fields) {
          factories++;
          return const _User('Ada', 1);
        });
    expect(() => schema.mockSeeded(), throwsA(isA<AcanthisMockException>()));
    expect(factories, 0);
    expect(checks, 0);
  });

  test('invalid factory output retries only to maxAttempts', () {
    var factories = 0;
    final schema = instance<_User>()
        .field('name', (u) => u.name, string().exact('Required'))
        .withFactory((fields) {
          factories++;
          return const _User('Wrong', 1);
        });
    expect(
      () => schema.mockSeeded(maxAttempts: 3),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(factories, 3);
  });

  test('invalid generated child fields retry without calling the factory', () {
    var factories = 0;
    final schema = instance<_User>()
        .field('name', (u) => u.name, string().exact('a').min(2))
        .withFactory((fields) {
          factories++;
          return const _User('a', 1);
        });
    expect(
      () => schema.mockSeeded(maxAttempts: 3),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(factories, 0);
  });

  test('factory output and schema depth remain bounded', () {
    final oversized = instance<_User>()
        .field('name', (u) => u.name, string())
        .withFactory((fields) => _User('x' * 257, 1));
    expect(
      () => oversized.mockSeeded(maxCollectionLength: 256),
      throwsA(isA<AcanthisMockException>()),
    );
    expect(
      () => _generated().mockSeeded(maxNodes: 1),
      throwsA(isA<AcanthisMockException>()),
    );
    final tooDeep = instance<_User>()
        .field('child', (u) => u.child, _generated())
        .withFactory(
          (fields) => _User('Parent', 1, child: fields['child'] as _User),
        );
    expect(
      () => tooDeep.mockSeeded(maxDepth: 2),
      throwsA(isA<AcanthisMockException>()),
    );
  });

  test('factory cancellation and programming errors remain control flow', () {
    final signal = AcanthisCancellationSignal();
    final cancelled = _described().withFactory((fields) {
      signal.cancel();
      return const _User('Ada', 1);
    });
    expect(
      () =>
          AcanthisValidationScope(cancellation: signal)
              .run(() => cancelled.mockSeeded()),
      throwsA(isA<AcanthisValidationCancelled>()),
    );
    expect(
      () => _described()
          .withFactory((fields) => throw StateError('constructor'))
          .mockSeeded(),
      throwsStateError,
    );
  });

  test(
    'default inspection cannot execute unaudited instance child callbacks',
    () {
      var calls = 0;
      final bad = instance<_User>()
          .field(
            'name',
            (u) {
              calls++;
              return u.name;
            },
            string().refine(
              onCheck: (_) {
                calls++;
                return true;
              },
            ),
          )
          .withFactory((fields) {
            calls++;
            return const _User('Ada', 1);
          });
      final schema = union<Object?>([bad, boolean()])
          .withDefault(const _User('Ada', 1));
      expect(() => schema.mockSeeded(), throwsA(isA<AcanthisMockException>()));
      expect(calls, 0);
    },
  );

  test('output inspection bounds described scalar-instance fields and detects cycles', () {
    final scalar = instance<String>()
        .field('derived', (s) => 'x' * 257, string())
        .withFactory((fields) => 'value');
    expect(() => scalar.mockSeeded(), throwsA(isA<AcanthisMockException>()));
    final cycle = <Object?>[];
    cycle.add(cycle);
    final cyclic = instance<_User>()
        .field(
          'derived',
          (u) => cycle,
          instance<Object?>().withFactory((fields) => Object()).list(),
        )
        .withFactory((fields) => const _User('Ada', 1));
    expect(() => cyclic.mockSeeded(), throwsA(isA<AcanthisMockException>()));
  });

  test('class mapping can use an input mock, and export each declared side explicitly', () {
    var maps = 0;
    final schema = classSchema<Map<String, Object?>, _User>()
        .input(
          object({
            'display_name': string().exact('Ada'),
            'score': number().between(0, 10),
          }),
        )
        .map((fields) {
          maps++;
          return _User(
            fields['display_name'] as String,
            fields['score'] as num,
          );
        })
        .validateWith(_described())
        .build();
    final input = schema.inType.toJsonSchema();
    final output = schema.outType.toJsonSchema(mode: AcanthisSchemaMode.output);
    expect((input['properties'] as Map).containsKey('display_name'), isTrue);
    expect((output['properties'] as Map).containsKey('name'), isTrue);
    expect(maps, 0);
    final sample = schema.parse(schema.inType.mockSeeded(seed: 42));
    expect(sample.name, 'Ada');
    expect(sample.score, inInclusiveRange(0, 10));
    expect(maps, 1);
  });
}
