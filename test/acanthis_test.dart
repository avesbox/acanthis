import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('tryParse returns a typed valid outcome', () {
    final result = AcanthisString().tryParse('This is a test');
    expect(result, isA<AcanthisValid<String>>());
    expect((result as AcanthisValid<String>).value, 'This is a test');
    expect(result.issues, isEmpty);
  });
}
