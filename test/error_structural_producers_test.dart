import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void check(AcanthisIssue issue, String code, Map<String, Object?> parameters) {
  expect(issue.code, code);
  expect(issue.parameters, parameters);
  expect(AcanthisIssueCodes.values, contains(code));
  expect(AcanthisMessageCatalogs.english(code, parameters), isNotNull);
  expect(AcanthisMessageCatalogs.italian(code, parameters), isNotNull);
}

void main() {
  test(
    'template, dependency, union guard and pipeline structural producers',
    () async {
      final literalTemplate = template(['ok-', string()]);
      final dependency = object({'a': string(), 'b': string()})
          .addFieldDependency(
            dependent: 'a',
            dependendsOn: 'b',
            dependency: (_, _) => false,
          );
      final guarded = union<String>([
        variant<String>(guard: (_) => false, schema: string(), name: 'entry'),
      ]);
      final pipeline = string().pipe<int>(
        integer(),
        transform: (_) => throw StateError('secret'),
      );
      for (final async in [false, true]) {
        Future<AcanthisOutcome> run(AcanthisType schema, dynamic value) async =>
            async ? await schema.tryParseAsync(value) : schema.tryParse(value);
        check(
          (await run(literalTemplate, 'bad')).issues.single,
          'templateLiteral',
          {'pattern': literalTemplate.pattern},
        );
        check(
          (await run(dependency, {'a': 'x', 'b': 'y'})).issues.single,
          'dependency',
          {'dependsOn': 'b'},
        );
        final issue = (await run(guarded, 'x')).issues.single;
        check(issue, 'union', {});
        check(issue.branches.single.single, 'variantGuard', {'name': 'entry'});
        final transformed = (await run(pipeline, 'x')).issues.single;
        check(transformed, 'transform', {});
        expect(
          jsonEncode(transformed.toTransport()),
          isNot(contains('secret')),
        );
      }
    },
  );

  test(
    'passthrough assignment failures use consistent structural metadata',
    () async {
      final schema = AcanthisMap<int>({}).passthrough(type: string());
      final input = {'extra': 'text'};
      final sync = schema.tryParse(input);
      final async = await schema.tryParseAsync(input);
      expect(sync.issues.single.path, ['extra']);
      expect(async.issues.single.path, ['extra']);
      check(sync.issues.single, 'passthrough', {});
      check(async.issues.single, 'passthrough', {});
      expect(
        () => schema.parse(input),
        throwsA(
          isA<ValidationError>().having(
            (e) => e.issue!.code,
            'code',
            'passthrough',
          ),
        ),
      );
    },
  );

  test('missing-field issues are synthesized without running checks', () {
    var calls = 0;
    final schema = object({
      'x': string()
          .min(3)
          .refine(
            onCheck: (_) {
              calls++;
              return false;
            },
            name: 'app.check',
            error: 'failure',
          ),
    });
    final result = schema.tryParse({});
    expect(calls, 0);
    expect(result.issues.map((i) => i.code), [
      'required',
      'minLength',
      'app.check',
    ]);
    expect(result.issues[1].parameters, {'value': 3});
    expect(result.issues.every((i) => i.path.single == 'x'), isTrue);
  });

  test(
    'real uncompromised producer with deterministic local HTTP response',
    () async {
      await HttpOverrides.runZoned(() async {
        final schema = string().uncompromised();
        final issue = (await schema.tryParseAsync('password')).issues.single;
        check(issue, 'uncompromised', {});
        await expectLater(
          schema.parseAsync('password'),
          throwsA(
            isA<ValidationError>().having(
              (e) => e.issue!.code,
              'code',
              'uncompromised',
            ),
          ),
        );
      }, createHttpClient: (_) => _Client());
    },
  );
}

class _Client implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _Response();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(
    utf8.encode(
      '${sha1.convert(utf8.encode('password')).toString().toUpperCase().substring(5)}:1\n',
    ),
  ).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
