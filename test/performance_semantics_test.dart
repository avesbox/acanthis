import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/issue_sink.dart';
import 'package:test/test.dart';

class _CoercingString extends AcanthisString {
  @override
  String coerceInput(dynamic value) => value.toString();
}

class _ReplacingString extends AcanthisString {
  @override
  String parseInternal(dynamic value) => '$value!';
}

class _ReplacingMap extends AcanthisMap<dynamic> {
  _ReplacingMap() : super({'name': string()});
  @override
  Map<String, dynamic> parseInternal(dynamic value) => {'custom': true};
}

void main() {
  test(
    'factory and public maps agree on first use and preserve subclass hooks',
    () {
      for (final input in <Map<String, dynamic>>[
        {'name': 'ok'},
        {'name': 'ok', 'extra': true},
        {},
        {'name': 42},
      ]) {
        final factory = object({'name': string()}).tryParse(input);
        final direct = AcanthisMap<dynamic>({'name': string()}).tryParse(input);
        expect(factory.success, direct.success);
        expect(factory.value, direct.value);
        expect(factory.issues, direct.issues);
      }
      expect(_ReplacingMap().parse({'name': 'ok'}).value, {'custom': true});
    },
  );

  test(
    'typed string batch preserves check order, messages and input sharing',
    () {
      final strings = string()
          .min(2, message: 'minimum')
          .max(3, message: 'maximum');
      final input = <String>['ab', 'abc'];
      expect(identical(strings.list().parse(input).value, input), isTrue);
      expect(
        () => strings.list().parse(<String>['a', 'abcd']),
        throwsA(
          isA<ValidationError>().having((e) => e.message, 'message', 'minimum'),
        ),
      );
      expect(
        () => strings.list().parse(<String>['ab', 'abcd']),
        throwsA(
          isA<ValidationError>().having((e) => e.message, 'message', 'maximum'),
        ),
      );
      expect(strings.list().parse(<dynamic>['ab']).value, ['ab']);
      final dynamicInput = <dynamic>['ab'];
      expect(
        identical(
          AcanthisList<dynamic>(strings).parse(dynamicInput).value,
          dynamicInput,
        ),
        isTrue,
      );
      expect(
        () => strings.list().parse(<dynamic>[42]),
        throwsA(isA<TypeError>()),
      );
    },
  );

  test('custom list callbacks retain copy-on-change behavior', () {
    final input = <String>['original'];
    final schema = string()
        .refine(
          onCheck: (_) {
            input[0] = 'changed by callback';
            return true;
          },
          error: '',
          name: 'mutating callback',
        )
        .list();
    expect(schema.parse(input).value, ['original']);
    expect(input, ['changed by callback']);
  });

  test('a sink can prefix a snapshot of its own diagnostics', () {
    final sink = IssueSink()..addIssue('custom', 'failure');
    sink.addChild('nested', sink);
    expect(sink.issues.map((issue) => issue.path), [
      [],
      ['nested'],
    ]);
  });

  test(
    'prefixed diagnostics retain immutable nested metadata and branches',
    () {
      final limits = <int>[1, 2];
      final child = AcanthisIssue(
        path: ['leaf'],
        code: 'custom',
        message: 'failure',
        parameters: {'limits': limits},
      );
      final issue = AcanthisIssue(
        path: [],
        code: 'union',
        message: 'failure',
        branches: [
          [child],
        ],
      ).prefixed(3).prefixed('items');
      limits.clear();
      expect(issue.branches.single.single.path, ['items', 3, 'leaf']);
      expect(issue.branches.single.single.parameters, {
        'limits': [1, 2],
      });
      expect(() => issue.path.add('bad'), throwsUnsupportedError);
      expect(() => issue.branches.single.clear(), throwsUnsupportedError);
      expect(() => issue.prefixed(Object()), throwsArgumentError);
    },
  );

  test('child sink reuse cannot change previously emitted diagnostics', () {
    final child = IssueSink()
      ..addIssue('minLength', 'short', parameters: {'value': 3});
    final parent = IssueSink()
      ..addChild(0, child)
      ..addChild(1, child);
    child.clear();
    expect(parent.issues.map((issue) => issue.path), [
      [0],
      [1],
    ]);
    expect(parent.issues.map((issue) => issue.parameters), [
      {'value': 3},
      {'value': 3},
    ]);
    expect(
      () => parent.issues.first.parameters['value'] = 7,
      throwsUnsupportedError,
    );
  });

  test(
    'primitive shortcuts preserve custom coercion and replacement hooks',
    () {
      expect(_CoercingString().tryParse(42).value, '42');
      expect(_CoercingString().tryParse(42).success, isTrue);
      final input = <String>['a', 'b'];
      expect(_ReplacingString().list().parse(input).value, ['a!', 'b!']);
      expect(input, ['a', 'b']);
      expect(
        identical(string().min(1).list().parse(input).value, input),
        isTrue,
      );
      expect(string().coerce().list().parse([42]).value, ['42']);
      expect(string().transform((v) => '$v!').list().parse(input).value, [
        'a!',
        'b!',
      ]);
    },
  );

  test(
    'direct type rejection preserves seeded recovery and async issues',
    () async {
      for (final schema in [
        string(),
        string().min(3),
        string().withDefault('fallback'),
      ]) {
        final sync = schema.tryParse(42);
        final async = await schema
            .refineAsync(onCheck: (_) async => true, error: '', name: 'pass')
            .tryParseAsync(42);
        expect(sync.success, isFalse);
        expect(sync.value, async.value);
        expect(sync.issues, async.issues);
      }
    },
  );
}
