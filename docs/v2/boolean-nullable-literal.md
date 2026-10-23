# Boolean, nullable and literal schemas

These schemas use the [V2 parsing API](parsing.md): raw values from `parse` /
`parseAsync`, boolean validation, and diagnostic outcomes from `tryParse` /
`tryParseAsync`. They support persistent check/transform chains, async operations,
defaults, list composition and strict JSON Schema/OpenAPI export.

```dart
final bool enabled = boolean().coerce().parse(' TRUE ');
final bool disabled = boolean().isFalse().parse(false);
final String tag = literal('node').parse('node');
final String? name = string().nullable().parse(null);
final List<String?> names = string().nullable().list().parse(['Ada', null]);
final List<String>? tags = string().list().nullable().parse(null);
```

Factories are available at top level and through `Acanthis` / `AcanthisType`.
Concrete classes are `AcanthisBoolean`, `AcanthisLiteral<T>` and
`AcanthisNullable<T>`.

## Boolean

Booleans are strict by default. `coerce()` additionally accepts numeric 0/1 and
trimmed, case-insensitive strings `true`, `false`, `0`, and `1`. Other numbers,
NaN, infinity, arbitrary strings and collections fail; general truthiness is
never used. `false` is a valid parsed value, including as a default.

`isTrue()` and `isFalse()` add ordered checks with corresponding diagnostic
codes. Customize presentation through message catalogs, as with other V2 checks.
Constraints and transformations run in declaration order. Boolean built-in checks
participate in callback-free object/list fast paths without losing false values.

## Composable nullability

`NullableSchema<I, O>` is a mixin on `Schema<I, O>`, matching the construction
pattern of `ListableSchema<I, O>`. Its `nullable()` method returns an
`AcanthisNullable<O>`. Both mixin orders work:

```dart
class LabelSchema extends Schema<String, String>
    with ListableSchema<String, String>, NullableSchema<String, String> {
  @override
  String parse(Object? input) => tryParse(input).valueOrThrow;

  @override
  AcanthisOutcome<String> tryParse(Object? input) => input is String
      ? AcanthisValid(input)
      : AcanthisInvalid<String>.withoutValue([
          AcanthisIssue(path: [], code: 'type'),
        ]);
}

final label = LabelSchema();
final List<String?> values = label.nullable().list().parse([null, 'Ada']);
```

Existing native schemas include the mixin. An extension on `Schema<I, O>` also
supports statically widened or third-party schema references. `unwrap()` returns
the wrapped schema. `nullable(element)` is available as a standalone factory.

Null skips child parsing but still runs the wrapper's own checks and transforms.
Non-null values pass through the child first. An async child still requires an
async entry point even for null, so synchronous parsing rejects the graph before
executing callbacks. Wrapped children expose their definition edges to the
cycle-safe async capability audit.

The wrapper inherits the child's default unless it has its own. Non-null
`nullable(defaultValue: value)` overrides it; use `withDefault(null)` to explicitly
override an inherited default with null. The explicit-null default remains
configured across fluent copies:

```dart
final inherited = string().withDefault('child').nullable();
final explicitNull = inherited.withDefault(null);
assert(inherited.parse(null) == 'child');
assert(explicitNull.parse(null) == null);

final required = object({'name': string().nullable()});
assert(!required.validate({}));
assert(required.validate({'name': null}));
final defaulted = object({'name': string().nullable().withDefault(null)});
assert(defaulted.parse({}).containsKey('name'));
assert(defaulted.partial().parse({}).isEmpty);
```

`enumerated(values)` snapshots its allowed values and always permits null. It
also retains the child's constraints. Failed child outcomes keep their typed
recovery when available; bad child types remain invalid without invented recovery.
Transformations stop at failed validation boundaries.

Unchanged wrapped maps/lists retain normal input reuse. Defaults of generic
literal/nullable schemas retain their ordinary Dart references; exported cached
contracts revalidate mutable defaults on each export.

For recursive fields, keep `lazy` directly in the object field and create the
nullable wrapper inside its resolver, e.g. `lazy((parent) => parent.nullable())`.
Nullable-only lazy alias cycles are rejected during resolution.

## Literal

`literal<T>(value)` checks the input's runtime type, followed by Dart `==`.
It does not coerce or use deep JSON equality. Thus `literal<int>(1)` rejects 1.0,
while `literal<num>(1)` accepts it; collection literals match by their Dart
identity/equality semantics. Type arguments can also be inferred from context.
`literal(null)` is a valid schema for null.

Literal validation happens before the ordered operation chain in both sync and
async parsing. Type-correct mismatches produce `literal` diagnostics with an
`expected` parameter and typed recovery. Wrong types have no typed recovery.
Defaults must satisfy the literal. An explicit null default on a null literal
also fills an omitted object field.

## Export and migration

Boolean constraints, JSON scalar literals, nullable branches/enumeration,
defaults, nesting, and recursive nullable objects export through the strict
input/output contracts. A non-null nullable default admits null input but its
output contract excludes null. Explicit null defaults participate in object
presence rules.

Export rejects opaque/custom/async behavior, coercion, transformations, object
identity literals, and numeric representation/equality restrictions that cannot
be expressed exactly in JSON. Use `literal<num>(1)` for a JSON numeric constant;
`literal<int>(1)` retains a Dart-specific restriction and is rejected by the
strict exporter. Nullable enumeration export is restricted to JSON scalar
equality. See [metadata and bounded mocks](metadata-and-mocks.md) for the separate
generation capabilities.

The dedicated export suite compares 1,155 runtime/input pairs and successful
outputs with independent JSON Schema 2020-12 and OpenAPI 3.1 validators. Its corpus
can be regenerated by setting `BOOLEAN_EXPORT_CORPUS`, `NULLABLE_EXPORT_CORPUS`, or `LITERAL_EXPORT_CORPUS` when running
the corresponding `test/boolean_export_test.dart`,
`test/nullable_export_test.dart`, or `test/literal_export_test.dart` and then passing that file to
`tool/verify_schema_export.py` with the optional Python validators installed.
`dart run tool/audit_schema_export.dart` generates and verifies all six current
native export corpora in one run.
