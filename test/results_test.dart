import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('all synchronous entry points reject async compositions', () {
    final child = string().refineAsync(
      onCheck: (_) async => true,
      name: 'remote',
      error: '',
    );
    for (final schema in <AcanthisType>[
      child.nullable(),
      tuple([child]),
      string().pipe(child, transform: (value) => value),
    ]) {
      expect(schema.isAsync, isTrue);
      expect(
        () => schema.parse(null),
        throwsA(isA<AsyncValidationException>()),
      );
      expect(
        () => schema.tryParse(null),
        throwsA(isA<AsyncValidationException>()),
      );
      expect(
        () => schema.validate(null),
        throwsA(isA<AsyncValidationException>()),
      );
    }
  });

  test('union throwing paths preserve the first own-check message', () async {
    var laterCalls = 0;
    final schema = union<String>([string()])
        .refine(onCheck: (_) => false, name: 'first', error: 'First failure')
        .refine(
          onCheck: (_) {
            laterCalls++;
            return false;
          },
          name: 'second',
          error: 'Later failure',
        );
    expect(schema.validate('Ada'), 'First failure');
    expect(
      await schema
          .refineAsync(onCheck: (_) async => true, name: 'remote', error: '')
          .validateAsync('Ada'),
      'First failure',
    );
    expect(laterCalls, 0);
  });

  test('tryParse exposes typed success', () {
    final outcome = string().tryParse('acanthis');

    expect(outcome, isA<AcanthisValid<String>>());
    expect((outcome as AcanthisValid<String>).value, 'acanthis');
  });

  test('tryParse emits data-only nested paths', () {
    final outcome =
        object({
          'account': object({'email': string().email()}),
        }).tryParse({
          'account': {'email': 'invalid'},
        });

    expect(outcome, isA<AcanthisInvalid<Map<String, dynamic>>>());
    final issue = (outcome as AcanthisInvalid).issues.single;
    expect(issue.path, ['account', 'email']);
    expect(issue.jsonPointer, '/account/email');
  });

  test('parse and parseAsync return raw transformed values', () async {
    final schema = string().transform((value) => value.trim());
    final String sync = schema.parse(' Ada ');
    final String async = await schema.parseAsync(' Ada ');
    expect(sync, 'Ada');
    expect(async, sync);
    expect(() => string().min(2).parse('x'), throwsA(isA<ValidationError>()));
    await expectLater(
      string().min(2).parseAsync('x'),
      throwsA(isA<ValidationError>()),
    );
  });

  test(
    'both outcomes expose value and metadata through the base type',
    () async {
      const metadata = MetadataEntry<String>(description: 'Display name');
      final schema = string().min(3).withDefault('Guest').meta(metadata);
      for (final outcome in [
        schema.tryParse('x'),
        await schema.tryParseAsync('x'),
      ]) {
        expect(outcome, isA<AcanthisInvalid<String>>());
        final invalid = outcome as AcanthisInvalid<String>;
        expect(outcome.value, 'Guest');
        expect(invalid.metadata, same(metadata));
        expect(invalid.issues.single.code, 'minLength');
      }
      final valid = schema.tryParse('Ada') as AcanthisValid<String>;
      expect(valid.value, 'Ada');
      expect(valid.metadata, same(metadata));
      expect(valid.issues, isEmpty);
    },
  );

  test('nullable success is distinct from invalid nullable recovery', () {
    final schema = string().min(3).nullable();
    final valid = schema.tryParse(null);
    expect(valid, isA<AcanthisValid<String?>>());
    expect((valid as AcanthisValid<String?>).value, isNull);
    final invalid = schema.tryParse('x');
    expect(invalid, isA<AcanthisInvalid<String?>>());
    expect((invalid as AcanthisInvalid<String?>).value, 'x');
  });

  test('invalid outcomes snapshot and protect their ordered issues', () {
    final issue = AcanthisIssue(path: [], code: 'custom', message: 'Invalid');
    final source = [issue, issue];
    final invalid = AcanthisInvalid<String>(source, value: 'x');
    source.clear();
    expect(invalid.issues, [issue, issue]);
    expect(() => invalid.issues.clear(), throwsUnsupportedError);
    invalid.errors.clear();
    expect(invalid.issues, hasLength(2));
  });

  test(
    'async outcomes preserve nested failures and transformed successes',
    () async {
      final schema = object({
        'name': string()
            .transform((value) => value.trim())
            .refineAsync(
              onCheck: (value) async => value == 'Ada',
              name: 'available',
              error: 'Unavailable',
            ),
      });
      final Map<String, dynamic> parsed = await schema.parseAsync({
        'name': ' Ada ',
      });
      expect(parsed, {'name': 'Ada'});
      final valid = await schema.tryParseAsync({'name': ' Ada '});
      expect((valid as AcanthisValid<Map<String, dynamic>>).value, parsed);
      final invalid = await schema.tryParseAsync({'name': ' Bob '});
      expect(invalid, isA<AcanthisInvalid<Map<String, dynamic>>>());
      expect(invalid.issues.single.path, ['name']);
      expect((invalid as AcanthisInvalid).value, {'name': 'Bob'});
    },
  );
}
