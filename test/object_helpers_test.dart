import 'dart:collection';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('extend keeps collisions, merge replaces them, and additions are snapshotted', () {
    final original = object({'a': string(), 'b': boolean()});
    final additions = <String, Schema<Object?, Object?>>{
      'a': number(),
      'c': string(),
    };
    final extended = original.extend(additions);
    final merged = original.merge(additions);
    additions.clear();
    expect(extended.fields.keys, ['a', 'b', 'c']);
    expect(merged.fields.keys, ['a', 'b', 'c']);
    expect(extended.validate({'a': 'yes', 'b': true, 'c': 'new'}), isTrue);
    expect(extended.validate({'a': 1, 'b': true, 'c': 'new'}), isFalse);
    expect(merged.validate({'a': 1, 'b': true, 'c': 'new'}), isTrue);
    expect(merged.validate({'a': 'yes', 'b': true, 'c': 'new'}), isFalse);
    expect(original.fields.keys, ['a', 'b']);
    expect(() => extended.fields.clear(), throwsUnsupportedError);
  });

  test('pick orders known names, omit preserves order, and removed optionals stay removed', () {
    final original = object({'a': string(), 'b': boolean(), 'c': number()})
        .optionals(['b']);
    final picked = original.pick(['c', 'missing', 'a', 'c']);
    expect(picked.fields.keys, ['c', 'a']);
    expect(picked.optionalFields, isEmpty);
    expect(original.omit(['missing', 'a']).fields.keys, ['b', 'c']);
    expect(original.pick(['b']).parse({}), isEmpty);
    expect(
      picked.merge({'b': boolean()}).validate({'a': 'a', 'c': 1}),
      isFalse,
    );
    expect(
      picked.extend({'b': boolean()}).validate({'a': 'a', 'c': 1}),
      isFalse,
    );
    expect(original.omit(['a', 'b', 'c']).parse({}), isEmpty);
    expect(original.pick(['missing']).parse({'x': 1}), isEmpty);
    expect(() => original.optionalFields.clear(), throwsUnsupportedError);
  });

  test('shape helpers preserve defaults, operations, presence and passthrough type', () async {
    final base = object({'a': string(), 'b': boolean()})
        .optionals(['b'])
        .passthrough(type: number())
        .withDefault({'a': 'default'})
        .minProperties(1)
        .transform((value) => {...value, 'checked': true});
    for (final derived in [
      base.extend({}),
      base.merge({}),
      base.pick(['a', 'b']),
      base.omit([]),
    ]) {
      expect(derived.parse(null), {'a': 'default', 'checked': true});
      expect(await derived.parseAsync({'a': 'a', 'extra': 1}), {
        'a': 'a',
        'extra': 1,
        'checked': true,
      });
      expect(derived.validate({'a': 'a', 'extra': false}), isFalse);
      expect(derived.optionalFields, {'b'});
    }
    final patch = base.patch();
    for (final derived in [
      patch.extend({'c': number()}),
      patch.merge({}),
      patch.pick(['a']),
      patch.omit(['b']),
    ]) {
      expect(derived.isPatch, isTrue);
      expect(derived.tryParse({}).issues.single.code, 'minProperties');
    }
    final strict = object({'a': string()})
        .unknownKeys(AcanthisUnknownKeys.reject);
    for (final derived in [
      strict.extend({}),
      strict.merge({}),
      strict.pick(['a']),
      strict.omit([]),
    ]) {
      expect(
        derived.tryParse({'a': 'a', 'extra': 1}).issues.single.code,
        'unknownKey',
      );
    }
  });

  test('deep partial and patch preserve missing defaults and validate supplied fields', () async {
    final nested = object({
      'name': string(),
      'active': boolean().withDefault(true),
    }).unknownKeys(AcanthisUnknownKeys.reject);
    final root = object({
      'child': nested,
      'flag': boolean().withDefault(false),
    });
    expect(root.partial().validate({'child': {}}), isFalse);
    for (final partial in [root.partial(deep: true), root.patch(deep: true)]) {
      expect(partial.parse({}), isEmpty);
      expect(partial.parse({'child': {}}), {'child': {}});
      expect(
        await partial.parseAsync({
          'child': {'active': null},
          'flag': null,
        }),
        {
          'child': {'active': true},
          'flag': false,
        },
      );
      expect(
        partial
            .tryParse({
              'child': {'name': null},
            })
            .issues
            .single
            .path,
        ['child', 'name'],
      );
      expect(
        partial
            .tryParse({
              'child': {'unknown': true},
            })
            .issues
            .single
            .code,
        'unknownKey',
      );
    }
    expect(root.validate({'child': {}}), isFalse);
    expect(nested.isPatch, isFalse);
  });

  test('deep partial retains V1 boundaries for lists and nullable schemas', () {
    final child = object({'required': string()});
    final schema = object({'list': child.list(), 'nullable': child.nullable()})
        .patch(deep: true);
    expect(schema.parse({}), isEmpty);
    expect(schema.parse({'list': [], 'nullable': null}), {
      'list': [],
      'nullable': null,
    });
    expect(
      schema
          .tryParse({
            'list': [{}],
            'nullable': {},
          })
          .issues
          .map((i) => i.path),
      [
        ['list', 0, 'required'],
        ['nullable', 'required'],
      ],
    );
  });

  test(
    'helpers bind lazy fields to the derived shape and do not eagerly resolve',
    () {
      var resolutions = 0;
      final field = lazy((parent) {
        resolutions++;
        return parent.pick(['name']).list();
      });
      final original = object({'name': string(), 'children': field});
      final changed = original.merge({'name': number()});
      final removed = original.omit(['children']);
      expect(resolutions, 0);
      expect(removed.parse({'name': 'original'}), {'name': 'original'});
      expect(resolutions, 0);
      expect(
        original.validate({
          'name': 'original',
          'children': [
            {'name': 'child'},
          ],
        }),
        isTrue,
      );
      expect(
        changed.validate({
          'name': 1,
          'children': [
            {'name': 2},
          ],
        }),
        isTrue,
      );
      expect(
        changed.validate({
          'name': 1,
          'children': [
            {'name': 'child'},
          ],
        }),
        isFalse,
      );
      expect(resolutions, 2);
    },
  );

  test('partial recursive parents retain lazy scope and wrapper checks', () {
    var calls = 0;
    final schema = object({
      'name': string(),
      'children': lazy((parent) => parent.patch(deep: true).list()).refine(
        onCheck: (value) {
          calls++;
          return value.length <= 1;
        },
      ),
    });
    final patch = schema.patch(deep: true);
    expect(
      patch.parse({
        'children': [
          {
            'children': [{}],
          },
        ],
      }),
      {
        'children': [
          {
            'children': [{}],
          },
        ],
      },
    );
    expect(calls, 2);
    expect(
      patch.validate({
        'children': [{}, {}],
      }),
      isFalse,
    );
  });

  test('typed passthrough validates only undeclared values and transforms without mutating input', () async {
    final schema = object({'name': string()})
        .passthrough(type: number().coerce());
    final input = <String, Object?>{'name': 'Ada', 'a.b': '3'};
    expect(schema.parse(input), {'name': 'Ada', 'a.b': 3});
    expect(await schema.parseAsync(input), {'name': 'Ada', 'a.b': 3});
    expect(input['a.b'], '3');
    final nulls = object({}).passthrough(type: boolean().nullable());
    final unchanged = <String, Object?>{'null': null, 'bool': false};
    expect(identical(nulls.parse(unchanged), unchanged), isTrue);
    expect(
      schema
          .tryParse({'name': false, 'a.b': false, 'z': false})
          .issues
          .map((i) => i.path),
      [
        ['name'],
        ['a.b'],
        ['z'],
      ],
    );
  });

  test('typed passthrough cannot be bypassed by any primitive object plan', () {
    for (var size = 0; size <= 5; size++) {
      final fields = {for (var i = 0; i < size; i++) 'f$i': boolean()};
      final schema = object(fields).passthrough(type: boolean().isTrue());
      final declaredOnly = <String, Object?>{
        for (final key in fields.keys) key: false,
      };
      expect(identical(schema.parse(declaredOnly), declaredOnly), isTrue);
      if (size > 0) {
        final missingWithExtra = {...declaredOnly}..remove('f0');
        missingWithExtra['extra'] = false;
        expect(schema.validate(missingWithExtra), isFalse);
      }
      final good = <String, Object?>{
        for (final key in fields.keys) key: false,
        'extra': true,
      };
      expect(identical(schema.parse(good), good), isTrue);
      expect(schema.validate({...good, 'extra': false}), isFalse);
      expect(
        object({'nested': schema}).validate({
          'nested': {...good, 'extra': false},
        }),
        isFalse,
      );
      final readonly = UnmodifiableMapView(good);
      expect(identical(schema.parse(readonly), readonly), isTrue);
      expect(schema.parse(<Object?, Object?>{...good}), good);
    }
  });

  test('typed passthrough retains nested paths, typed recovery and fail-fast behavior', () {
    final visited = <int>[];
    final schema = object({}).passthrough(
      type: number().refine(
        onCheck: (n) {
          visited.add(n.toInt());
          return n > 0;
        },
      ),
    );
    final input = {'a': -1, 'b': -2};
    expect(() => schema.parse(input), throwsA(isA<ValidationError>()));
    expect(visited, [-1]);
    visited.clear();
    final recovery =
        schema.tryParse(input) as AcanthisInvalid<Map<String, Object?>>;
    expect(recovery.hasValue, isTrue);
    expect(recovery.value, input);
    expect(identical(recovery.value, input), isFalse);
    expect(visited, [-1, -2]);
    final noRecovery =
        schema.tryParse({'a': false}) as AcanthisInvalid<Map<String, Object?>>;
    expect(noRecovery.hasValue, isFalse);
    final nested = object({})
        .passthrough(type: list(object({'ok': boolean()})));
    expect(
      nested
          .tryParse({
            'a.b': [
              {'ok': 1},
            ],
          })
          .issues
          .single
          .path,
      ['a.b', 0, 'ok'],
    );
  });

  test('passthrough resets typed values and policy switches discard inactive types', () {
    final typed = object({}).passthrough(type: boolean());
    expect(typed.passthrough().parse({'a': 1}), {'a': 1});
    expect(
      typed.unknownKeys(AcanthisUnknownKeys.strip).parse({'a': 1}),
      isEmpty,
    );
    expect(
      typed
          .unknownKeys(AcanthisUnknownKeys.reject)
          .tryParse({'a': 1})
          .issues
          .single
          .code,
      'unknownKey',
    );
    expect(
      typed
          .unknownKeys(AcanthisUnknownKeys.strip)
          .unknownKeys(AcanthisUnknownKeys.preserve)
          .parse({'a': 1}),
      {'a': 1},
    );
    expect(
      typed.unknownKeys(AcanthisUnknownKeys.preserve).validate({'a': 1}),
      isFalse,
    );
    expect(typed.validate({'a': 1}), isFalse);
  });

  test(
    'async passthrough guards synchronous APIs before any callbacks',
    () async {
      var fieldCalls = 0;
      final extras = <num>[];
      final schema =
          object({
            'name': string().refine(
              onCheck: (_) {
                fieldCalls++;
                return true;
              },
            ),
          }).passthrough(
            type: number().refineAsync(
              CallbackAsyncCheck((n, ctx) async {
                extras.add(n);
                if (n < 0) ctx.addIssue('negative');
              }),
            ),
          );
      expect(schema.isAsync, isTrue);
      expect(() => schema.parse({'name': 'a'}), throwsStateError);
      expect(fieldCalls, 0);
      expect(await schema.parseAsync({'name': 'a'}), {'name': 'a'});
      expect(
        await schema.validateAsync({'name': 'a', 'x': -1, 'y': -2}),
        isFalse,
      );
      expect(extras, [-1]);
      extras.clear();
      final result = await schema.tryParseAsync({
        'name': 'a',
        'x': -1,
        'y': -2,
      });
      expect(result.issues.map((i) => i.path), [
        ['x'],
        ['y'],
      ]);
      expect(extras, [-1, -2]);
      final stripped = schema.unknownKeys(AcanthisUnknownKeys.strip);
      expect(stripped.isAsync, isFalse);
      expect(stripped.parse({'name': 'a', 'x': -1}), {'name': 'a'});
    },
  );

  test('recursive typed passthrough resolves once and participates in capability traversal', () async {
    var resolutions = 0;
    final tree = object({'name': string()}).passthrough(
      type: lazy((parent) {
        resolutions++;
        return parent;
      }),
    );
    expect(resolutions, 0);
    final input = {
      'name': 'root',
      'child': {'name': 'child'},
    };
    expect(tree.parse(input), input);
    expect(await tree.parseAsync(input), input);
    expect(resolutions, 1);
    expect(
      tree
          .tryParse({
            'name': 'root',
            'child': {'name': false},
          })
          .issues
          .single
          .path,
      ['child', 'name'],
    );
  });

  test(
    'count checks observe parsed maps after strip, defaults and transforms',
    () async {
      final schema = object({'a': string().withDefault('default')})
          .lengthProperties(1);
      expect(schema.parse({'unknown': true}), {'a': 'default'});
      expect(schema.partial().validate({'unknown': true}), isFalse);
      expect(schema.passthrough().validate({'unknown': true}), isFalse);
      final ordered = object({})
          .transform((m) => {...m, 'a': true})
          .lengthProperties(1);
      expect(ordered.parse({}), {'a': true});
      expect(await ordered.parseAsync({}), {'a': true});
      expect(
        object({})
            .lengthProperties(1)
            .transform((m) => {...m, 'a': true})
            .validate({}),
        isFalse,
      );
    },
  );

  test(
    'count diagnostics preserve parameters, recovery, order and presentation',
    () {
      final schema = object({})
          .minProperties(2)
          .maxProperties(-1)
          .lengthProperties(1);
      final result =
          schema.tryParse({}) as AcanthisInvalid<Map<String, Object?>>;
      expect(result.value, isEmpty);
      expect(result.issues.map((i) => i.code), [
        'minProperties',
        'maxProperties',
        'lengthProperties',
      ]);
      expect(result.issues.map((i) => i.parameters), [
        {'constraintValue': 2},
        {'constraintValue': -1},
        {'constraintValue': 1},
      ]);
      expect(result.issues.every((i) => i.path.isEmpty), isTrue);
      expect(schema.parseOutcome({}).issues.length, 1);
      expect(
        () => object({}).lengthProperties(1).parse({}),
        throwsA(
          isA<ValidationError>().having(
            (e) => e.message,
            'message',
            contains('exactly 1 properties'),
          ),
        ),
      );
      final recovery = object({'a': boolean().isTrue()})
          .lengthProperties(2)
          .tryParse({'a': false});
      expect(recovery.issues.map((i) => i.code), [
        'isTrue',
        'lengthProperties',
      ]);
      final missing = object({'a': boolean()}).lengthProperties(2).tryParse({});
      expect(missing.issues.map((i) => i.code), ['required']);
    },
  );
}
