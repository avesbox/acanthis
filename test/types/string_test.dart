import 'package:acanthis/acanthis.dart' as acanthis;
import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/types/string.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisType<String> ', () {
    test("Can be created using `const`", () {
      const AcanthisType<String>();
    });

    test(
        'when creating a string validator,'
        'and the string is valid, '
        'then the result should be successful', () {
      final string = acanthis.string();
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a max check,'
        'and the string is greater than the check, '
        'then the result should be successful', () {
      final string = acanthis.string().max(3);
      final result = string.tryParse('tes');

      expect(result.success, true);

      final resultParse = string.parse('tes');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a max check,'
        'and the string is greater than the check, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().max(3);
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a min check,'
        'and the string is less than the check, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().min(5);
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a min check,'
        'and the string is less than the check, '
        'then the result should be successful', () {
      final string = acanthis.string().min(3);
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a min and max check,'
        'and the string is less than the min check, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().min(5).max(10);
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a min and max check,'
        'and the string is greater than the max check, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().min(1).max(3);
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a min and max check,'
        'and the string is within the min and max check, '
        'then the result should be successful', () {
      final string = acanthis.string().min(1).max(10);
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a pattern check,'
        'and the string matches the pattern, '
        'then the result should be successful', () {
      final string = acanthis.string().pattern(RegExp(r'^[a-z]+$'));
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a pattern check,'
        'and the string does not match the pattern, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().pattern(RegExp(r'^[a-z]+$'));
      final result = string.tryParse('test1');

      expect(result.success, false);

      expect(
          () => string.parse('test1'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a required check,'
        'and the string is empty, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().required();
      final result = string.tryParse('');

      expect(result.success, false);

      expect(() => string.parse(''), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a required check,'
        'and the string is not empty, '
        'then the result should be successful', () {
      final string = acanthis.string().required();
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with an email check,'
        'and the string is a valid email, '
        'then the result should be successful', () {
      final string = acanthis.string().email();
      final result = string.tryParse('test@test.com');

      expect(result.success, true);

      final resultParse = string.parse('test@test.com');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with an email check,'
        'and the string is not a valid email, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().email();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a length check,'
        'and the string length is not the same, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().length(5);
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a length check,'
        'and the string length is the same, '
        'then the result should be successful', () {
      final string = acanthis.string().length(4);
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a contains check,'
        'and the string contains the substring, '
        'then the result should be successful', () {
      final string = acanthis.string().contains('es');
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a contains check,'
        'and the string does not contain the substring, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().contains('us');
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a startsWith check,'
        'and the string does not starts with the substring, '
        'then the result should be successful', () {
      final string = acanthis.string().startsWith('te');
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a startsWith check,'
        'and the string does not starts with the substring, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().startsWith('es');
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a endsWith check,'
        'and the string does not ends with the substring, '
        'then the result should be successful', () {
      final string = acanthis.string().endsWith('st');
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a endsWith check,'
        'and the string does not ends with the substring, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().endsWith('es');
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with a custom check,'
        'and the custom check is successful, '
        'then the result should be successful', () {
      final string = acanthis.string().refine(
          onCheck: (value) => value == 'test',
          error: 'Value must be test',
          name: 'customCheck');
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    });

    test(
        'when creating a string validator with a custom check,'
        'and the custom check is unsuccessful, '
        'then the result should be unsuccessful', () {
      final string = acanthis.string().refine(
          onCheck: (value) => value == 'test',
          error: 'Value must be test',
          name: 'customCheck');
      final result = string.tryParse('test1');

      expect(result.success, false);

      expect(
          () => string.parse('test1'), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a string validator with the toUpperCase transformation,'
        'and the string is valid, '
        'then the result should be the string in uppercase', () {
      final string = acanthis.string().toUpperCase();
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
      expect(resultParse.value, 'TEST');
    });

    test(
        'when creating a string validator with the toLowerCase transformation,'
        'and the string is valid, '
        'then the result should be the string in lowercase', () {
      final string = acanthis.string().toLowerCase();
      final result = string.tryParse('TEST');

      expect(result.success, true);

      final resultParse = string.parse('TEST');

      expect(resultParse.success, true);
      expect(resultParse.value, 'test');
    });

    test(
        'when creating a string validator with the encode transformation,'
        'and the string is valid, '
        'then the result should be the string encoded in base64', () {
      final string = acanthis.string().encode();
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
      expect(resultParse.value, 'dGVzdA==');
    });

    test(
        'when creating a string validator with the decode transformation,'
        'and the string is valid, '
        'then the result should be the string decoded from base64', () {
      final string = acanthis.string().decode();
      final result = string.tryParse('dGVzdA==');

      expect(result.success, true);

      final resultParse = string.parse('dGVzdA==');

      expect(resultParse.success, true);
      expect(resultParse.value, 'test');
    });
    test("checks and transformations can be used as annotations", () {
      // TODO: RegExp is not const
      //@StringChecks.pattern(RegExp(r'^[a-z]+$'))
      @StringChecks.email
      @StringChecks.min(1)
      @StringChecks.max(1)
      @StringChecks.letters
      @StringChecks.strictLetters
      @StringChecks.digits
      @StringChecks.strictDigits
      @StringChecks.alphanumeric
      @StringChecks.strictAlphanumeric
      @StringChecks.alphanumericWithSpaces
      @StringChecks.strictAlphanumericWithSpaces
      @StringChecks.specialCharacters
      @StringChecks.strictSpecialCharacters
      @StringChecks.allCharacters
      @StringChecks.strictAllCharacters
      @StringChecks.upperCase
      @StringChecks.lowerCase
      @StringChecks.mixedCase
      @StringChecks.dateTime
      @StringChecks.time
      @StringChecks.uri
      @StringChecks.required
      @StringChecks.length(2)
      @StringChecks.contains("")
      @StringChecks.startsWith("")
      @StringChecks.endsWith("")
      @StringChecks.cuid
      @StringChecks.cuid2
      @StringChecks.ulid
      @StringChecks.uuid
      @StringChecks.nanoid
      @StringChecks.jwt
      @StringChecks.base64
      @StringChecks.hexColor
      @StringChecks.url
      @StringChecks.card
      @StringChecks.uncompromised
      @StringTransforms.toUpperCase
      @StringTransforms.toLowerCase
      @StringTransforms.base64Encode
      @StringTransforms.base64Decode
      @StringTransforms.trim

      // ignore: unused_local_variable
          final a = 1;
    });
  });

  test(
    'when creating a string validator with a letters check,'
    'and the string contains only letters, '
    'then the result should be successful',
    () {
      final string = acanthis.string().letters();
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with a letters check,'
    'and the string contains numbers, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().letters();
      final result = string.tryParse('test1');

      expect(result.success, false);

      expect(
          () => string.parse('test1'), throwsA(TypeMatcher<ValidationError>()));
    },
  );

  test(
    'when creating a string validator with a digits check,'
    'and the string contains only digits, '
    'then the result should be successful',
    () {
      final string = acanthis.string().digits();
      final result = string.tryParse('123');

      expect(result.success, true);

      final resultParse = string.parse('123');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with a digits check,'
    'and the string contains letters, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().digits();
      final result = string.tryParse('123a');

      expect(result.success, false);

      expect(
          () => string.parse('123a'), throwsA(TypeMatcher<ValidationError>()));
    },
  );

  test(
    'when creating a string validator with an alphanumeric check,'
    'and the string contains only letters and digits, '
    'then the result should be successful',
    () {
      final string = acanthis.string().alphanumeric();
      final result = string.tryParse('test123');

      expect(result.success, true);

      final resultParse = string.parse('test123');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with an alphanumeric check,'
    'and the string contains special characters, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().alphanumeric();
      final result = string.tryParse('test123!');

      expect(result.success, false);

      expect(
          () => string.parse('test123!'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a string validator with an alphanumeric with spaces check,'
    'and the string contains only letters, digits and spaces, '
    'then the result should be successful',
    () {
      final string = acanthis.string().alphanumericWithSpaces();
      final result = string.tryParse('test 123');

      expect(result.success, true);

      final resultParse = string.parse('test 123');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with an alphanumeric with spaces check,'
    'and the string contains special characters, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().alphanumericWithSpaces();
      final result = string.tryParse('test 123!');

      expect(result.success, false);

      expect(
          () => string.parse('test 123!'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a string validator with a special characters check,'
    'and the string contains only special characters, '
    'then the result should be successful',
    () {
      final string = acanthis.string().specialCharacters();
      final result = string.tryParse('!@#');

      expect(result.success, true);

      final resultParse = string.parse('!@#');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with a special characters check,'
    'and the string contains letters, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().specialCharacters();
      final result = string.tryParse('!@#a');

      expect(result.success, false);

      expect(
          () => string.parse('!@#a'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a string validator with an upperCase check,'
    'and the string is in uppercase, '
    'then the result should be successful',
    () {
      final string = acanthis.string().upperCase();
      final result = string.tryParse('TEST');

      expect(result.success, true);

      final resultParse = string.parse('TEST');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with an upperCase check,'
    'and the string is not in uppercase, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().upperCase();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a string validator with a lowerCase check,'
    'and the string is in lowercase, '
    'then the result should be successful',
    () {
      final string = acanthis.string().lowerCase();
      final result = string.tryParse('test');

      expect(result.success, true);

      final resultParse = string.parse('test');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with a lowerCase check,'
    'and the string is not in lowercase, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().lowerCase();
      final result = string.tryParse('TEST');

      expect(result.success, false);

      expect(
          () => string.parse('TEST'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a string validator with a mixedCase check,'
    'and the string is in mixed case, '
    'then the result should be successful',
    () {
      final string = acanthis.string().mixedCase();
      final result = string.tryParse('Test');

      expect(result.success, true);

      final resultParse = string.parse('Test');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with a mixedCase check,'
    'and the string is not in mixed case, '
    'then the result should be unsuccessful',
    () {
      final string = acanthis.string().mixedCase();
      final result = string.tryParse('TEST');

      expect(result.success, false);

      expect(
          () => string.parse('TEST'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
      final result2 = string.tryParse('test');

      expect(result2.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a string validator with multiple non-strict pattern checks, then the result should be successful',
    () {
      final string =
          acanthis.string().digits(strict: false).letters(strict: false);
      final result = string.tryParse('test 123');

      expect(result.success, true);

      final resultParse = string.parse('test 123');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with multiple non-strict pattern checks, then the result should be successful',
    () {
      final string = acanthis
          .string()
          .digits(strict: false)
          .letters(strict: false)
          .lowerCase();
      final result = string.tryParse('test 123');

      expect(result.success, true);

      final resultParse = string.parse('test 123');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a string validator with multiple non-strict pattern checks, then the result should be successful',
    () {
      final string = acanthis
          .string()
          .digits(strict: false)
          .letters(strict: false)
          .lowerCase();
      final result = string.tryParse('test 123');

      expect(result.success, true);

      final resultParse = string.parse('test 123');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a uri string validator, and the value is a parsable uri then the result should be successful',
    () {
      final string = acanthis.string().uri();
      final result = string.tryParse('https://test.com');

      expect(result.success, true);

      final resultParse = string.parse('https://test.com');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating an async string validator, then the result should be successful',
    () async {
      final string = acanthis.string().refineAsync(
            onCheck: (value) async {
              return value == 'test';
            },
            name: 'asyncCheck',
            error: 'Value must be test',
          );
      final result = await string.tryParseAsync('test');

      expect(result.success, true);

      final resultParse = await string.parseAsync('test');

      expect(resultParse.success, true);
    },
  );

  test(
    'when using an uncompromised check, and the password is on Pwoned then the result should be unsuccessful',
    () async {
      final string = acanthis.string().uncompromised();
      final result = await string.tryParseAsync('test');

      expect(result.success, false);
    },
  );

  test(
    'when creating an async string validator, and a sync parse method is used, then an exception should be thrown',
    () async {
      final string = acanthis.string().refineAsync(
            onCheck: (value) async {
              return value == 'test';
            },
            name: 'asyncCheck',
            error: 'Value must be test',
          );
      expect(
          () => string.parse('test'), throwsA(isA<AsyncValidationException>()));
    },
  );

  test(
    'when creating an uuid string validator, and the string is a valid uuid, then the result should be successful',
    () {
      final string = acanthis.string().uuid();
      final result = string.tryParse('550e8400-e29b-41d4-a716-446655440000');

      expect(result.success, true);

      final resultParse = string.parse('550e8400-e29b-41d4-a716-446655440000');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating an uuid string validator, and the string is not a valid uuid, then the result should be unsuccessful',
    () {
      final string = acanthis.string().uuid();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a ulid string validator, and the string is a valid ulid, then the result should be successful',
    () {
      final string = acanthis.string().ulid();
      final result = string.tryParse('01AN4Z07BY79KA1307SR9X4MV4');

      expect(result.success, true);

      final resultParse = string.parse('01AN4Z07BY79KA1307SR9X4MV4');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a ulid string validator, and the string is not a valid ulid, then the result should be unsuccessful',
    () {
      final string = acanthis.string().ulid();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a nanoid string validator, and the string is a valid nanoid, then the result should be successful',
    () {
      final string = acanthis.string().nanoid();
      final result = string.tryParse('V1StGXR8_Z5jdHi6B-myT');

      expect(result.success, true);

      final resultParse = string.parse('V1StGXR8_Z5jdHi6B-myT');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a nanoid string validator, and the string is not a valid nanoid, then the result should be unsuccessful',
    () {
      final string = acanthis.string().nanoid();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a cuid string validator, and the string is a valid cuid, then the result should be successful',
    () {
      final string = acanthis.string().cuid();
      final result = string.tryParse('cjb8k7v7s000001zv9l3k4f4l');

      expect(result.success, true);

      final resultParse = string.parse('cjb8k7v7s000001zv9l3k4f4l');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a cuid string validator, and the string is not a valid cuid, then the result should be unsuccessful',
    () {
      final string = acanthis.string().cuid();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a cuid2 string validator, and the string is a valid cuid2, then the result should be successful',
    () {
      final string = acanthis.string().cuid2();
      final result = string.tryParse('cjb8k7v7s000001zv9l3k4f4l');

      expect(result.success, true);

      final resultParse = string.parse('cjb8k7v7s000001zv9l3k4f4l');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a cuid2 string validator, and the string is not a valid cuid2, then the result should be unsuccessful',
    () {
      final string = acanthis.string().cuid2();
      final result = string.tryParse('%');

      expect(result.success, false);

      expect(
          () => string.parse('%'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a base64 string validator, and the string is a valid base64, then the result should be successful',
    () {
      final string = acanthis.string().base64();
      final result = string.tryParse('dGVzdA==');

      expect(result.success, true);

      final resultParse = string.parse('dGVzdA==');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a base64 string validator, and the string is not a valid base64, then the result should be unsuccessful',
    () {
      final string = acanthis.string().base64();
      final result = string.tryParse('tester');

      expect(result.success, false);

      expect(
          () => string.parse('tester'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a jwt string validator, and the string is a valid jwt, then the result should be successful',
    () {
      final string = acanthis.string().jwt();
      final result = string.tryParse(
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.aiodjiajidoaojidaoijdjo');

      expect(result.success, true);

      final resultParse = string.parse(
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.aiodjiajidoaojidaoijdjo');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a jwt string validator, and the string is not a valid jwt, then the result should be unsuccessful',
    () {
      final string = acanthis.string().jwt();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a time string validator, and the string is a valid time, then the result should be successful',
    () {
      final string = acanthis.string().time();
      final result = string.tryParse('12:00');

      expect(result.success, true);

      final resultParse = string.parse('12:00');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a time string validator, and the string is not a valid time, then the result should be unsuccessful',
    () {
      final string = acanthis.string().time();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a hexColor string validator, and the string is a valid hexColor, then the result should be successful',
    () {
      final string = acanthis.string().hexColor();
      final result = string.tryParse('#ffffff');

      expect(result.success, true);

      final resultParse = string.parse('#ffffff');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a hexColor string validator, and the string is not a valid hexColor, then the result should be unsuccessful',
    () {
      final string = acanthis.string().hexColor();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a url string validator, and the string is a valid url, then the result should be successful',
    () {
      final string = acanthis.string().url();
      final result = string.tryParse('https://test.com');

      expect(result.success, true);

      final resultParse = string.parse('https://test.com');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a url string validator, and the string is not a valid url, then the result should be unsuccessful',
    () {
      final string = acanthis.string().url();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );

  test(
    'when creating a card string validator, and the string is a valid date, then the result should be successful',
    () {
      final string = acanthis.string().card();
      final result = string.tryParse('4242-4242-4242-4242');

      expect(result.success, true);

      final resultParse = string.parse('4242-4242-4242-4242');

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating a card string validator, and the string is not a valid date, then the result should be unsuccessful',
    () {
      final string = acanthis.string().card();
      final result = string.tryParse('test');

      expect(result.success, false);

      expect(
          () => string.parse('test'),
          throwsA(
            TypeMatcher<ValidationError>(),
          ));
    },
  );
}
