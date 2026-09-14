---
description: Find the schema or operation you need, from primitive values to custom validation.
---

# Schema reference {#defining-schemas}

Start with a type, then chain checks and transformations. Each method returns a new schema, so you can reuse a base schema without changing it.

```dart
final email = string().email();
final account = object({'email': email});
```

New to Acanthis? Follow the [quick start](/basic-usage) for a complete example.

<div class="doc-cards">
<a href="/schemas/strings.html"><strong>Strings</strong><span>Validate text, check formats, and transform string values.</span></a>
<a href="/schemas/numbers.html"><strong>Numbers, booleans, and dates</strong><span>Choose a primitive schema and add the constraints your data needs.</span></a>
<a href="/schemas/objects.html"><strong>Objects</strong><span>Validate named fields, control unknown keys, and compose reusable object schemas.</span></a>
<a href="/schemas/collections.html"><strong>Lists and tuples</strong><span>Validate repeated values with lists or fixed positions with tuples.</span></a>
<a href="/schemas/nullable.html"><strong>Nullable values</strong><span>Allow null explicitly and distinguish it from an absent object field.</span></a>
<a href="/schemas/instances.html"><strong>Instances and classes</strong><span>Validate existing Dart instances and describe class fields.</span></a>
<a href="/schemas/unions.html"><strong>Literals and unions</strong><span>Match exact values or accept one of several schema shapes.</span></a>
<a href="/schemas/refinements.html"><strong>Custom validation</strong><span>Add synchronous or asynchronous rules when built-in checks are not enough.</span></a>
<a href="/schemas/transformations.html"><strong>Transformations and defaults</strong><span>Convert input values, chain schemas, and provide recovery defaults.</span></a>
<a href="/schemas/mocking.html"><strong>Mock data</strong><span>Generate sample input and choose between legacy mocking and bounded seeded generation.</span></a>
</div>

## Find a specific type or operation

| Type or operation | Reference |
| --- | --- |
| <span id="string"></span>String | [View guide](/schemas/strings#string) |
| <span id="string-formats"></span>String Formats | [View guide](/schemas/strings#string-formats) |
| <span id="emails"></span>Emails | [View guide](/schemas/strings#emails) |
| <span id="numeric-values"></span>Numeric values | [View guide](/schemas/numbers#numeric-values) |
| <span id="booleans"></span>Booleans | [View guide](/schemas/numbers#booleans) |
| <span id="dates"></span>Dates | [View guide](/schemas/numbers#dates) |
| <span id="nullables"></span>Nullables | [View guide](/schemas/nullable#nullables) |
| <span id="objects"></span>Objects | [View guide](/schemas/objects#objects) |
| <span id="extend"></span>`extend()` | [View guide](/schemas/objects#extend) |
| <span id="merge"></span>`merge()` | [View guide](/schemas/objects#merge) |
| <span id="pick"></span>`pick()` | [View guide](/schemas/objects#pick) |
| <span id="omit"></span>`omit()` | [View guide](/schemas/objects#omit) |
| <span id="partial"></span>`partial()` | [View guide](/schemas/objects#partial) |
| <span id="recursive-objects"></span>Recursive Objects | [View guide](/schemas/objects#recursive-objects) |
| <span id="lists"></span>Lists | [View guide](/schemas/collections#lists) |
| <span id="instances"></span>Instances | [View guide](/schemas/instances#instances) |
| <span id="differences-to-object"></span>Differences to `object()` | [View guide](/schemas/instances#differences-to-object) |
| <span id="cross-field-validation-with-refs"></span>Cross-field validation with refs | [View guide](/schemas/instances#cross-field-validation-with-refs) |
| <span id="class-schemas"></span>Class Schemas | [View guide](/schemas/instances#class-schemas) |
| <span id="tuples"></span>Tuples | [View guide](/schemas/collections#tuples) |
| <span id="variadic"></span>`variadic()` | [View guide](/schemas/collections#variadic) |
| <span id="literals"></span>Literals | [View guide](/schemas/unions#literals) |
| <span id="union"></span>Union | [View guide](/schemas/unions#union) |
| <span id="variant"></span>`variant()` | [View guide](/schemas/unions#variant) |
| <span id="refinements"></span>Refinements | [View guide](/schemas/refinements#refinements) |
| <span id="refine"></span>`refine()` | [View guide](/schemas/refinements#refine) |
| <span id="refineasync"></span>`refineAsync()` | [View guide](/schemas/refinements#refineasync) |
| <span id="pipes"></span>Pipes | [View guide](/schemas/transformations#pipes) |
| <span id="default-values"></span>Default Values | [View guide](/schemas/transformations#default-values) |
| <span id="template-literals"></span>Template Literals | [View guide](/schemas/unions#template-literals) |
| <span id="mocking-schemas"></span>Mocking schemas | [View guide](/schemas/mocking#mocking-schemas) |
| <span id="type-coercion"></span>Type Coercion | [View guide](/schemas/transformations#type-coercion) |
| <span id="coerce-and-unions"></span>`coerce()` and Unions | [View guide](/schemas/transformations#coerce-and-unions) |
| <span id="seeded-test-data"></span>Seeded test data | [View guide](/schemas/mocking#seeded-test-data) |
