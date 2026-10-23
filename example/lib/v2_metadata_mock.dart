import 'package:acanthis/acanthis.dart';

void main() {
  final name = string().exact('Ada').meta(const MetadataEntry<String>(
        title: 'Name',
        examples: ['Ada'],
      ));
  const key = SchemaKey<String, AcanthisString>('account.name');
  final registry = (SchemaRegistryBuilder()..add(key, name)).build();
  final schema =
      object({'name': registry.get(key), 'rating': number().gte(0).lte(5)});
  final sample = schema.mockSeeded(seed: 42);
  if (!schema.validate(sample) ||
      sample.toString() != schema.mock(42).toString()) {
    throw StateError('Mock generation must be valid and reproducible');
  }
  print(sample);
  print(schema.toJsonSchema(mode: AcanthisSchemaMode.input));
  print(MetadataRegistry().get<String>(name.metadataKey)?.title);
}
