import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/validators/string.dart';
import 'package:test/test.dart';

class _Box {
  _Box(this.value);
  final dynamic value;
}

class _DiagnosticString extends AcanthisString {
  _DiagnosticString({bool async = false}) : super(isAsync: async);
  @override
  String coerceInput(dynamic value) => throw ValidationError.diagnostic(
    'fallback',
    code: 'app.constraint',
    path: ['inside'],
    parameters: {'limit': 3},
    branches: [
      [
        AcanthisIssue(path: ['inside', 0], code: 'type', message: 'branch'),
      ],
    ],
  );
}

void main() {
  test('base catches retain metadata and branches in both modes', () async {
    for (final schema in [
      _DiagnosticString(),
      _DiagnosticString(async: true),
    ]) {
      final issue = (await schema.tryParseAsync('x')).issues.single;
      expect(issue.code, 'app.constraint');
      expect(issue.path, ['inside']);
      expect(issue.parameters, {'limit': 3});
      expect(issue.branches.single.single.path, ['inside', 0]);
    }
  });

  test(
    'instance fields validate complete schemas once and preserve ordering',
    () async {
      var transformations = 0;
      var getters = 0;
      final child = object({
        'a/b~': string()
            .transform((s) {
              transformations++;
              return s.trim();
            })
            .withCheck(MinStringLengthCheck(3))
            .withCheck(MinStringLengthCheck(4)),
      });
      final schema = instance<_Box>().field('value', (b) {
        getters++;
        return b.value;
      }, child);
      final input = _Box({'a/b~': ' x '});
      for (final async in [false, true]) {
        getters = transformations = 0;
        final result = async
            ? await schema.tryParseAsync(input)
            : schema.tryParse(input);
        expect(result.value, same(input));
        expect(result.issues.map((i) => i.code), ['minLength', 'minLength']);
        expect(result.issues.map((i) => i.parameters['value']), [3, 4]);
        expect(result.issues.first.jsonPointer, '/value/a~1b~0');
        expect(getters, 1);
        expect(transformations, 1);
      }
      expect(
        () => schema.parse(input),
        throwsA(
          isA<ValidationError>()
              .having((e) => e.issue!.path, 'path', ['value', 'a/b~'])
              .having((e) => e.issue!.parameters, 'parameters', {'value': 3}),
        ),
      );
    },
  );

  test(
    'nested async fields, defaults, optional fields and fail-fast',
    () async {
      var calls = 0;
      final child = string()
          .min(3)
          .refineAsync(
            onCheck: (_) async {
              await Future<void>.delayed(Duration.zero);
              calls++;
              return false;
            },
            name: 'app.remote',
            error: 'remote',
          );
      final schema = instance<_Box>().field(
        'value',
        (b) => b.value,
        child.list(),
      );
      expect(schema.isAsync, isTrue);
      expect(
        () => schema.parse(_Box(['abc'])),
        throwsA(isA<AsyncValidationException>()),
      );
      await expectLater(
        schema.parseAsync(_Box(['x'])),
        throwsA(isA<ValidationError>()),
      );
      expect(calls, 0);
      final result = await schema.tryParseAsync(_Box(['x']));
      expect(calls, 1);
      expect(result.issues.map((i) => i.code), ['minLength', 'app.remote']);
      expect(result.issues.last.path, ['value', 0]);
      final optional = instance<_Box>().field(
        'value',
        (b) => b.value,
        child,
        optional: true,
      );
      expect((await optional.tryParseAsync(_Box(null))).isValid, isTrue);
      final fallback = _Box('fallback');
      expect(
        instance<_Box>()
            .field('value', (b) => b.value, string().min(3))
            .withDefault(fallback)
            .tryParse(_Box('x'))
            .value,
        same(fallback),
      );
    },
  );

  test(
    'input type failures have structured diagnostics in throwing modes',
    () async {
      for (final schema in <AcanthisType>[
        string(),
        string().list(),
        tuple([string()]),
        object({'x': string()}),
        instance<_Box>(),
        string().refineAsync(
          onCheck: (_) async => true,
          error: '',
          name: 'pass',
        ),
      ]) {
        if (!schema.isAsync) {
          expect(
            () => schema.parse(42),
            throwsA(
              isA<ValidationError>().having(
                (e) => e.issue!.code,
                'code',
                'type',
              ),
            ),
          );
          expect(schema.validate(42), isNotNull);
        }
        await expectLater(
          schema.parseAsync(42),
          throwsA(
            isA<ValidationError>().having((e) => e.issue!.code, 'code', 'type'),
          ),
        );
        expect((await schema.tryParseAsync(42)).issues.first.code, 'type');
      }
      final callback = string().transform((s) => (42 as dynamic) as String);
      expect(() => callback.parse('x'), throwsA(isA<TypeError>()));
    },
  );

  test('transport preserves segments, branches and duplicate order, excludes messages', () {
    final result =
        object({
          'a/b~': union([string().min(3), number().gte(4)]).list(),
        }).tryParse({
          'a/b~': [false],
        });
    final en = AcanthisI18n.runWith(
      AcanthisLocaleConfig.forLocale('en'),
      result.issues.toTransport,
    );
    final it = AcanthisI18n.runWith(
      AcanthisLocaleConfig.forLocale('it'),
      result.issues.toTransport,
    );
    expect(it, en);
    expect(jsonDecode(jsonEncode(en)), en);
    expect(en['version'], 1);
    final json = jsonEncode(en);
    expect(json, isNot(contains('message')));
    expect(json, isNot(contains('false')));
    expect(result.issues.single.branches.first.first.path, ['a/b~', 0]);
    final issue = AcanthisIssue(
      path: ['0', 0],
      code: 'app.test',
      message: 'secret',
    );
    expect((issue.toTransport()['path'] as List), ['0', 0]);
    expect([issue, issue].toTransport()['issues'], hasLength(2));
    expect(issue.toJson()['message'], 'secret');
  });

  test(
    'metadata freezing bounds cycles, depth, infinite iterables and maps',
    () {
      final list = <Object?>[];
      list.add(list);
      final map = <String, Object?>{};
      map['self'] = map;
      Object? deep = 'leaf';
      for (var i = 0; i < 40; i++) {
        deep = [deep];
      }
      final issue = AcanthisIssue(
        path: [],
        code: 'app.test',
        message: '',
        parameters: {
          'list': list,
          'map': map,
          'deep': deep,
          'infinite': _infinite(),
          'unknown': Object(),
          'largeMap': {for (var i = 0; i < 1025; i++) '$i': i},
          'date': DateTime.utc(2026),
          'duration': const Duration(seconds: 1),
          'nan': double.nan,
          'regexp': RegExp('a'),
        },
      );
      final encoded = jsonEncode(issue.toTransport());
      expect(encoded, contains('<cycle>'));
      expect(encoded, contains('<max-depth>'));
      expect(encoded, contains('<truncated>'));
      expect(encoded, contains('<truncated-map>'));
      expect(issue.parameters['duration'], 1000000);
      expect(
        () => (issue.parameters['list'] as List).add(0),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'locale precedence, restoration, null/empty resolution and exceptions',
    () async {
      final old = AcanthisI18n.configure(AcanthisLocaleConfig.forLocale('it'));
      addTearDown(() => AcanthisI18n.configure(old));
      final issue = string()
          .min(3, message: 'custom')
          .tryParse('x')
          .issues
          .single;
      expect(issue.formatMessage(), startsWith('Il valore'));
      await AcanthisI18n.runWith(
        AcanthisLocaleConfig.forLocale('en'),
        () async {
          await Future<void>.delayed(Duration.zero);
          expect(issue.formatMessage(), startsWith('Value'));
          expect(issue.formatMessage(resolver: (_, _) => null), 'custom');
          expect(issue.formatMessage(resolver: (_, _) => ''), '');
          expect(
            () => issue.formatMessage(
              resolver: (_, _) => throw StateError('resolver'),
            ),
            throwsStateError,
          );
          expect(
            () => AcanthisI18n.runWith(
              const AcanthisLocaleConfig(locale: 'none'),
              () {
                expect(issue.formatMessage(), 'custom');
                throw StateError('scope');
              },
            ),
            throwsStateError,
          );
          expect(issue.formatMessage(), startsWith('Value'));
        },
      );
      expect(issue.formatMessage(), startsWith('Il valore'));
      expect(await Isolate.run(() => AcanthisI18n.current.locale), '');
      final results = await Future.wait([
        for (final locale in ['en', 'it'])
          AcanthisI18n.runWith(
            AcanthisLocaleConfig.forLocale(locale),
            () async {
              await Future<void>.delayed(Duration.zero);
              return issue.formatMessage();
            },
          ),
      ]);
      expect(results[0], startsWith('Value'));
      expect(results[1], startsWith('Il valore'));
    },
  );

  test('locale overrides normalize tags and fall through in order', () {
    final resolver = AcanthisMessageCatalogs.forLocale(
      ' IT_ch ',
      overrides: {
        'it-CH': (c, p) => c == 'app.exact' ? 'exact' : null,
        'IT': (c, p) => c == 'app.base' ? 'base' : null,
      },
    );
    expect(resolver('app.exact', {}), 'exact');
    expect(resolver('app.base', {}), 'base');
    expect(resolver('required', {}), isNotNull);
    expect(resolver('app.unknown', {}), isNull);
    expect(AcanthisMessageCatalogs.forLocale('xx')('required', {}), isNull);
  });

  test('shared acyclic metadata cannot expand exponentially', () {
    Object tree = [1];
    for (var i = 0; i < 25; i++) {
      tree = [tree, tree];
    }
    final issue = AcanthisIssue(
      path: [],
      code: 'app.graph',
      message: '',
      parameters: {'tree': tree},
    );
    final encoded = jsonEncode(issue.toTransport());
    expect(encoded, contains('<max-nodes>'));
    expect(encoded.length, lessThan(100000));
  });
}

Iterable<int> _infinite() sync* {
  while (true) {
    yield 1;
  }
}
