# Context and selected-field rules

Selected-field rules run after their inputs have been parsed, even when an
unrelated field is invalid. Use them for password confirmation and conditional
requirements. Whole-object `refine()` and legacy `addFieldDependency()` retain
their existing behavior.

## Compare parsed fields

```dart
final schema = object({
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

final result = schema.tryParse({
  'password': 'password-one',
  'confirmation': 'password-two',
  'email': 'invalid',
}); // Reports both email and confirmation issues.
```

Use `checkFields()` for a predicate that reports one error. Its `name` is both
its unique rule ID and issue code; `at` declares where the error belongs.
`checkFieldsAsync()` accepts an asynchronous predicate. Both preserve the same
prerequisite gating and live scheduling as an explicit rule.

Paths accept a field name (`'email'`), a nested segment list
(`['addresses', 0, 'city']`), or an existing `AcanthisPath`. Strings are literal
keys: `'user.name'` is not shorthand for `['user', 'name']`. Lists are copied to
immutable paths at declaration time. `fields[path]` reads a valid parsed value;
`fields.value<String>(path)` adds a typed cast, and `fields.state(path)` exposes
presence. You usually do not need to construct `AcanthisPath` yourself.

Use `.rule(AcanthisRule<Context>(...))` for typed context or multiple issues.
Its `inputs` and `outputs` accept the same field names and segment lists.
Declare every input and exact output issue path. IDs must be unique in an
object. Unknown static fields, undeclared reads, and undeclared issue paths
are rejected. Paths can traverse objects, nullable objects, and lists; an index
outside the current list is missing. Declare a transformed field itself as an
input when its internal output shape is not statically known.

A rule sees parsed values, including explicit transformations and defaults.
Children are parsed once per evaluation. Invalid prerequisites skip the rule;
recovery values are never treated as valid inputs. Missing prerequisites skip
ordinary rules. Rules run in declaration order, and their issues do not gate
other rules. Object operations run after the rules only when children and rules
are valid. A failed pipeline does not run its downstream transform.

Rule callbacks must be deterministic for their input and context and must not
mutate values. Return issues for validation failures; callback exceptions
propagate as application errors in sync and async evaluation. Legacy `refine`
callbacks still convert exceptions to failed checks. Keep sensitive input out of
issue parameters. Schema export rejects selected-field rules because their
arbitrary predicates cannot be represented faithfully.

Schema modifiers retain rules. `pick`, `omit`, or `merge` reject a resulting
schema if a declared path no longer exists. Define rules after shaping the schema.

## Localize custom rule messages

For `checkFields()` and `checkFieldsAsync()`, `name` is the issue code used as
the translation key, and `error` is the fallback message. Translate when
presenting issues so the same schema and result can serve multiple languages.

```dart
final schema = object({
  'password': string(),
  'confirmation': string(),
}).checkFields(
  ['password', 'confirmation'],
  at: 'confirmation',
  name: 'passwordMismatch',
  error: 'Passwords do not match',
  check: (fields) => fields['password'] == fields['confirmation'],
);

String? italian(String code, Map<String, Object?> parameters) => switch (code) {
  'passwordMismatch' => 'Le password non coincidono',
  _ => null, // Keep the schema's fallback message for unknown codes.
};

final result = schema.tryParse({
  'password': 'one',
  'confirmation': 'two',
});
final messages = result.issues.formatFields(resolver: italian);
// {'/confirmation': ['Le password non coincidono']}
```

Live sessions use the same formatter:

```dart
final session = schema.watch({'password': 'one', 'confirmation': 'two'});
final messages = session.issues.formatFields(resolver: italian);
```

This also works with `watchAsync()` after awaiting an update. Formatting does
not rerun validation or change `issue.message`, which remains the fallback.
`issue.formatMessage(resolver: italian)` formats a single issue; `formatTree()`
and `formatJson()` also accept the resolver.

### Parameterized messages

Use an explicit `AcanthisRule` when the message needs parameters. Its `id`
identifies the rule for scheduling; the returned `AcanthisIssue.code` is the
translation key. These can differ.

```dart
final schema = object({'seats': integer()}).rule(AcanthisRule<void>(
  id: 'bookingCapacity',
  inputs: ['seats'],
  outputs: ['seats'],
  check: (fields, _) => fields.value<int>('seats') <= 4
      ? []
      : [AcanthisIssue(
          path: ['seats'],
          code: 'seatLimit',
          message: 'Book at most 4 seats',
          parameters: {'max': 4},
        )],
));

String? italian(String code, Map<String, Object?> parameters) => switch (code) {
  'seatLimit' => 'Puoi prenotare al massimo ${parameters['max']} posti',
  _ => null,
};

final messages = schema.tryParse({'seats': 5}).issues
    .formatFields(resolver: italian);
// {'/seats': ['Puoi prenotare al massimo 4 posti']}
```

Keep parameters limited to constraints such as limits; do not include passwords
or other sensitive input. Custom codes need your own translations. See
[message customization](./error-customization.md#localize-at-presentation-time)
for the general localization approach.

## Conditional presence

```dart
final account = object({
  'kind': string().contained(['personal', 'business']),
  'businessId': string().min(1),
}).optionals(['businessId']).checkFields(
  ['kind', 'businessId'],
  at: 'businessId',
  name: 'required',
  error: 'Enter a business identifier',
  allowMissing: true,
  when: (fields) => fields.state('kind').status == AcanthisFieldStatus.valid &&
      fields['kind'] == 'business',
  check: (fields) => fields.state('businessId').submitted,
);
```

`allowMissing` allows presence inspection, while invalid inputs still skip the
rule. `submitted` describes the original input: a default can produce a valid
value with `submitted == false`. To accept defaults as effective presence, test
`state.status == AcanthisFieldStatus.valid` instead. Explicit null is submitted;
its field schema decides whether null is valid. Do not call `value<T>()` for a
missing input.

## Request context and asynchronous rules

`AcanthisValidationScope` carries per-call context into nested schemas and
asynchronous continuations without changing global state.

```dart
final allowed = AcanthisPath(['country']);
final schema = object({'country': string()}).rule(AcanthisRule<Set<String>>(
  id: 'allowedCountry',
  inputs: [allowed],
  outputs: [allowed],
  check: (fields, countries) => countries.contains(fields.value<String>(allowed))
      ? []
      : [AcanthisIssue(
          path: allowed.segments,
          code: 'country',
          message: 'Country is unavailable',
        )],
));
final result = AcanthisValidationScope(context: {'IT', 'FR'})
    .run(() => schema.tryParse({'country': 'IT'}));
```

Use `AcanthisRule<Services>.async(...)` with an async `check` for remote rules,
then call `tryParseAsync()` or `parseAsync()`. Nested checks can retrieve the same
typed context with `AcanthisValidationScope.current.contextAs<Services>()`.
Supply the context type expected by every rule; use a shared application context
object when different services are needed. Context and opaque domain values must
be treated as immutable. Concurrent scopes are isolated, including after awaits.

## Collection policies

```dart
final scope = AcanthisValidationScope(
  fieldPolicy: AcanthisCollectionPolicy.first,
  objectPolicy: AcanthisCollectionPolicy.all,
);
final schema = object({
  'username': string().min(3).refineAsync(
    onCheck: (name) => api.isAvailable(name),
    name: 'available',
    error: 'Username is unavailable',
  ),
  'email': string().email(),
});
final result = await scope.run(() => schema.tryParseAsync(input));
```

`fieldPolicy: first` stops later operations in a failing field, including remote
checks and transformations, while other object fields still collect errors.
`objectPolicy: first` stops after the first failing child or rule. The defaults
are `all` for both. Policies apply recursively; whole-object stopping uses full
validation in live sessions so earlier failures cannot be hidden by a cache.
`parse()` and `parseAsync()` remain throwing APIs; use collecting APIs when
selected-field diagnostics must be displayed alongside unrelated field failures.
