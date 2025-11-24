import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

class _Record {
  final String label;
  final int count;

  const _Record({required this.label, required this.count});
}

void main() {
  group('AcanthisType.toOpenApiSchema', () {
    test('boolean exposes literal enums when pinned', () {
      expect(boolean().toOpenApiSchema(), equals({'type': 'boolean'}));
      expect(
        boolean().isTrue().toOpenApiSchema(),
        equals({
          'type': 'boolean',
          'enum': [true],
        }),
      );
      expect(
        boolean().isFalse().toOpenApiSchema(),
        equals({
          'type': 'boolean',
          'enum': [false],
        }),
      );
    });

    test('number infers integer constraints', () {
      final schema = number().integer().gte(1).lt(10).toOpenApiSchema();

      expect(
        schema,
        equals({'type': 'integer', 'minimum': 1, 'exclusiveMaximum': 10}),
      );
    });

    test('number exposes enums and exact values', () {
      final enumeratedSchema = number().enumerated([3, 7]).toOpenApiSchema();
      expect(
        enumeratedSchema,
        equals({
          'type': 'number',
          'enum': [3, 7],
        }),
      );

      final exactSchema = number()
          .enumerated([1, 2])
          .exact(5)
          .toOpenApiSchema();
      expect(
        exactSchema,
        equals({
          'type': 'number',
          'enum': [5],
        }),
      );
    });

    test('date surfaces ISO minimum and maximum boundaries', () {
      final minDate = DateTime.utc(2024, 1, 1, 8, 30);
      final maxDate = DateTime.utc(2025, 1, 1, 16, 45);

      final schema = date().min(minDate).max(maxDate).toOpenApiSchema();

      expect(
        schema,
        equals({
          'type': 'string',
          'format': 'date-time',
          'maximum': maxDate.toIso8601String(),
          'minimum': minDate.toIso8601String(),
        }),
      );
    });

    test('string collects format and length data', () {
      final schema = string().min(2).max(5).email().toOpenApiSchema();

      expect(
        schema,
        equals({
          'type': 'string',
          'minLength': 2,
          'maxLength': 5,
          'format': 'email',
        }),
      );
    });

    test('string pattern checks surface regex metadata', () {
      final schema = string().pattern(RegExp(r'^[a-z]+$')).toOpenApiSchema();

      expect(schema, equals({'type': 'string', 'pattern': r'^[a-z]+$'}));
    });

    test('string exposes exact value enums and contains helpers', () {
      expect(
        string().exact('fixed').toOpenApiSchema(),
        equals({
          'type': 'string',
          'enum': ['fixed'],
        }),
      );

      expect(
        string().notEmpty().toOpenApiSchema(),
        equals({'type': 'string', 'minLength': 1}),
      );

      expect(
        string().contains('token').toOpenApiSchema(),
        equals({'type': 'string', 'pattern': '/token/'}),
      );
    });

    test('literal exports single enum definition', () {
      expect(
        literal('ready').toOpenApiSchema(),
        equals({
          'type': 'literal',
          'enum': ['ready'],
        }),
      );
    });

    test('list captures cardinality, uniqueness and anyOf branches', () {
      final schema = string().list().min(2).unique().anyOf([
        'foo',
        'bar',
      ]).toOpenApiSchema();

      expect(
        schema,
        equals({
          'type': 'array',
          'items': {
            'oneOf': [
              {'type': 'string'},
              {'type': 'string'},
            ],
          },
          'minItems': 2,
          'uniqueItems': true,
        }),
      );
    });

    test('nullable wraps the schema and preserves defaults', () {
      final schema = string()
          .nullable(defaultValue: 'fallback')
          .toOpenApiSchema();

      expect(
        schema,
        equals({
          'type': 'string',
          'nullable': true,
          if (schema['default'] != null) 'default': 'fallback',
        }),
      );
    });

    test('tuple includes prefix items and variadic metadata', () {
      final tupleType = tuple([string(), number()]);

      expect(
        tupleType.toOpenApiSchema(),
        equals({
          'type': 'array',
          'prefixItems': [
            {'type': 'string'},
            {'type': 'number'},
          ],
          'items': false,
        }),
      );

      expect(
        tupleType.variadic().toOpenApiSchema(),
        equals({
          'type': 'array',
          'prefixItems': [
            {'type': 'string'},
            {'type': 'number'},
          ],
          'items': {'type': 'number'},
        }),
      );
    });

    test('instance schemas mirror JSON Schema output', () {
      final schema = instance<_Record>()
          .field('label', (r) => r.label, string().min(1))
          .field('count', (r) => r.count, number().integer())
          .toOpenApiSchema();

      expect(
        schema,
        equals({
          'type': 'object',
          'properties': {
            'label': {'type': 'string', 'minLength': 1},
            'count': {'type': 'integer'},
          },
          'required': ['label', 'count'],
        }),
      );
    });

    test('union bundles variants and inline schemas', () {
      final schema = union<dynamic>([
        string().min(3),
        variant<String>(
          name: 'uuid',
          guard: (value) => value is String && value.contains('-'),
          schema: string().uuid(),
        ),
        number(),
      ]).toOpenApiSchema();

      expect(
        schema,
        equals({
          'oneOf': [
            {
              'type': 'string',
              'pattern':
                  r'^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$',
              'format': 'uuid',
            },
            {'type': 'string', 'minLength': 3},
            {'type': 'number'},
          ],
        }),
      );
    });

    test('map outputs refs, optionals and passthrough rules', () {
      final node = object({'label': string().notEmpty()});

      final schema =
          object({'id': string().notEmpty(), 'child': lazy((_) => node)})
              .optionals(['child'])
              .passthrough(type: string())
              .minProperties(1)
              .toOpenApiSchema();

      expect(
        schema,
        equals({
          'refs': {
            'child-lazy': {
              'type': 'object',
              'properties': {
                'label': {'type': 'string', 'minLength': 1},
              },
              'additionalProperties': false,
              'required': ['label'],
            },
          },
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'minLength': 1},
            'child': {r'$ref': '#/components/child-lazy'},
          },
          'additionalProperties': {'type': 'string'},
          'required': ['id'],
          'minProperties': 1,
        }),
      );
    });
  });
}
