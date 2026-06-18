import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisPipeline', () {
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
      'when using a pipeline inside an object, then the parsed field should keep the transformed value',
      () {
        final schema = object({
          'close_at': string().dateTime().pipe(
            date(),
            transform: (value) => DateTime.parse(value),
          ),
        });

        final result = schema.tryParse({
          'close_at': '2026-06-10T10:20:52+00:00',
        });

        expect(result.success, true);
        expect(result.value['close_at'], isA<DateTime>());
      },
    );

    test(
      'when using a pipeline inside a list, then each parsed item should keep the transformed value',
      () {
        final schema = string()
            .dateTime()
            .pipe(date(), transform: (value) => DateTime.parse(value))
            .list();

        final result = schema.tryParse(['2026-06-10T10:20:52+00:00']);

        expect(result.success, true);
        expect(result.value.single, isA<DateTime>());
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

        expect(
          () => pipeline.parse('aaaa'),
          throwsA(TypeMatcher<ValidationError>()),
        );
      },
    );
  });
}
