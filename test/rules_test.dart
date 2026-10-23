import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

ObjectSchema matching({void Function()? called}) =>
    object({
      'password': string().trim(),
      'confirm': string(),
      'other': boolean(),
    }).checkFields(
      ['password', 'confirm'],
      at: 'confirm',
      name: 'passwordMismatch',
      error: 'Passwords do not match',
      check: (fields) {
        called?.call();
        return fields['password'] == fields['confirm'];
      },
    );

void main() {
  test(
    'selected rules consume parsed fields once and ignore unrelated failures',
    () async {
      var transforms = 0;
      var checks = 0;
      final schema = matching(called: () => checks++).merge({
        'password': string().transform((s) {
          transforms++;
          return s.trim();
        }),
      });
      final input = {'password': ' a ', 'confirm': 'b', 'other': 1};
      for (final result in [
        schema.tryParse(input),
        await schema.tryParseAsync(input),
      ]) {
        expect(result.issues.map((i) => i.code), ['type', 'passwordMismatch']);
        expect(result.issues.last.path, ['confirm']);
        expect((result as AcanthisInvalid).hasValue, isFalse);
        expect(result.issues.last.message, 'Passwords do not match');
        expect(result.issues.last.parameters, isEmpty);
      }
      expect(checks, 2);
      expect(transforms, 2);
      expect(schema.validate(input), isFalse);
      expect(await schema.validateAsync(input), isFalse);
      expect(checks, 2); // Throwing/fail-fast traversal never reaches the rule.
      expect(
        schema.parse({
          'password': ' a ',
          'confirm': 'a',
          'other': true,
        })['password'],
        'a',
      );
    },
  );

  test(
    'invalid selected inputs, including recovery, skip checks and conditions',
    () async {
      var calls = 0;
      final schema = object({'a': string().min(2), 'b': string()})
          .checkFieldsAsync(
            ['a', 'b'],
            at: 'b',
            name: 'compare',
            when: (_) {
              calls++;
              return true;
            },
            check: (_) async {
              calls++;
              return false;
            },
          );
      expect(schema.isAsync, isTrue);
      expect(() => schema.tryParse({'a': 'ok', 'b': 'ok'}), throwsStateError);
      expect(
        (await schema.tryParseAsync({'a': '', 'b': 'ok'})).issues.single.code,
        'minLength',
      );
      expect(calls, 0);
      expect(
        (await schema.tryParseAsync({'a': 'ok', 'b': 'ok'})).issues.single.code,
        'compare',
      );
      expect(calls, 2);
    },
  );

  test('missing, null and defaulted presence remain distinct', () {
    final observed = <(AcanthisFieldStatus, Object?, bool)>[];
    final schema = object({'a': boolean().nullable().withDefault(null)})
        .checkFields(
          ['a'],
          at: 'a',
          name: 'presence',
          allowMissing: true,
          check: (fields) {
            final state = fields.state('a');
            observed.add((state.status, state.value, state.submitted));
            if (state.status == AcanthisFieldStatus.missing) {
              expect(() => fields.value<bool>('a'), throwsStateError);
            }
            return true;
          },
        );
    expect(schema.validate({}), isTrue);
    expect(schema.validate({'a': null}), isTrue);
    expect(schema.patch().validate({}), isTrue);
    expect(observed, [
      (AcanthisFieldStatus.valid, null, false),
      (AcanthisFieldStatus.valid, null, true),
      (AcanthisFieldStatus.missing, null, false),
    ]);
    var calls = 0;
    final ordinary = object({'a': boolean()})
        .optionals(['a'])
        .checkFields(
          ['a'],
          at: 'a',
          name: 'missing',
          check: (_) {
            calls++;
            return true;
          },
        );
    expect(ordinary.validate({}), isTrue);
    expect(calls, 0);
  });

  test('conditional requirements gate invalid inputs and distinguish omitted defaults', () {
    final schema =
        object({'business': boolean(), 'id': string().withDefault('generated')})
            .checkFields(
              ['business', 'id'],
              at: 'id',
              name: 'required',
              allowMissing: true,
              when: (f) => f.value<bool>('business'),
              check: (f) => f.state('id').submitted,
            );
    expect(schema.tryParse({'business': true}).issues.single.path, ['id']);
    expect(schema.validate({'business': false}), isTrue);
    expect(schema.validate({'business': true, 'id': 'id'}), isTrue);
    expect(schema.tryParse({'business': 1}).issues.single.code, 'type');
  });

  test('nested object/list/tuple paths retain valid siblings without typed recovery', () async {
    var transforms = 0;
    final child = object({
      'good': string().transform((s) {
        transforms++;
        return s.trim();
      }),
      'bad': boolean(),
    });
    final selectors = <List<Object>>[
      ['child', 'good'],
      ['items', 0, 'good'],
      ['tuple', 0, 'good'],
    ];
    final schema =
        object({
          'child': child,
          'items': child.list(),
          'tuple': tuple([child]),
        }).checkFields(
          selectors,
          at: ['child', 'good'],
          name: 'selected',
          check: (f) {
            expect(selectors.map((p) => f.value<String>(p)), [
              'parsed',
              'parsed',
              'parsed',
            ]);
            return false;
          },
        );
    final input = {
      'child': {'good': ' parsed ', 'bad': 1},
      'items': [
        {'good': ' parsed ', 'bad': 1},
      ],
      'tuple': [
        {'good': ' parsed ', 'bad': 1},
      ],
    };
    for (final result in [
      schema.tryParse(input),
      await schema.tryParseAsync(input),
    ]) {
      expect(result.issues.map((i) => i.code), [
        'type',
        'type',
        'type',
        'selected',
      ]);
      expect((result as AcanthisInvalid).hasValue, isFalse);
      expect(() => result.value, throwsStateError);
    }
    expect(transforms, 6);
  });

  test('nested list selectors handle missing indices, dotted keys and nullable parents', () {
    var calls = 0;
    final schema =
        object({
          'a.b': string(),
          'items': list(object({'name': string()}).nullable()),
        }).checkFields(
          [
            'a.b',
            ['items', 1, 'name'],
          ],
          at: 'a.b',
          name: 'nested',
          allowMissing: true,
          check: (f) {
            calls++;
            expect(f['a.b'], 'a');
            expect(
              f.state(['items', 1, 'name']).status,
              AcanthisFieldStatus.missing,
            );
            return true;
          },
        );
    expect(
      schema.validate({
        'a.b': 'a',
        'items': [null],
      }),
      isTrue,
    );
    expect(calls, 1);
    expect(AcanthisPath(['a']).overlaps(AcanthisPath(['a', 0])), isTrue);
    expect(AcanthisPath(['a.b']), isNot(AcanthisPath(['a', 'b'])));
  });

  test('rule issues do not gate later rules and root transforms stop after failure', () {
    final calls = <String>[];
    var schema = object({'a': string()});
    for (final id in ['first', 'second']) {
      schema = schema.checkFields(
        ['a'],
        at: 'a',
        name: id,
        check: (_) {
          calls.add(id);
          return false;
        },
      );
    }
    schema = schema.transform((value) {
      calls.add('transform');
      return value;
    });
    expect(schema.tryParse({'a': 'a'}).issues.map((i) => i.code), [
      'first',
      'second',
    ]);
    expect(calls, ['first', 'second']);
    calls.clear();
    expect(schema.parseOutcome({'a': 'a'}).issues.single.code, 'first');
    expect(calls, ['first']);
  });

  test('declarations, snapshots, undeclared reads and output ownership are checked', () {
    final paths = <Object>['a'];
    final rule = AcanthisRule<void>(
      id: 'r',
      inputs: paths,
      outputs: paths,
      check: (_, _) => [],
    );
    paths.clear();
    expect(rule.inputs.single.segments, ['a']);
    final schema = object({'a': string()}).rule(rule);
    expect(() => schema.rule(rule), throwsArgumentError);
    expect(() => object({}).rule(rule), throwsArgumentError);
    expect(() => schema.omit(['a']), throwsArgumentError);
    expect(() => AcanthisPath([]), throwsArgumentError);
    expect(() => AcanthisPath([-1]), throwsArgumentError);
    expect(() => AcanthisPath([true]), throwsArgumentError);
    expect(() => schema.rules.clear(), throwsUnsupportedError);
    final read = object({'a': string(), 'b': string()})
        .checkFields(['a'], at: 'b', name: 'read', check: (f) => f['b'] == 'b');
    expect(() => read.tryParse({'a': 'a', 'b': 'b'}), throwsArgumentError);
    final output = object({'a': string(), 'b': string()}).rule(
      AcanthisRule<void>(
        id: 'output',
        inputs: ['a'],
        outputs: ['a'],
        check: (_, _) => [
          AcanthisIssue(path: ['b'], code: 'bad'),
        ],
      ),
    );
    expect(() => output.tryParse({'a': 'a', 'b': 'b'}), throwsStateError);
    final bad = object({'a': string()}).checkFields(
      ['a'],
      at: 'a',
      name: 'bad',
      check: (_) => throw StateError('programming error'),
    );
    expect(() => bad.tryParse({'a': 'a'}), throwsStateError);
  });

  test(
    'helpers and lazy parents retain rule behavior and async eligibility',
    () async {
      var resolutions = 0;
      final base =
          object({
            'a': boolean(),
            'children': lazy((parent) {
              resolutions++;
              return parent.patch().list();
            }),
          }).checkFieldsAsync(
            ['a'],
            at: 'a',
            name: 'true',
            check: (f) async => f['a'] == true,
          );
      final derived = [
        base.extend({}),
        base.merge({}),
        base.pick(['a', 'children']),
        base.omit([]),
        base.patch(),
        base.passthrough(),
      ];
      expect(resolutions, 0);
      for (final schema in derived) {
        expect(schema.isAsync, isTrue);
        expect(
          (await schema.tryParseAsync({'a': false, 'children': []}))
              .issues
              .single
              .code,
          'true',
        );
      }
      final nested = await base.tryParseAsync({
        'a': true,
        'children': [
          {'a': false},
        ],
      });
      expect(nested.issues.single.path, ['children', 0, 'a']);
    },
  );

  test('legacy dependencies retain raw queries, null failure and unrelated-error execution', () async {
    final seen = <Object?>[];
    final schema =
        object({'a': number().coerce(), 'b': number(), 'other': boolean()})
            .addFieldDependency(
              dependent: 'b',
              dependendsOn: 'a',
              dependency: (from, to) {
                seen.add(from);
                return from == to;
              },
            );
    for (final result in [
      schema.tryParse({'a': '1', 'b': 1, 'other': 1}),
      await schema.tryParseAsync({'a': '1', 'b': 1, 'other': 1}),
    ]) {
      expect(result.issues.map((i) => i.code), ['type', 'dependency']);
      expect(result.issues.last.parameters, {'dependsOn': 'a'});
    }
    expect(seen, ['1', '1']);
    expect(schema.tryParse({'b': 1, 'other': true}).issues.map((i) => i.code), [
      'required',
      'dependency',
    ]);
    final nested = object({'items': list(number()), 'total': number()})
        .addFieldDependency(
          dependent: 'total',
          dependendsOn: 'items.[0]',
          dependency: (a, b) => a == b,
        );
    expect(
      nested.validate({
        'items': [1],
        'total': 1,
      }),
      isTrue,
    );
    expect(nested.validate({'items': [], 'total': 1}), isFalse);
    final negative = nested.addFieldDependency(
      dependent: 'total',
      dependendsOn: 'items.[-1]',
      dependency: (_, _) => true,
    );
    expect(
      negative.validate({
        'items': [1],
        'total': 1,
      }),
      isFalse,
    );
    for (final derived in [
      schema.extend({}),
      schema.merge({}),
      schema.pick(['a', 'b', 'other']),
      schema.omit([]),
    ]) {
      expect(derived.validate({'a': '1', 'b': 1, 'other': true}), isFalse);
    }
  });

  test(
    'typed context is isolated across concurrent calls and nested async checks',
    () async {
      final schema =
          object({
            'a': string().refineAsync(
              CallbackAsyncCheck((value, check) async {
                await Future<void>.delayed(Duration.zero);
                if (check.contextAs<String>() != value) {
                  check.addIssue('context');
                }
              }),
            ),
          }).rule(
            AcanthisRule<String>.async(
              id: 'scope',
              inputs: ['a'],
              outputs: ['a'],
              check: (fields, context) async {
                await Future<void>.delayed(Duration.zero);
                expect(
                  context,
                  AcanthisValidationScope.current.contextAs<String>(),
                );
                return fields['a'] == context
                    ? []
                    : [
                        AcanthisIssue(path: ['a'], code: 'scope'),
                      ];
              },
            ),
          );
      final results = await Future.wait([
        for (final value in ['one', 'two'])
          AcanthisValidationScope(context: value)
              .run(() => schema.tryParseAsync({'a': value})),
      ]);
      expect(results.every((r) => r.isValid), isTrue);
      expect(AcanthisValidationScope.current.context, isNull);
      expect(
        () =>
            const AcanthisValidationScope(context: 1)
                .run(() => throw StateError('failure')),
        throwsStateError,
      );
      expect(AcanthisValidationScope.current.context, isNull);
    },
  );

  test('field and object stopping policies remain independent', () async {
    var remote = 0;
    final field = string()
        .min(2)
        .refineAsync(
          CallbackAsyncCheck((_, check) async {
            remote++;
            check.addIssue('remote');
          }),
        );
    final schema = object({'a': field, 'b': boolean()});
    final all = await const AcanthisValidationScope(
      fieldPolicy: AcanthisCollectionPolicy.first,
    ).run(() => schema.tryParseAsync({'a': '', 'b': 1}));
    expect(all.issues.map((i) => i.code), ['minLength', 'type']);
    expect(remote, 0);
    final first = await const AcanthisValidationScope(
      objectPolicy: AcanthisCollectionPolicy.first,
    ).run(() => schema.tryParseAsync({'a': '', 'b': 1}));
    expect(first.issues.map((i) => i.code), ['minLength', 'remote']);
    expect(remote, 1);
    for (final value in <Schema<Object?, Object?>>[
      number().gte(2).lte(-1),
      boolean().isTrue().isFalse(),
      list(boolean()).min(2).max(-1),
    ]) {
      final result =
          const AcanthisValidationScope(
            fieldPolicy: AcanthisCollectionPolicy.first,
          ).run(
            () => value.tryParse(
              value is AcanthisNumeric
                  ? 0
                  : value is AcanthisBoolean
                  ? false
                  : [],
            ),
          );
      expect(result.issues.length, 1);
    }
  });

  test('pre-cancellation and cancellation after a synchronous callback throw control flow', () {
    final signal = AcanthisCancellationSignal()
      ..cancel()
      ..cancel();
    expect(signal.isCancelled, isTrue);
    expect(
      () =>
          AcanthisValidationScope(cancellation: signal)
              .run(() => boolean().tryParse(true)),
      throwsA(isA<AcanthisValidationCancelled>()),
    );
    final active = AcanthisCancellationSignal();
    var later = 0;
    final schema = object({
      'a': string().transform((value) {
        active.cancel();
        return value;
      }),
      'b': string().refine(
        onCheck: (_) {
          later++;
          return true;
        },
      ),
    });
    expect(
      () =>
          AcanthisValidationScope(cancellation: active)
              .run(() => schema.tryParse({'a': 'a', 'b': 'b'})),
      throwsA(isA<AcanthisValidationCancelled>()),
    );
    expect(later, 0);
  });

  test('cancellation after awaited rules discards results and skips subsequent work', () async {
    final signal = AcanthisCancellationSignal();
    final started = Completer<void>();
    final release = Completer<void>();
    var later = 0;
    final schema = object({'a': boolean()})
        .checkFieldsAsync(
          ['a'],
          at: 'a',
          name: 'remote',
          check: (_) async {
            if (!started.isCompleted) started.complete();
            await release.future;
            return true;
          },
        )
        .checkFields(
          ['a'],
          at: 'a',
          name: 'later',
          check: (_) {
            later++;
            return true;
          },
        );
    final future = AcanthisValidationScope(cancellation: signal)
        .run(() => schema.tryParseAsync({'a': true}));
    final cancelled = expectLater(
      future,
      throwsA(isA<AcanthisValidationCancelled>()),
    );
    await started.future;
    signal.cancel();
    await signal.whenCancelled;
    release.complete();
    await cancelled;
    expect(later, 0);
    expect((await schema.tryParseAsync({'a': false})).isValid, isTrue);
  });

  test('async cancellation is checked after final field and transformation callbacks', () async {
    for (final schemaFactory
        in <Schema<Object?, Object?> Function(AcanthisCancellationSignal)>[
          (s) => string().transformAsync(
            CallbackAsyncTransform((v) async {
              s.cancel();
              return v;
            }),
          ),
          (s) => number().refineAsync(
            CallbackAsyncCheck((_, _) async {
              s.cancel();
            }),
          ),
          (s) => boolean().refineAsync(
            CallbackAsyncCheck((_, _) async {
              s.cancel();
            }),
          ),
          (s) => list(boolean()).transformAsync(
            CallbackAsyncTransform((v) async {
              s.cancel();
              return v;
            }),
          ),
          (s) => object({}).transformAsync(
            CallbackAsyncTransform((v) async {
              s.cancel();
              return v;
            }),
          ),
        ]) {
      final signal = AcanthisCancellationSignal();
      final schema = schemaFactory(signal) as AsyncSchema<Object?, Object?>;
      final input = schema is AcanthisString
          ? 'a'
          : schema is AcanthisNumeric
          ? 1
          : schema is AcanthisBoolean
          ? true
          : schema is AcanthisList
          ? []
          : {};
      await expectLater(
        AcanthisValidationScope(cancellation: signal)
            .run(() => schema.tryParseAsync(input)),
        throwsA(isA<AcanthisValidationCancelled>()),
      );
    }
  });

  test('rule and dependency exports fail without running callbacks', () {
    var calls = 0;
    final base = object({'a': string()});
    for (final schema in [
      base.checkFields(
        ['a'],
        at: 'a',
        name: 'rule',
        check: (_) {
          calls++;
          return true;
        },
      ),
      base.addFieldDependency(
        dependent: 'a',
        dependendsOn: 'a',
        dependency: (_, _) {
          calls++;
          return true;
        },
      ),
    ]) {
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
}
