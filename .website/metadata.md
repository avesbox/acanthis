# Metadata

Sometimes you may want to add some metadata to your schema for documentation, AI structured outputs, or other purposes.

## Metadata Registry

The metadata registry is a dictionary that contains metadata for each schema. The keys are generated lazily when the metadata is accessed for the first time.

::: info
The keys are created using the `nanoid2` package.
:::

## Add Metadata

To add metadata to a schema, you can use the `meta` method. This method takes a `MetadataEntry` as an argument and adds it to the metadata registry.

```dart
final schema = object({
  'name': string(),
  'age': int(),
}).meta(MetadataEntry(
  description: 'This is a schema for a person.',
));
```
