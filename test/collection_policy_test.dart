import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'field stopping prevents expensive checks while other fields collect',
    () async {
      var remote = 0;
      final schema = object({
        'name': string()
            .min(3)
            .refineAsync(
              onCheck: (_) async {
                remote++;
                return false;
              },
              error: 'remote',
              name: 'remote',
            ),
        'email': string().email(),
      });
      final result =
          await const AcanthisValidationScope(
                fieldPolicy: AcanthisCollectionPolicy.first,
              ).run(() => schema.tryParseAsync({'name': '', 'email': 'bad'}))
              as AcanthisInvalid;
      expect(remote, 0);
      expect(result.issues.map((i) => i.path.first), ['name', 'email']);
      final stopped =
          await const AcanthisValidationScope(
                objectPolicy: AcanthisCollectionPolicy.first,
                fieldPolicy: AcanthisCollectionPolicy.first,
              ).run(() => schema.tryParseAsync({'name': '', 'email': 'bad'}))
              as AcanthisInvalid;
      expect(stopped.issues.length, 1);
    },
  );

  test('sync operation stopping and object policy are independent', () {
    var count = 0;
    final field = string()
        .min(2)
        .refine(
          onCheck: (_) {
            count++;
            return false;
          },
          error: 'later',
          name: 'later',
        );
    final schema = object({'a': field, 'b': string()});
    final result = const AcanthisValidationScope(
      fieldPolicy: AcanthisCollectionPolicy.first,
    ).run(() => schema.tryParse({'a': '', 'b': 1})) as AcanthisInvalid;
    expect(count, 0);
    expect(result.issues.length, 2);
  });
}
