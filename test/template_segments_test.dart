import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'genuinely async throwing traversal stops before later segment checks',
    () async {
      final calls = <String>[];
      final schema = Acanthis.template([
        Acanthis.string().refineAsync(
          CallbackAsyncCheck((value, context) async {
            await Future<void>.delayed(Duration.zero);
            calls.add('first:$value');
            context.addIssue('first');
          }),
        ),
        '/',
        Acanthis.string().refineAsync(
          CallbackAsyncCheck((value, context) async {
            calls.add('second:$value');
            context.addIssue('second');
          }),
        ),
      ]);
      await expectLater(
        schema.parseAsync('a/b'),
        throwsA(isA<ValidationError>()),
      );
      expect(calls, ['first:a']);
      calls.clear();
      final result = await schema.tryParseAsync('a/b');
      expect(calls, ['first:a', 'second:b']);
      expect(result.issues.map((issue) => issue.code), ['first', 'second']);
      expect(result.issues.map((issue) => issue.path), [
        [0],
        [2],
      ]);
    },
  );

  test(
    'async ambiguous boundaries do not retry a failing refinement',
    () async {
      final seen = <String>[];
      final schema = Acanthis.template([
        Acanthis.string().refineAsync(
          CallbackAsyncCheck((value, context) async {
            seen.add(value);
            if (value != 'a') context.addIssue('boundary');
          }),
        ),
        Acanthis.string(),
      ]);
      final result = await schema.tryParseAsync('ab');
      expect(result.issues.single.code, 'boundary');
      expect(result.issues.single.path, [0]);
      expect(seen, ['ab']);
    },
  );

  test(
    'empty and Unicode substrings reach refinements without changing text',
    () async {
      final seen = <String>[];
      final schema = Acanthis.template([
        '[',
        Acanthis.string().refine(
          onCheck: (value) {
            seen.add(value);
            return value.isNotEmpty;
          },
        ),
        ']',
      ]);
      expect(schema.tryParse('[]').issues.single.path, [1]);
      expect(schema.parse('[🦜é\n]'), '[🦜é\n]');
      expect(await schema.parseAsync('[🦜é\n]'), '[🦜é\n]');
      expect(seen, ['', '🦜é\n', '🦜é\n']);
      expect(Acanthis.template(['']).parse(''), '');
    },
  );

  test(
    'coercion and invalid input retain segment checks on every entry point',
    () async {
      final seen = <String>[];
      final schema = Acanthis.template([
        Acanthis.string().refine(
          onCheck: (value) {
            seen.add(value);
            return value == '12';
          },
        ),
      ]).coerce();
      expect(schema.parse(12), '12');
      expect(await schema.parseAsync(12), '12');
      expect(schema.tryParse(true).isValid, isFalse);
      expect((await schema.tryParseAsync(true)).isValid, isFalse);
      expect(seen, ['12', '12', 'true', 'true']);
      for (final result in [
        schema.tryParse({}),
        await schema.tryParseAsync(null),
      ]) {
        expect(result.issues.single.code, 'type');
        expect((result as AcanthisInvalid<String>).hasValue, isFalse);
      }
      expect(seen, hasLength(4));
    },
  );

  test(
    'union and nullable wrapper transforms feed refinements exactly once',
    () async {
      final seen = <Object?>[];
      final segment = Acanthis.union<num>([Acanthis.number()])
          .transform((value) {
            seen.add(value);
            return value + 1;
          })
          .refine(onCheck: (value) => value == 3)
          .nullable()
          .transform((value) {
            seen.add(value);
            return value == null ? null : value * 2;
          })
          .refine(onCheck: (value) => value == 6);
      final schema = Acanthis.template([segment]);
      expect(schema.parse('2'), '2');
      expect(seen, [2, 3]);
      seen.clear();
      expect(await schema.parseAsync('2'), '2');
      expect(seen, [2, 3]);
    },
  );

  test(
    'failed segment checks prevent whole-template transformations',
    () async {
      var transforms = 0;
      final schema =
          Acanthis.template([
            Acanthis.string().refineAsync(
              CallbackAsyncCheck((_, context) async {
                context.addIssue('segment');
              }),
            ),
          ]).transformAsync(
            CallbackAsyncTransform((value) async {
              transforms++;
              return value.toUpperCase();
            }),
          );
      final result = await schema.tryParseAsync('bad');
      expect(result.issues.single.code, 'segment');
      expect(result.value, 'bad');
      await expectLater(
        schema.parseAsync('bad'),
        throwsA(isA<ValidationError>()),
      );
      expect(transforms, 0);
    },
  );

  test(
    'shape matcher reuse does not share diagnostics between templates',
    () async {
      final segment = Acanthis.string().refineAsync(
        CallbackAsyncCheck((value, context) async {
          await Future<void>.delayed(Duration.zero);
          if (value != 'ok') context.addIssue('segment');
        }),
      );
      final left = Acanthis.template(['left:', segment]);
      final right = Acanthis.template([segment, ':right']);
      final results = await Future.wait([
        left.tryParseAsync('left:bad'),
        right.tryParseAsync('ok:right'),
        left.tryParseAsync('left:ok'),
        right.tryParseAsync('bad:right'),
      ]);
      expect(results.map((result) => result.isValid), [
        false,
        true,
        true,
        false,
      ]);
      expect(results.first.issues.single.path, [1]);
      expect(results.last.issues.single.path, [0]);
      expect(results.first.value, 'left:bad');
      expect(results.last.value, 'bad:right');
    },
  );

  test('export rejects refinements hidden inside nested segment wrappers', () {
    var calls = 0;
    final child = Acanthis.string().refine(
      onCheck: (_) {
        calls++;
        return true;
      },
    );
    final schemas = [
      Acanthis.template([
        Acanthis.template(['inner:', child]),
      ]),
      Acanthis.template([child.nullable()]),
      Acanthis.template([
        Acanthis.union<String>([Acanthis.literal('ok'), child]),
      ]),
    ];
    for (final schema in schemas) {
      for (final mode in AcanthisSchemaMode.values) {
        expect(
          () => schema.toJsonSchema(mode: mode),
          throwsA(isA<AcanthisSchemaExportException>()),
        );
        expect(
          () => schema.toOpenApiSchema(mode: mode),
          throwsA(isA<AcanthisSchemaExportException>()),
        );
      }
    }
    expect(calls, 0);
  });

  test(
    'segment regex flags, unanchored matches and duplicate captures stay local',
    () {
      final first = Acanthis.string().pattern(
        RegExp(r'(?<letter>a)', caseSensitive: false),
      );
      final second = Acanthis.string().pattern(RegExp(r'(?<letter>b)'));
      final schema = Acanthis.template([first, '/', second]);
      expect(schema.parse('CAT/bob'), 'CAT/bob');
      expect(
        Acanthis.template([Acanthis.string().pattern(RegExp(r'\$'))])
            .parse(r'price$'),
        r'price$',
      );
      expect(
        Acanthis.template([
          Acanthis.string().pattern(RegExp(r'^a$', multiLine: true)),
        ]).parse('x\na\nx'),
        'x\na\nx',
      );
    },
  );
  test('async union and nullable wrappers apply their own checks', () async {
    final seen = <Object?>[];
    final child = Acanthis.number().refineAsync(
      CallbackAsyncCheck((n, c) async {
        seen.add(n);
        if (n < 2) c.addIssue('small');
      }),
    );
    final segment = Acanthis.union<Object?>([child, Acanthis.literal('other')])
        .refineAsync(
          CallbackAsyncCheck((v, c) async {
            seen.add(v);
          }),
        );
    final schema = Acanthis.template([
      segment.nullable().refineAsync(
        CallbackAsyncCheck((v, c) async {
          if (v == null) c.addIssue('nullValue');
        }),
      ),
    ]);
    expect(await schema.parseAsync('3'), '3');
    expect(seen, [3, 3]);
    expect((await schema.tryParseAsync('1')).issues.single.code, 'union');
    expect(
      (await schema.tryParseAsync('null')).issues.single.code,
      'nullValue',
    );
  });
  test(
    'string segment refinements see substrings through every entry point',
    () async {
      final seen = <String>[];
      final schema = Acanthis.template([
        'user:',
        Acanthis.string().refine(
          onCheck: (value) {
            seen.add(value);
            return value == 'alice';
          },
          name: 'username',
        ),
      ]);
      expect(schema.parse('user:alice'), 'user:alice');
      expect(schema.tryParse('user:alice').isValid, isTrue);
      expect(await schema.parseAsync('user:alice'), 'user:alice');
      expect((await schema.tryParseAsync('user:alice')).isValid, isTrue);
      expect(seen, List.filled(4, 'alice'));
      for (final result in [
        schema.tryParse('user:bob'),
        await schema.tryParseAsync('user:bob'),
      ]) {
        expect(result.issues.single.code, 'username');
        expect(result.issues.single.path, [1]);
        expect(result.value, 'user:bob');
      }
      expect(() => schema.parse('user:bob'), throwsA(isA<ValidationError>()));
      await expectLater(
        schema.parseAsync('user:bob'),
        throwsA(isA<ValidationError>()),
      );
    },
  );
  test(
    'built-in string length checks and numeric bounds run on typed segments',
    () {
      final seen = <num>[];
      final schema = Acanthis.template([
        Acanthis.string().min(2),
        ':',
        Acanthis.integer()
            .gte(10)
            .refine(
              onCheck: (n) {
                seen.add(n);
                return n.isEven;
              },
            ),
      ]);
      expect(schema.parse('ab:12'), 'ab:12');
      expect(seen, [12]);
      final result = schema.tryParse('a:3');
      expect(result.issues.map((i) => i.code), ['minLength', 'gte', 'custom']);
      expect(result.issues.map((i) => i.path), [
        [0],
        [2],
        [2],
      ]);
    },
  );
  test(
    'collecting visits segments; throwing stops before later callbacks',
    () async {
      var calls = 0;
      final schema = Acanthis.template([
        Acanthis.string().refine(onCheck: (_) => false),
        '/',
        Acanthis.string().refine(
          onCheck: (_) {
            calls++;
            return false;
          },
        ),
      ]);
      expect(() => schema.parse('a/b'), throwsA(isA<ValidationError>()));
      expect(calls, 0);
      expect(schema.tryParse('a/b').issues.length, 2);
      expect(calls, 1);
      await expectLater(
        schema.parseAsync('a/b'),
        throwsA(isA<ValidationError>()),
      );
      expect(calls, 1);
      expect((await schema.tryParseAsync('a/b')).issues.length, 2);
    },
  );
  test(
    'async segment checks propagate through containing compositions',
    () async {
      final seen = <String>[];
      final schema = Acanthis.template([
        '@',
        Acanthis.string().refineAsync(
          CallbackAsyncCheck((value, context) async {
            await Future<void>.delayed(Duration.zero);
            seen.add(value);
            if (value != 'ok') context.addIssue('username');
          }),
        ),
      ]);
      final object = Acanthis.object({'name': schema});
      expect(schema.isAsync, isTrue);
      expect(object.isAsync, isTrue);
      expect(() => schema.tryParse('@ok'), throwsStateError);
      expect(await schema.parseAsync('@ok'), '@ok');
      final results = await Future.wait([
        object.tryParseAsync({'name': '@bad'}),
        object.tryParseAsync({'name': '@ok'}),
      ]);
      expect(results.first.issues.single.path, ['name', 1]);
      expect(results.last.isValid, isTrue);
      expect(seen, containsAll(['ok', 'bad', 'ok']));
      await expectLater(
        schema.parseAsync('@bad'),
        throwsA(isA<ValidationError>()),
      );
    },
  );
  test(
    'segment transforms feed their checks without rewriting template text',
    () async {
      var calls = 0;
      final schema = Acanthis.template([
        '[',
        Acanthis.string()
            .transform((s) {
              calls++;
              return s.toUpperCase();
            })
            .refine(onCheck: (s) => s == 'OK'),
        ']',
      ]);
      expect(schema.parse('[ok]'), '[ok]');
      expect(calls, 1);
      final asynchronous = Acanthis.template([
        Acanthis.string()
            .transformAsync(
              CallbackAsyncTransform((s) async => s.toUpperCase()),
            )
            .refine(onCheck: (s) => s == 'OK'),
      ]);
      expect(await asynchronous.parseAsync('ok'), 'ok');
    },
  );
  test('ambiguous boundaries are greedy and callbacks are not retried', () {
    final seen = <String>[];
    final schema = Acanthis.template([
      Acanthis.string().refine(
        onCheck: (s) {
          seen.add(s);
          return s == 'a';
        },
      ),
      Acanthis.string(),
    ]);
    expect(schema.tryParse('ab').isValid, isFalse);
    expect(seen, ['ab']);
    expect(
      Acanthis.template([Acanthis.string(), '|', Acanthis.string()])
          .parse('a|b|c'),
      'a|b|c',
    );
  });
  test(
    'shape mismatches never execute callbacks and regex captures remain local',
    () {
      var calls = 0;
      final schema = Acanthis.template([
        'x:',
        Acanthis.string()
            .pattern(RegExp(r'^(a)\1$'))
            .refine(
              onCheck: (_) {
                calls++;
                return true;
              },
            ),
        ':',
        Acanthis.integer(),
      ]);
      expect(schema.parse('x:aa:1'), 'x:aa:1');
      expect(calls, 1);
      expect(schema.tryParse('y:aa:1').issues.single.code, 'templateLiteral');
      expect(calls, 1);
    },
  );
  test(
    'unions convert each candidate and execute branch and wrapper checks once',
    () async {
      final seen = <Object?>[];
      final segment =
          Acanthis.union<Object?>([
            Acanthis.number().refine(
              onCheck: (n) {
                seen.add(n);
                return false;
              },
            ),
            Acanthis.string().refine(
              onCheck: (s) {
                seen.add(s);
                return s == '12';
              },
            ),
          ]).refine(
            onCheck: (v) {
              seen.add(v);
              return true;
            },
          );
      final schema = Acanthis.template([segment]);
      expect(schema.parse('12'), '12');
      expect(seen, [12, '12', '12']);
      seen.clear();
      expect(await schema.parseAsync('12'), '12');
      expect(seen, [12, '12', '12']);
      final invalid = schema.tryParse('bad');
      expect(invalid.issues.single.branches.length, 2);
      expect(invalid.issues.single.path, [0]);
    },
  );
  test('nullable, boolean, double and nested template refinements', () {
    final nullable = Acanthis.template([Acanthis.number().gte(2).nullable()]);
    expect(nullable.parse('null'), 'null');
    expect(nullable.tryParse('1').issues.single.code, 'gte');
    expect(Acanthis.template([Acanthis.doubleType().gte(1.5)]).parse('2'), '2');
    expect(
      Acanthis.template([Acanthis.boolean().refine(onCheck: (b) => b)])
          .tryParse('false')
          .isValid,
      isFalse,
    );
    final nested = Acanthis.template([
      '[',
      Acanthis.template(['n=', Acanthis.integer().gte(2)]),
      ']',
    ]);
    expect(nested.parse('[n=3]'), '[n=3]');
    expect(nested.tryParse('[n=1]').issues.single.path, [1, 1]);
  });
  test(
    'refinement programming errors propagate in sync and async parsing',
    () async {
      final schema = Acanthis.template([
        Acanthis.string().refine(onCheck: (_) => throw StateError('bug')),
      ]);
      expect(() => schema.tryParse('x'), throwsStateError);
      await expectLater(schema.tryParseAsync('x'), throwsStateError);
      final asynchronous = Acanthis.template([
        Acanthis.string().refineAsync(
          CallbackAsyncCheck((_, _) async => throw StateError('bug')),
        ),
      ]);
      await expectLater(asynchronous.tryParseAsync('x'), throwsStateError);
    },
  );
  test('defaults, nullable wrappers, snapshots and all validation helpers retain segments', () async {
    final parts = <Object?>['x', Acanthis.string().min(2)];
    final schema = Acanthis.template(parts).withDefault('xab');
    parts.clear();
    expect(schema.parse(null), 'xab');
    expect(schema.validate('xa'), isFalse);
    expect(schema.tryValidate('xab'), isTrue);
    expect(await schema.validateAsync('xa'), isFalse);
    expect(await schema.tryValidateAsync('xab'), isTrue);
    expect(schema.nullable().parse(null), 'xab');
    expect(schema.list().tryParse(['xa']).issues.single.path, [0, 1]);
  });
  test('export refuses segment constraints without executing callbacks', () {
    var calls = 0;
    final schema = Acanthis.template([
      Acanthis.string().refine(
        onCheck: (_) {
          calls++;
          return true;
        },
      ),
    ]);
    for (final mode in AcanthisSchemaMode.values) {
      expect(
        () => schema.toJsonSchema(mode: mode),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    }
    expect(calls, 0);
    expect(
      () =>
          Acanthis.template([Acanthis.number().gte(2)])
              .toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
  });
}
