# Custom refinements

```dart
import 'package:acanthis/acanthis.dart' as acanthis;

final number = acanthis.number().refine(
  onCheck: (value) => value == 1,
  error: 'Value must be 1',
  name: 'custom',
);

final accepted = number.parse(1); // 1
final rejected = number.tryParse(2); // invalid, recovery value: 2
final message = rejected.issues.single.message; // Value must be 1
```

`onCheck` receives the schema's typed output and returns bool. False adds one
issue using `name` as its code; the default name, including an empty name, is
`custom`. `error` is optional. Without it, messages come from the usual catalog.
Number, integer, double, and string schemas retain their concrete fluent return
types. Coercion and earlier transformations happen before the predicate.

The supplied `error` becomes an immutable per-check code-to-message catalog,
created when defining the schema. It is resolved only when presenting an issue.
Issue parameters and transport do not contain the error text; IssueSink has no
message argument. Checks with the same name can use different messages without
changing a global catalog. Prefixing an issue preserves its default catalog.

An explicitly supplied presentation catalog takes precedence over the per-check
catalog, and retains complete-replacement semantics for missing codes:

```dart
final italian = acanthis.AcanthisMessageCatalog({
  'custom': (_) => 'Il valore deve essere 1',
});
final localized = rejected.issues.single.formatMessage(catalog: italian);
```

Predicate exceptions propagate. Synchronous parsing still stops at the first
failure with `parse`, throwing `ValidationError`, and collects ordered failures
as outcomes with `tryParse`. Both async
entry points also execute synchronous predicates. Definitions and introspection
never invoke the predicate.

## Check objects

Dart cannot combine optional positional parameters with named parameters in one
method. The former V2 `refine(check)` API is now `withCheck(check)`:

```dart
final schema = acanthis.integer().withCheck(
  acanthis.CallbackCheck<int>((value, context) {
    if (value != 1) context.addIssue('app.one');
  }),
);
```

`withCheck` accepts existing `Check<T>` implementations, including
`PredicateCheck`, without changing their behavior. `refineAsync(AsyncCheck<T>)`
is unchanged. Built-in predicates keep their existing optimized executor;
custom refinements use the normal ordered check path.

## Transform callbacks

`transform` accepts a callback directly, preserving the schema's output type:

```dart
final tripled = number.transform((value) => value * 3);
final value = tripled.parse(1); // 3
```

This works on number, integer, double, and string schemas. Callbacks execute in
fluent order after coercion and prior successful checks. An earlier failed
check skips subsequent transformations; a later failure retains the transformed
value as recovery. Callback exceptions propagate.

For `Transform<I, O>` objects, use `withTransform(transform)` instead of the
former `transform(transform)` form. `transformAsync(AsyncTransform<T, T>)` is
unchanged.
