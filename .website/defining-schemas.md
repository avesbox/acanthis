# Defining Schemas

To validate data, you need to define a schema. A schema is a blueprint that describes the data you want to validate. They are associated with _types_.

## String

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
string().required();
string().digits();
string().letters();
string().alphanumeric();
string().alphanumericWithSpaces();
string().specialCharacters();
string().allCharacters();
string().enumerated(['Acanthis', 'Dart']);
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

Under the hood it uses the `email_validator` package. You can find more information about the package [here](https://pub.dev/packages/email_validator).

## Numbers

Use the `number()` method to create a number schema. This method allows you to validate and transform numbers.

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

::: info
The `extend()` method will not overwrite the existing properties. It will only add the new properties to the schema.
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

::: info
The `merge()` method will overwrite the existing properties. It will only add the new properties to the schema.
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
