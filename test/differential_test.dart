import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

class _OrdinaryString extends AcanthisString {}

class _OrdinaryBoolean extends AcanthisBoolean {}

class _OrdinaryInt extends AcanthisNumeric<int> {}

class _OrdinaryDouble extends AcanthisNumeric<double> {}

class _OrdinaryNumber extends AcanthisNumeric<num> {}

dynamic _copy(dynamic value) => jsonDecode(jsonEncode(value));

// Capture sharing at every corresponding container, not just root identity.
List<String> _sharing(dynamic input, dynamic output, [String path = '']) {
  final shared = <String>[];
  if ((input is Map || input is List) && identical(input, output)) {
    shared.add(path);
  }
  if (input is Map && output is Map) {
    for (final key in input.keys) {
      if (output.containsKey(key)) {
        shared.addAll(
          _sharing(input[key], output[key], '$path/${jsonEncode(key)}'),
        );
      }
    }
  } else if (input is List && output is List) {
    for (var i = 0; i < min(input.length, output.length); i++) {
      shared.addAll(_sharing(input[i], output[i], '$path/$i'));
    }
  }
  return shared;
}

void main() {
  final seed = int.parse(Platform.environment['DIFFERENTIAL_SEED'] ?? '730201');
  final count = int.parse(Platform.environment['DIFFERENTIAL_CASES'] ?? '500');
  if (count < 1) throw ArgumentError('DIFFERENTIAL_CASES must be positive');
  print('Differential corpus: seed=$seed cases=$count');
  test(
    'invalid nested recovery strips unknowns and preserves absent optionals',
    () async {
      final sync = object({
        'account': object({'email': string().min(2)}),
        'optional': string().nullable(),
      }).optionals(['optional']);
      final async = sync.refineAsync(
        onCheck: (_) async => true,
        name: 'scheduled',
        error: '',
      );
      final payload = {
        'account': {'email': '', 'unknown': true},
        'extra': true,
      };
      final result = sync.tryParse(payload);
      expect(result.value, {
        'account': {'email': ''},
      });
      expect((await async.tryParseAsync(payload)).value, result.value);
      expect(payload, {
        'account': {'email': '', 'unknown': true},
        'extra': true,
      });
    },
  );
  test(
    'randomized specialization-eligible nested objects preserve all behavior',
    () async {
      final random = Random(seed);
      for (var trial = 0; trial < count; trial++) {
        final key = ['a/b', '~', '.', '0', ''][random.nextInt(5)];
        final kind = random.nextInt(5);
        final fastLeaf = <AcanthisType>[
          string(),
          boolean(),
          integer(),
          doubleType(),
          number(),
        ][kind];
        final ordinaryLeaf = <AcanthisType>[
          _OrdinaryString(),
          _OrdinaryBoolean(),
          _OrdinaryInt(),
          _OrdinaryDouble(),
          _OrdinaryNumber(),
        ][kind];
        final validValue = <Object>['ok', true, 42, 3.5, 5.5][kind];
        final fast = object({
          'account': object({key: fastLeaf}),
        });
        final ordinary = object({
          'account': object({key: ordinaryLeaf}),
        });
        final payload = <String, dynamic>{
          'account': <String, dynamic>{
            key: [validValue, null, <String, dynamic>{}][random.nextInt(3)],
          },
        };
        if (random.nextInt(5) == 0) (payload['account'] as Map).remove(key);
        if (random.nextInt(5) == 0) payload['extra'] = true;
        final input = _copy(payload);
        final expectedInput = _copy(payload);
        final actual = fast.tryParse(input);
        final expected = ordinary.tryParse(expectedInput);
        final reason =
            'seed=$seed specialized=$trial input=${jsonEncode(payload)}';
        expect(actual.success, expected.success, reason: reason);
        expect(actual.value, expected.value, reason: reason);
        expect(actual.issues, expected.issues, reason: reason);
        expect(
          _sharing(input, actual.value),
          _sharing(expectedInput, expected.value),
          reason: reason,
        );
        expect(input, payload, reason: reason);
        expect(expectedInput, payload, reason: reason);
        if (actual.success) {
          expect(
            fast.parse(_copy(payload)).value,
            actual.value,
            reason: reason,
          );
          expect(
            (await fast.parseAsync(_copy(payload))).value,
            actual.value,
            reason: reason,
          );
        }
      }
    },
  );
  test(
    'missing nullable fields agree between sync and genuinely async schemas',
    () async {
      final sync = object({'value': string().nullable()});
      final async = sync.refineAsync(
        onCheck: (_) async => true,
        error: '',
        name: 'scheduled',
      );
      expect((await async.tryParseAsync({})).issues, sync.tryParse({}).issues);
      expect((await async.tryParseAsync({})).value, sync.tryParse({}).value);
      expect(() => sync.parse({}), throwsA(isA<ValidationError>()));
      await expectLater(async.parseAsync({}), throwsA(isA<ValidationError>()));
    },
  );
  test('seeded differential acceptance, output, issues and input mutation', () async {
    final random = Random(seed);
    const keys = ['email', 'a/b', '~name', 'a.b', '0', ''];
    for (var trial = 0; trial < count; trial++) {
      final key = keys[random.nextInt(keys.length)];
      final constrained = random.nextBool();
      final defaulted = random.nextBool();
      final transformed = random.nextBool();
      final listed = random.nextBool();
      AcanthisMap schema({bool ordinary = false, bool async = false}) {
        AcanthisType<String> leaf = ordinary ? _OrdinaryString() : string();
        if (constrained) {
          leaf = leaf.refine(
            onCheck: (s) => s.length >= 2,
            error: 'Too short',
            name: 'length',
          );
        }
        if (defaulted) leaf = leaf.withDefault('fallback');
        if (transformed) leaf = leaf.transform((s) => s.trim().toUpperCase());
        if (async) {
          leaf = leaf.refineAsync(
            onCheck: (_) async => true,
            error: '',
            name: 'scheduled',
          );
        }
        final AcanthisType child = listed ? leaf.list() : leaf;
        return object({
          'account': object({key: child}),
          'optional': string().nullable(),
        }).optionals(['optional']);
      }

      dynamic value() => [null, 42, '', ' a ', 'ok'][random.nextInt(5)];
      final child = <String, dynamic>{};
      if (random.nextInt(4) != 0) {
        child[key] = listed
            ? List.generate(random.nextInt(5), (_) => value())
            : value();
      }
      if (random.nextBool()) child['unknown'] = true;
      final payload = <String, dynamic>{};
      if (random.nextInt(6) != 0) {
        payload['account'] = random.nextInt(8) == 0 ? null : child;
      }
      if (random.nextBool()) payload['optional'] = null;
      if (random.nextBool()) payload['extra'] = 'strip';
      final reason =
          'seed=$seed trial=$trial flags=$constrained/$defaulted/$transformed/$listed input=${jsonEncode(payload)}';
      final inputs = List.generate(3, (_) => _copy(payload));
      final expected = schema(ordinary: true).tryParse(inputs[0]);
      final fast = schema().tryParse(inputs[1]);
      final async = await schema(async: true).tryParseAsync(inputs[2]);
      for (final result in [fast, async]) {
        expect(result.success, expected.success, reason: reason);
        expect(result.value, expected.value, reason: reason);
        expect(result.issues, expected.issues, reason: reason);
      }
      for (var i = 0; i < inputs.length; i++) {
        expect(inputs[i], payload, reason: reason);
        expect(
          _sharing(inputs[i], [expected, fast, async][i].value),
          _sharing(inputs[0], expected.value),
          reason: reason,
        );
      }
    }
  });

  test('random live updates agree with full sync and async validation', () async {
    final random = Random(seed);
    for (final dependent in [false, true]) {
      var schema = object({
        'a/b': string().email().email(),
        '0': string().min(2).withDefault('fallback'),
        '~.': string().transform((s) => s.trim()),
      });
      if (dependent) {
        schema = schema.addFieldDependency(
          dependent: 'a/b',
          dependendsOn: '0',
          dependency: (a, b) => a != b,
        );
      }
      final input = <String, dynamic>{
        'a/b': 'ok@example.com',
        '0': 'ok',
        '~.': ' x ',
      };
      final sync = schema.watch(input);
      final async = await schema.watchAsync(input);
      for (var trial = 0; trial < count; trial++) {
        final key = ['a/b', '0', '~.'][random.nextInt(3)];
        final value = [
          null,
          42,
          '',
          ' x ',
          'ok@example.com',
        ][random.nextInt(5)];
        input[key] = value;
        final delta = sync.set(key, value);
        final asyncDelta = await async.set(key, value);
        final full = schema.tryParse(_copy(input));
        final reason =
            'seed=$seed update=$trial dependent=$dependent input=${jsonEncode(input)}';
        expect(sync.issues, full.issues, reason: reason);
        expect(async.issues, full.issues, reason: reason);
        expect(delta.changedIssues, asyncDelta.changedIssues, reason: reason);
        expect(
          sync.validated,
          full.success ? full.value : null,
          reason: reason,
        );
        expect(async.validated, sync.validated, reason: reason);
        expect(sync.input, input, reason: reason);
      }
    }
  });
}
