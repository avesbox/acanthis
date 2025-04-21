import 'package:acanthis/acanthis.dart' as acanthis;
import 'package:acanthis/acanthis.dart';

import 'package:test/test.dart';

void main() {
  group('$AcanthisMap', () {
    test(
        'when creating a map validator,'
        'and the map is valid, '
        'then the result should be successful', () {
      final map = acanthis.object({'key': acanthis.string().min(5).max(20)});
      final result = map.tryParse({'key': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'key': 'value'});

      expect(resultParse.success, true);
    });

    test(
        'when creating a map validator with a required field,'
        'and the map is missing the required field, '
        'then the result should be unsuccessful', () {
      final map = acanthis.object({'key': acanthis.string().min(5).max(20)});
      final result = map.tryParse({});

      expect(result.success, false);

      expect(() => map.parse({}), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a map validator with the passthrough property,'
        'and the parse value contains a non validated key, '
        'then the result should be successful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).passthrough();
      final result = map.tryParse({'key': 'value', 'other': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'key': 'value', 'other': 'value'});

      expect(resultParse.success, true);
    });

    test(
        'when creating a map validator with the passthrough property,'
        'and the parse value contains a non validated key, '
        'then the result should be unsuccessful', () {
      final map = acanthis.object({'key': acanthis.string().min(5).max(20)});

      final result = map.tryParse({'key': 'value', 'other': 'value'});

      expect(result.success, false);

      expect(() => map.parse({'key': 'value', 'other': 'value'}),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a map validator with the omit property,'
        'and the parse value does not contains a validated key, '
        'then the result should be successful', () {
      final map = acanthis.object({
        'key': acanthis.string().min(5).max(20),
        'other': acanthis.string().min(5).max(20)
      }).omit(['key']);

      final result = map.tryParse({'other': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'other': 'value'});

      expect(resultParse.success, true);
    });

    test(
        'when creating a map validator with the omit property,'
        'and the parse value contains a validated key, '
        'then the result should be unsuccessful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).omit(['key']);

      final result = map.tryParse({'key': 'value'});

      expect(result.success, false);

      expect(() => map.parse({'key': 'value'}),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a map validator with the merge property, '
        'and the parse value contains a validated key, '
        'then the result should be successful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).merge(
              {'other': acanthis.string().min(5).max(20)});

      final result = map.tryParse({'key': 'value', 'other': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'key': 'value', 'other': 'value'});

      expect(resultParse.success, true);
    });

    test(
        'when creating a map validator with the merge property, '
        'and the parse value does not contain a validated key, '
        'then the result should be unsuccessful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).merge(
              {'other': acanthis.string().min(5).max(20)});

      final result = map.tryParse({'key': 'value'});

      expect(result.success, false);

      expect(() => map.parse({'key': 'value'}),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a map validator with the extend property, '
        'and the parse value contains a validated key, '
        'then the result should be successful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).extend(
              {'other': acanthis.string().min(5).max(20)});

      final result = map.tryParse({'key': 'value', 'other': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'key': 'value', 'other': 'value'});

      expect(resultParse.success, true);
    });

    test(
        'when creating a map validator with the extend property, '
        'and the new field is already in the map, '
        'then it should be ignored', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).extend(
              {'key': acanthis.string().max(1)});

      final result = map.fields['key']?.parse('value');
      expect(result?.success, true);
    });

    test(
        'when creating a map validator with the merge property, '
        'and the new field is already in the map, '
        'then it should be overridden', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).merge(
              {'key': acanthis.string().max(1)});

      final result = map.fields['key']?.parse('v');
      expect(result?.success, true);
    });

    test(
        'when creating a map validator with the extend property, '
        'and the parse value does not contain a validated key, '
        'then the result should be unsuccessful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).extend(
              {'other': acanthis.string().min(5).max(20)});

      final result = map.tryParse({'key': 'value'});

      expect(result.success, false);

      expect(() => map.parse({'key': 'value'}),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a map validator with the pick property, '
        'and the parse value contains a validated key, '
        'then the result should be successful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).pick(['key']);

      final result = map.tryParse({'key': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'key': 'value'});

      expect(resultParse.success, true);
    });

    test(
        'when creating a map validator with the pick property, '
        'and the parse value does not contain a validated key, '
        'then the result should be unsuccessful', () {
      final map = acanthis
          .object({'key': acanthis.string().min(5).max(20)}).pick(['key']);

      final result = map.tryParse({'other': 'value'});

      expect(result.success, false);

      expect(() => map.parse({'other': 'value'}),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a map validator with a custom transformation,'
        'and all the elements in the map are valid, '
        'and the map itself is valid, '
        'then the result should be transformed', () {
      final map = acanthis.object({
        'key': acanthis.string().min(5).max(20),
      }).transform((value) => value
          .map((key, value) => MapEntry(key, value.toString().toUpperCase())));

      final result = map.tryParse({'key': 'value'});

      expect(result.success, true);

      final resultParse = map.parse({'key': 'value'});

      expect(resultParse.success, true);
      expect(resultParse.value['key'], 'VALUE');
    });

    test(
        'when creating a map validator for a complex object,'
        'and the map is valid, '
        'then the result should be successful', () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.object({
          'age': acanthis.number().gte(18),
          'email': acanthis.string().email(),
          'style': acanthis.object({
            'color': acanthis
                .string()
                .min(3)
                .max(10)
                .transform((value) => value.toUpperCase())
          }),
          'date': acanthis.date().min(DateTime.now())
        }),
      }).passthrough();

      final parsed = object.parse({
        'name': 'Hello',
        'attributes': {
          'age': 18,
          'email': 'test@gmail.com',
          'style': {
            'color': 'red',
          },
          'date': DateTime.now()
        },
        'elements': ['Hell', 5],
      });

      expect(parsed.success, true);
    });

    test(
        'when creating a map validator for a complex object, '
        'and use the list method, '
        'and all the values are valid, '
        'then the result should be successful', () {
      final object = acanthis
          .object({
            'name': acanthis.string().min(5).max(10).encode(),
            'attributes': acanthis.object({
              'age': acanthis.number().gte(18),
              'email': acanthis.string().email(),
              'style': acanthis.object({
                'color': acanthis
                    .string()
                    .min(3)
                    .max(10)
                    .transform((value) => value.toUpperCase())
              }),
              'date': acanthis.date().min(DateTime.now())
            }),
          })
          .passthrough()
          .list();

      object.parse([
        {
          'name': 'Hello',
          'attributes': {
            'age': 18,
            'email': 'test@test.com',
            'style': {
              'color': 'red',
            },
            'date': DateTime.now()
          },
          'elements': ['Hell', 5],
        },
        {
          'name': 'Hello',
          'attributes': {
            'age': 18,
            'email': 'test@example.com',
            'style': {
              'color': 'red',
            },
            'date': DateTime.now()
          },
          'elements': ['Hell', 5],
        }
      ]);
    });

    test(
      'when creating a map validator for a complex object, '
      'and add a field dependency, '
      'and the dependency is not met, '
      'then the result should be unsuccessful',
      () {
        final object = acanthis
            .object({
              'name': acanthis.string().min(5).max(10).encode(),
              'attributes': acanthis.object({
                'age': acanthis.number().gte(18),
                'email': acanthis.string().email(),
                'style': acanthis.object({
                  'color': acanthis
                      .string()
                      .min(3)
                      .max(10)
                      .transform((value) => value.toUpperCase())
                }),
                'date': acanthis.date().min(DateTime.now())
              }),
            })
            .passthrough()
            .addFieldDependency(
                dependent: 'name',
                dependendsOn: 'attributes.age',
                dependency: (age, name) {
                  return name.length > age;
                });

        expect(
            () => object.parse({
                  'name': 'Hello',
                  'attributes': {
                    'age': 18,
                    'email': 'test@test.com',
                    'style': {
                      'color': 'red',
                    },
                    'date': DateTime.now()
                  },
                  'elements': ['Hell', 5],
                }),
            throwsA(TypeMatcher<ValidationError>()));

        final result = object.tryParse({
          'name': 'Hello',
          'attributes': {
            'age': 18,
            'email': 'test@test.com',
            'style': {
              'color': 'red',
            },
            'date': DateTime.now()
          },
          'elements': ['Hell', 5],
        });

        expect(result.success, false);
        expect(result.errors['name'].keys.contains('dependency'), true);
      },
    );

    test(
      'when creating a map validator for a complex object, '
      'and add a field dependency, '
      'and the dependency is met, '
      'then the result should be successful',
      () {
        final object = acanthis
            .object({
              'name': acanthis.string().min(5).max(10).encode(),
              'attributes': acanthis.object({
                'age': acanthis.number().gte(18),
                'email': acanthis.string().email(),
                'style': acanthis.object({
                  'color': acanthis
                      .string()
                      .min(3)
                      .max(10)
                      .transform((value) => value.toUpperCase())
                }),
                'date': acanthis.date().min(DateTime.now())
              }),
            })
            .passthrough()
            .addFieldDependency(
                dependent: 'name',
                dependendsOn: 'attributes.age',
                dependency: (age, name) {
                  return name.length < age;
                });

        final result = object.tryParse({
          'name': 'Hello',
          'attributes': {
            'age': 18,
            'email': 'test@test.com',
            'style': {
              'color': 'red',
            },
            'date': DateTime.now()
          },
          'elements': ['Hell', 5],
        });

        expect(result.success, true);

        final resultParse = object.parse({
          'name': 'Hello',
          'attributes': {
            'age': 18,
            'email': 'test@test.com',
            'style': {
              'color': 'red',
            },
            'date': DateTime.now()
          },
          'elements': ['Hell', 5],
        });

        expect(resultParse.success, true);
      },
    );

    test(
        'when creating a map validator for an object, '
        'and add a field to the optional list, '
        'then the result should be successful even if the field is not present',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.object({
          'age': acanthis.number().gte(18),
          'email': acanthis.string().email(),
          'style': acanthis.object({'color': acanthis.string().min(3).max(10)}),
          'date': acanthis.date().min(DateTime.now())
        }).optionals(['style', 'date']),
      }).optionals(['name']);

      final result = object.tryParse({
        'attributes': {
          'age': 18,
          'email': 'test@test.com',
          'date': DateTime.now()
        },
      });
      expect(result.success, true);
    });

    test(
        'when creating a map validator for an object with the partial method, then only the first level should be nullable',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.object({
          'age': acanthis.number().gte(18),
          'style': acanthis.object({'color': acanthis.string().min(3).max(10)}),
          'date': acanthis.date().min(DateTime.now())
        }).partial()
      });

      final result = object.tryParse({
        'name': 'Hello',
        'attributes': {
          'age': null,
          'style': {
            'color': 'red',
          },
          'date': DateTime.now()
        }
      });
      expect(result.success, true);
    });

    test(
        'when creating a map validator for an object with the partial method and the deep param at true, then all the elements should be nullable',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.object({
          'age': acanthis.number().gte(18),
          'style': acanthis.object({'color': acanthis.string().min(3).max(10)}),
          'date': acanthis.date().min(DateTime.now())
        }).partial(deep: true)
      });

      final result = object.tryParse({
        'name': 'Hello',
        'attributes': {
          'age': null,
          'style': {
            'color': null,
          },
          'date': DateTime.now()
        }
      });
      expect(result.success, true);
    });

    test(
        'when a map validator is created with a lazy object inside, then the object should be recursively parsable',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.lazy((parent) => parent.passthrough().list())
      });

      final result = object.tryParse({
        'name': 'Hello',
        'attributes': [
          {'name': 'Hello', 'age': 18, 'attributes': []}
        ]
      });
      expect(result.success, true);
    });

    test(
        'when a map validator is created and the maxProperties check is used, '
        'then the result should be successful if the map has less or equal than the max properties',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.lazy((parent) => parent.passthrough().list())
      }).maxProperties(2);

      final result = object.tryParse({
        'name': 'Hello',
        'attributes': [
          {'name': 'Hello', 'attributes': []}
        ]
      });
      expect(result.success, true);
    });

    test(
        'when a map validator is created and the minProperties check is used, '
        'then the result should be successful if the map has more or equal than the min properties',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.lazy((parent) => parent.passthrough().list())
      }).minProperties(2);

      final result = object.tryParse({
        'name': 'Hello',
        'attributes': [
          {'name': 'Hello', 'attributes': [], 'age': 18}
        ]
      });
      expect(result.success, true);
    });

    test(
        'when a map validator is created and the type parameter in the passthrough method is used, '
        'then all the unknown properties should be of the same type', () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes':
            acanthis.lazy((parent) => parent.passthrough(type: number()).list())
      }).minProperties(2);

      final result = object.tryParse({
        'name': 'Hello',
        'attributes': [
          {'name': 'Hello', 'attributes': [], 'age': 18}
        ]
      });
      expect(result.success, true);
      final result2 = object.tryParse({
        'name': 'Hello',
        'attributes': [
          {'name': 'Hello', 'attributes': [], 'age': '18'}
        ]
      });
      expect(result2.success, false);
    });

    test(
        'when the method toJsonSchema is called, then the result should be a valid json schema',
        () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.lazy((parent) => parent.passthrough().list())
      });

      final result = object.toJsonSchema();
      expect(result, isA<Map<String, dynamic>>());
      expect(result['type'], 'object');
      expect(result['properties'], isA<Map<String, dynamic>>());
      expect(result['properties']['name'], isA<Map<String, dynamic>>());
      expect(result['properties']['attributes'], isA<Map<String, dynamic>>());
      expect(result['properties']['attributes'].containsKey(r'$ref'), true);
    });

    test(
        'when the method toJsonSchema is called and the object has metadata, '
        'then the result should be a valid json schema with metadata', () {
      final object = acanthis.object({
        'name': acanthis.string().min(5).max(10).encode(),
        'attributes': acanthis.lazy((parent) => parent.passthrough().list())
      }).meta(
        MetadataEntry(
          examples: [
            {'name': 'test', 'attributes': []}
          ],
          title: 'test title',
        ),
      );

      final result = object.toJsonSchema();
      expect(result, isA<Map<String, dynamic>>());
      expect(result['type'], 'object');
      expect(result['properties'], isA<Map<String, dynamic>>());
      expect(result['properties']['name'], isA<Map<String, dynamic>>());
      expect(result['properties']['attributes'], isA<Map<String, dynamic>>());
      expect(result['properties']['attributes'].containsKey(r'$ref'), true);
      expect(result['examples'], isA<List<Map<String, dynamic>>>());
      expect(result['title'], 'test title');
    });

    test(
        'when creating an object validator,'
        'and use the toJsonSchema method and the constraint checks are used, '
        'then the result should be a valid json schema with the constraints',
        () {
      final object = acanthis
          .object({
            'name': acanthis.string().min(5).max(10).encode(),
            'attributes': acanthis.lazy((parent) => parent.passthrough().list())
          })
          .maxProperties(5)
          .minProperties(2);
      final result = object.toJsonSchema();
      expect(result, isA<Map<String, dynamic>>());
      expect(result['type'], 'object');
      expect(result['properties'], isA<Map<String, dynamic>>());
      expect(result['properties']['name'], isA<Map<String, dynamic>>());
      expect(result['properties']['attributes'], isA<Map<String, dynamic>>());
      expect(result['maxProperties'], 5);
      expect(result['minProperties'], 2);
    });
  });
}
