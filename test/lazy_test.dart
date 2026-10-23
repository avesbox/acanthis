import 'support/parse_result.dart';

import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _Identity extends Schema<Object?, Object?> {
  @override
  Object? parse(Object? input) => input;
  @override
  AcanthisOutcome<Object?> tryParse(Object? input) => AcanthisValid(input);
}

void main() {
  test('shared field definitions resolve once but execute wrapper behavior per field', () {
    var resolutions = 0;
    var validations = 0;
    final entry =
        lazy((_) {
          resolutions++;
          return integer();
        }).refine(
          onCheck: (_) {
            validations++;
            return true;
          },
        );
    final schema = object({'a': entry, 'b': entry});
    expect(schema.parseResult({'a': 1, 'b': 2}).value, {'a': 1, 'b': 2});
    expect(resolutions, 1);
    expect(validations, 2);
  });

  test('recursive parent variants retain parent and derived operations once per node', () {
    var baseChecks = 0;
    var derivedChecks = 0;
    var resolutions = 0;
    final schema =
        object({
          'name': string(),
          'children': lazy((parent) {
            resolutions++;
            return parent
                .refine(
                  onCheck: (_) {
                    derivedChecks++;
                    return true;
                  },
                )
                .list();
          }),
        }).refine(
          onCheck: (_) {
            baseChecks++;
            return true;
          },
        );
    expect(
      schema.parseResult({
        'name': 'root',
        'children': [
          {'name': 'left', 'children': []},
          {'name': 'right', 'children': []},
        ],
      }).isValid,
      isTrue,
    );
    expect(baseChecks, 3);
    expect(derivedChecks, 2);
    expect(resolutions, 1);
  });
  test('nullable defaults and synchronous third-party targets work with async wrappers', () async {
    final entry = lazy((_) => _Identity())
        .withDefault(null)
        .refineAsync(
          CallbackAsyncCheck((v, context) async {
            if (v != null) context.addIssue('mustBeNull');
          }),
        );
    final schema = object({'value': entry});
    expect(schema.isAsync, isTrue);
    expect((await schema.parseResultAsync({})).value, {'value': null});
    expect((await schema.tryParseAsync({'value': 1})).issues.single.path, [
      'value',
    ]);
  });

  test('long lazy operation chains share definitions and materialize without recursion', () {
    var resolutions = 0;
    var entry = lazy((_) {
      resolutions++;
      return integer();
    });
    for (var i = 0; i < 5000; i++) {
      entry = entry.refine(onCheck: (v) => v > 0);
    }
    final schema = object({'n': entry});
    expect(schema.parseResult({'n': 1}).value, {'n': 1});
    expect(entry.checks, hasLength(5000));
    expect(resolutions, 1);
  });
  test(
    'lazy factories retain concrete output types and cache binding by parent',
    () async {
      for (final create in [
        lazy<int>,
        Acanthis.lazy<int>,
        AcanthisType.lazy<int>,
      ]) {
        var resolutions = 0;
        final entry = create((_) {
          resolutions++;
          return integer().coerce();
        });
        final parent = object({'n': entry});
        expect(resolutions, 0);
        expect(parent.isAsync, isFalse);
        expect(resolutions, 1);
        final Schema<Object?, int> bound = entry.call(parent);
        expect(entry.call(parent), same(bound));
        for (final result in [
          parent.parseResult({'n': '1'}),
          parent.tryParse({'n': '1'}),
          await parent.parseResultAsync({'n': '1'}),
          await parent.tryParseAsync({'n': '1'}),
        ]) {
          expect(result.isValid, isTrue);
          expect(result.value, {'n': 1});
        }
        expect(entry.parseResult('1', parent).value, 1);
        expect(entry.tryParse('1', parent).value, 1);
        expect((await entry.parseResultAsync('1', parent)).value, 1);
        expect((await entry.tryParseAsync('1', parent)).value, 1);
        expect(entry.validate('1', parent), isTrue);
        expect(entry.tryValidate('1', parent), isTrue);
        expect(await entry.validateAsync('1', parent), isTrue);
        expect(await entry.tryValidateAsync('1', parent), isTrue);
        expect(resolutions, 1);
      }
    },
  );

  test('unbound lazy entry points fail with a clear parent requirement', () {
    final entry = lazy((_) => string());
    expect(() => entry.isAsync, throwsStateError);
    expect(() => entry.parseResult('x'), throwsStateError);
    expect(() => entry.tryParse('x'), throwsStateError);
    expect(() => entry.parseResultAsync('x'), throwsStateError);
    expect(() => entry.tryParseAsync('x'), throwsStateError);
  });

  test(
    'recursive parent lists resolve once and preserve unknown-key variants',
    () async {
      var resolutions = 0;
      final children = lazy((parent) {
        resolutions++;
        return parent.unknownKeys(AcanthisUnknownKeys.preserve).list().max(2);
      });
      final tree = object({
        'name': string().toUpperCase(),
        'children': children,
      });
      final input = {
        'name': 'root',
        'children': [
          {
            'name': 'child',
            'extra': 3,
            'children': [
              {'name': 'leaf', 'children': []},
            ],
          },
        ],
      };
      for (final result in [
        tree.parseResult(input),
        tree.tryParse(input),
        await tree.parseResultAsync(input),
        await tree.tryParseAsync(input),
      ]) {
        expect(result.isValid, isTrue);
        expect(result.value, {
          'name': 'ROOT',
          'children': [
            {
              'name': 'CHILD',
              'extra': 3,
              'children': [
                {'name': 'LEAF', 'children': []},
              ],
            },
          ],
        });
      }
      expect(resolutions, 1);
      expect(
        tree
            .tryParse({
              'name': 'root',
              'children': [
                {
                  'name': 'leaf',
                  'children': [{}, {}, {}],
                },
              ],
            })
            .issues
            .map((i) => i.path),
        contains(equals(['children', 0, 'children', 0, 'name'])),
      );
      expect(input['name'], 'root');
    },
  );

  test(
    'recursive records and optional recursive objects support finite input',
    () {
      var resolutions = 0;
      final tree = object({
        'n': integer(),
        'branches': lazy((parent) {
          resolutions++;
          return record(string(), parent);
        }),
      });
      expect(
        tree.parseResult({
          'n': 1,
          'branches': {
            'left': {'n': 2, 'branches': {}},
          },
        }).isValid,
        isTrue,
      );
      expect(
        tree
            .tryParse({
              'n': 1,
              'branches': {
                'left': {'n': 'bad', 'branches': {}},
              },
            })
            .issues
            .single
            .path,
        ['branches', 'left', 'n'],
      );
      expect(resolutions, 1);
      final linked = object({'n': integer(), 'next': lazy((parent) => parent)})
          .optionals(['next']);
      expect(
        linked.parseResult({
          'n': 1,
          'next': {'n': 2},
        }).value,
        {
          'n': 1,
          'next': {'n': 2},
        },
      );
    },
  );

  test('mutual recursive objects bind into a finite graph', () async {
    var aCalls = 0;
    var bCalls = 0;
    late ObjectSchema a;
    late ObjectSchema b;
    a = object({
      'a': integer(),
      'b': lazy((_) {
        aCalls++;
        return b;
      }),
    }).optionals(['b']);
    b = object({
      'b': string(),
      'a': lazy((_) {
        bCalls++;
        return a;
      }),
    }).optionals(['a']);
    expect(a.isAsync, isFalse);
    expect(b.isAsync, isFalse);
    expect(
      a.parseResult({
        'a': 1,
        'b': {
          'b': 'x',
          'a': {'a': 2},
        },
      }).isValid,
      isTrue,
    );
    expect(
      (await b.tryParseAsync({
        'b': 'x',
        'a': {'a': 'bad'},
      })).issues.single.path,
      ['a', 'a'],
    );
    expect(aCalls, 1);
    expect(bCalls, 1);
  });

  test(
    'lazy checks and transforms run once in order after resolved child parsing',
    () async {
      final seen = <String>[];
      final base = lazy((_) => string().toUpperCase());
      final entry = base
          .withCheck(
            CallbackCheck((v, _) {
              seen.add('check:$v');
            }),
          )
          .transform((v) {
            seen.add('transform:$v');
            return '$v!';
          })
          .refine(
            onCheck: (v) {
              seen.add('refine:$v');
              return v.endsWith('!');
            },
          );
      final parent = object({'text': entry});
      for (final collect in [false, true]) {
        seen.clear();
        final result = collect
            ? parent.tryParse({'text': 'hi'})
            : parent.parseResult({'text': 'hi'});
        expect(result.value, {'text': 'HI!'});
        expect(seen, ['check:HI', 'transform:HI', 'refine:HI!']);
      }
      expect(base.checks, isEmpty);
      expect(base.transformations, isEmpty);
      expect(entry.checks, hasLength(2));
      expect(() => entry.checks.clear(), throwsUnsupportedError);
      expect(() => entry.transformations.clear(), throwsUnsupportedError);
      expect((await parent.tryParseAsync({'text': 'hi'})).value, {
        'text': 'HI!',
      });
    },
  );

  test('fail-fast, collecting, missing recovery and transform boundaries are preserved', () async {
    var transforms = 0;
    final entry = lazy((_) => integer().positive())
        .refine(onCheck: (_) => false, name: 'one', error: 'First')
        .refine(onCheck: (_) => false, name: 'two')
        .transform((v) {
          transforms++;
          return v;
        });
    final parent = object({'n': entry});
    expect(parent.parseResult({'n': -1}).issues.map((i) => i.code), [
      'positive',
    ]);
    final collected = parent.tryParse({'n': -1});
    expect(collected.issues.map((i) => i.code), ['positive', 'one', 'two']);
    expect(collected.issues.map((i) => i.path), [
      ['n'],
      ['n'],
      ['n'],
    ]);
    expect(collected.issues[1].message, 'First');
    expect(collected.value, {'n': -1});
    expect((await parent.tryParseAsync({'n': -1})).issues, collected.issues);
    final wrong =
        parent.tryParse({'n': 'bad'}) as AcanthisInvalid<Map<String, Object?>>;
    expect(wrong.hasValue, isFalse);
    expect(wrong.issues.single.code, 'type');
    expect(transforms, 0);
  });

  test('lazy and resolved defaults propagate, validate, and respect partial omission', () async {
    final parent = object({
      'own': lazy((_) => integer().positive()).withDefault(-1),
      'child': lazy((_) => string().withDefault('child')),
      'optional': lazy((_) => integer()).withDefault(2),
    }).optionals(['optional']);
    final result = parent.tryParse({});
    expect(result.issues.single.code, 'positive');
    expect(result.issues.single.path, ['own']);
    expect(result.value, {'own': -1, 'child': 'child', 'optional': 2});
    expect(parent.partial().parseResult({}).value, isEmpty);
    expect((await parent.partial().parseResultAsync({})).value, isEmpty);
    final required = object({'n': lazy((_) => integer())});
    expect(required.parseResult({}).issues.single.code, 'required');
  });

  test(
    'a reused lazy definition binds independently to external parent variants',
    () {
      var resolutions = 0;
      final entry = lazy((parent) {
        resolutions++;
        return parent.list();
      });
      final base = object({'name': string(), 'children': entry});
      final strict = base.unknownKeys(AcanthisUnknownKeys.reject);
      final preserve = base.unknownKeys(AcanthisUnknownKeys.preserve);
      final input = {
        'name': 'root',
        'children': [
          {'name': 'leaf', 'children': [], 'extra': 1},
        ],
      };
      expect(base.parseResult(input).isValid, isTrue);
      expect(strict.parseResult(input).issues.single.path, [
        'children',
        0,
        'extra',
      ]);
      expect(preserve.parseResult(input).value, input);
      expect(resolutions, 3);
      expect(entry.call(base), same(entry.call(base)));
      expect(entry.call(base), isNot(same(entry.call(strict))));
    },
  );

  test('hidden async descendants reject sync parsing before any validation callbacks', () async {
    var callbacks = 0;
    final schema = object({
      'first': integer().transform((v) {
        callbacks++;
        return v;
      }),
      'nested': lazy(
        (_) => object({
          'children': list(
            integer().refineAsync(
              CallbackAsyncCheck((v, context) async {
                callbacks++;
                if (v < 0) context.addIssue('remote');
              }),
            ),
          ),
        }),
      ),
    });
    expect(schema.isAsync, isTrue);
    expect(
      () => schema.parseResult({
        'first': 1,
        'nested': {
          'children': [-1],
        },
      }),
      throwsStateError,
    );
    expect(() => schema.tryParse(null), throwsStateError);
    expect(callbacks, 0);
    final result = await schema.tryParseAsync({
      'first': 1,
      'nested': {
        'children': [-1],
      },
    });
    expect(result.issues.single.path, ['nested', 'children', 0]);
    expect(callbacks, 2);
  });

  test('recursive async eligibility propagates across back edges without caching false', () async {
    late ObjectSchema a;
    late ObjectSchema b;
    a = object({
      'b': lazy((_) => b),
      'n': integer().refineAsync(CallbackAsyncCheck((_, _) async {})),
    }).optionals(['b']);
    b = object({'a': lazy((_) => a)}).optionals(['a']);
    expect(a.isAsync, isTrue);
    expect(b.isAsync, isTrue);
    expect(() => b.parseResult({}), throwsStateError);
    expect(list(b).isAsync, isTrue);
    expect(record(string(), b).isAsync, isTrue);
    expect(
      (await b.parseResultAsync({
        'a': {'n': 1},
      })).isValid,
      isTrue,
    );
  });

  test(
    'async wrapper operations retain ordering and isolate concurrent contexts',
    () async {
      var transforms = 0;
      final entry = lazy((_) => integer())
          .refineAsync(
            CallbackAsyncCheck((v, context) async {
              await Future<void>.value();
              if (v < 0) context.addIssue('remote', path: ['value']);
            }),
          )
          .refine(onCheck: (v) => v != 0, name: 'nonzero')
          .transformAsync(
            CallbackAsyncTransform((v) async {
              transforms++;
              return v + 1;
            }),
          );
      final parent = object({'n': entry});
      expect(parent.isAsync, isTrue);
      expect(() => parent.parseResult({'n': 1}), throwsStateError);
      final results = await Future.wait([
        parent.tryParseAsync({'n': -1}),
        parent.tryParseAsync({'n': 1}),
        parent.tryParseAsync({'n': 0}),
      ]);
      expect(results[0].issues.single.path, ['n', 'value']);
      expect(results[0].value, {'n': -1});
      expect(results[1].value, {'n': 2});
      expect(results[2].issues.single.code, 'nonzero');
      expect(transforms, 1);
      expect(entry.asyncChecks, hasLength(1));
      expect(() => entry.asyncChecks.clear(), throwsUnsupportedError);
    },
  );

  test('async resolved children and wrapper transformations work for recursive lists', () async {
    var resolutions = 0;
    final entry = lazy((parent) {
      resolutions++;
      return parent.list();
    }).transformAsync(CallbackAsyncTransform((v) async => v));
    final tree = object({'n': integer(), 'children': entry});
    expect(tree.isAsync, isTrue);
    expect(
      (await tree.parseResultAsync({
        'n': 1,
        'children': [
          {'n': 2, 'children': []},
        ],
      })).isValid,
      isTrue,
    );
    expect(resolutions, 1);
    final invalid = await tree.tryParseAsync({
      'n': 1,
      'children': [
        {'n': 'bad', 'children': []},
      ],
    }) as AcanthisInvalid<Map<String, Object?>>;
    expect(invalid.hasValue, isFalse);
    expect(invalid.issues.single.path, ['children', 0, 'n']);
  });

  test('invalid lazy aliases and reentrant resolver inspection fail without unbounded setup', () {
    late LazyEntry<Object?> entry;
    entry = lazy((_) => entry);
    expect(() => object({'x': entry}).isAsync, throwsStateError);
    late LazyEntry<Object?> a;
    late LazyEntry<Object?> b;
    a = lazy((parent) => b.call(parent));
    b = lazy((parent) => a.call(parent));
    expect(() => object({'x': a}).isAsync, throwsStateError);
    final reentrant = lazy((parent) {
      parent.isAsync;
      return integer();
    });
    expect(() => object({'x': reentrant}).isAsync, throwsStateError);
  });

  test('resolver errors are cached and callback errors propagate', () async {
    final error = StateError('resolver');
    var calls = 0;
    final parent = object({
      'x': lazy<int>((_) {
        calls++;
        throw error;
      }),
    });
    expect(() => parent.isAsync, throwsA(same(error)));
    expect(() => parent.parseResult({}), throwsA(same(error)));
    expect(calls, 1);
    final callback = object({
      'x': lazy((_) => integer()).transform((_) => throw error),
    });
    expect(() => callback.parseResult({'x': 1}), throwsA(same(error)));
    final asyncCallback = object({
      'x': lazy((_) => integer())
          .transformAsync(CallbackAsyncTransform((_) async => throw error)),
    });
    await expectLater(
      asyncCallback.parseResultAsync({'x': 1}),
      throwsA(same(error)),
    );
  });
}
