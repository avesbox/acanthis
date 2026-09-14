---
description: Validate repeated values with lists or fixed positions with tuples.
---

# Lists and tuples

Validate repeated values with lists or fixed positions with tuples.

## Lists

Use the `list()` method to create a list schema. This method allows you to validate and transform lists.

```dart
list(string()).min(5);
list(string()).max(10);
list(string()).length(5);
list(string()).everyOf(['Acanthis', 'Dart']);
list(string()).anyOf(['Acanthis', 'Dart']);
list(string()).unique();
```

You can also create a list from the type.

```dart
string().list();
number().list();
boolean().list();
```

Instead, if you want to get the element type from the list type you can use the `unwrap()` method.

```dart
final names = string().list();
final elementType = names.unwrap(); // string()
```

## Tuples

Unlike lists, tuples are fixed-length lists that specify different schemas for each index.

```dart
final tupleSchema = tuple([
  string(),
  number(),
  boolean(),
]);
```

You can also create a tuple from the type.

```dart
final tupleSchema = string().tuple([
  string(),
  number(),
  boolean(),
]);
```

::: info
The previous example creates a tuple of 4 elements not 3. The first element is the schema type that is used to create the tuple and the rest are what you pass to the `tuple()` method.

```dart
final tupleSchema = string().tuple([
  string(),
  number(),
  boolean(),
]); // [string(), string(), number(), boolean()]
```

:::

### `variadic()`

To create a variadic tuple, you can use the `variadic()` method. This method allows you to create a tuple with a fixed number of elements and a variable number of elements.

```dart
final tupleSchema = string().tuple([
  string(),
  number(),
]).variadic();
```

The last element will behave like a list. It will accept any number of elements of the same type.

```dart
final tupleSchema = string().tuple([
  string(),
  number(),
]).variadic();

tupleSchema.parse([
  'Acanthis',
  'Dart',
  5,
  10,
  15,
  20,
]); // ✅
```

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
