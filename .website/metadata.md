---
description: Annotate schemas without changing validation and retrieve metadata through the metadata registry.
---

# Metadata

`.meta()` attaches descriptions and annotations to a new schema. It keeps the concrete schema type, so you can continue chaining checks.

```dart
final name = string().min(1).meta(const MetadataEntry<String>(
  title: 'Display name',
  description: 'The name shown on the profile',
  examples: ['Ada'],
));
final shortName = name.max(80);
print(shortName.metadataEntry?.title); // Display name
```

The original schema is unchanged. Metadata is descriptive; a metadata `defaultValue` does not insert a validation default. Use `.withDefault()` to change parsing.

## Annotations {#add-metadata}

`MetadataEntry<T>` accepts `title`, `description`, `id`, `comment`, `examples`, `defaultValue`, `deprecated`, `format`, `readOnly`, `writeOnly`, and `otherProperties`. Examples and defaults use the schema's output type.

The entry snapshots its outer lists and maps. Nested application values remain shared; treat them as immutable. JSON serialization supports bounded JSON data and dates. Cycles, non-finite values, and opaque objects fail instead of invoking arbitrary `toJson()` callbacks.

[Strict export](/export-compatibility) emits supported annotations. Metadata cannot make an unsupported runtime constraint exportable. Metadata `format` is rejected because it has no audited runtime contract.

## Metadata registry

`.meta()` registers its entry under an opaque `metadataKey`.

```dart
final name = string().meta(const MetadataEntry<String>(title: 'Name'));
final entry = MetadataRegistry().get<String>(name.metadataKey);
print(entry?.title); // Name
print(MetadataRegistry().has(name.metadataKey)); // true
```

`MetadataRegistry()` is a singleton with `add`, `get<T>`, `has`, and `remove`. Derived schemas retain the key. The registry tracks its latest binding; each schema retains its own metadata entry. Do not depend on the key's spelling. Entries stay registered until removed.

For an application-owned catalog of schemas with typed lookup, use a [schema registry](/schema-registry).
