---
description: Add predicates, parameterized checks, multiple issues, and asynchronous validation.
---

# Custom validation

## Refinements

Use a refinement when built-in checks cannot express a constraint. A callback returning false reports an issue; callback exceptions propagate.

### `refine()`

```dart
final even = integer().refine(
  onCheck: (value) => value.isEven,
  name: 'even',
  error: 'Enter an even number',
);
print(even.tryParse(3).issues.first.message); // Enter an even number
```

`name` becomes the issue code and `error` is an optional fallback message. The check receives the current parsed value. Earlier transformations affect that value.

### Parameterized checks

Use `PredicateCheck<T>` for a code with structured parameters.

```dart
final multiple = integer().withCheck(PredicateCheck<int>(
  (value) => value % 3 == 0,
  code: 'multiple',
  parameters: {'divisor': 3},
  catalog: AcanthisMessageCatalog({
    'multiple': (p) => 'Enter a multiple of ${p['divisor']}',
  }),
));
print(multiple.tryParse(4).issues.first.message); // Enter a multiple of 3
```

Parameters are immutable diagnostic data. Include constraints rather than submitted secrets. Catalogs can translate the same code at presentation time.

### Multiple issues

`CallbackCheck<T>` gives you a context for reporting more than one issue or attaching a relative path.

```dart
final password = string().withCheck(CallbackCheck<String>((value, context) {
  if (!value.contains(RegExp(r'[0-9]'))) context.addIssue('passwordDigit');
  if (!value.contains(RegExp(r'[A-Z]'))) context.addIssue('passwordUppercase');
}));
print(password.tryParse('password').issues.length); // 2
```

Use [cross-field rules](/contextual-rules) when a check should run on selected valid object fields despite unrelated failures.

### `refineAsync()` {#refineasync}

```dart
final username = string().min(3).refineAsync(CallbackAsyncCheck(
  (value, context) async {
    context.throwIfCancelled();
    final available = await Future.value(value != 'admin');
    context.throwIfCancelled();
    if (!available) context.addIssue('usernameTaken');
  },
));
print((await username.tryParseAsync('admin')).isValid); // false
```

Use `context.contextAs<T>()` for scoped services and `context.cancellation` for cooperative cancellation. Sync entry points reject async schemas. [Validation scopes](/contextual-rules#request-context-and-asynchronous-rules) carry context across nested schemas and awaits.

## Checks and transforms

Checks report validity without replacing a value. [Transforms](/schemas/transformations) replace it. Collecting parsing can run several checks on a failed value, but does not cross a subsequent transform after failure. Use `fieldPolicy: AcanthisCollectionPolicy.first` to stop earlier, for example before a remote check.
