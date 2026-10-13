# Missing fields, nulls, and defaults

Presence and nullability answer different questions: may a key be omitted, and
may its value be null? Start with `object({'name': field})` and choose the policy
below. Each cell shows the validity and the parsed map returned by `tryParse()`.
Invalid output is recovery data, not a value you should save.

| Field and object policy | Missing: `{}` | Null: `{'name': null}` | Invalid: `{'name': ''}` |
| --- | --- | --- | --- |
| `string().min(2)` | Invalid; `{}` | Invalid; recovery value | Invalid; `{'name': ''}` |
| `string().min(2).nullable()` | Invalid; `{}` | Valid; `{'name': null}` | Invalid; `{'name': ''}` |
| `string().min(2)` + `.optionals(['name'])` | Valid; `{}` | Invalid; recovery value | Invalid; `{'name': ''}` |
| `string().min(2).nullable()` + `.optionals(['name'])` | Valid; `{}` | Valid; `{'name': null}` | Invalid; `{'name': ''}` |
| `string().min(2).withDefault('Guest')` | Valid; `{'name': 'Guest'}` | Valid; `{'name': 'Guest'}` | Invalid; `{'name': 'Guest'}` |
| Same default + `.optionals(['name'])` | Valid; `{'name': 'Guest'}` | Valid; `{'name': 'Guest'}` | Invalid; `{'name': 'Guest'}` |
| Same default + `.patch()` | Valid; `{}` | Valid; `{'name': 'Guest'}` | Invalid; `{'name': 'Guest'}` |

All rows accept `{'name': 'Ada'}` and return that value. Type-failure recovery
without a default is deliberately not specified here; use `issues` to handle the
failure instead of depending on a replacement value.

## Choose a default

`withDefault()` replaces missing or null input before normal validation. The
default must pass the field's checks. On invalid supplied input, `tryParse()` can
return the default as recovery output, but the outcome remains invalid.

```dart
final schema = object({
  'name': string().min(2).withDefault('Guest'),
});
schema.parse({}); // {name: Guest}
schema.parse({'name': null}); // {name: Guest}
final invalid = schema.tryParse({'name': ''});
print(invalid.isValid); // false
print(invalid.value); // {name: Guest}
```

`parse()` throws for that invalid supplied value. A default that fails its own
constraints also fails validation: `string().min(2).withDefault('x')` does not
make missing input valid.

`nullable(defaultValue: 'Guest')` also replaces missing/null input with its
non-null default. Plain `nullable()` preserves an explicit null. For an explicit
null default that fills a missing key, use `string().nullable().withDefault(null)`.

## Preserve omission in updates

`patch()` and `partial()` are aliases. They suppress defaults for omitted fields,
preserve the original nullability, and retain the unknown-key policy.

```dart
final patch = object({
  'name': string().min(2).withDefault('Guest'),
  'nickname': string().nullable(),
}).patch();
patch.parse({}); // {}
patch.parse({'nickname': null}); // {nickname: null}
patch.parse({'name': null}); // {name: Guest}
```

Use `containsKey()` when applying a patch; testing `value != null` loses explicit
null updates. `deep: true` recurses through directly nested object schemas only.
It does not define database merge semantics or make list elements into patches.
See the [request-validation recipe](/request-validation#apply-a-patch) for a full example.

These presence rules also apply to async parsing and live sessions. See
[objects](/schemas/objects) for composition and
[validation results](/validation-results) for recovery and issues.
