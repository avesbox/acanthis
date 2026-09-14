# Changelog

## 2.0.0

- feat: extend audited input/output JSON Schema 2020-12 and OpenAPI 3.1 exports with numeric bounds, scalar equality/enumeration, boolean checks, nonempty strings, list lengths, and stable recursive object references. Keep repeated constraints conjunctive and diagnose unaudited semantics explicitly.
- test: verify 1,620 runtime/input pairs and successful outputs with independent JSON Schema and OpenAPI validators; add a repeatable export audit runner.

- breaking: separate required nullable fields from optional presence; validate defaults for absent/null input consistently across execution modes. Preserve nullable nulls and keep invalid-input recovery unsuccessful.
- breaking: `partial()` now preserves omission, nullability and unknown-key policy; add `patch()` alias and suppress defaults only for omitted PATCH fields.
- feat: add explicit strip/preserve/reject unknown-key policies and structural input/output exports for JSON Schema 2020-12 and OpenAPI 3.1, with diagnostics for unsupported behavior.
- fix: preserve defaulted field values in live recovery without repeating transformations; validate pipeline defaults on their output side.

- fix: export ordinary OpenAPI unions using `anyOf` so inputs matching multiple branches remain valid.
- docs: record native issue compatibility, an executable presence/default/export audit, and selected-field rule design before changing live scheduling.

- test: add reproducible differential validation and lifecycle benchmarks for JIT/AOT, invalid inputs, large unions, transformed outputs, live updates, controlled async callbacks, and separate allocation/CPU profiling.
- feat: add `mockSeeded` with a documented supported subset, validation guarantees, resource limits and explained failures; bound the legacy list mock loop.
- fix: align sync/async recovery output, nested stripping, absent optional fields, and container sharing. Type-failure fallback mocking now uses a fixed seed for reproducible recovery.

- feat: emit ordered structured issues directly, retaining duplicate failures, typed data paths, constraint parameters, and nested union branch diagnostics. Add field/tree/JSON formatters and presentation-time message resolvers; keep `errors` as a lossy compatibility projection.
- fix: finalize the unreleased 2.0 path contract (`/account/email`, without a trailing check name), preserve diagnostics across async composition and live updates, and omit input values from built-in coercion messages. Missing dependencies use a stable `dependency` code.

- perf: reuse input maps and typed lists when validation leaves them unchanged. Parsed values can now share identity with their input; transformations, coercion, defaults, and unknown-key stripping retain their output handling.

- feat: add `watch` and `watchAsync` extensions on object schemas for synchronous and asynchronous live validation sessions. Synchronous sessions expose `explain(field)`; update deltas report executed fields and whether full validation ran.
- feat: add `validate`/`validateAsync`, typed validation outcomes, and structured issues with paths and JSON pointers.
- perf: specialize eligible object schemas with inline primitive checks and flattened nested validation.
- fix: execute object and list transformations once through async entry points, propagate nested stripped output without mutating input, and report invalid map/list inputs through non-throwing APIs.
- breaking: require Dart 3.13 or later. Parsed maps/lists may share input identity; copy the returned container explicitly when independent mutable output is required. Unknown properties are stripped at every object level unless that level uses passthrough.
- chore: update dependencies to ensure compatibility with the latest versions of Dart and Flutter, improving overall stability and performance of the library.
- fix: resolve issues with asynchronous validation in sessions, ensuring that all asynchronous checks are properly handled and that validation results are accurate and reliable.

## 1.6.0

- feat: add coercion support for all types, allowing for automatic type conversion when parsing values. This feature enables more flexible and user-friendly validation by accepting different input formats and converting them to the expected type.

## 1.5.4

- fix: Prevent nullable to be treated always like a pure type and use type purity to determine if the schema is pure or not, allowing for more complex schemas to be nullable without losing their purity.

## 1.5.3

- perf: improve general performances

## 1.5.2

- feat: add `AcanthisType#mock` to generate mocks values from the schema.

## 1.5.1

- feat: add dot-shorthand support for all types.
- feat: add `AcanthisInteger` and `AcanthisDouble` to represent integer and double types separately.
- feat: add `template` type to create template literal schemas with placeholders.

## 1.5.0

- feat: add Open API schema generation for all types.

## 1.4.6

- feat: add `AcanthisType#defaultValue` to get the default value of the schema.
- chore: `meta` dependency is now less strict.

## 1.4.5

- feat: add `CustomCauseCheck` to allow for custom checks that return a cause message on failure based on the input value.

## 1.4.4

- feat: pipes are now acanthis type and can be used to validate more complex structures.
- feat: date type accept now string, int and DateTime values.

## 1.4.3

- perf: improve performances again.

## 1.4.2

- chore: update dependencies
- perf: improved overall performances

## 1.4.1

- feat: add support for `literal` values in objects, unions, tuples, list

## 1.4.0

- feat: add support for class schemas with `classSchema<I, T>()`
- feat: add support for instances validation with `instance<T>()`
- feat: add support for discriminated union with `union<T>()` and `variant<T>()`

## 1.3.2

- fix(#14): change list parse values to dynamic values [#15](https://github.com/avesbox/acanthis/pull/15) by [francescovallone](https://github.com/francescovallone)

## 1.3.1

- fix: wrong error messages for missing keys when parsing maps [#13](https://github.com/avesbox/acanthis/pull/13) by [jesus-gueyp](https://github.com/jesus-gueyp)

>

## 1.3.0

- feat: add `AcanthisString#contained` to check if the string is one of the contained values.
- fix: `AcanthisString#enumerated` now accepts a optional parameter `nameTransformer` to transform the name property of the enum values if needed. [#12](https://github.com/avesbox/acanthis/pull/12) by [Hanibachi](https://github.com/Hanibachi)

## 1.2.3

- refactor: improve overall code quality and performance.
- feat: allow custom error message for all validators.

## 1.2.2

- refactor: add possiblity to use both String and RegExp for `AcanthisString#pattern` validator.
- feat: add `AcanthisType#elementType` to get the type of the schema.

## 1.2.1

- refactor: improve overall code quality and performance.
- remove 'fast_immutable_collections' dependency.

## 1.2.0

- feat: add `toJsonSchema` method to generate JSON Schema from Acanthis Types. [#10](https://github.com/avesbox/acanthis/pull/10) by [francescovallone](https://github.com/francescovallone)
- feat: add `tuple` validator to create a tuple schema. [#10](https://github.com/avesbox/acanthis/pull/10) by [francescovallone](https://github.com/francescovallone)
- feat: add several checks to multiple validators. [#10](https://github.com/avesbox/acanthis/pull/10) by [francescovallone](https://github.com/francescovallone)
- feat: add Metadata System to allow for adding metadata to schemas. [#10](https://github.com/avesbox/acanthis/pull/10) by [francescovallone](https://github.com/francescovallone)

## 1.1.0

- fix: `AcanthisMap.extend` method now does not override existing key-value pairs. [#7](https://github.com/avesbox/acanthis/pull/7) by [francescovallone](https://github.com/francescovallone)
- refactor: codebase is now immutable. [#6](https://github.com/avesbox/acanthis/pull/6) by [dickermoshe](https://github.com/dickermoshe)

## 1.0.2

- Add `differsFromNow` to the `AcanthisDate` validator.
- Add `double` and `between` to the `AcanthisNumber` validator.
- Add `time`, `url`, `card` and `hexColor` to the `AcanthisString` validator.

## 1.0.1

- Add `lazy` validator to allow for recursive schemas.

## 1.0.0

- Upgrade dependencies.
- Add async checks for all validators to allow for a more flexible validation process.
- Add `partial` validator to object validator.
- Add more String validators.
- Rename `customCheck` to `refine` in all validators.
- Add `refineAsync` to all validators.
- Add `pipe` and  `AcanthisPipeline` to allow for more complex validation and transformation processes.

## 0.1.3

### Features

- Add the `optionals` function to the `object` validator.

### Docs

- Add information about `optionals` in the `object` validator.

## 0.1.2

- Add the `addFieldDependency` function to the `object` validator.
- Add information about `addFieldDependency` in the `object` validator.
- Remove the `Operations` section from the documentation.

## 0.1.1

### Refactor

- The function `jsonObject` has been renamed as `object`.
- Add explicit information about the parse result object `AcanthisParseResult`.

## 0.1.0

- Add the `nullable` validator.
- Add the `union` validator.
- Add the `boolean` validator.
- Add transformation functions for all the validators except `nullable`, `boolean` and `union`.
- Add tests for all the validators (100% coverage 🎉).
- Add documentation for all the validators.
- [#1] Fix the `string().email()` validator that will now use the `email_validator` package.

## 0.0.1

- Initial version.
