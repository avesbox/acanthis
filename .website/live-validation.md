# Live validation

Live sessions keep raw input, ordered issues, and parsed output together. They
reuse unaffected field results and selected-field rules between edits.

## Editing and deltas

```dart
final schema = object({
  'name': string().min(2),
  'email': string().email(),
  'addresses': object({'city': string()}).list(),
  'nickname': string().nullable(),
}).optionals(['nickname']);
final session = schema.watch({
  'name': 'Ada',
  'email': 'ada@example.com',
  'addresses': [{'city': 'Rome'}],
});

final delta = session.batch([
  AcanthisEdit.set(['name'], 'Grace'),
  AcanthisEdit.set(['addresses', 0, 'city'], 'Paris'),
]);
print(delta.revision); // 1: the batch is one coherent revision.
print(delta.executedFields); // {name, addresses}
print(delta.addedIssues);
print(delta.removedIssues);
print(session.validated);

session.set('nickname', null); // Present with a null value.
session.remove('nickname');    // Absent.
session.setPath(['addresses', 0, 'city'], 'Milan');
session.removePath(['addresses', 0]);
```

`set` and `remove` address a top-level field; `setPath` and `removePath` accept
nested paths. Batches apply edits in order on a private copy and publish one
revision. Invalid destinations reject the whole batch without changing the input
or revision. Parents must already exist. Setting a list index equal to its length
appends; removing an element shifts later indices. Removing an absent map key is
allowed. Removal of a required field produces a required issue; defaults and
PATCH omission retain the schema's ordinary behavior.

Both session types expose `input`, `issues`, `validated`, and `revision`.
`validated` is null when invalid or awaiting async validation. `issues` retains
the last settled issues while a revision is pending. Raw input snapshots deeply
copy and freeze JSON-like maps and lists. Parsed output has a read-only top-level
map and preserves the schema's value types: treat nested parsed values and
opaque domain objects as immutable, just as cached callback inputs.

Deltas contain their own `input`, `issues`, `validated`, and `revision`, plus:

| Member | Meaning |
| --- | --- |
| `addedIssues` / `removedIssues` | Multiset differences; equal repeated issues are preserved |
| `changedIssues` | Removed issues followed by added issues, for compatibility |
| `executedFields` | Top-level field subtrees evaluated |
| `executedRules` | Rule IDs reevaluated, including rules skipped for invalid/missing inputs |
| `fullValidation` | Whether the conservative fallback was used |
| `isCurrent` | Whether this revision was current when its result completed |
| `settled` | False for a debounced revision superseded before validation started |

## Dependency scheduling

[Selected-field rules](./contextual-rules.md) declare input paths. Editing a
field reruns that field subtree and rules that read it, reusing other parsed
fields and rule issues. A nested edit reruns its top-level subtree, including
its nested validators. Rules reading any part of that subtree are reevaluated:
this accounts for ancestor transformations and list index shifts. An unrelated
top-level field is reused. Field transforms therefore run once for each executed
field, and never again merely to feed a selected rule.

Rule issues are cached by rule ID, not issue path/code. If two rules report the
same issue, changing one rule's input removes only its own contribution. Losing
eligibility clears the old rule issue. Rule failures never invalidate other
rules' prerequisites. Diagnostics remain in field and rule declaration order.

Object refinements, whole-object transforms, legacy `addFieldDependency`, and
`objectPolicy: first` use full validation. Their undeclared dependencies or
stopping behavior require it. Keep callbacks deterministic for input and context;
external changes must be represented by a context update or another edit.

```dart
final session = schema.watch(initial,
  scope: AcanthisValidationScope(context: services),
);
final delta = session.updateContext(newServices);
```

Context updates create a revision and invalidate all fields and rules, including
nested checks that may access context without declaring dependencies.

## Async scheduling and cancellation

```dart
final schema = object({
  'username': string().min(3).refineAsync(
    onCheck: (value) async {
      final signal = AcanthisValidationScope.current.cancellation;
      if (signal?.isCancelled ?? false) return true;
      // A client that supports cancellation can observe signal.whenCancelled.
      return api.isUsernameAvailable(value);
    },
    error: 'Username is unavailable',
    name: 'available',
  ),
});
final session = await schema.watchAsync(
  {'username': 'ada'},
  debounce: Duration(milliseconds: 150),
  scope: AcanthisValidationScope(
    fieldPolicy: AcanthisCollectionPolicy.first,
  ),
);
final pending = session.set('username', 'grace');
print(session.pendingFields); // Fields waiting for validation or still running.
final delta = await pending;
if (delta.isCurrent && delta.settled) print(delta.issues);
session.dispose();
```

Initial validation is immediate; subsequent edits can be debounced. Superseded
queued updates complete with `settled == false`. Edits accumulated during a
pending revision remain dirty until a current revision settles. A running stale
revision can finish and return its own snapshot, but cannot overwrite current
state. `isCurrent` is a completion-time flag; compare `delta.revision` with
`session.revision` again if using a retained delta later.

`pendingFields` tracks field subtrees, clearing each as it finishes. Selected
async rules run after field validation; an empty pending-field set alone does
not mean a revision has settled. Await the update Future. In fallback mode,
fields remain pending until the whole validation completes.

Every new async revision cancels the previous cooperative signal. Underlying
Dart Futures continue unless the callback/client observes `isCancelled` or
`whenCancelled`; revision guards still protect state. `dispose()` cancels the
signal, invalidates in-flight publication, and rejects subsequent edits. It does
not forcibly terminate arbitrary Futures. Callback errors propagate to the
update Future, clear pending state, and leave `validated` null; a later edit can
retry. Sync callback errors likewise propagate and clear `validated`.

## Performance

Scheduling saves validator work, but snapshots, cache lookup, and deltas have a
cost. With 24 cheap string fields and one rule, the September 28 benchmark runs
one field per edit. JIT/AOT async live updates were about 13–15% faster than full
validation; synchronous live updates were slower than the cheap full pass.
Use full parsing for one-off validation and sessions when editing state and
avoiding expensive repeated checks matter. Reproducible measurements are in
`benchmark/rules-live/` in the repository.
