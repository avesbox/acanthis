# V2 reference notes

For learning and application examples, start with the [documentation introduction](../../.website/introduction.md) and [quick start](../../.website/basic-usage.md). These notes describe detailed V2 contracts and implementation boundaries.

| Topic | Reference |
| --- | --- |
| Return types, outcomes, and input reuse | [Parsing](parsing.md) |
| Numeric semantics | [Numbers](number.md) |
| Nullability and literal equality | [Booleans, nullable values, and literals](boolean-nullable-literal.md) |
| Maps and lists | [Collections](collections.md) |
| Unions, variants, tuples, and templates | [Composition](composition.md) |
| Recursive parent binding | [Lazy schemas](lazy.md) |
| Getter validation and class construction | [Instances](instances.md) |
| Custom predicates and diagnostics | [Refinements](refinement.md) |
| Typed conversion stages | [Pipelines](pipeline.md) |
| Prerequisites, context, and cancellation | [Rules](rules.md) |
| Incremental scheduling and revisions | [Live validation](live.md) |
| Catalog lookup and locale scopes | [Localization](localization.md) |
| Annotations, registries, and generation budgets | [Metadata and mocks](metadata-and-mocks.md) |
| JSON/OpenAPI subsets and audit runners | [Contracts](contracts.md) |
| Issue codes and formatters | [Public helpers](helpers.md) |

`parse()` returns raw output, `validate()` returns a boolean, and `tryParse()` returns a diagnostic outcome. Examples use `package:acanthis/acanthis.dart`. The `v1/` directory and dated architecture/benchmark reports are historical comparison material.

## Regenerate primitive references

Run from the repository root:

```sh
dart run tool/generate_v2_string_reference.dart
dart run tool/generate_v2_number_reference.dart
```

These tools capture the current V2 implementation in `string_v2_reference.json`
and `number_v2_reference.json` under `test/fixtures/`. They record seeded corpus
fingerprints, predicate results, the SDK, and source hashes. They do not require
`v1/` or an alternate package configuration. Review regenerated changes as
regression baselines, not independent correctness evidence.

The frozen `string_v1_reference.json` and `number_v1_reference.json` fixtures
remain compatibility checks. Tests read their recorded results without loading
V1 source. The version-comparison benchmark still requires the archived sources.
