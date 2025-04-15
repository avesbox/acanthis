import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

DateTime _transformDateTime(DateTime value) {
  return value;
}

void main() {
  group('$AcanthisPipeline', () {
    test("Can be created using `const`", () {
      const AcanthisPipeline(
        inType: AcanthisType<DateTime>(),
        outType: AcanthisType<DateTime>(),
        transform: _transformDateTime,
      );
    });
    test(
      'when creating a pipeline to convert a string to a date, and the string is a parsable string, then the result should be successful',
      () {
        final pipeline = string().dateTime().pipe(
              date(),
              transform: (value) => DateTime.parse(value),
            );
        final result = pipeline.tryParse('2020-01-01');

        expect(result.success, true);

        final resultParse = pipeline.parse('2020-01-01');

        expect(resultParse.success, true);

        expect(result.value, isA<DateTime>());
      },
    );

    test(
      'when creating a pipeline to convert a string to a date, and the string is not a parsable string, then the result should be unsuccessful',
      () {
        final pipeline = string().dateTime().pipe(
              date(),
              transform: (value) => DateTime.parse(value),
            );
        final result = pipeline.tryParse('aaaa');

        expect(result.success, false);

        expect(() => pipeline.parse('aaaa'),
            throwsA(TypeMatcher<ValidationError>()));
      },
    );
  });
}
