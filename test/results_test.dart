import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('validate exposes typed success', () {
    final outcome = string().validate('acanthis');

    expect(outcome, isA<AcanthisValid<String>>());
    expect((outcome as AcanthisValid<String>).value, 'acanthis');
  });

  test('validate emits data-only nested paths', () {
    final outcome =
        object({
          'account': object({'email': string().email()}),
        }).validate({
          'account': {'email': 'invalid'},
        });

    expect(outcome, isA<AcanthisInvalid<Map<String, dynamic>>>());
    final issue = (outcome as AcanthisInvalid).issues.single;
    expect(issue.path, ['account', 'email']);
    expect(issue.jsonPointer, '/account/email');
  });
}
