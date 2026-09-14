# Live validation

Live validation keeps an object schema and an input snapshot together. It is
useful for forms, editable configuration, and PATCH-style handlers where a
single field changes much more often than the entire object.

## Synchronous sessions

Create a session with `watch()`. It accepts synchronous object schemas.

```dart
final accountSchema = object({
  'email': string().email(),
  'name': string().min(2),
});

final session = accountSchema.watch({
  'email': 'ada@example.com',
  'name': 'Ada',
});

final delta = session.set('email', 'not-an-email');

print(delta.changedIssues);
print(delta.executedFields); // {email}
print(delta.fullValidation); // false
print(session.validated); // null while invalid
print(session.explain('email'));
```

For an independent top-level field, `set()` reruns only that field. The
session exposes the current ordered list through `session.issues`, including
repeated equal failures. Update deltas preserve duplicate additions/removals
in `changedIssues`. The session returns the fields it executed and a typed
immutable snapshot through `validated` when the current revision is valid.

Object-level checks and declared cross-field dependencies deliberately use a
full validation pass. This keeps the live result equivalent to calling
`tryParse()` on the whole object.

```dart
final passwords = object({
  'password': string(),
  'confirmation': string(),
}).addFieldDependency(
  dependent: 'confirmation',
  dependendsOn: 'password',
  dependency: (password, confirmation) => password == confirmation,
);

final session = passwords.watch({
  'password': 'one',
  'confirmation': 'one',
});

final delta = session.set('password', 'two');
print(delta.fullValidation); // true
```

Sessions own a copy of the input map. `input` and `validated` are read-only
views; use `set()` to create the next revision.

## Asynchronous sessions

Use `watchAsync()` for schemas with `refineAsync()` or other asynchronous
checks.

```dart
final schema = object({
  'username': string().refineAsync(
    onCheck: (value) => api.isUsernameAvailable(value),
    error: 'Username is unavailable',
    name: 'usernameAvailable',
  ),
});

final session = await schema.watchAsync({'username': 'ada'});
final delta = await session.set('username', 'grace');
```

Async sessions assign every change a monotonically increasing revision. A
slower response from an older validation can finish, but it cannot overwrite a
newer input or its issues. Async updates currently validate the full object so
asynchronous effects and cross-field behavior remain predictable.
