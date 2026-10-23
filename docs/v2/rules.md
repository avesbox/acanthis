# Cross-field rules and validation scopes

`checkFields` validates declared parsed fields after children and before root
checks/transforms. It reports one issue; `rule(AcanthisRule<C>(...))` supports
typed context and multiple issues. Async versions are `checkFieldsAsync` and
`AcanthisRule<C>.async`. Synchronous APIs reject async schemas before callbacks.

```dart
final passwords = object({
  'password': string().min(8),
  'confirm': string(),
}).checkFields(
  ['password', 'confirm'],
  at: 'confirm',
  name: 'passwordMismatch',
  error: 'Passwords do not match', // Optional schema message for localization.
  check: (fields) => fields['password'] == fields['confirm'],
);
```

The name is the unique rule ID and diagnostic code. Paths are literal names,
segment lists such as `['items', 0, 'name']`, or immutable `AcanthisPath` values.
Dots in string names remain literal. Object, list, nullable and tuple paths are
checked statically; lazy descendants are deferred without eagerly resolving
callbacks. Selectors through records, unions, or opaque schemas are not supported.
Rule declarations are snapshotted. Reading undeclared inputs, emitting diagnostics
outside declared outputs, duplicate/empty IDs, and invalid static paths throw.
Callback programming errors propagate.

Only valid selected inputs run a rule. Invalid prerequisites skip its `when`
predicate and check, including failures that retain typed recovery. Unrelated
field errors do not skip a rule in collecting mode. Nested valid siblings remain
available internally even when their container has no typed recovery; `.value`
on such an invalid outcome still throws. Child transformations execute once.
Rule diagnostics do not gate subsequent rules. Issues retain child order,
followed by rule declaration order, then legacy dependencies and root operations.
Throwing parse/boolean validate methods retain fail-fast behavior.

## Presence and contextual checks

With `allowMissing: true`, `fields.state(path)` exposes effective status, value,
and `submitted` from the original input. Missing optional values differ from
explicit nullable null. Defaults are valid effective values with
`submitted == false`; partial objects preserve missing values. Calling
`fields.value<T>(path)` for missing input throws.

```dart
final country = object({'country': string()}).rule(AcanthisRule<Set<String>>(
  id: 'allowedCountry', inputs: ['country'], outputs: ['country'],
  check: (fields, allowed) => allowed.contains(fields.value<String>('country'))
      ? [] : [AcanthisIssue(path: ['country'], code: 'countryUnavailable')],
));
final result = AcanthisValidationScope(context: {'IT', 'FR'})
    .run(() => country.tryParse({'country': 'IT'}));
```

Nested callbacks and async continuations inherit the same context.
`AcanthisValidationScope.current.contextAs<T>()` and `CheckContext.contextAs<T>()`
read it. Concurrent calls and nested scopes stay isolated, including exceptions.
Treat application context as immutable and use a context type shared by all rules
in the graph. Field states include `pending` for API compatibility; ordinary
validation awaits children before evaluating rules and does not publish pending
results. For editing and scheduling, see [live validation](live.md).

`fieldPolicy: AcanthisCollectionPolicy.first` stops later operations in a failing
field while other object fields collect. `objectPolicy: ...first` stops after the
first failing child or rule; a child can still collect several operation issues.
Both default to `all` and are independent of the fail-fast parse API.

## Field dependencies

V1's `addFieldDependency(dependent:, dependendsOn:, dependency:)` is available,
including its existing `dependendsOn` spelling. It reads **raw** values before
field transformation/default substitution. Queries split on dots and accept
list index segments such as `items.[0]`. Missing/null values fail with a
`dependency` issue at `[dependent]` and a `dependsOn` parameter. Collecting mode
runs dependencies even if unrelated or selected fields failed. Use selected
rules when callbacks should consume validated parsed values instead.

Object helpers preserve rules and dependencies. Removing a statically referenced
rule field via pick/omit throws; legacy queries remain dynamically evaluated.
Strict JSON/OpenAPI export rejects both callback-based APIs without invoking
their checks.

## Cancellation

```dart
final signal = AcanthisCancellationSignal();
final pending = AcanthisValidationScope(cancellation: signal)
    .run(() => passwords.tryParseAsync(input));
signal.cancel();
// Await pending and catch AcanthisValidationCancelled separately from validation.
```

Cancellation is cooperative: an in-flight callback may finish, then validation
throws `AcanthisValidationCancelled` and skips subsequent callbacks. It never
becomes a field issue, union failure, successful parse, or recovery result.
Callbacks can observe `CheckContext.cancellation`, await `whenCancelled`, or
call `throwIfCancelled()`. Cancelling is idempotent. It does not abort network
requests or undo callback side effects; callbacks own those resources.
