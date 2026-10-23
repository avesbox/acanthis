---
description: Validate object edits incrementally, debounce asynchronous checks, and track revisions and issue deltas.
---

# Live validation

A live session keeps an object's raw input, parsed output, and issues together across edits. It reuses unaffected top-level field results and [declared rules](/contextual-rules).

## Create a session

```dart
final schema = object({
  'name': string().min(2),
  'email': string().email(),
});
final session = schema.watch({'name': 'Ada', 'email': 'invalid'});

print(session.revision); // 0
print(session.validated); // null: input is invalid.
final delta = session.set('email', 'ada@example.com');
print(delta.revision); // 1
print(delta.executedFields); // {email}
print(session.validated?['name']); // Ada
```

`watch()` validates immediately and requires a synchronous `ObjectSchema`. Use ordinary parsing for one-off validation. Record schemas do not expose live sessions.

## Edit fields and paths {#editing-and-deltas}

```dart
final schema = object({
  'name': string(),
  'addresses': object({'city': string()}).list(),
  'nickname': string().nullable(),
}).optionals(['nickname']);
final session = schema.watch({
  'name': 'Ada',
  'addresses': [{'city': 'Rome'}],
});

session.set('nickname', null); // Present null.
session.remove('nickname'); // Absent key.
session.setPath(['addresses', 0, 'city'], 'Milan');
final delta = session.batch([
  AcanthisEdit.set(['name'], 'Grace'),
  AcanthisEdit.remove(['addresses', 0]),
]);
print(delta.revision); // 4: the batch is one revision.
```

A batch applies edits in order on a private copy, then publishes one revision. An invalid destination rejects the batch without changing input or revision. Parents must exist. Setting index `list.length` appends; removing a list element shifts later indices. Removing an absent map key is allowed. Missing required fields, defaults, and PATCH omission follow ordinary parsing rules.

## Read state and deltas

Sessions expose `input`, `issues`, `validated`, and `revision`. `validated` is null while invalid or awaiting async validation. While pending, issues retain the last settled result.

| Delta member | Meaning |
| --- | --- |
| `input`, `issues`, `validated`, `revision` | The revision's own result snapshot |
| `addedIssues`, `removedIssues` | Multiset differences, preserving repeated issues |
| `changedIssues` | Removed issues followed by added issues |
| `executedFields`, `executedRules` | Evaluated top-level fields and rule IDs |
| `fullValidation` | Whether scheduling fell back to a complete parse |
| `isCurrent` | Whether the revision was current when it completed |
| `settled` | False if a queued revision was superseded before validation began |

`session.explain(field)` explains why a field was rerun or reused in the latest update. Format session or delta issues with the ordinary [issue formatters](/validation-results#presentation-and-localization).

Raw JSON-like input snapshots are deeply copied and frozen. Parsed output has a read-only outer map; treat nested parsed values and opaque objects as immutable because results can be cached.

## Dependency scheduling

A nested edit reruns its top-level field subtree. Rules reading any part of that subtree are reevaluated, accounting for ancestor transforms and shifted indices. Unrelated fields are reused. A field transform does not rerun just to supply a rule input.

Rules cache issues by rule ID. If two rules emit the same issue, changing one removes only its contribution. A rule losing eligibility clears its old issues. Issue order follows field and rule declarations.

Whole-object refinements, transforms, legacy field dependencies, and `objectPolicy: first` require full validation. A context update also invalidates every field and rule because nested checks can read context.

```dart
final schema = object({'name': string()});
final session = schema.watch({'name': 'Ada'},
  scope: AcanthisValidationScope(context: {'region': 'EU'}),
);
final delta = session.updateContext({'region': 'US'});
print(delta.executedFields); // {name}
```

Represent external changes with a context update or an edit. Keep callbacks deterministic for the supplied input and context.

## Async checks and debouncing {#async-scheduling-and-cancellation}

```dart
final schema = object({
  'username': string().min(3).refineAsync(CallbackAsyncCheck(
    (value, context) async {
      context.throwIfCancelled();
      final available = await Future.value(value != 'admin');
      context.throwIfCancelled();
      if (!available) context.addIssue('usernameTaken');
    },
  )),
});
final session = await schema.watchAsync(
  {'username': 'ada'},
  debounce: const Duration(milliseconds: 150),
  scope: AcanthisValidationScope(fieldPolicy: AcanthisCollectionPolicy.first),
);

try {
  final pending = session.set('username', 'grace');
  print(session.pendingFields);
  final delta = await pending;
  if (delta.isCurrent && delta.settled) print(delta.validated);
} finally {
  session.dispose();
}
```

Initial validation runs immediately. Later edits can be debounced. Superseded queued updates complete with `settled == false`; a running stale update can return its own result but cannot overwrite current state. `isCurrent` describes completion time. Compare the delta revision with `session.revision` again if using it later.

Await the update Future before submitting. An empty `pendingFields` set alone does not prove completion: async rules can still be running after fields finish. Edits made during a pending revision stay dirty until a current revision settles.

## Cancellation and disposal

Each new async revision cancels the previous cooperative signal. Callbacks or clients must observe cancellation to stop their own work. Revision checks still prevent stale publication when an underlying Future continues.

`dispose()` cancels the signal and rejects further edits. Callback errors propagate to the update Future, clear pending state, and leave `validated` null; a later edit can retry. Dispose sessions when their owning widget or component is removed.

For a complete widget with pending state, confirmation rules, and submission, follow the [Flutter recipe](/flutter-live-form).
