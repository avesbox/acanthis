import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _External extends Schema<Object?, String> {
  @override
  String parse(Object? input) => input as String;
  @override
  AcanthisOutcome<String> tryParse(Object? input) =>
      AcanthisValid(input as String);
}

void main() {
  test('replacing metadata on imported schemas discards previous native annotations', () {
    final imported = fromJsonSchema({'type': 'string'});
    final first = imported.meta(const MetadataEntry<Object?>(title: 'First'));
    final second = first.meta(
      const MetadataEntry<Object?>(description: 'Second'),
    );
    final exported = second.toJsonSchema(mode: AcanthisSchemaMode.input);
    expect(exported['title'], isNull);
    expect(exported['description'], 'Second');
    expect(first.metadataEntry!.title, 'First');
    expect(imported.metadataEntry, isNull);
  });
  test('meta creates an independent concrete schema and snapshots annotation collections', () {
    final original = string();
    final examples = ['a'];
    final properties = <String, Object?>{'x-owner': 'test'};
    final AcanthisString schema = original.meta(
      MetadataEntry(
        title: 'Name',
        examples: examples,
        otherProperties: properties,
      ),
    );
    examples.clear();
    properties.clear();
    expect(original.metadataEntry, isNull);
    expect(schema, isNot(same(original)));
    expect(schema.metadataEntry!.examples, ['a']);
    expect(schema.metadataEntry!.otherProperties, {'x-owner': 'test'});
    expect(
      () => schema.metadataEntry!.examples!.clear(),
      throwsUnsupportedError,
    );
    expect(MetadataRegistry().get<String>(schema.metadataKey)!.title, 'Name');
    expect(
      MetadataRegistry().get<String>(schema.metadataKey),
      same(schema.metadataEntry),
    );
    expect(schema.min(1).metadataEntry, same(schema.metadataEntry));
    expect(
      schema.coerce().withDefault('a').metadataEntry,
      same(schema.metadataEntry),
    );
    expect(schema.min(1).parse('a'), 'a');
  });

  test(
    'native fluent clones preserve metadata without changing parse plans',
    () async {
      final numberSchema = integer().meta(
        const MetadataEntry<int>(title: 'Count'),
      );
      final dateSchema = date().meta(
        const MetadataEntry<DateTime>(title: 'When'),
      );
      final booleanSchema = boolean().meta(
        const MetadataEntry<bool>(title: 'Flag'),
      );
      final literalSchema = literal('x')
          .meta(const MetadataEntry<String>(title: 'Tag'));
      final nullableSchema = boolean().nullable().meta(
        const MetadataEntry<bool?>(title: 'Maybe'),
      );
      final listSchema = list(boolean())
          .meta(const MetadataEntry<List<bool>>(title: 'Flags'));
      final objectSchema = object({'x': boolean()})
          .meta(const MetadataEntry<Map<String, Object?>>(title: 'Object'));
      final recordSchema = record(
        string(),
        boolean(),
      ).meta(const MetadataEntry<Map<String, bool>>(title: 'Record'));
      final tupleSchema = tuple([boolean()])
          .meta(const MetadataEntry<List<Object?>>(title: 'Tuple'));
      final unionSchema = union<Object?>([boolean(), string()])
          .meta(const MetadataEntry<Object?>(title: 'Union'));
      final templateSchema = template(['x', boolean()])
          .meta(const MetadataEntry<String>(title: 'Template'));
      final pairs =
          <(Schema<Object?, Object?>, List<Schema<Object?, Object?>>)>[
            (
              numberSchema,
              [
                numberSchema.gte(0),
                numberSchema.coerce(),
                numberSchema.withDefault(1),
              ],
            ),
            (
              dateSchema,
              [
                dateSchema.min(DateTime.utc(2000)),
                dateSchema.coerce(),
                dateSchema.withDefault(DateTime.utc(2000)),
              ],
            ),
            (
              booleanSchema,
              [
                booleanSchema.isTrue(),
                booleanSchema.coerce(),
                booleanSchema.withDefault(true),
              ],
            ),
            (literalSchema, [literalSchema.withDefault('x')]),
            (
              nullableSchema,
              [
                nullableSchema.enumerated([true]),
                nullableSchema.withDefault(null),
              ],
            ),
            (listSchema, [listSchema.min(1), listSchema.withDefault([])]),
            (
              objectSchema,
              [
                objectSchema.extend({}),
                objectSchema.merge({}),
                objectSchema.pick(['x']),
                objectSchema.omit([]),
                objectSchema.patch(),
                objectSchema.partial(deep: true),
                objectSchema.optionals(['x']),
                objectSchema.passthrough(),
                objectSchema.unknownKeys(AcanthisUnknownKeys.reject),
                objectSchema.minProperties(1),
                objectSchema.withDefault({'x': true}),
              ],
            ),
            (
              recordSchema,
              [
                recordSchema.withDefault({}),
                recordSchema.refine(onCheck: (_) => true),
              ],
            ),
            (
              tupleSchema,
              [
                tupleSchema.variadic(),
                tupleSchema.withDefault([true]),
              ],
            ),
            (unionSchema, [unionSchema.withDefault(true)]),
            (
              templateSchema,
              [templateSchema.coerce(), templateSchema.withDefault('xtrue')],
            ),
          ];
      for (final (source, clones) in pairs) {
        for (final clone in clones) {
          expect(clone.metadataEntry, same(source.metadataEntry));
          expect(clone.metadataKey, source.metadataKey);
        }
      }
      final input = <String, Object?>{'x': true};
      expect(objectSchema.parse(input), same(input));
      expect(await objectSchema.parseAsync(input), same(input));
    },
  );

  test('lazy metadata binds without eager callbacks and external schemas have a transparent view', () async {
    var resolutions = 0;
    final entry = lazy((_) {
      resolutions++;
      return boolean();
    }).meta(const MetadataEntry<bool>(title: 'Lazy'));
    final schema = object({'x': entry});
    expect(entry.withDefault(false).checks, isEmpty);
    expect(entry.withDefault(false).metadataEntry, same(entry.metadataEntry));
    expect(resolutions, 0);
    final exported = schema.toJsonSchema(mode: AcanthisSchemaMode.input);
    expect((exported['properties'] as Map)['x']['title'], 'Lazy');
    expect(resolutions, 1);
    expect(schema.parse({'x': true}), {'x': true});
    final external = _External();
    final annotated = external.meta(
      const MetadataEntry<String>(title: 'External'),
    );
    expect(external.metadataEntry, isNull);
    expect(annotated.parse('x'), 'x');
    expect(
      await (annotated as AsyncSchema<Object?, String>).parseAsync('x'),
      'x',
    );
  });

  test('metadata registry keeps explicit lifecycle separate from typed schema bindings', () {
    final registry = MetadataRegistry();
    expect(registry, same(MetadataRegistry()));
    final schema = string().meta(const MetadataEntry(title: 'First'));
    final next = schema.meta(const MetadataEntry(title: 'Second'));
    expect(next.metadataKey, schema.metadataKey);
    expect(schema.metadataEntry!.title, 'First');
    expect(registry.get<String>(next.metadataKey)!.title, 'Second');
    expect(
      () => registry.get<int>(next.metadataKey),
      throwsA(isA<TypeError>()),
    );
    registry.remove(next.metadataKey);
    expect(registry.has(next.metadataKey), isFalse);
    expect(next.metadataEntry!.title, 'Second');
    const key = SchemaKey<String, AcanthisString>('annotated');
    final typed = (SchemaRegistryBuilder()..add(key, schema)).build();
    expect(typed.get(key), same(schema));
    expect(typed.get(key).metadataEntry!.title, 'First');
  });

  test(
    'exports preserve annotations, runtime defaults and fresh nested snapshots',
    () {
      final example = <String, Object?>{'x': true};
      final schema = object({'x': boolean()}).meta(
        MetadataEntry(
          id: 'test',
          title: 'Object',
          description: 'Description',
          comment: 'Comment',
          examples: [example],
          defaultValue: {'x': false},
          readOnly: true,
          writeOnly: false,
          deprecated: true,
          otherProperties: {'x-owner': 'team'},
        ),
      );
      final before = object({'x': boolean()})
          .toJsonSchema(mode: AcanthisSchemaMode.input);
      for (var i = 0; i < 4; i++) {
        final json = schema.toJsonSchema(mode: AcanthisSchemaMode.input);
        expect(json['title'], 'Object');
        expect(json[r'$comment'], 'Comment');
        expect(json['x-acanthis-id'], 'test');
        expect(json['x-owner'], 'team');
        expect(json['default'], {'x': false});
        expect(json['properties'], before['properties']);
        expect(fromJsonSchema(json).validate({'x': true}), isTrue);
        expect(
          fromJsonSchema(json).validate(null),
          isFalse,
        ); // Annotation isn't a runtime default.
        ((json['examples'] as List).first as Map)['x'] = 1;
      }
      example['x'] = false;
      expect(
        (schema.toOpenApiSchema(mode: AcanthisSchemaMode.output)['examples']
                as List)
            .first,
        {'x': false},
      );
      expect(schema.metadataEntry!.toJson()['id'], 'test');
      final defaulted = boolean()
          .withDefault(true)
          .meta(const MetadataEntry<bool>(defaultValue: false));
      expect(defaulted.parse(null), isTrue);
      expect(
        fromJsonSchema(defaulted.toJsonSchema(mode: AcanthisSchemaMode.input))
            .validate(null),
        isTrue,
      );
    },
  );

  test('metadata cannot replace constraints or smuggle unsupported format assertions', () {
    for (final metadata in [
      const MetadataEntry<String>(format: 'email'),
      const MetadataEntry<String>(otherProperties: {'type': 'integer'}),
    ]) {
      final schema = string().meta(metadata);
      expect(schema.parse('text'), 'text');
      expect(
        () => schema.toJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    }
    final cyclic = <Object?>[];
    cyclic.add(cyclic);
    expect(
      () => MetadataEntry<Object?>(examples: [cyclic]).toJson(),
      throwsArgumentError,
    );
    expect(
      MetadataEntry<DateTime>(examples: [DateTime.utc(2020)])
          .toJson()['examples'],
      ['2020-01-01T00:00:00.000Z'],
    );
  });
}
