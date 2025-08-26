# Changelog

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
