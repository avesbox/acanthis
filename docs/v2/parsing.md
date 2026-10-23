# Parsing and validation

`parse(input)` returns the schema's raw output type. `parseAsync(input)` returns
`Future<Output>`. Invalid input throws `ValidationError`, even when a typed
recovery value exists. Both methods stop at the first failure. Coercion,
defaults, checks and transformations run before the value is returned.

```dart
final int count = integer().coerce().positive().parse('3');
final List<int> counts = list(integer()).parse([1, 2]);
final Map<String, Object?> user = object({'name': string()}).parse({'name': 'Ada'});

try {
  integer().positive().parse(-1);
} on ValidationError catch (error) {
  print(error.issues.first.code); // positive
  print(error.issues.first.jsonPointer);
}
```

`ValidationError.issues` is immutable and retains structured codes, parameters,
branch diagnostics and complete nested paths. Messages are formatted when
requested. `failure` exposes the failed outcome and any typed recovery value.
Callback programming errors propagate unchanged.

`validate` / `validateAsync` return booleans and stop at the first validation
failure. `tryValidate` / `tryValidateAsync` also return booleans and collect
failures. Invalid input produces false; callback errors and synchronous use of
an async schema still throw.

`tryParse` / `tryParseAsync` return `AcanthisOutcome<Output>` and collect ordered
diagnostics without throwing for invalid input. Successful outcomes contain the
parsed value. Invalid outcomes can contain a best-effort typed recovery value;
check `isValid` or `AcanthisInvalid.hasValue` before reading it. Transformations
stop at a failed validation boundary.

```dart
final schema = integer().positive();
final bool accepted = schema.validate(-1); // false
final result = schema.tryParse(-1);
print(result.isValid); // false
print(result.issues.first.code); // positive
```

These contracts apply to strings, numeric types, booleans, nullable and literal
schemas, lists, objects, records, bound lazy schemas and imported JSON/OpenAPI
contracts. See [boolean, nullable and literal](boolean-nullable-literal.md) for
their composition mixins and defaults. Imported contracts can return
null or false as successful raw values; neither value is a failure sentinel.
Input map/list reuse follows the [collection contract](collections.md).

During migration, replace `schema.parse(input).value` with `schema.parse(input)`.
Use `validate` for a boolean, `tryParse` for diagnostics, or catch `ValidationError`
when using a throwing parse. Third-party schemas implement raw-value `parse`
and outcome-returning `tryParse`; composition preserves validation failures
without converting programming exceptions into issues.
