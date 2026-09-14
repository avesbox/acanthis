# Validation results

Every parsing method returns an `AcanthisParseResult<T>`. It always carries a
value, including a recovery value on failure, and its `success` flag indicates
whether validation completed without issues.

```dart
final result = string().email().tryParse('not-an-email');

if (result.success) {
  print(result.value);
} else {
  print(result.errors);
}
```

Use `parse()` when invalid input should stop the current operation with a
`ValidationError`. Use `tryParse()` when the caller needs every error. Schemas
containing an asynchronous refinement require `parseAsync()` or
`tryParseAsync()`; calling a synchronous entry point throws
`AsyncValidationException`.

## Typed outcomes

`validate()` and `validateAsync()` are typed companions to the legacy result
API. They expose exhaustive success and failure branches without removing
`AcanthisParseResult` from existing applications.

```dart
switch (object({
  'email': string().email(),
}).validate({
  'email': 'not-an-email',
})) {
  case AcanthisValid(value: final account):
    save(account);
  case AcanthisInvalid(issues: final issues):
    for (final issue in issues) {
      print('${issue.jsonPointer}: ${issue.message}');
    }
}
```

## Structured diagnostics

Validation records an ordered issue list when checks fail. Read it through
`result.issues`, a failed outcome's `issues`, or a live session's `issues`.
Issues are no longer reconstructed from the legacy error map.

`AcanthisIssue` contains:

- `path`: data locations only, with string object keys and integer list/tuple indices.
- `code`: a stable check identifier, independent of the message.
- `parameters`: immutable, JSON-safe schema constraints for localization and adapters.
- `message`: the schema's fallback message, including existing message overrides.
- `branches`: failed union branches in evaluation order, with nested diagnostics.
- `jsonPointer`: an RFC 6901 pointer with `~` and `/` escaped.

An invalid nested email has path `['account', 'email']`, code `email`, and
pointer `/account/email`. A list element has a path such as
`['accounts', 0, 'email']`. Dots are literal characters in path segments;
`'0'` remains a string key and `0` remains an integer index. The root path is
`[]` and its pointer is the empty string; an empty object key has pointer `/`.
Use the typed path or tree when distinguishing numeric keys from indices
without the input document: JSON pointers themselves do not encode that type.

### Collection policy

Non-throwing validation collects all applicable checks in declaration order,
including repeated failures with the same code and message. Object children
follow schema order, list/tuple children follow index order, and container
operations run after children and dependencies. A type/coercion failure stops
that value's operations. Missing required fields retain the existing policy:
report `required` followed by their synchronous declared check messages without
executing those predicates. A wrong tuple length stops element validation.

A union accepts the first successful branch. When all branches fail, one
`union` issue contains each branch's diagnostics; branch paths are relative to
the original input root, not to the union issue. Guarded variants are tried
before plain types, each in declaration order. A rejected guard has a
`variantGuard` diagnostic. Once a branch succeeds, union-level checks collect
all failures. Branch evaluation does not suppress arbitrary application errors.

This policy applies to sync, async, specialized object execution, and live
sessions. Existing throwing `parse` methods retain their fail-fast API.

### Presentation and localization

Resolve messages from codes and parameters when presenting issues. A resolver
returns `null` to fall back to the schema's message. No global locale is stored
on schemas, so one result can be formatted for several locales.

```dart
final issues = string().min(3).min(5).tryParse('x').issues;

String? italian(String code, Map<String, Object?> parameters) =>
    code == 'minLength'
        ? 'Almeno ${parameters['value']} caratteri'
        : null;

final fields = issues.formatFields(resolver: italian);
// {'': ['Almeno 3 caratteri', 'Almeno 5 caratteri']}
final tree = issues.formatTree(resolver: italian);
final json = issues.formatJson(resolver: italian);
```

`formatFields` groups all messages by JSON pointer. `formatTree` has `messages`
at each node and `children` keyed by the original string or integer segment.
`formatJson` serializes the ordered list, retaining typed paths, parameters,
and branch details. `issue.toJson()` returns one JSON-ready record. All
formatters accept the same optional resolver; `issue.formatMessage()` formats
one message. Branches are available explicitly through `branches` and JSON,
while field/tree views show the top-level union summary.

Constraint parameters use the check's documented fields: for example
`minLength` has `value`, `between` has `min` and `max`, and list `minItems`
has `minItems`. Custom `refine`/`refineAsync` calls accept `parameters`;
custom check subclasses can override `code` and `parameters`. Dates serialize
as ISO 8601 strings, durations as microseconds, enums as names, and patterns as
strings. Arbitrary constraint objects are represented by their type name.

Diagnostics do not retain input values or include them in built-in error
messages. Recovery values remain available separately on parse results and
outcomes. Custom messages, cause callbacks, and supplied parameters are
application-controlled: omit sensitive values from them.

### Legacy errors

`result.errors` remains available as a derived compatibility projection. It
cannot represent repeated same-code failures at one location, so the last
message wins. Check names can collide with child field names; integer indices
become string keys. Union branch diagnostics are available only in `issues`.
Do not round-trip through this map when forwarding structured diagnostics.

Custom schemas can construct `AcanthisParseResult(issues: ..., ...)` directly.
The existing `tryParseInternal(..., errors: ...)` extension point remains
supported: library-owned sinks record legacy extension writes as they happen.
A manually constructed result with only a plain `errors` map gets a best-effort
conversion; already overwritten duplicates and index types cannot be recovered.

## Object input and output

Object schemas distinguish an absent field from a present `null` value.
Required fields report `required` only when the key is absent. A present null
is passed to the field schema and usually produces a type error unless that
field is nullable.

Object schemas strip unknown keys by default in every execution mode. Use
`passthrough()` when extra input must be retained, optionally with a schema to
validate each extra value.

```dart
final account = object({
  'email': string().email(),
});

account.parse({'email': 'ada@example.com', 'debug': true}).value;
// {email: ada@example.com}

account.passthrough().parse({
  'email': 'ada@example.com',
  'debug': true,
}).value;
// {email: ada@example.com, debug: true}
```

Transformations execute once in declared order. This applies equally to a
nullable schema and to synchronous or asynchronous parsing.
