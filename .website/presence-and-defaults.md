---
description: Decide whether a field may be omitted, contain null, or receive a default.
---

# Presence and defaults

An optional field may be omitted. A nullable value may be null. Choose each behavior explicitly.

## Choose a field policy

For `object({'name': field})`, the policies below produce these results. Every row accepts `'Ada'`.

| Field and object policy | Missing key | Supplied null | Supplied `''` |
| --- | --- | --- | --- |
| `string().min(2)` | Invalid | Invalid | Invalid |
| `string().min(2).nullable()` | Invalid | Keeps null | Invalid |
| `string().min(2)` + `.optionals(['name'])` | Omitted | Invalid | Invalid |
| Nullable field + `.optionals(['name'])` | Omitted | Keeps null | Invalid |
| `string().min(2).withDefault('Guest')` | Guest | Guest | Invalid |
| Same default + `.optionals(['name'])` | Guest | Guest | Invalid |
| Same default + `.patch()` | Omitted | Guest | Invalid |

## Optional fields

```dart
final account = object({'name': string()}).optionals(['name']);
print(account.parse({})); // {}
print(account.validate({'name': null})); // false
```

Optionality is an object policy. A supplied value still runs its child schema.

## Nullable fields

```dart
final account = object({'name': string().nullable()});
print(account.validate({})); // false
print(account.parse({'name': null})); // {name: null}
```

Add `.optionals(['name'])` to permit both omission and null.

## Defaults

```dart
final account = object({'name': string().min(2).withDefault('Guest')});
print(account.parse({})); // {name: Guest}
print(account.parse({'name': null})); // {name: Guest}
print(account.validate({'name': ''})); // false
```

Defaults replace missing/null input and undergo normal validation. An invalid default fails; a supplied invalid value is not replaced. Pipeline defaults are output values; see [pipeline defaults](/schemas/transformations#pipeline-defaults).

`nullable(defaultValue: 'Guest')` also supplies a non-null default. To fill a missing key with null, use `.nullable().withDefault(null)`.

## Preserve omission in updates

`.patch()` and `.partial()` make fields optional and suppress defaults for omitted keys. Supplied values retain their original validation, nullability, and default handling.

```dart
final patch = object({
  'name': string().min(2).withDefault('Guest'),
  'nickname': string().nullable(),
}).patch();

print(patch.parse({})); // {}
print(patch.parse({'nickname': null})); // {nickname: null}
print(patch.parse({'name': null})); // {name: Guest}
```

Use `containsKey()` when applying an update so explicit null remains distinct from omission. `deep: true` applies to direct nested object schemas; it does not define database merging or patch list elements. Follow the [request recipe](/request-validation#apply-a-patch) to apply a patch and validate the merged value.

The same policies apply to async parsing, live sessions, and contract export. Invalid outcomes can lack typed recovery; use their issues and check [hasValue](/validation-results#recovery-values) before inspecting recovery.
