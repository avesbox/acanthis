import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('seeded nested edits match full sync and async evaluation', () async {
    final selected = AcanthisPath(['items', 1, 'value']);
    final schema =
        object({
          'items': object({'value': string().min(1)}).list(),
          'other': string().min(1),
        }).rule(
          AcanthisRule<void>(
            id: 'second',
            inputs: [selected],
            outputs: [selected],
            check: (v, _) => v.value<String>(selected) == 'bad'
                ? [
                    AcanthisIssue(
                      path: selected.segments,
                      code: 'second',
                      message: 'Bad second item',
                    ),
                  ]
                : [],
          ),
        );
    final initial = {
      'items': [
        {'value': 'ok'},
        {'value': 'bad'},
      ],
      'other': 'ok',
    };
    final sync = schema.watch(initial);
    final asyncSession = await schema.watchAsync(initial);
    final random = Random(90428);
    for (var i = 0; i < 200; i++) {
      final edits = switch (random.nextInt(4)) {
        0 => [
          AcanthisEdit.set(
            AcanthisPath(['other']),
            random.nextBool() ? '' : 'ok',
          ),
        ],
        1 => [
          AcanthisEdit.set(
            AcanthisPath(['items', 0, 'value']),
            random.nextBool() ? 'bad' : 'ok',
          ),
        ],
        2 => [
          AcanthisEdit.remove(AcanthisPath(['items', 0])),
          AcanthisEdit.set(AcanthisPath(['items', 1]), {'value': 'ok'}),
        ],
        _ => [AcanthisEdit.set(selected, random.nextBool() ? 'bad' : 1)],
      };
      sync.batch(edits);
      await asyncSession.batch(edits);
      final full = schema.tryParse(sync.input);
      final fullIssues = full is AcanthisInvalid
          ? full.issues
          : <AcanthisIssue>[];
      expect(sync.issues, fullIssues, reason: 'sync edit $i');
      expect(asyncSession.issues, fullIssues, reason: 'async edit $i');
      expect(sync.validated, full.isValid ? full.value : null);
      expect(asyncSession.validated, sync.validated);
    }
  });

  test('equal issues from different rules retain independent ownership', () {
    final a = AcanthisPath(['a']);
    final b = AcanthisPath(['b']);
    final target = AcanthisPath(['target']);
    AcanthisRule<void> rule(String id, AcanthisPath input) =>
        AcanthisRule<void>(
          id: id,
          inputs: [input],
          outputs: [target],
          check: (v, _) => v.value<String>(input).isEmpty
              ? [
                  AcanthisIssue(
                    path: ['target'],
                    code: 'required',
                    message: 'Required',
                  ),
                ]
              : [],
        );
    final schema = object({'a': string(), 'b': string(), 'target': string()})
        .rule(rule('a', a))
        .rule(rule('b', b));
    final session = schema.watch({'a': '', 'b': '', 'target': ''});
    expect(session.issues.length, 2);
    final delta = session.set('a', 'ok');
    expect(delta.removedIssues.length, 1);
    expect(delta.addedIssues, isEmpty);
    expect(delta.executedRules, {'a'});
    expect(session.issues.length, 1);
  });

  test('typed list outputs retain their element type in sessions', () {
    final schema = AcanthisMap<List<int>>({'items': integer().list()});
    final session = schema.watch({
      'items': [1, 2],
    });
    expect(session.validated!['items'], isA<List<int>>());
    session.setPath(AcanthisPath(['items', 0]), 3);
    expect(session.validated, {
      'items': [3, 2],
    });
  });
}
