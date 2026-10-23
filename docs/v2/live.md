# Live validation

`ObjectSchema.watch(initial)` creates a synchronous editing session and validates
revision 0 immediately. `watchAsync` awaits the initial validation and supports
async children and rules. Session and delta outputs are `Map<String, Object?>`,
matching V2's heterogeneous objects; sessions no longer take V1's value type parameter.

```dart
final schema = object({
  'age': string().pipe(integer().gte(18), transform: int.parse),
  'name': string().min(1),
});
final session = schema.watch({'age': '21', 'name': 'Ada'});
final delta = session.set('name', 'Grace');
// delta.executedFields == {'name'}; parsed age remains the integer 21.
```

Use `set`/`remove` for literal top-level names and `setPath`/`removePath` for
segment lists or `AcanthisPath`. Dots in string paths are literal. Paths use string
map keys and nonnegative list indices. Parents must exist; setting index equal
to list length appends. Removing an element shifts subsequent indices.

`batch([AcanthisEdit.set(path, value), AcanthisEdit.remove(otherPath)])` applies
edits in order and advances the revision once. Invalid paths, cycles, or oversized
snapshots reject the entire batch before changing input or revision. Validation
failures commit the edited input and publish issues. Callback programming errors
propagate; the input stays committed, `validated` is cleared, and subsequent edits
can retry. Synchronous callbacks cannot reenter the same session with edits.

Only changed top-level fields are parsed again. Nested edits revalidate their
entire top-level field, including its transforms and list index shifts. Selected
rules reuse cached diagnostics unless one of their input top-level fields changed.
Skipped rules clear their previous issues when prerequisites become invalid or
missing. `updateContext(context)` advances the revision and invalidates all field
and rule caches, including checks inside nested objects.

Root checks/transforms, legacy field dependencies, and `objectPolicy: first`
invalidate all caches and set `fullValidation: true`. Unknown-key handling remains
identical to ordinary parsing; typed passthrough values are parsed each revision.
`executedFields` and `executedRules` report cache misses actually visited, including
missing fields and rules skipped by prerequisite gating.

Each delta captures its `revision`, `input`, all `issues`, and `validated` output
(null when invalid). `addedIssues` and `removedIssues` compare against the last
published revision. `changedIssues` concatenates removals and additions. Equality
uses diagnostic paths, codes, parameters and branches, preserving duplicate counts
and ignoring localized messages. Sync sessions also expose `explain(field)`.

## Async sessions

```dart
final session = await schema.watchAsync(
  {'age': '21', 'name': 'Ada'},
  debounce: const Duration(milliseconds: 150),
);
final previous = session.set('name', 'G');
final latest = session.set('name', 'Grace');
final cancelled = await previous; // settled == false, isCurrent == false
final result = await latest;     // current settled revision
session.dispose();
```

Debouncing coalesces work while retaining all edits since the last published
revision. Every newer edit cancels the previous revision's cooperative signal.
Stale work never replaces session state and returns an unsettled delta without
issues or validated output. A running callback may finish before cancellation
is observed. Callback errors still propagate. `validated` is null while pending;
`issues` remains the last published set until a current revision finishes.
`pendingFields` tracks fields still awaiting evaluation; async rules may remain
in flight after the last field settles. Await the edit's future to await completion.

A scope supplied to `watchAsync` retains its context and collection policies.
Its cancellation signal also cancels active revisions and propagates
`AcanthisValidationCancelled` to callers. `dispose()` cancels work, clears pending
and validated state, and rejects further edits. Always dispose async sessions.

Raw collections are copied on entry and deeply frozen in input snapshots. Cyclic
collections, more than 100,000 visited values, or nesting beyond 128 levels are
rejected. Parsed root maps are frozen while nested outputs retain schema runtime
types, such as `List<int>`. Treat nested parsed values, opaque domain objects and
context as immutable so cached results remain reliable. Snapshotting and output
assembly still visit the object; incremental reuse avoids repeated callbacks,
not all work proportional to input size.
