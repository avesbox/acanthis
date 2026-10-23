---
description: Customize messages and localize the same validation result without running validation again.
---

# Messages and localization

Issues store codes and parameters. A message catalog turns them into text when you display them.

## Customize messages {#set-messages-on-a-schema}

Extend a bundled catalog to override selected codes and keep its fallback messages.

```dart
final catalog = AcanthisMessageCatalogs.english.extend({
  'minLength': (p) => 'Use at least ${p['value']} characters',
  'email': (_) => 'Enter a valid email address',
});
final issues = string().min(3).tryParse('x').issues;
print(issues.formatFields(catalog: catalog));
// {: [Use at least 3 characters]}
```

An explicit `catalog:` replaces normal lookup. A standalone catalog without a fallback renders unknown codes as the code itself. Use `.extend()` for partial overrides.

A missing object field reports `required`; an empty string can report `notEmpty`. Give application checks distinct codes when they need distinct messages.

## Add a custom check message

```dart
final slug = string().refine(
  onCheck: (value) => !value.contains(' '),
  name: 'slugSpaces',
  error: 'Use hyphens instead of spaces',
);
print(slug.tryParse('hello world').issues.first.message);
// Use hyphens instead of spaces
```

`name` is the issue code; `error` supplies that check's fallback text. For parameterized messages, use [custom checks](/schemas/refinements#parameterized-checks).

## Choose a language {#localize-at-presentation-time}

English and Italian catalogs cover built-in codes. Pass a catalog to a formatter to translate an existing result.

```dart
final issues = string().min(3).tryParse('x').issues;
print(issues.formatFields(catalog: AcanthisMessageCatalogs.italian));
// {: [Il valore deve contenere almeno 3 caratteri]}
```

`issue.formatMessage(catalog: ...)`, `formatFields()`, `formatTree()`, and `formatJson()` accept the same catalogs. These formatters also work with live-session issues.

## Scope a locale

`AcanthisI18n.runWith()` scopes message lookup to an action and its async continuations.

```dart
final issues = object({'name': string()}).tryParse({}).issues;
final config = AcanthisLocaleConfig.forLocale('it-CH', overrides: {
  'it': AcanthisMessageCatalog({'required': (_) => 'Obbligatorio'}),
  'it-CH': AcanthisMessageCatalog({'required': (_) => 'Campo obbligatorio'}),
});

final fields = AcanthisI18n.runWith(config, () => issues.formatFields());
print(fields); // {/name: [Campo obbligatorio]}
```

Locale lookup tries regional overrides, language overrides, then the bundled language. Locale keys normalize whitespace, case, and `_`/`-`. Application catalogs can supply other languages. `AcanthisMessageCatalogs.forLocale()` exposes the same lookup directly; `AcanthisI18n.configure()` sets the application default.

## Message precedence

With an explicit `catalog:`, only that catalog and its fallbacks are used. Otherwise lookup tries the active locale, the issue's per-check `defaultCatalog`, then English. An unresolved code renders as its code.

A builder returning null continues fallback. An empty string is a resolved message. Formatting changes neither validation nor issue equality, and `toTransport()` never formats messages.

## Translate rules {#custom-rules}

`checkFields()` uses its `name` as the translation key. Extend a catalog with that code, as with any built-in check. An explicit `AcanthisRule` has a scheduling ID separate from the codes it returns. See [cross-field messages](/contextual-rules#localize-custom-rule-messages).

Compare codes using `AcanthisIssueCodes` constants or your application strings. Keep issue parameters limited to shareable constraints; dates become ISO strings and durations become microseconds.
