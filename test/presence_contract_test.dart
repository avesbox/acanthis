import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

AcanthisType<Map<String, dynamic>> scheduled(AcanthisMap<dynamic> schema) =>
    schema.refineAsync(
      onCheck: (_) async => true,
      error: 'unused',
      name: 'schedule',
    );

Future<void> agrees(
  AcanthisMap<dynamic> schema,
  Map<String, dynamic> input,
  bool valid,
  Map<String, dynamic> output,
) async {
  final snapshot = Map<String, dynamic>.of(input);
  for (final result in [
    schema.tryParse(input),
    await schema.tryParseAsync(input),
    await scheduled(schema).tryParseAsync(input),
  ]) {
    expect(result.success, valid);
    expect(result.value, output);
    expect(result.issues, schema.tryParse(input).issues);
  }
  if (valid) {
    expect(schema.parse(input).value, output);
    expect((await schema.parseAsync(input)).value, output);
    expect((await scheduled(schema).parseAsync(input)).value, output);
  } else {
    expect(() => schema.parse(input), throwsA(anything));
    await expectLater(scheduled(schema).parseAsync(input), throwsA(anything));
  }
  expect(input, snapshot);
}

void main() {
  test('presence and nullability are independent in every mode', () async {
    final required = object({'name': string().nullable()});
    await agrees(required, {}, false, {});
    await agrees(required, {'name': null}, true, {'name': null});
    final optional = required.optionals(['name']);
    await agrees(optional, {}, true, {});
    await agrees(optional, {'name': null}, true, {'name': null});
    final nonNullable = object({'name': string()}).optionals(['name']);
    expect(nonNullable.tryParse({'name': null}).success, false);
  });

  test(
    'defaults replace null and absence, including optional fields',
    () async {
      for (final field in <AcanthisType>[
        string().withDefault('guest'),
        string().nullable(defaultValue: 'guest'),
        string().withDefault('guest').nullable(),
        string().nullable().withDefault('guest'),
      ]) {
        for (final optional in [false, true]) {
          var schema = object({'name': field});
          if (optional) schema = schema.optionals(['name']);
          await agrees(schema, {}, true, {'name': 'guest'});
          await agrees(schema, {'name': null}, true, {'name': 'guest'});
          await agrees(schema, {'name': 42}, false, {'name': 'guest'});
          await agrees(schema, {'name': 'Ada'}, true, {'name': 'Ada'});
        }
      }
    },
  );

  test(
    'explicit nullable null default fills absence and survives copies',
    () async {
      final field = string()
          .withDefault('guest')
          .nullable()
          .withDefault(null)
          .refine(onCheck: (_) => true, error: '', name: 'accept');
      await agrees(object({'name': field}), {}, true, {'name': null});
    },
  );

  test(
    'defaults undergo constraints, and invalid supplied input stays invalid',
    () async {
      final field = string().min(3).withDefault('x');
      await agrees(object({'name': field}), {}, false, {'name': 'x'});
      await agrees(
        object({'name': field}),
        {'name': null},
        false,
        {'name': 'x'},
      );
      expect(field.tryParse(null).success, false);
      expect((await field.tryParseAsync(null)).success, false);
      final nullable = string().min(3).nullable(defaultValue: 'x');
      expect(nullable.tryParse(null).success, false);
      expect(
        (await nullable
                .refineAsync(
                  onCheck: (_) async => true,
                  error: '',
                  name: 'scheduled',
                )
                .tryParseAsync(null))
            .success,
        false,
      );
    },
  );

  test(
    'container defaults and defaulted elements use normal validation',
    () async {
      final schemas = <AcanthisType>[
        string().withDefault('guest'),
        string().list().withDefault(['guest']),
        object({'name': string()}).withDefault({'name': 'guest'}),
        tuple([string()]).withDefault(['guest']),
        union<String>([string()]).withDefault('guest'),
      ];
      for (final schema in schemas) {
        expect(schema.tryParse(null).success, true);
        expect(schema.parse(null).value, schema.defaultValue);
        expect((await schema.tryParseAsync(null)).value, schema.defaultValue);
      }
      expect(string().withDefault('guest').list().parse([null]).value, [
        'guest',
      ]);
    },
  );

  test(
    'PATCH preserves omission, nullability, defaults and policies',
    () async {
      for (final policy in AcanthisUnknownKeys.values) {
        final schema = object({
          'name': string().nullable(defaultValue: 'guest'),
        }).unknownKeys(policy).patch();
        await agrees(schema, {}, true, {});
        await agrees(schema, {'name': null}, true, {'name': 'guest'});
        expect(schema.unknownKeyPolicy, policy);
        expect(
          (schema.refine(
            onCheck: (_) => true,
            error: '',
            name: 'ok',
          ) as AcanthisMap).isPatch,
          true,
        );
        final result = schema.tryParse({'extra': 1});
        expect(result.success, policy != AcanthisUnknownKeys.reject);
        expect(
          result.value,
          policy == AcanthisUnknownKeys.preserve ? {'extra': 1} : {},
        );
        expect(
          (await scheduled(schema).tryParseAsync({'extra': 1})).issues,
          result.issues,
        );
      }
      expect(
        object({'name': string()}).partial().tryParse({'name': null}).success,
        false,
      );
      expect(
        object({'name': string().nullable()})
            .patch()
            .parse({'name': null})
            .value,
        {'name': null},
      );
      final nested = object({
        'account': object({'name': string().withDefault('guest')}),
      });
      expect(
        nested.patch(deep: true).parse({'account': <String, dynamic>{}}).value,
        {'account': {}},
      );
      expect(nested.patch().parse({'account': <String, dynamic>{}}).value, {
        'account': {'name': 'guest'},
      });
    },
  );

  test(
    'reject policy survives fluent copies and collects unknown paths',
    () async {
      final schema = object({'name': string()})
          .unknownKeys(AcanthisUnknownKeys.reject)
          .optionals(['name'])
          .extend({'age': number()})
          .optionals(['age']);
      final result = schema.tryParse({'extra': 1, 'other': 2});
      expect(result.issues.map((issue) => issue.code), [
        'unknownKey',
        'unknownKey',
      ]);
      expect(result.issues.map((issue) => issue.path), [
        ['extra'],
        ['other'],
      ]);
      expect(() => schema.parse({'extra': 1}), throwsA(isA<ValidationError>()));
      expect(
        (await scheduled(schema).tryParseAsync({'extra': 1, 'other': 2}))
            .issues,
        result.issues,
      );
    },
  );
  test(
    'default transformations run once and pipeline defaults validate output',
    () async {
      var calls = 0;
      final field = string()
          .transform((value) {
            calls++;
            return value.toUpperCase();
          })
          .withDefault('guest');
      final schema = object({'name': field});
      expect(schema.parse({}).value, {'name': 'GUEST'});
      expect(calls, 1);
      calls = 0;
      expect((await scheduled(schema).tryParseAsync({})).value, {
        'name': 'GUEST',
      });
      expect(calls, 1);
      var mapped = 0;
      final pipeline = string().pipe(
        integer().gte(0),
        transform: (value) {
          mapped++;
          return int.parse(value);
        },
        defaultValue: 12,
      );
      await agrees(object({'name': pipeline}), {}, true, {'name': 12});
      expect(mapped, 0);
      expect(pipeline.parse(null).value, 12);
      expect((await pipeline.parseAsync(null)).value, 12);
      expect(pipeline.tryParse('bad').success, false);
    },
  );

  test(
    'live recovery retains filled defaults and does not repeat transforms',
    () {
      var calls = 0;
      final schema = object({
        'name': string()
            .transform((value) {
              calls++;
              return value.toUpperCase();
            })
            .withDefault('guest'),
        'email': string().email(),
      });
      final session = schema.watch({'email': 'bad'});
      expect(calls, 1);
      session.set('email', 'ada@example.com');
      expect(session.validated, {'name': 'GUEST', 'email': 'ada@example.com'});
      expect(calls, 1);
    },
  );
}
