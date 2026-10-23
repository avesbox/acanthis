---
description: Choose a parsing API, inspect structured issues, and format errors for a UI or an API.
---

# Results and issues

Choose an entry point based on the result you need.

| Method | Returns | Invalid input |
| --- | --- | --- |
| `parse(input)` | `T` | Throws `ValidationError` at the first failure |
| `tryParse(input)` | `AcanthisOutcome<T>` | Collects issues |
| `validate(input)` | `bool` | Returns false at the first failure |
| `tryValidate(input)` | `bool` | Collects checks, then returns false |

Each method has an async counterpart: `parseAsync`, `tryParseAsync`, `validateAsync`, and `tryValidateAsync`. Async schemas require these entry points. Callback exceptions and cancellation can still propagate; `tryParse()` handles validation failures.

## Handle an outcome

```dart
final result = object({'email': string().email()})
    .tryParse({'email': 'invalid'});

if (result.isValid) {
  print(result.value);
} else {
  print(result.issues.formatFields());
}
```

`AcanthisValid<T>` contains the parsed value and no issues. `AcanthisInvalid<T>` contains one or more issues. Metadata stays on the schema as `metadataEntry`.

## Recovery values

An invalid outcome can retain a typed value for inspection. A failed type conversion may have no value at all.

```dart
final result = integer().gte(18).tryParse(16);
if (result case AcanthisInvalid<int>(:final hasValue)) {
  if (hasValue) print(result.value); // 16, still invalid.
}
```

Check `hasValue` before reading invalid recovery. Access without recovery throws `StateError`. A default does not replace supplied invalid data. Only successful output should reach your application's accepted-data path.

## Inspect an issue {#structured-diagnostics}

Each `AcanthisIssue` stores a data `path`, a stable `code`, immutable constraint `parameters`, and optional union `branches`.

```dart
final issue = object({'tags': string().min(3).list()})
    .tryParse({'tags': ['x']}).issues.first;

print(issue.path); // [tags, 0]
print(issue.jsonPointer); // /tags/0
print(issue.code); // minLength
print(issue.parameters); // {value: 3}
print(issue.message); // Localized when read.
```

Paths use strings for keys and integers for list indices. The root path is empty; its JSON pointer is `''`. Pointer encoding escapes `~` and `/`. Codes are separate from paths, and repeated issues retain their order.

`tryParse()` collects failures up to a failed transformation boundary. [Collection policies](/contextual-rules#collection-policies) can stop after the first check per field or the first failing object child.

## Format issues {#presentation-and-localization}

```dart
final issues = string().min(3).min(5).tryParse('x').issues;
print(issues.formatFields());
print(issues.formatTree().messages);
print(issues.formatJson());
```

| View | Use it for |
| --- | --- |
| `formatFields(catalog: ...)` | All messages grouped by JSON pointer |
| `formatTree(catalog: ...)` | Nested messages with typed string/int child keys |
| `formatJson(catalog: ...)` | Ordered issue records, messages, and union branch details as JSON |
| `toTransport()` | Locale-independent records for another process |

Field and tree views show a union's summary. JSON and transport retain its branch details. Index `0` and key `'0'` stay distinct in a tree but share pointer `/0` in a field map.

## Send issues over the wire

```dart
final issues = string().min(3).tryParse('x').issues;
print(issues.toTransport());
// {version: 1, issues: [{path: [], code: minLength, parameters: {value: 3}}]}
```

Transport contains codes, typed paths, parameters, and optional branches. It excludes messages, submitted input, and recovery values. Parameters must remain safe to share: custom parameters are not automatically redacted. Built-in string lengths and numeric bounds use `value`; list minima use `minItems`.

Format the same issues in another language without revalidating. See [messages and localization](/error-customization).

## Upgrade result adapters {#legacy-errors}

Replace V1's `result.errors` with `result.issues.formatFields()` for UI text or `result.issues.toTransport()` for a protocol. Replace `result.success` with `result.isValid`. See the [migration guide](/migration-2) for the remaining return-type changes.
