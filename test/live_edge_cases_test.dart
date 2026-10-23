import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'incremental rules retain valid nested siblings beside invalid fields',
    () {
      final schema =
          object({
            'nested': object({'good': string().trim(), 'bad': integer()}),
            'other': string(),
          }).checkFields(
            [
              ['nested', 'good'],
            ],
            at: ['nested', 'good'],
            name: 'selected',
            check: (v) => v.value<String>(['nested', 'good']) == 'ok',
          );
      final session = schema.watch({
        'nested': {'good': ' bad ', 'bad': 'invalid'},
        'other': 'a',
      });
      expect(session.issues.map((i) => i.code), ['type', 'selected']);
      final unrelated = session.set('other', 'b');
      expect(unrelated.executedRules, isEmpty);
      expect(session.issues, schema.tryParse(session.input).issues);
      final fixed = session.setPath(['nested', 'good'], ' ok ');
      expect(fixed.removedIssues.single.code, 'selected');
      expect(session.issues, schema.tryParse(session.input).issues);
      expect(session.validated, isNull);
    },
  );

  test(
    'missing optional, nullable defaults, and patches match full parsing',
    () {
      for (final schema in [
        object({'a': string().nullable().withDefault(null), 'b': string()})
            .optionals(['b']),
        object({'a': string().withDefault('default'), 'b': string()}).patch(),
      ]) {
        final session = schema.watch({});
        session.set('b', 'x');
        expect(session.validated, schema.parse(session.input));
        session.remove('b');
        expect(session.validated, schema.parse(session.input));
        session.set('a', null);
        final result = schema.tryParse(session.input);
        expect(session.validated, result.isValid ? result.value : null);
        expect(session.issues, result.issues);
      }
    },
  );

  test(
    'full fallback preserves root transforms and collection policies',
    () async {
      var calls = 0;
      final schema = object({'a': string(), 'b': string()}).transform((value) {
        calls++;
        return {...value, 'joined': '${value['a']}${value['b']}'};
      });
      final session = schema.watch({'a': 'a', 'b': 'b'});
      final delta = session.set('a', 'c');
      expect(delta.fullValidation, isTrue);
      expect(delta.executedFields, {'a', 'b'});
      expect(calls, 2);
      expect(session.validated!['joined'], 'cb');
      final first = await object({'a': string(), 'b': string()}).watchAsync(
        {'a': 1, 'b': 2},
        scope: const AcanthisValidationScope(
          objectPolicy: AcanthisCollectionPolicy.first,
        ),
      );
      final result = await first.set('a', 'ok');
      expect(result.fullValidation, isTrue);
      expect(result.issues.single.path, ['b']);
      first.dispose();
    },
  );

  test(
    'typed unknown fields are validated even when named fields are cached',
    () async {
      final schema = object({'a': string()})
          .passthrough(type: integer().gte(0));
      final sync = schema.watch({'a': 'ok', 'extra': 1});
      final async = await schema.watchAsync(sync.input);
      for (final value in [-1, 'invalid', 2]) {
        sync.set('extra', value);
        final delta = await async.set('extra', value);
        expect(delta.executedFields, isEmpty);
        expect(sync.issues, schema.tryParse(sync.input).issues);
        expect(async.issues, sync.issues);
        expect(async.validated, sync.validated);
      }
      async.dispose();
    },
  );

  test('input and deltas are isolated, frozen, and batches reject cycles atomically', () {
    final initial = <String, Object?>{
      'items': <Object?>['a'],
    };
    final session = object({'items': string().list()}).watch(initial);
    (initial['items'] as List).add('outside');
    final replacement = ['b'];
    final delta = session.set('items', replacement);
    replacement.add('outside');
    session.setPath(['items', 0], 'c');
    expect(delta.input['items'], ['b']);
    expect(delta.validated!['items'], ['b']);
    expect(() => delta.input.clear(), throwsUnsupportedError);
    expect(
      () => (session.input['items'] as List).add('x'),
      throwsUnsupportedError,
    );
    final cycle = <Object?>[];
    cycle.add(cycle);
    expect(
      () => session.batch([
        AcanthisEdit.set('items', ['changed']),
        AcanthisEdit.set('items', cycle),
      ]),
      throwsArgumentError,
    );
    expect(session.revision, 2);
    expect(session.input['items'], ['c']);
    expect(() => object({}).watch({'cyclic': cycle}), throwsArgumentError);
  });

  test(
    'synchronous reentrancy is rejected before changing revision or input',
    () {
      AcanthisLiveSession? session;
      final schema = object({
        'a': string().refine(
          onCheck: (v) {
            if (v == 'edit') session!.set('a', 'reentrant');
            return true;
          },
        ),
      });
      session = schema.watch({'a': 'ok'});
      expect(() => session!.set('a', 'edit'), throwsStateError);
      expect(session.revision, 1);
      expect(session.input['a'], 'edit');
      expect(session.validated, isNull);
      session.set('a', 'fixed');
      expect(session.validated, {'a': 'fixed'});
    },
  );

  test(
    'disposing a debounced revision cancels it and prevents new edits',
    () async {
      final session = await object({'a': string()})
          .watchAsync({'a': 'ok'}, debounce: const Duration(seconds: 30));
      final future = session.set('a', 'new');
      session.dispose();
      final revision = session.revision;
      session.dispose();
      expect(session.revision, revision);
      final delta = await future;
      expect(delta.settled, isFalse);
      expect(delta.isCurrent, isFalse);
      expect(session.pendingFields, isEmpty);
      expect(session.validated, isNull);
      expect(() => session.updateContext(null), throwsStateError);
    },
  );

  test(
    'parent cancellation reaches active callbacks and remains control flow',
    () async {
      final parent = AcanthisCancellationSignal();
      final entered = Completer<AcanthisCancellationSignal>();
      final release = Completer<void>();
      final schema = object({
        'a': string().refineAsync(
          CallbackAsyncCheck((v, c) async {
            if (v == 'wait') {
              entered.complete(c.cancellation!);
              await release.future;
            }
          }),
        ),
      });
      final session = await schema.watchAsync({
        'a': 'ok',
      }, scope: AcanthisValidationScope(cancellation: parent));
      final future = session.set('a', 'wait');
      final signal = await entered.future;
      final assertion = expectLater(
        future,
        throwsA(isA<AcanthisValidationCancelled>()),
      );
      parent.cancel();
      expect(signal.isCancelled, isTrue);
      release.complete();
      await assertion;
      expect(session.pendingFields, isEmpty);
      expect(session.validated, isNull);
      expect(
        () => session.set('a', 'ignored'),
        throwsA(isA<AcanthisValidationCancelled>()),
      );
      expect(session.revision, 1);
      session.dispose();
    },
  );

  test(
    'context changes invalidate nested callbacks and all rule caches',
    () async {
      var calls = 0;
      final schema = object({
        'nested': object({
          'name': string().withCheck(
            CallbackCheck((v, c) {
              calls++;
              if (v != c.contextAs<String>()) c.addIssue('tenant');
            }),
          ),
        }),
      });
      final session = await schema.watchAsync({
        'nested': {'name': 'first'},
      }, scope: const AcanthisValidationScope(context: 'first'));
      final delta = await session.updateContext('second');
      expect(delta.addedIssues.single.code, 'tenant');
      expect(delta.executedFields, {'nested'});
      expect(calls, 2);
      session.dispose();
    },
  );

  test('sync schemas reject watch when any descendant or rule is async', () {
    final schema = object({'a': string()}).checkFieldsAsync(
      ['a'],
      at: 'a',
      name: 'remote',
      check: (_) async => true,
    );
    expect(() => schema.watch({'a': 'ok'}), throwsArgumentError);
    expect(
      object({'a': string()})
          .watchAsync({'a': 'ok'}, debounce: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });
}
