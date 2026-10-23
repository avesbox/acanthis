---
description: Match exact values, accept alternative shapes, and validate structured strings.
---

# Literals and unions

## Literals

`literal(value)` requires that value before running added checks and transformations.

```dart
final tag = literal('published');
print(tag.validate('published')); // true
print(tag.validate('draft')); // false

print(literal<int>(1).validate(1.0)); // false
print(literal<num>(1).validate(1.0)); // true
```

Matching uses the declared Dart type and `==`. Lists and maps do not gain deep equality. Use scalar literals for tags and JSON contracts. `literal(null)` accepts null.

## Unions {#union}

`union<T>()` accepts a value when one of its branches succeeds. Plain branches run in declaration order; the first valid branch supplies the output.

```dart
final identifier = union<Object?>([string(), integer()]);
print(identifier.parse('acct_1')); // acct_1
print(identifier.parse(42)); // 42
print(identifier.validate(false)); // false
```

`.or<T>(alternatives)` includes its receiver as the first branch.

```dart
final value = string().or<Object?>([number(), boolean()]);
print(value.parse(true)); // true
```

Failed union diagnostics retain branch issues. Branch order matters when coercion or transformations overlap.

## `variant()`

A variant pairs a cheap guard with a full schema. Use it to select tagged shapes before running their child checks.

```dart
final shape = union<Map<String, Object?>>([
  variant(
    name: 'circle',
    guard: (value) => value is Map && value['type'] == 'circle',
    schema: object({'type': literal('circle'), 'radius': number().positive()}),
  ),
  variant(
    name: 'rectangle',
    guard: (value) => value is Map && value['type'] == 'rectangle',
    schema: object({
      'type': literal('rectangle'),
      'width': number().positive(),
      'height': number().positive(),
    }),
  ),
]);
print(shape.validate({'type': 'circle', 'radius': 10})); // true
```

Matching variants are tried in order. If a matching variant fails, later matching variants can still succeed. When variants and plain branches are mixed, matching variants run before the plain alternatives, regardless of where plain branches appear in the list.

Keep guards pure and cheap, and name variants for branch diagnostics. Guard callbacks are application code; strict export rejects guarded unions.

## Template literals

`template()` combines literal string pieces and supported scalar schemas. It validates a complete string and returns that string.

```dart
final size = template([number().positive(), string().contained(['px', 'em', 'rem'])]);
print(size.parse('12px')); // 12px
print(size.validate('15pt')); // false

final item = template(['item-', integer().positive()]);
print(item.parse('item-42')); // item-42
```

Segment shapes choose substring boundaries, then segment schemas validate typed values. Their transformations feed later checks without rewriting the returned template string. Failed checks do not retry alternative splits. Use literal separators to make boundaries unambiguous. Async segments require async parsing; complex object segments and guarded segment unions are unsupported.
