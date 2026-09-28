import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'async revisions capture input, cancellation, pending and stale outcomes',
    () async {
      final slow = Completer<void>();
      AcanthisCancellationSignal? oldSignal;
      final schema = object({
        'name': string().refineAsync(
          onCheck: (v) async {
            if (v == 'slow') {
              oldSignal = AcanthisValidationScope.current.cancellation;
              await slow.future;
            }
            return v != 'slow';
          },
          error: 'unavailable',
          name: 'remote',
        ),
        'other': string(),
      });
      final session = await schema.watchAsync({
        'name': 'initial',
        'other': 'a',
      });
      final old = session.set('name', 'slow');
      await Future<void>.delayed(Duration.zero);
      expect(session.pendingFields, {'name'});
      final latest = await session.set('name', 'fast');
      expect(oldSignal!.isCancelled, true);
      slow.complete();
      final stale = await old;
      expect(stale.isCurrent, false);
      expect(stale.input['name'], 'slow');
      expect(stale.issues.single.code, 'remote');
      expect(latest.revision, 2);
      expect(session.validated!['name'], 'fast');
      expect(session.pendingFields, isEmpty);
      session.dispose();
      expect(() => session.set('name', 'x'), throwsStateError);
    },
  );

  test('debounced edits coalesce work and preserve all dirty fields', () async {
    var calls = 0;
    final schema = object({
      'a': string().refineAsync(
        onCheck: (_) async {
          calls++;
          return true;
        },
        error: 'x',
        name: 'x',
      ),
      'b': string(),
    });
    final session = await schema.watchAsync({
      'a': 'a',
      'b': 'b',
    }, debounce: const Duration(milliseconds: 5));
    final first = session.set('a', 'new');
    final second = session.set('b', 'new');
    expect((await first).settled, false);
    final result = await second;
    expect(result.executedFields, {'a', 'b'});
    expect(calls, 2);
    expect(
      session.validated,
      (await schema.tryParseAsync(session.input)).value,
    );
  });
  test(
    'pending fields settle individually and callback failures clear pending',
    () async {
      final waiting = Completer<void>();
      final entered = Completer<void>();
      final schema = object({
        'a': string(),
        'b': string().refineAsync(
          onCheck: (v) async {
            if (v == 'wait') {
              entered.complete();
              await waiting.future;
            }
            return true;
          },
          error: 'remote',
          name: 'remote',
        ),
      });
      final session = await schema.watchAsync({'a': 'a', 'b': 'b'});
      final future = session.batch([
        AcanthisEdit.set(AcanthisPath(['a']), 'new'),
        AcanthisEdit.set(AcanthisPath(['b']), 'wait'),
      ]);
      await entered.future;
      expect(session.pendingFields, {'b'});
      waiting.complete();
      await future;
      expect(session.pendingFields, isEmpty);
    },
  );

  test(
    'live async rule failures propagate and leave the revision unsettled',
    () async {
      final path = AcanthisPath(['a']);
      final schema = object({'a': string()}).rule(
        AcanthisRule<void>.async(
          id: 'throws',
          inputs: [path],
          outputs: [path],
          check: (v, _) async {
            if (v.value<String>(path) == 'throw') {
              throw StateError('application');
            }
            return [];
          },
        ),
      );
      final session = await schema.watchAsync({'a': 'ok'});
      await expectLater(session.set('a', 'throw'), throwsStateError);
      expect(session.validated, isNull);
      expect(session.pendingFields, isEmpty);
      await session.set('a', 'ok');
      expect(session.validated, {'a': 'ok'});
    },
  );
}
