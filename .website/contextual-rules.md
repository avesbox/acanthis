---
description: Validate related parsed fields, supply request context, and cancel asynchronous work.
---

# Cross-field rules

Use a field rule when a constraint depends on more than one object field. Rules read parsed values and can report an issue even when an unrelated field fails.

## `checkFields()` {#compare-parsed-fields}

```dart
final signup = object({
  'password': string().min(8),
  'confirmation': string(),
  'email': string().email(),
}).checkFields(
  ['password', 'confirmation'],
  at: 'confirmation',
  name: 'passwordMismatch',
  error: 'Passwords do not match',
  check: (fields) => fields['password'] == fields['confirmation'],
);

final result = signup.tryParse({
  'password': 'password-one',
  'confirmation': 'password-two',
  'email': 'invalid',
});
print(result.issues.map((issue) => issue.jsonPointer).toList());
// [/email, /confirmation]
```

The first argument declares inputs. `at` declares the issue path, `name` is the unique rule ID and issue code, and `error` is fallback text. `checkFieldsAsync()` accepts an async predicate with the same scheduling and prerequisite rules.

Rules see child defaults and transformations. Invalid prerequisites skip a rule; recovery values are not valid inputs. Missing prerequisites also skip it unless `allowMissing: true`. Rules run in declaration order, and one rule's issues do not prevent another rule from running. Whole-object operations run only after children and rules succeed.

## Paths and field state

Use a string for a literal key, a segment list for a nested location, or an `AcanthisPath`.

| Path | Location |
| --- | --- |
| `'email'` | Top-level email field |
| `['addresses', 0, 'city']` | First address's city |
| `'user.name'` | A literal key containing a dot |

`fields[path]` reads a valid parsed value. `fields.value<T>(path)` adds a typed cast. `fields.state(path)` exposes status, value, and whether the original input submitted that path. A default can produce a valid value with `submitted == false`.

Declare every read and exact issue output path. Unknown static fields, undeclared reads, duplicate IDs, and undeclared output paths are rejected. Declare a transformed field itself when its internal output shape is unknown. Derive object shapes before adding rules; shape helpers reject rules whose paths no longer exist.

## Conditional presence

```dart
final account = object({
  'kind': string().contained(['personal', 'business']),
  'businessId': string().notEmpty(),
}).optionals(['businessId']).checkFields(
  ['kind', 'businessId'],
  at: 'businessId',
  name: 'businessIdRequired',
  error: 'Enter a business identifier',
  allowMissing: true,
  when: (fields) => fields['kind'] == 'business',
  check: (fields) => fields.state('businessId').submitted,
);
print(account.validate({'kind': 'personal'})); // true
print(account.validate({'kind': 'business'})); // false
```

`allowMissing` permits presence inspection; invalid inputs still skip the rule. Test `status == AcanthisFieldStatus.valid` instead of `submitted` when a default should satisfy presence. Do not read `value<T>()` from a missing state. Explicit null is submitted; the child schema decides whether it is valid.

## `rule()` and typed context {#request-context-and-asynchronous-rules}

Use `AcanthisRule<C>` for typed per-call context or several issues.

```dart
final destination = object({'country': string()}).rule(AcanthisRule<Set<String>>(
  id: 'availableDestination',
  inputs: ['country'],
  outputs: ['country'],
  check: (fields, countries) => countries.contains(fields.value<String>('country'))
      ? []
      : [AcanthisIssue(path: ['country'], code: 'countryUnavailable')],
));

final result = AcanthisValidationScope(context: {'IT', 'FR'})
    .run(() => destination.tryParse({'country': 'IT'}));
print(result.isValid); // true
```

The rule ID controls scheduling; returned issue codes control messages. Use `AcanthisRule<Services>.async(...)` for an async check, then call an async parsing method. Scopes carry context through nested schemas and awaits, with concurrent scopes isolated. Nested checks can use `context.contextAs<Services>()`.

Supply the expected context type. Keep context and callbacks deterministic and treat their input as immutable so [live validation](/live-validation) can reuse results safely. Callback exceptions propagate.

## Collection policies

```dart
final schema = object({
  'name': string().min(3).max(10),
  'email': string().email(),
});
final scope = AcanthisValidationScope(
  fieldPolicy: AcanthisCollectionPolicy.first,
  objectPolicy: AcanthisCollectionPolicy.all,
);
final result = scope.run(() => schema.tryParse({'name': '', 'email': 'invalid'}));
print(result.issues.length); // 2
```

`fieldPolicy: first` stops later operations in a failing field, including remote checks. `objectPolicy: first` stops after the first failing child or rule. Collecting defaults are `all` for both. Throwing parsing and `validate()` stop at the first failure regardless of collecting defaults. Policies apply recursively.

## Cancellation

```dart
final signal = AcanthisCancellationSignal();
final scope = AcanthisValidationScope(cancellation: signal);
signal.cancel();

try {
  scope.run(() => string().parse('Ada'));
} on AcanthisValidationCancelled {
  print('Cancelled');
}
```

Cancellation propagates as `AcanthisValidationCancelled`, separate from invalid data. Async callbacks can call `context.throwIfCancelled()` before and after awaiting work. Connect `context.cancellation?.whenCancelled` to a client's cancellation API when available. Cancelling a signal does not forcibly terminate an arbitrary Dart Future.

## Rule messages {#localize-custom-rule-messages}

Extend a catalog with the rule's issue code.

```dart
final catalog = AcanthisMessageCatalogs.italian.extend({
  'passwordMismatch': (_) => 'Le password non coincidono',
});
final issue = AcanthisIssue(path: ['confirmation'], code: 'passwordMismatch');
print(issue.formatMessage(catalog: catalog)); // Le password non coincidono
```

Explicit rules can attach parameters and a `defaultCatalog` to each issue. See [localization](/error-customization) for fallback precedence. Strict export rejects arbitrary rules rather than omitting their constraints.

## Legacy dependencies

`addFieldDependency(dependent: ..., dependendsOn: ..., dependency: ...)` remains available for compatibility. It reads raw values using dotted queries and does not gate on parsed field validity. Prefer `checkFields()` for new code; its declared paths also support incremental scheduling.
