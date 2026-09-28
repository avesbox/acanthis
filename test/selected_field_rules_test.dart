import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final password = AcanthisPath(['password']);
final confirm = AcanthisPath(['confirm']);
AcanthisRule<void> matching({void Function()? called}) => AcanthisRule<void>(
  id: 'matching',
  inputs: [password, confirm],
  outputs: [confirm],
  check: (values, _) {
    called?.call();
    return values.value<String>(password) == values.value<String>(confirm)
        ? []
        : [
            AcanthisIssue(
              path: confirm.segments,
              code: 'mismatch',
              message: 'Passwords differ',
            ),
          ];
  },
);

void main() {
  test(
    'selected valid inputs run despite unrelated errors; transforms run once',
    () async {
      var transforms = 0;
      var checks = 0;
      final schema = object({
        'password': string().transform((s) {
          transforms++;
          return s.trim();
        }),
        'confirm': string(),
        'email': string().email(),
      }).rule(matching(called: () => checks++));
      final raw = {'password': ' a ', 'confirm': 'b', 'email': 'invalid'};
      final result = schema.tryParse(raw) as AcanthisInvalid;
      expect(result.issues.map((i) => i.path.first), ['email', 'confirm']);
      expect(transforms, 1);
      expect(checks, 1);
      final asyncResult = await schema.tryParseAsync(raw) as AcanthisInvalid;
      expect(asyncResult.issues, result.issues);
      expect(transforms, 2);
      expect(() => schema.parse(raw), throwsA(isA<ValidationError>()));
    },
  );

  test('invalid and failed pipeline prerequisites skip rules', () {
    var checks = 0;
    final schema = object({'password': string().min(2), 'confirm': string()})
        .rule(matching(called: () => checks++));
    schema.tryParse({'password': 1, 'confirm': 'a'});
    schema.tryParse({'password': 'a', 'confirm': 'a'});
    expect(checks, 0);
  });

  test('presence rules distinguish omission, null, invalid and defaults', () {
    final kind = AcanthisPath(['kind']);
    final id = AcanthisPath(['id']);
    final rule = AcanthisRule<void>(
      id: 'business',
      inputs: [kind, id],
      outputs: [id],
      allowMissing: true,
      when: (v, _) => v.value<String>(kind) == 'business',
      check: (v, _) => v.state(id).submitted
          ? []
          : [
              AcanthisIssue(
                path: ['id'],
                code: 'required',
                message: 'Business ID required',
              ),
            ],
    );
    final schema = object({'kind': string(), 'id': string().min(1)})
        .optionals(['id'])
        .rule(rule);
    expect(
      (schema.tryParse({
        'kind': 'business',
      }) as AcanthisInvalid).issues.single.code,
      'required',
    );
    expect(schema.tryParse({'kind': 'personal'}).isValid, true);
    expect(
      (schema.tryParse({
        'kind': 'business',
        'id': null,
      }) as AcanthisInvalid).issues.single.code,
      'type',
    );
    expect(
      (schema.tryParse({
        'kind': 'business',
        'id': '',
      }) as AcanthisInvalid).issues.length,
      1,
    );
    final defaulted = object({
      'kind': string(),
      'id': string().withDefault('auto'),
    }).rule(rule);
    expect(defaulted.tryParse({'kind': 'business'}).isValid, false);
  });

  test(
    'context is typed, nested and isolated across concurrent requests',
    () async {
      final path = AcanthisPath(['value']);
      final child = object({'value': string()}).rule(
        AcanthisRule<String>.async(
          id: 'context',
          inputs: [path],
          outputs: [path],
          check: (v, context) async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
            expect(
              AcanthisValidationScope.current.contextAs<String>(),
              context,
            );
            return v.value<String>(path) == context
                ? []
                : [
                    AcanthisIssue(
                      path: ['value'],
                      code: 'context',
                      message: 'Wrong tenant',
                    ),
                  ];
          },
        ),
      );
      final schema = object({'children': child.list()});
      final results = await Future.wait([
        for (final context in ['a', 'b'])
          AcanthisValidationScope(context: context).run(
            () => schema.tryParseAsync({
              'children': [
                {'value': context},
              ],
            }),
          ),
      ]);
      expect(results.every((r) => r.isValid), true);
      expect(AcanthisValidationScope.current.context, isNull);
    },
  );

  test(
    'declarations, access, output ownership and callback errors are checked',
    () {
      final schema = object({'password': string(), 'confirm': string()})
          .rule(matching());
      expect(() => schema.rule(matching()), throwsArgumentError);
      expect(
        () => object({'password': string()}).rule(matching()),
        throwsArgumentError,
      );
      AcanthisMap bad(
        List<AcanthisIssue> Function(AcanthisRuleInputs, void) check,
      ) => object({'password': string()}).rule(
        AcanthisRule<void>(
          id: 'bad',
          inputs: [password],
          outputs: [password],
          check: check,
        ),
      );
      expect(
        () => bad((v, _) {
          v.state(confirm);
          return [];
        }).tryParse({'password': 'a'}),
        throwsArgumentError,
      );
      expect(
        () => bad(
          (v, _) => [
            AcanthisIssue(path: ['confirm'], code: 'x', message: 'x'),
          ],
        ).tryParse({'password': 'a'}),
        throwsStateError,
      );
      expect(
        () =>
            bad((v, _) => throw StateError('application'))
                .tryParse({'password': 'a'}),
        throwsStateError,
      );
    },
  );
  test(
    'pipeline failures skip rules without running downstream transforms',
    () {
      var transformed = 0;
      var called = 0;
      final schema = object({
        'password': string()
            .min(2)
            .pipe(
              string(),
              transform: (v) {
                transformed++;
                return v;
              },
            ),
        'confirm': string(),
      }).rule(matching(called: () => called++));
      expect(schema.tryParse({'password': '', 'confirm': ''}).isValid, false);
      expect(transformed, 0);
      expect(called, 0);
    },
  );

  test(
    'async rule errors propagate and failed rules do not gate later rules',
    () async {
      final first = AcanthisRule<void>.async(
        id: 'first',
        inputs: [password],
        outputs: [password],
        check: (v, _) async => [
          AcanthisIssue(path: ['password'], code: 'first', message: 'First'),
        ],
      );
      final second = AcanthisRule<void>.async(
        id: 'second',
        inputs: [password],
        outputs: [password],
        check: (v, _) async => [
          AcanthisIssue(path: ['password'], code: 'second', message: 'Second'),
        ],
      );
      final schema = object({'password': string()}).rule(first).rule(second);
      final result =
          await schema.tryParseAsync({'password': 'valid'}) as AcanthisInvalid;
      expect(result.issues.map((i) => i.code), ['first', 'second']);
      final broken = object({'password': string()}).rule(
        AcanthisRule<void>.async(
          id: 'broken',
          inputs: [password],
          outputs: [password],
          check: (v, _) async => throw StateError('application'),
        ),
      );
      await expectLater(
        broken.tryParseAsync({'password': 'valid'}),
        throwsStateError,
      );
      await expectLater(
        broken.parseAsync({'password': 'valid'}),
        throwsStateError,
      );
    },
  );

  test(
    'rule declarations stay immutable and incompatible schema edits reject',
    () {
      final schema = object({'password': string(), 'confirm': string()})
          .rule(matching());
      expect(() => schema.rules.clear(), throwsUnsupportedError);
      expect(() => schema.rules.first.inputs.clear(), throwsUnsupportedError);
      expect(() => password.segments.clear(), throwsUnsupportedError);
      expect(() => schema.omit(['password']), throwsArgumentError);
      expect(
        () => schema.exportJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
      expect(
        () => schema.exportOpenApiSchema(mode: AcanthisSchemaMode.output),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    },
  );
  test('checkFields uses field names and retains incremental scheduling', () {
    final schema =
        object({
          'password': string(),
          'confirm': string(),
          'email': string().email(),
        }).checkFields(
          ['password', 'confirm'],
          at: 'confirm',
          name: 'match',
          error: 'Passwords differ',
          check: (fields) => fields['password'] == fields['confirm'],
        );
    final session = schema.watch({
      'password': 'a',
      'confirm': 'b',
      'email': 'bad',
    });
    expect(session.issues.map((i) => i.code), contains('match'));
    final delta = session.set('confirm', 'a');
    expect(delta.executedFields, {'confirm'});
    expect(delta.executedRules, {'match'});
    expect(delta.removedIssues.single.code, 'match');
  });

  test(
    'paths normalize literal keys and nested lists without ambiguity',
    () async {
      final nested = <Object>['items', 0, 'name'];
      final rule = AcanthisRule<void>(
        id: 'nested',
        inputs: [nested, 'a.b'],
        outputs: [nested],
        check: (fields, _) => fields[['items', 0, 'name']] == fields['a.b']
            ? []
            : [
                AcanthisIssue(
                  path: ['items', 0, 'name'],
                  code: 'nested',
                  message: 'Mismatch',
                ),
              ],
      );
      nested[0] = 'mutated';
      final schema = object({
        'items': object({'name': string()}).list(),
        'a.b': string(),
      }).rule(rule);
      final initial = {
        'items': [
          {'name': 'a'},
        ],
        'a.b': 'a',
      };
      final session = schema.watch(initial);
      expect(
        session.setPath(['items', 0, 'name'], 'b').addedIssues.single.code,
        'nested',
      );
      final asyncSession = await schema.watchAsync(initial);
      expect(
        (await asyncSession.setPath(['items', 0, 'name'], 'b')).issues,
        session.issues,
      );
      expect(() => AcanthisPath.from(1), throwsArgumentError);
      expect(() => AcanthisPath.from(['items', -1]), throwsArgumentError);
    },
  );

  test(
    'checkFields supports conditional presence and undeclared read guards',
    () {
      final schema = object({'kind': string(), 'id': string()})
          .optionals(['id'])
          .checkFields(
            ['kind', 'id'],
            at: 'id',
            name: 'required',
            error: 'ID required',
            allowMissing: true,
            when: (fields) => fields['kind'] == 'business',
            check: (fields) => fields.state('id').submitted,
          );
      expect(schema.tryParse({'kind': 'personal'}).isValid, true);
      expect(schema.tryParse({'kind': 'business'}).isValid, false);
      final broken = object({'a': string(), 'b': string()}).checkFields(
        ['a'],
        at: 'a',
        name: 'bad',
        error: 'bad',
        check: (fields) => fields['b'] == 'ok',
      );
      expect(
        () => broken.tryParse({'a': 'ok', 'b': 'ok'}),
        throwsArgumentError,
      );
    },
  );

  test(
    'checkFieldsAsync preserves errors, exceptions and prerequisite gating',
    () async {
      var calls = 0;
      final schema = object({'a': string().min(1)}).checkFieldsAsync(
        ['a'],
        at: 'a',
        name: 'remote',
        error: 'Unavailable',
        check: (fields) async {
          calls++;
          if (fields['a'] == 'throw') throw StateError('service');
          return false;
        },
      );
      await schema.tryParseAsync({'a': ''});
      expect(calls, 0);
      final result =
          await schema.tryParseAsync({'a': 'valid'}) as AcanthisInvalid;
      expect(result.issues.single.code, 'remote');
      await expectLater(schema.tryParseAsync({'a': 'throw'}), throwsStateError);
    },
  );
}
