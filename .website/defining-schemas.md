# Defining Schemas

To validate data, you need to define a schema. A schema is a blueprint that describes the data you want to validate. They are associated with _types_.

## String

::: warning Deprecated
`string().required()` is deprecated in Acanthis 1.3.1. The validator was ambiguous and has been replaced with `string().notEmpty()`
:::

Acanthis provides many built-in validators for string validation and transformation. To perform some common validations:

```dart
string().min(5);
string().max(10);
string().length(5);
string().pattern(RegExp('^[a-zA-Z0-9]+$'));
// string().pattern('^[a-zA-Z0-9]+$'); equivalent to the previous example
string().contains('Acanthis');
string().startsWith('Acanthis');
string().endsWith('Acanthis');
string().upperCase();
string().lowerCase();
string().mixedCase();
string().notEmpty();
string().digits();
string().letters();
string().alphanumeric();
string().alphanumericWithSpaces();
string().specialCharacters();
string().allCharacters();
string().contained(TestEnum.values);
string().contained(['Acanthis', 'Dart']);
string().exact('Acanthis');
```

To perform simple transformations:

```dart
string().toUpperCase();
string().toLowerCase();
string().encode();
string().decode();
```

## String Formats

```dart
string().email();
string().url();
string().uri();
string().uuid();
string().dateTime();
string().time();
string().nanoid();
string().hexColor();
string().base64();
string().cuid();
string().cuid2();
string().ulid();
string().jwt();
string().card();
```

### Emails

To validate an email address, you can use the `email()` method. This method checks if the string is a valid email address format.

```dart
string().email();
```

Under the hood it uses the `email_validator` package. You can find more information about the package at [his pub.dev page](https://pub.dev/packages/email_validator).

## Numeric values

Acanthis provides three types to represent numeric values: `AcanthisNumber`, `AcanthisInteger` and `AcanthisDouble`. All of them shares the same validators and api.

Use the `number()` function or the `integer()` or `double()` functions to create a number schema. This method allows you to validate and transform numbers.

```dart
number().gt(5);
number().gte(10);
number().lt(5);
number().lte(10);
number().positive();
number().negative();
number().nonNegative();
number().nonPositive();
number().multipleOf(5);
number().integer();
number().double();
number().nonNan();
number().nan();
number().finite();
number().infinite();
number().enumerated([1, 2, 3]);
number().exact(5);
```

To perform simple transformations:

```dart
number().pow(2);
```

## Booleans

Use the `boolean()` method to create a boolean schema. This method allows you to validate and transform booleans.

```dart
boolean().isTrue();
boolean().isFalse();
```

## Dates

Use the `date()` method to create a date schema. This method allows you to validate and transform dates.

```dart
date().min(DateTime.now());
date().max(DateTime.now());
date().differsFromNow(Duration(days: 5));
date().differsFrom(DateTime.now(), Duration(days: 5));
```

## Nullables

Use the `nullable()` method to create a nullable schema. This method allows you to validate and transform nullables.

Nullables are a bit special in Acanthis. They are not a type, but a modifier. You can use them with any type to make it nullable.

```dart
string().nullable(defaultValue: 'default');
number().nullable(defaultValue: 5);
boolean().nullable(defaultValue: true);
date().nullable(defaultValue: DateTime.now());
...
```

You can also validate the nullable type.

```dart
string().nullable().enumerated(['Acanthis', 'Dart']);
```

::: info
At the enumerated list will be added `null` and the default value if provided.
:::

## Objects

Use the `object()` method to create an object schema. This method allows you to validate and transform objects.

With objects Acanthis refers to `Map<String, dynamic>` or `Map<String, Object?>` or so called json-encodeable types.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
});
```

By default, the object schema is strict and all the properties are required.

To add optional properties, you can use the `optionals()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
  'email': string().email(),
}).optionals([
  'email',
]);
```

To define a loose object schema, instead, you can use the `passthrough()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
}).passthrough();
```

This will allow any additional properties to be present in the object without validation.

To the passthrough method can be passed a type to validate the additional properties.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
}).passthrough(type: string());

object.parse({
  'name': 'Acanthis',
  'age': 5,
  'email': 'test@example.com'
}); // ✅

object.parse({
  'name': 'Acanthis',
  'age': 5,
  'email': 5
}); // ❌ throws ValidationError

```

Also, Acanthis provides some built-in validators for object validation:

```dart
object({}).maxProperties(5);
object({}).minProperties(5);
```

### `extend()`

To add additional properties to the object schema, you can use the `extend()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
}).extend({
  'email': string().email(),
});
```

::: warning
The `extend()` method will not overwrite the existing properties. It will only add the new properties to the schema if they do not already exist.
:::

### `merge()`

To merge two object schemas, you can use the `merge()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
}).merge({
  'email': string().email(),
});
```

::: warning
The `merge()` method will overwrite the existing properties.
:::

### `pick()`

To pick specific properties from the object schema to create a new schema, you can use the `pick()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
});

final personWithoutAge = person.pick(['name']);
```

### `omit()`

To omit specific properties from the object schema to create a new schema, you can use the `omit()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
});

final personWithoutName = person.omit(['name']);
```

### `partial()`

The `partial()` method makes all properties of the object schema nullable.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
});

final personPartial = person.partial();
```

It also accepts the `deep` parameter to make all nested properties nullable.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
  'address': object({
    'city': string().min(3),
    'country': string().min(3),
  })
});

final personPartial = person.partial(deep: true);
```

## Recursive Objects

Sometimes you need to validate recursive objects. For example, a tree structure or a linked list. Acanthis provides a way to do this using the `lazy()` method.

```dart
final tree = object({
  'value': number(),
  'children': lazy((parent) => parent.list()),
});
```

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
...
```

Instead, if you want to get the element type from the list type you can use the `unwrap()` method.

```dart
final list = string().list();
final elementType = list.unwrap(); // string()
```

## Instances

Use `instance<T>()` to validate already constructed Dart objects (class instances) without converting them to `Map`.  
You attach field validators via getters. The original instance is returned unchanged (no structural transformation).

```dart
class User {
  final String name;
  final int age;
  final String? email;
  User(this.name, this.age, this.email);
}

final userSchema = instance<User>()
  .field('name', (u) => u.name, string().min(3))
  .field('age', (u) => u.age, number().positive())
  .field('email', (u) => u.email, string().email(), optional: true);

userSchema.parse(User('Alice', 30, null)); // ✅
userSchema.parse(User('A', 30, null));     // ❌ ValidationError (name.min)
```

::: info
A field flagged as optional will be skipped if the getter returns `null`.
:::

### Differences to `object()`

- `object()` validates `Map` data (often decoded JSON).  
- `instance()` validates real Dart objects via property getters.

### Cross-field validation with refs

Define reusable references, then create a refinement that can access them.

```dart
class Order {
  final int quantity;
  final double unitPrice;
  Order(this.quantity, this.unitPrice);
}

final orderSchema = instance<Order>()
  .field('quantity', (o) => o.quantity, number().positive())
  .field('unitPrice', (o) => o.unitPrice, number().positive())
  .withRefs((r) => r
    .ref<int>('qty', (o) => o.quantity)
    .ref<double>('price', (o) => o.unitPrice)
  )
  .refineWithRefs(
    (o, refs) => refs<int>('qty') * refs<double>('price') <= 1000,
    'Total exceeds limit',
    name: 'totalLimit',
  );
```

`refineWithRefs` supplies a `RefAccessor` so you can read previously registered references by name and perform cross-field logic.

## Class Schemas

Use `classSchema<I, T>()` to build a typed pipeline that validates the input shape (I), maps the validated input into a class (T) via a pure mapper.

```dart
class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

final buildUser = classSchema<Map<String, dynamic>, User>()
  .input(object({
    'name': string().min(3),
    'age': number().positive(),
  }))
  .map((data) => User(data['name'], data['age']))
  .validateWith(
    instance<User>()
      .field('name', (u) => u.name, string().max(50))
      .field('age', (u) => u.age, number().gte(18)),
  )
  .build();

final user = buildUser.parse({
  'name': 'Alice',
  'age': 30,
}); // ✅ returns User instance
```

::: info
You can also validate the result of the mapping using `validateWith` and an `instance()` schema.
:::

## Tuples

Unlike lists, tuples are fixed-length lists that specify different schemas for each index.

```dart
final tuple = tuple([
  string(),
  number(),
  boolean(),
]);
```

You can also create a tuple from the type.

```dart
final tuple = string().tuple([
  string(),
  number(),
  boolean(),
]);
```

::: info
The previous example creates a tuple of 4 elements not 3. The first element is the schema type that is used to create the tuple and the rest are what you pass to the `tuple()` method.

```dart
final tuple = string().tuple([
  string(),
  number(),
  boolean(),
]); // [string(), string(), number(), boolean()]
```

:::

### `variadic()`

To create a variadic tuple, you can use the `variadic()` method. This method allows you to create a tuple with a fixed number of elements and a variable number of elements.

```dart
final tuple = string().tuple([
  string(),
  number(),
]).variadic();
```

The last element will behave like a list. It will accept any number of elements of the same type.

```dart
final tuple = string().tuple([
  string(),
  number(),
]).variadic();

tuple.parse([
  'Acanthis',
  'Dart',
  5,
  10,
  15,
  20,
]); // ✅
```

## Literals

Use `literal()` to create a schema that matches a specific literal value.

```dart
final numeric = literal(1);
```

The literal validator does not expose any additional check. It simply matches the exact value you provide.
It can be useful for creating unions of literal values, objects with specific shapes, or when a value can be both a literal and a more complex type.

## Union

To create a union type, you can use the `union()` method. This method allows you to create a type that can be one of several types.

```dart
final union = union([
  string()
  number(),
  boolean(),
]);

final union = string().union([
  number(),
  boolean(),
]); // it is the same as the previous example

```

This will create a type that can be either a string, number or boolean.

```dart
final union = string().union([
  number(),
  boolean(),
]);

union.parse('Acanthis'); // ✅
union.parse(5); // ✅
union.parse(true); // ✅
union.parse([1, 2, 3]); // ❌ throws ValidationError
```

### `variant()`

Use `variant()` to build a discriminated (guarded) branch inside a `union()`.  
A variant couples a lightweight guard with a full schema. The guard decides if the schema should even be attempted, letting you short‑circuit work and produce clearer errors.

Concept:

- Guard: `bool Function(dynamic)` returning true if this branch may validate the value.
- Schema: the `AcanthisType<T>` executed only when the guard passes.
- Name (optional): label used in aggregated errors (recommended).

Why variants instead of only plain union element types?

- Selective evaluation: only schemas whose guards return true are parsed (a plain union tries everything).
- Cleaner error surfaces: if no guard matches you get one union error instead of multiple unrelated schema errors.
- Natural discriminators: model tagged / algebraic unions (`type` fields, prefix patterns, structural probes).
- Performance: cheap guards filter out heavy schemas early.

Basic (tagged) example:

```dart
final shape = union([
  variant(
    name: 'circle',
    guard: (v) => v is Map && v['type'] == 'circle',
    schema: object({
      'type': string().exact('circle'),
      'radius': number().positive(),
    }),
  ),
  variant(
    name: 'rectangle',
    guard: (v) => v is Map && v['type'] == 'rectangle',
    schema: object({
      'type': string().exact('rectangle'),
      'width': number().positive(),
      'height': number().positive(),
    }),
  ),
]);

shape.parse({'type': 'circle', 'radius': 10});    // ✅
shape.parse({'type': 'rectangle', 'width': 5, 'height': 7}); // ✅
shape.parse({'type': 'triangle'}); // ❌ ValidationError (no variant matched)
```

Mixing variants and plain types:

```dart
final idOrPointOrBool = union([
  variant(
    name: 'idString',
    guard: (v) => v is String && v.startsWith('id:'),
    schema: string().pattern(RegExp(r'^id:\d+$')),
  ),
  variant(
    name: 'point',
    guard: (v) => v is Map && v.containsKey('x') && v.containsKey('y'),
    schema: object({
      'x': number().finite(),
      'y': number().finite(),
    }),
  ),
  boolean(), // plain type (checked after matching variants)
]);
```

Fallback pattern (keep last):

```dart
final numericInput = union([
  variant(
    name: 'numberLike',
    guard: (v) => v is String && double.tryParse(v) != null,
    schema: string().pipe(number(), transform: double.parse),
  ),
  variant(
    name: 'rawNumber',
    guard: (v) => v is num,
    schema: number(),
  ),
]);
```

Guidelines:

- Order matters. Guards are evaluated top‑down. The first variant whose guard returns true is attempted; if its schema fails, later variants whose guards also returned true will still be considered.
- Keep guards pure, fast, and side‑effect free. They must not throw.
- Name every variant for clearer aggregated errors (`name:`).
- Combine variants with plain union element types freely. After all matching variants are tried, remaining plain types are attempted.
- If no guard matches and no plain type validates, the union fails with a single error.
- If at least one guard matches but all corresponding schemas fail, union aggregates those failures.

When to use:

- Tagged JSON objects (`type`, `kind`, `opcode`).
- Structural branching (presence of keys, collection shape).
- Prefix / pattern based routing for primitives.
- Performance sensitive large unions.

Use `variant()` whenever a cheap discriminator can prevent wasted work or produce more precise diagnostics.

## Refinements

Refinements are a way to add custom validation to a schema. You can use the `refine()` method to add a custom validation function to a schema.

::: warning
Refinments function should never throw an error. It should always return a boolean value.
:::

### `refine()`

To add a custom sync validation function to a schema, you can use the `refine()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
}).refine(onCheck: (value) => value['age'] > 4, error: 'Age is lower than 4', name: 'ageCheck');
```

### `refineAsync()`

To add a custom async validation function to a schema, you can use the `refineAsync()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
}).refineAsync(onCheck: (value) async => value['age'] > 4, error: 'Age is lower than 4', name: 'ageCheck');
```

## Pipes

Pipes are a way to add custom transformation to a schema. They are useful when you want to transform a value from one type to another.

You can use the `pipe()` method to add a custom transformation function to a schema.

```dart
final name = string().pipe(number(), transform: (value) => int.parse(value));
```

## Default Values

To provide a default value for a schema, you can use the `withDefault()` method. This method allows you to specify a value that will be used if the validation operations fail.

```dart
final name = string().min(2).max(100).withDefault('Unknown');
name.tryParse('A'); // returns 'Unknown'
name.tryParse('Acanthis'); // returns 'Acanthis'
```

::: warning
This behavior is available only when using `tryParse()` or `tryParseAsync()`. When using `parse()` or `parseAsync()`, a `ValidationError` will be thrown if the validation fails regardless of the default value.
:::

## Template Literals

Use `template()` to create a schema that matches template literal strings with placeholders.

```dart

enum SizeUnit { px, em, rem }

final sizeSchema = template([
  number(),
  string().enumerated(SizeUnit.values),
]);

sizeSchema.parse('12px'); // ✅
sizeSchema.parse('5em');  // ✅
sizeSchema.parse('20rem'); // ✅
sizeSchema.parse('15pt'); // ❌ ValidationError
```

The `template()` function takes a list of schemas that represent the placeholders in the template literal. The resulting schema will match strings that follow the pattern defined by the schemas.

The placeholders can be of any type, including strings, numbers, booleans, or even complex objects.

## Mocking schemas

To tests if your schema works as expected, you can use the `mock()` method to generate random data that conforms to the schema. This can be useful for testing your validation logic and for generating sample data.

```dart
final userSchema = object({
  'name': string().min(3),
  'age': number().positive(),
  'email': string().email(),
});
final mockUser = userSchema.mock();

print(mockUser);
// => { name: 'Acanthis', age: 32, email: 'test@example.com' }
```
