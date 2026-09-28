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
    'live rules reuse independent fields, clear skipped issues and match full',
    () {
      var transforms = 0;
      final schema = object({
        'password': string(),
        'confirm': string(),
        'other': string().transform((s) {
          transforms++;
          return s;
        }),
      }).rule(matching());
      final session = schema.watch({
        'password': 'a',
        'confirm': 'a',
        'other': 'ok',
      });
      final delta = session.set('password', 'b');
      expect(delta.executedFields, {'password'});
      expect(delta.executedRules, {'matching'});
      expect(delta.addedIssues.single.code, 'mismatch');
      expect(transforms, 1);
      final skipped = session.set('confirm', 1);
      expect(skipped.removedIssues.single.code, 'mismatch');
      expect(
        session.issues,
        (schema.tryParse(session.input) as AcanthisInvalid).issues,
      );
      expect(session.set('other', 'new').executedRules, isEmpty);
    },
  );

  test(
    'batch is atomic, one revision, supports nested lists and explicit removal',
    () {
      final schema = object({
        'items': object({'name': string()}).list(),
        'nullable': string().nullable(),
      }).optionals(['nullable']);
      final session = schema.watch({
        'items': [
          {'name': 'a'},
          {'name': 'b'},
        ],
        'nullable': null,
      });
      final delta = session.batch([
        AcanthisEdit.remove(AcanthisPath(['items', 0])),
        AcanthisEdit.set(AcanthisPath(['items', 0, 'name']), 'c'),
        AcanthisEdit.remove(AcanthisPath(['nullable'])),
      ]);
      expect(delta.revision, 1);
      expect(session.validated, schema.parse(session.input));
      expect(session.input.containsKey('nullable'), false);
      session.set('nullable', null);
      expect(session.input.containsKey('nullable'), true);
      expect(
        () => session.batch([
          AcanthisEdit.set(AcanthisPath(['nullable']), 'x'),
          AcanthisEdit.remove(AcanthisPath(['missing', 0])),
        ]),
        throwsArgumentError,
      );
      expect(session.revision, 2);
      expect(session.input['nullable'], isNull);
      expect(
        () => (delta.input['items'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('required removal and validated defaults match full parsing', () {
    final schema = object({
      'a': string(),
      'b': string().withDefault('default'),
    });
    final session = schema.watch({'a': 'a', 'b': 'b'});
    session.remove('b');
    expect(session.validated, schema.parse(session.input));
    session.remove('a');
    expect(
      session.issues,
      (schema.tryParse(session.input) as AcanthisInvalid).issues,
    );
  });

  test('unknown key policies remain consistent during editing', () {
    for (final schema in [
      object({'a': string()}),
      object({'a': string()}).passthrough(),
      object({'a': string()}).unknownKeys(AcanthisUnknownKeys.reject),
    ]) {
      final session = schema.watch({'a': 'a'});
      session.set('extra', 1);
      final full = schema.tryParse(session.input);
      expect(session.validated, full.isValid ? full.value : null);
      if (full is AcanthisInvalid) expect(session.issues, full.issues);
      session.remove('extra');
      expect(session.validated, {'a': 'a'});
    }
  });

  test('context updates invalidate nested checks and selected rules', () async {
    final path = AcanthisPath(['a']);
    final schema = object({'a': string()}).rule(
      AcanthisRule<String>(
        id: 'tenant',
        inputs: [path],
        outputs: [path],
        check: (v, context) => v.value<String>(path) == context
            ? []
            : [
                AcanthisIssue(
                  path: ['a'],
                  code: 'tenant',
                  message: 'Wrong tenant',
                ),
              ],
      ),
    );
    final session = schema.watch({
      'a': 'a',
    }, scope: const AcanthisValidationScope(context: 'a'));
    expect(session.updateContext('b').addedIssues.single.code, 'tenant');
    final asyncSession = await schema.watchAsync({
      'a': 'a',
    }, scope: const AcanthisValidationScope(context: 'a'));
    expect(
      (await asyncSession.updateContext('b')).addedIssues.single.code,
      'tenant',
    );
  });
}
