import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('an independent field update validates only that field', () {
    final session = object({'email': string().email(), 'name': string().min(2)})
        .watch({'email': 'a@b.com', 'name': 'Ada'});

    final delta = session.set('email', 'invalid');

    expect(delta.fullValidation, isFalse);
    expect(delta.executedFields, {'email'});
    expect(delta.changedIssues.single.path, ['email']);
    expect(session.validated, isNull);
    expect(session.explain('email'), contains('value changed'));
  });

  test('a schema with a cross-field dependency conservatively revalidates', () {
    final session = object({'password': string(), 'confirmation': string()})
        .addFieldDependency(
          dependent: 'confirmation',
          dependendsOn: 'password',
          dependency: (password, confirmation) => password == confirmation,
        )
        .watch({'password': 'a', 'confirmation': 'a'});

    final delta = session.set('password', 'b');

    expect(delta.fullValidation, isTrue);
    expect(delta.changedIssues, isNotEmpty);
    expect(session.explain('confirmation'), contains('cross-field'));
  });

  test('a corrected independent value restores the complete snapshot', () {
    final session = object({'email': string().email(), 'name': string().min(2)})
        .watch({'email': 'bad', 'name': 'Ada'});

    session.set('email', 'ada@example.com');

    expect(session.validated, {'email': 'ada@example.com', 'name': 'Ada'});
  });

  test('async sessions discard stale validation responses', () async {
    final schema = object({
      'name': string().refineAsync(
        onCheck: (value) async {
          await Future<void>.delayed(
            Duration(milliseconds: value == 'slow' ? 20 : 1),
          );
          return value == 'fast';
        },
        error: 'not available',
        name: 'remote',
      ),
    });
    final session = await schema.watchAsync({'name': 'fast'});

    final slow = session.set('name', 'slow');
    final fast = session.set('name', 'fast');
    await Future.wait([slow, fast]);

    expect(session.validated, {'name': 'fast'});
    expect(session.issues, isEmpty);
  });
}
