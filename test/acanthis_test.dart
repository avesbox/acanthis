import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('Should return a string with the message', () {
    AcanthisParseResult result =
        AcanthisType<String>().tryParse('This is a test');

    expect(result.success, true);
    expect(result.value, 'This is a test');
    expect(result.toString(),
        'AcanthisParseResult<String>{value: This is a test, errors: {}, success: true}');
  });
}
