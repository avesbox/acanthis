import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:test/test.dart';

class _GenericString extends AcanthisString {}

void main() {
  test('live full validation preserves cross-field diagnostic order', () async {
    final schema = object({'a': string().email(), 'b': string().email()})
        .addFieldDependency(
          dependent: 'a',
          dependendsOn: 'b',
          dependency: (_, _) => false,
        );
    final input = {'a': 'bad', 'b': 'bad'};
    final expected = schema.tryParse(input).issues;
    expect(expected.map((issue) => issue.path), [
      ['a'],
      ['b'],
      ['a'],
    ]);
    final sync = schema.watch(input);
    expect(sync.issues, expected);
    expect((await schema.watchAsync(input)).issues, expected);
    sync.set('a', 'still bad');
    expect(sync.issues, expected);
  });
  test(
    'literal and template async diagnostics match sync constraints',
    () async {
      for (final schema in <AcanthisType<String>>[
        literal('ok'),
        template(['ok-', string()]),
      ]) {
        final async = schema.refineAsync(
          onCheck: (_) async => true,
          error: '',
          name: 'pass',
        );
        expect(
          (await async.tryParseAsync('bad')).issues,
          schema.tryParse('bad').issues,
        );
        expect(schema.tryParse('bad').issues.single.parameters, isNotEmpty);
      }
      final transform = string().transform((_) => (42 as dynamic) as String);
      final async = transform.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      expect(
        (await async.tryParseAsync('x')).issues,
        transform.tryParse('x').issues,
      );
    },
  );
  test('same-code constraints retain order and legacy errors are lossy', () {
    final result = string().min(3).min(5).tryParse('x');
    expect(result.issues.map((issue) => issue.code), [
      'minLength',
      'minLength',
    ]);
    expect(result.issues.map((issue) => issue.parameters), [
      {'value': 3},
      {'value': 5},
    ]);
    expect(result.issues.map((issue) => issue.path), [[], []]);
    expect(result.errors, {'minLength': result.issues.last.message});
    expect((result.toOutcome() as AcanthisInvalid).issues, result.issues);
  });

  test(
    'collection and child reuse never overwrite or retain another input',
    () {
      final schema = string().email().email().list();
      final result = schema.tryParse(['bad', 'ok@example.com', 'bad']);
      expect(result.issues.map((issue) => issue.path), [
        [0],
        [0],
        [2],
        [2],
      ]);
      schema.tryParse(['good@example.com']);
      expect(result.issues, hasLength(4));
      expect(() => result.issues.clear(), throwsUnsupportedError);
    },
  );

  test('paths preserve escaped keys, empty keys, dots, and numeric text', () {
    final result =
        object({
          'a/b~c.d': object({'0': string().email().list()}),
          '': string().email(),
        }).tryParse({
          'a/b~c.d': {
            '0': ['bad'],
          },
          '': 'bad',
        });
    expect(result.issues.first.path, ['a/b~c.d', '0', 0]);
    expect(result.issues.first.path[1], isA<String>());
    expect(result.issues.first.path[2], isA<int>());
    expect(result.issues.map((issue) => issue.jsonPointer), [
      '/a~1b~0c.d/0/0',
      '/',
    ]);
    final json = jsonDecode(result.issues.formatJson()) as List;
    expect(json.first['path'], ['a/b~c.d', '0', 0]);
  });

  test('parent checks and identically named fields both survive', () {
    final result = object({'same': string().email()})
        .refine(onCheck: (_) => false, name: 'same', error: 'Object rule')
        .tryParse({'same': 'bad'});
    expect(result.issues.map((issue) => issue.path), [
      ['same'],
      [],
    ]);
    expect(result.errors, {'same': 'Object rule'});
  });

  test('formatters resolve messages at presentation time', () {
    final issues = string().min(3).min(5).tryParse('x').issues;
    String? resolver(String code, Map<String, Object?> params) =>
        code == 'minLength' ? 'Almeno ${params['value']} caratteri' : null;
    expect(issues.formatFields(resolver: resolver), {
      '': ['Almeno 3 caratteri', 'Almeno 5 caratteri'],
    });
    expect(issues.formatTree(resolver: resolver).messages, [
      'Almeno 3 caratteri',
      'Almeno 5 caratteri',
    ]);
    expect(
      jsonDecode(issues.formatJson(resolver: resolver))[0]['message'],
      'Almeno 3 caratteri',
    );
    expect(issues.first.message, isNot(contains('Almeno')));
  });

  test('tree and JSON retain integer versus numeric string paths', () {
    final issues = [
      AcanthisIssue(path: [0], code: 'test', message: 'Index'),
      AcanthisIssue(path: ['0'], code: 'test', message: 'Key'),
    ];
    final tree = issues.formatTree();
    expect(tree.children[0]!.messages, ['Index']);
    expect(tree.children['0']!.messages, ['Key']);
    expect(jsonDecode(issues.formatJson())[0]['path'], [0]);
    expect(jsonDecode(issues.formatJson())[1]['path'], ['0']);
  });

  test('issues freeze nested parameters, paths and branches', () {
    final path = <Object>['account'];
    final limits = [1, 2];
    final branches = <List<AcanthisIssue>>[[]];
    final issue = AcanthisIssue(
      path: path,
      code: 'test',
      message: 'test',
      parameters: {'limits': limits},
      branches: branches,
    );
    path.clear();
    limits.clear();
    branches.clear();
    expect(issue.path, ['account']);
    expect(issue.parameters, {
      'limits': [1, 2],
    });
    expect(issue.branches, [[]]);
    expect(
      () => (issue.parameters['limits'] as List).clear(),
      throwsUnsupportedError,
    );
    final equal = AcanthisIssue(
      path: ['account'],
      code: 'test',
      message: 'test',
      parameters: {
        'limits': [1, 2],
      },
      branches: [[]],
    );
    expect(issue, equal);
    expect(issue.hashCode, equal.hashCode);
  });

  test(
    'nested union diagnostics preserve every branch and data path',
    () async {
      final schema = object({
        'account': union([
          object({'email': string().email().email()}),
          object({'age': number().gte(18)}),
        ]),
      });
      final input = {
        'account': {'email': 'bad', 'age': 2},
      };
      final issue = schema.tryParse(input).issues.single;
      expect(issue.code, 'union');
      expect(issue.path, ['account']);
      expect(issue.branches.map((branch) => branch.length), [2, 1]);
      expect(issue.branches.first.first.path, ['account', 'email']);
      expect(issue.branches.last.single.path, ['account', 'age']);
      expect((await schema.tryParseAsync(input)).issues, [issue]);
    },
  );

  test(
    'sync and genuinely async unions collect equivalent branch issues',
    () async {
      final sync = union([string().email().email(), number().gte(10)]);
      final async = union([
        string().email().email().refineAsync(
          onCheck: (_) async => true,
          error: '',
          name: 'pass',
        ),
        number().gte(10),
      ]);
      expect(
        (await async.tryParseAsync('bad')).issues,
        sync.tryParse('bad').issues,
      );
      final own = union([string()])
          .refine(onCheck: (_) => false, error: 'one', name: 'rule')
          .refine(onCheck: (_) => false, error: 'two', name: 'rule');
      final asyncOwn = own.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      expect(own.tryParse('x').issues, hasLength(2));
      expect(
        (await asyncOwn.tryParseAsync('x')).issues,
        own.tryParse('x').issues,
      );
    },
  );

  test(
    'async list, tuple, nullable and pipeline retain child diagnostics',
    () async {
      final syncLeaf = string().min(3).min(5);
      final asyncLeaf = syncLeaf.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      final pairs = <(AcanthisType, AcanthisType, dynamic)>[
        (syncLeaf.list(), asyncLeaf.list(), ['x', 'y']),
        (tuple([syncLeaf]), tuple([asyncLeaf]), ['x']),
        (syncLeaf.nullable(), asyncLeaf.nullable(), 'x'),
        (
          syncLeaf.pipe(string(), transform: (s) => s),
          asyncLeaf.pipe(string(), transform: (s) => s),
          'x',
        ),
      ];
      for (final (sync, async, input) in pairs) {
        expect(
          (await async.tryParseAsync(input)).issues,
          sync.tryParse(input).issues,
        );
      }
    },
  );

  test(
    'async required checks retain duplicates and defaults match sync',
    () async {
      final sync = object({
        'email': string().email().email(),
        'name': string().withDefault('ok'),
      });
      final async = sync.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      expect((await async.tryParseAsync({})).issues, sync.tryParse({}).issues);
      expect(sync.tryParse({}).issues, hasLength(3));
    },
  );

  test(
    'specialized and generic object diagnostics match all entry points',
    () async {
      final fast = object({
        'account': object({'email': string()}),
      });
      final generic = object({
        'account': object({'email': _GenericString()}),
      });
      for (final input in [
        {
          'account': {'email': 1},
        },
        {'account': <String, dynamic>{}},
        {
          'account': {'email': 'ok'},
        },
      ]) {
        final expected = generic.tryParse(input).issues;
        expect(fast.tryParse(input).issues, expected);
        expect((await fast.tryParseAsync(input)).issues, expected);
        expect(fast.watch(input).issues, expected);
        expect((await fast.watchAsync(input)).issues, expected);
      }
    },
  );

  test(
    'live updates preserve duplicates, branch metadata and schema order',
    () async {
      final schema = object({
        'first': string().email().email(),
        'second': string().min(5),
      });
      final initial = {'first': 'ok@example.com', 'second': 'bad'};
      final sync = schema.watch(initial);
      final async = await schema.watchAsync(initial);
      final delta = sync.set('first', 'bad');
      final asyncDelta = await async.set('first', 'bad');
      expect(delta.changedIssues, hasLength(2));
      expect(asyncDelta.changedIssues, delta.changedIssues);
      expect(
        sync.issues,
        schema.tryParse({'first': 'bad', 'second': 'bad'}).issues,
      );
      expect(async.issues, sync.issues);
      expect(sync.set('first', 'ok@example.com').changedIssues, hasLength(2));
      final branchSchema = object({
        'u': union([string().min(5), number()]),
      });
      final session = branchSchema.watch({'u': 'valid'});
      session.set('u', 'bad');
      expect(session.issues, branchSchema.tryParse({'u': 'bad'}).issues);
    },
  );

  test(
    'custom metadata and causes survive sync and async collection',
    () async {
      final sync = string()
          .withCheck(
            CustomCauseCheck(
              (_) => 'reason',
              name: 'custom',
              parameters: {'limit': 2},
            ),
          )
          .refine(
            onCheck: (_) => false,
            error: 'reason',
            name: 'custom',
            parameters: {'limit': 3},
          );
      final async = sync.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      expect(
        (await async.tryParseAsync('x')).issues,
        sync.tryParse('x').issues,
      );
      expect(sync.tryParse('x').issues.last.parameters, {'limit': 3});
    },
  );

  test(
    'built-in diagnostics never interpolate input or caught exceptions',
    () async {
      const secret = 'private-secret-input';
      for (final schema in <AcanthisType>[
        boolean().coerce(),
        number().coerce(),
        date(),
        tuple([string()]),
      ]) {
        final sync = schema.tryParse(secret);
        final async = await schema.tryParseAsync(secret);
        expect(sync.issues, isNotEmpty);
        expect(sync.issues.formatJson(), isNot(contains(secret)));
        expect(async.issues.formatJson(), isNot(contains(secret)));
      }
    },
  );

  test('public result accepts direct issues and derives legacy errors', () {
    final issue = AcanthisIssue(
      path: ['email'],
      code: 'email',
      message: 'Invalid email',
    );
    final result = AcanthisParseResult(
      value: null,
      success: false,
      issues: [issue, issue],
    );
    expect(result.issues, [issue, issue]);
    expect(result.errors, {
      'email': {'email': 'Invalid email'},
    });
  });

  test(
    'container rules see equivalent child recovery in sync and async',
    () async {
      final sync = object({'s': string()}).refine(
        onCheck: (value) => value['s'] is String,
        error: 'Expected a string',
        name: 'stringField',
      );
      final async = sync.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      for (final input in [
        42,
        {'s': 42},
        <String, dynamic>{},
      ]) {
        expect(
          (await async.tryParseAsync(input)).issues,
          sync.tryParse(input).issues,
        );
      }
      final syncList = string().list().refine(
        onCheck: (values) => values.every((s) => s.isNotEmpty),
        error: 'Empty',
        name: 'nonempty',
      );
      final asyncList = syncList.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'pass',
      );
      expect(
        (await asyncList.tryParseAsync([42])).issues,
        syncList.tryParse([42]).issues,
      );
    },
  );
}
