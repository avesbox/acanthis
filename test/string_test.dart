import 'support/parse_result.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support/string_corpus.dart';
import 'support/string_schemas.dart';
import 'support/password_http.dart';

enum _Color { red, green }

class _NotCoercible {
  @override
  String toString() =>
      throw StateError('Should not stringify arbitrary objects');
}

void main() {
  test(
    'default password provider uses HTTPS, padding and closes its client',
    () async {
      final client = PasswordHttpClient(
        statusCode: HttpStatus.ok,
        body: '${'0' * 35}:1\r\n',
      );
      const password = 'test password';
      final result = await HttpOverrides.runZoned(
        () => string().uncompromised().tryParseAsync(password),
        createHttpClient: (_) => client,
      );
      final prefix = sha1
          .convert(utf8.encode(password))
          .toString()
          .substring(0, 5)
          .toUpperCase();
      expect(result.isValid, isTrue);
      expect(
        client.requests.single,
        Uri.https('api.pwnedpasswords.com', '/range/$prefix'),
      );
      expect(client.headers['Add-Padding'], 'true');
      expect(client.closed, isTrue);
      expect(client.forced, isTrue);
      expect(client.connectionTimeout, const Duration(seconds: 10));
    },
  );

  test(
    'default password provider closes on HTTP and response-format errors',
    () async {
      for (final status in [HttpStatus.serviceUnavailable, HttpStatus.ok]) {
        final client = PasswordHttpClient(
          statusCode: status,
          body: 'not a range response',
        );
        await expectLater(
          HttpOverrides.runZoned(
            () => string().uncompromised().tryParseAsync('test password'),
            createHttpClient: (_) => client,
          ),
          status == HttpStatus.ok
              ? throwsFormatException
              : throwsA(isA<HttpException>()),
        );
        expect(client.closed, isTrue);
      }
    },
  );

  for (final entry in stringCases()) {
    final name = entry['name'] as String;
    test('V1 string predicate: $name', () async {
      final schema = buildStringCase(name);
      for (final input in entry['valid'] as List) {
        expect(
          schema.parseResult(input),
          isA<AcanthisValid<String>>(),
          reason: '$name: $input',
        );
        expect(schema.tryParse(input).value, input);
        expect((await schema.parseResultAsync(input)).isValid, isTrue);
        expect((await schema.tryParseAsync(input)).value, input);
      }
      for (final input in entry['invalid'] as List) {
        final result = schema.tryParse(input);
        expect(result, isA<AcanthisInvalid<String>>(), reason: '$name: $input');
        expect(result.value, input);
        expect(result.issues.single.code, entry['code']);
        expect(result.issues.single.path, isEmpty);
        expect(result.issues.single.message, isNot(result.issues.single.code));
        expect(schema.parseResult(input).isValid, isFalse);
        expect((await schema.parseResultAsync(input)).isValid, isFalse);
        expect((await schema.tryParseAsync(input)).isValid, isFalse);
      }
    });
  }

  for (final baseline in ['v1', 'v2']) {
    test('all string predicates match the $baseline randomized reference', () {
      final reference = jsonDecode(
        File('test/fixtures/string_${baseline}_reference.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final inputs = stringCorpus(
        seed: reference['seed'] as int,
        samples: reference['samples'] as int,
      );
      expect(inputs.length, reference['corpus_size']);
      expect(
        sha256.convert(utf8.encode(jsonEncode(inputs))).toString(),
        reference['corpus_sha256'],
      );
      final cases = reference['cases'] as Map<String, dynamic>;
      expect(cases.keys, unorderedEquals(stringCases().map((entry) => entry['name'])));
      if (baseline == 'v2') expect(reference['implementation'], 'v2');
      for (final entry in cases.entries) {
        final schema = buildStringCase(entry.key);
        final expected = entry.value as String;
        expect(expected.length, inputs.length);
        for (var index = 0; index < inputs.length; index++) {
          expect(
            schema.tryParse(inputs[index]).isValid,
            expected[index] == '1',
            reason: '${entry.key}, sample $index: ${jsonEncode(inputs[index])}',
          );
        }
      }
    });
  }

  test(
    'strict type boundary skips checks and has no invented recovery value',
    () async {
      var calls = 0;
      final Schema<String, String> schema = string().withCheck(
        CallbackCheck((value, context) {
          calls++;
        }),
      );
      for (final input in <Object?>[null, 1, false, [], {}, _NotCoercible()]) {
        for (final result in [
          schema.parseResult(input),
          schema.tryParse(input),
        ]) {
          expect(result, isA<AcanthisInvalid<String>>());
          expect((result as AcanthisInvalid<String>).hasValue, isFalse);
          expect(() => result.value, throwsStateError);
          expect(result.issues.single.code, 'type');
        }
      }
      expect(calls, 0);
      final String output = schema.parseResult('accepted').value;
      expect(output, 'accepted');
      final asyncSchema = string().refineAsync(
        CallbackAsyncCheck((value, context) async {
          calls++;
        }),
      );
      expect((await asyncSchema.tryParseAsync(null)).isValid, isFalse);
      expect(calls, 1);
    },
  );

  test(
    'coercion and defaults survive every fluent copy and validate the default',
    () {
      final date = DateTime.utc(2026, 10, 14);
      final schema = string()
          .coerce()
          .withDefault('fallback')
          .min(1)
          .toUpperCase();
      for (final input in <Object>[42, 1.25, true, date]) {
        expect(schema.tryParse(input).value, input.toString().toUpperCase());
      }
      expect(schema.tryParse(null).value, 'FALLBACK');
      expect(schema.tryParse(_NotCoercible()).isValid, isFalse);
      expect(string().tryParse(42).isValid, isFalse);
      final badDefault = string().withDefault('').notEmpty().tryParse(null);
      expect(badDefault.isValid, isFalse);
      expect(badDefault.value, '');
      expect(string().min(-1).parseResult('').isValid, isTrue);
      expect(string().max(-1).parseResult('').isValid, isFalse);
    },
  );

  test(
    'parse is fail-fast and tryParse collects ordered independent checks',
    () {
      final schema = string().min(5).max(1).pattern(r'^x');
      expect(schema.parseResult('abc').issues.map((i) => i.code), [
        'minLength',
      ]);
      expect(schema.tryParse('abc').issues.map((i) => i.code), [
        'minLength',
        'maxLength',
        'pattern',
      ]);
      expect(schema.validate('abc'), isFalse);
      expect(schema.tryValidate('abc'), isFalse);
      expect(string().validate('abc'), isTrue);
      expect(string().tryValidate('abc'), isTrue);
    },
  );

  test('transformations and checks execute exactly once in fluent order', () {
    final seen = <String>[];
    final schema = string()
        .toLowerCase()
        .withCheck(
          CallbackCheck((value, context) {
            seen.add(value);
          }),
        )
        .toUpperCase()
        .contains('A');
    expect(schema.parseResult('AbC').value, 'ABC');
    expect(schema.tryParse('AbC').value, 'ABC');
    expect(seen, ['abc', 'abc']);
    expect(schema.checks, hasLength(2));
    expect(schema.transformations, hasLength(2));
    expect(schema.checks, same(schema.checks));
    expect(() => schema.checks.clear(), throwsUnsupportedError);
    expect(() => schema.transformations.clear(), throwsUnsupportedError);
  });

  test(
    'failed checks prevent transformations and their dependent checks',
    () async {
      var transformations = 0;
      var dependentChecks = 0;
      final schema = string()
          .min(5)
          .max(1)
          .withTransform(
            CallbackTransform((value) {
              transformations++;
              return value;
            }),
          )
          .withCheck(
            CallbackCheck((value, context) {
              dependentChecks++;
            }),
          );
      expect(schema.tryParse('abc').issues, hasLength(2));
      expect((await schema.tryParseAsync('abc')).issues, hasLength(2));
      expect(transformations, 0);
      expect(dependentChecks, 0);
    },
  );

  test('base64 transforms round-trip ASCII and Unicode with UTF-8', () async {
    for (final input in ['', 'hello', 'é', 'ciao 😀', '日本語']) {
      final encoded = string().encode().parseResult(input).value;
      expect(encoded, base64.encode(utf8.encode(input)));
      expect(string().decode().parseResult(encoded).value, input);
      expect(
        (await string().encode().decode().parseResultAsync(input)).value,
        input,
      );
    }
    expect(string().trim().toUpperCase().parseResult(' a ').value, 'A');
  });

  test('malformed base64 and UTF-8 are native transform failures', () {
    for (final input in ['???', '/w==']) {
      for (final result in [
        string().decode().parseResult(input),
        string().decode().tryParse(input),
      ]) {
        expect(result.isValid, isFalse);
        expect(result.value, input);
        expect(result.issues.single.code, 'transform');
        expect(result.issues.single.parameters, {'operation': 'decode'});
      }
    }
    expect(
      string().base64().decode().tryParse('???').issues.single.code,
      'base64',
    );
  });

  test(
    'callback exceptions propagate without becoming input or decode errors',
    () async {
      final failure = StateError('callback bug');
      final check = string().withCheck(
        PredicateCheck((value) => throw failure),
      );
      final transform = string().withTransform(
        CallbackTransform((value) => throw failure),
      );
      for (final schema in [check, transform]) {
        expect(() => schema.parseResult('x'), throwsA(same(failure)));
        expect(() => schema.tryParse('x'), throwsA(same(failure)));
        await expectLater(schema.parseResultAsync('x'), throwsA(same(failure)));
      }
      final customFormatError = string().withTransform(
        CallbackTransform(
          (value) => throw const FormatException('user callback'),
        ),
      );
      expect(() => customFormatError.tryParse('x'), throwsFormatException);
      final asyncCheck = string().refineAsync(
        CallbackAsyncCheck((value, context) async {
          throw failure;
        }),
      );
      await expectLater(asyncCheck.tryParseAsync('x'), throwsA(same(failure)));
    },
  );

  test('definition copies and source collections are immutable', () {
    final original = string().min(1);
    final stricter = original.max(2);
    expect(original.parseResult('long').isValid, isTrue);
    expect(stricter.parseResult('long').isValid, isFalse);
    final values = ['red', 'green'];
    final membership = string().contained(values);
    values
      ..clear()
      ..add('blue');
    expect(membership.parseResult('red').isValid, isTrue);
    expect(membership.parseResult('blue').isValid, isFalse);
    var mapped = 0;
    final enums = [_Color.red, _Color.green];
    final enumerated = string().enumerated(
      enums,
      nameTransformer: (name) {
        mapped++;
        return name.toUpperCase();
      },
    );
    enums.clear();
    expect(enumerated.parseResult('RED').isValid, isTrue);
    expect(enumerated.parseResult('GREEN').isValid, isTrue);
    expect(mapped, 2);
    expect(() => string().contained([]), throwsArgumentError);
    expect(() => string().enumerated(<_Color>[]), throwsArgumentError);
    expect(() => string().pattern('['), throwsFormatException);
  });

  test(
    'custom checks publish multiple relative paths and localize by code',
    () {
      final sourceParameters = <String, Object?>{'limit': 3};
      final predicate = PredicateCheck<String>(
        (value) => false,
        code: 'app.custom',
        parameters: sourceParameters,
      );
      sourceParameters['limit'] = 99;
      final schema = string()
          .withCheck(predicate)
          .withCheck(
            CallbackCheck((value, context) {
              context.addIssue(
                'app.custom',
                path: ['confirmation'],
                parameters: {'limit': 5},
              );
            }),
          );
      final result = schema.tryParse('x');
      expect(result.issues, hasLength(2));
      expect(result.issues.first.parameters, {'limit': 3});
      expect(result.issues.last.path, ['confirmation']);
      final messages = AcanthisMessageCatalog({
        'app.custom': (p) => 'Limite ${p['limit']}',
      });
      expect(result.issues.first.formatMessage(catalog: messages), 'Limite 3');
      expect(result.issues.last.formatMessage(catalog: messages), 'Limite 5');
    },
  );

  test(
    'repeated and reentrant invocations have independent check contexts',
    () {
      late AcanthisString schema;
      final contexts = <CheckContext>[];
      schema = string().withCheck(
        CallbackCheck((value, context) {
          contexts.add(context);
          if (value == 'outer') {
            expect(schema.tryParse('inner').issues.single.code, 'inner');
          }
          context.addIssue(value);
        }),
      );
      final first = schema.tryParse('outer');
      final second = schema.tryParse('second');
      expect(first.issues.map((i) => i.code), ['outer']);
      expect(second.issues.map((i) => i.code), ['second']);
      expect(contexts.toSet(), hasLength(3));
      expect(string().min(2).tryParse('bad').isValid, isTrue);
    },
  );

  test('async checks and transformations execute sequentially', () async {
    final calls = <String>[];
    final schema = string()
        .toLowerCase()
        .refineAsync(
          CallbackAsyncCheck((value, context) async {
            calls.add('check:$value');
            await Future<void>.value();
            calls.add('checked');
          }),
        )
        .transformAsync(
          CallbackAsyncTransform((value) async {
            calls.add('transform:$value');
            return value.toUpperCase();
          }),
        )
        .withCheck(
          CallbackCheck((value, context) {
            calls.add('last:$value');
          }),
        );
    expect(schema.isAsync, isTrue);
    expect(() => schema.parseResult('X'), throwsStateError);
    expect(() => schema.tryParse('X'), throwsStateError);
    expect(() => schema.validate('X'), throwsStateError);
    expect(calls, isEmpty);
    expect((await schema.parseResultAsync('X')).value, 'X');
    expect(calls, ['check:x', 'checked', 'transform:x', 'last:X']);
    expect(await string().notEmpty().validateAsync('x'), isTrue);
    expect(await string().notEmpty().tryValidateAsync(''), isFalse);
  });

  test(
    'async failure policy agrees with sync and skips dependent transforms',
    () async {
      var transforms = 0;
      final schema = string()
          .refineAsync(
            CallbackAsyncCheck((value, context) async {
              context.addIssue('first');
            }),
          )
          .withCheck(
            CallbackCheck((value, context) {
              context.addIssue('second');
            }),
          )
          .transformAsync(
            CallbackAsyncTransform((value) async {
              transforms++;
              return value;
            }),
          );
      expect((await schema.parseResultAsync('x')).issues.map((i) => i.code), [
        'first',
      ]);
      expect((await schema.tryParseAsync('x')).issues.map((i) => i.code), [
        'first',
        'second',
      ]);
      expect(transforms, 0);
    },
  );

  test('concurrent async parses do not share diagnostics', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var count = 0;
    final schema = string().refineAsync(
      CallbackAsyncCheck((value, context) async {
        if (++count == 2) entered.complete();
        await release.future;
        context.addIssue(value, parameters: {'limit': value.length});
      }),
    );
    final first = schema.tryParseAsync('first');
    final second = schema.tryParseAsync('second');
    await entered.future;
    release.complete();
    expect((await first).issues.single.code, 'first');
    expect((await second).issues.single.code, 'second');
  });

  test(
    'deep immutable operation chains compile and execute without recursion',
    () {
      var schema = string();
      final check = PredicateCheck<String>((value) => value.isNotEmpty);
      for (var i = 0; i < 5000; i++) {
        schema = schema.withCheck(check);
      }
      expect(schema.parseResult('x').value, 'x');
      expect(schema.tryParse('').issues, hasLength(5000));
      expect(schema.checks, hasLength(5000));
    },
  );

  test(
    'password range check sends only a prefix and ignores zero-count padding',
    () async {
      const password = 'test password é';
      final hash = sha1.convert(utf8.encode(password)).toString().toUpperCase();
      final prefixes = <String>[];
      final compromised = string().uncompromised(
        lookup: (prefix) async {
          prefixes.add(prefix);
          return '${hash.substring(5).toLowerCase()}:10\r\n';
        },
      );
      expect(() => compromised.parseResult(password), throwsStateError);
      expect(prefixes, isEmpty);
      final invalid = await compromised.tryParseAsync(password);
      expect(invalid.issues.single.code, 'uncompromised');
      expect(invalid.issues.single.parameters, isEmpty);
      expect(prefixes, [hash.substring(0, 5)]);
      final padding = string().uncompromised(
        lookup: (_) async => '${hash.substring(5)}:0\r\n',
      );
      expect((await padding.parseResultAsync(password)).isValid, isTrue);
      final unmatched = string().uncompromised(
        lookup: (_) async => '${'0' * 35}:1\r\n',
      );
      expect((await unmatched.parseResultAsync(password)).isValid, isTrue);
    },
  );

  test('password transport and malformed responses cannot become successful validation', () async {
    for (final body in [
      '',
      'error page',
      '${'0' * 35}:invalid',
      '${'0' * 35}:1\ninvalid',
    ]) {
      final schema = string().uncompromised(lookup: (_) async => body);
      await expectLater(
        schema.tryParseAsync('password'),
        throwsFormatException,
      );
    }
    final failure = HttpException('Service unavailable');
    final schema = string().uncompromised(lookup: (_) async => throw failure);
    await expectLater(schema.tryParseAsync('password'), throwsA(same(failure)));
  });
}
