# Localization

Diagnostics keep locale-independent codes, paths and parameters. Validation,
rule evaluation, equality, hashing and `toTransport()` never format messages.
The same result can be presented in several languages without revalidation.

```dart
final result = string().min(3).tryParse('a');
final localized = AcanthisI18n.runWith(
  AcanthisLocaleConfig.forLocale('it-IT'),
  () => result.issues.map((issue) => issue.toJson()).toList(),
);
// Message: Il valore deve contenere almeno 3 caratteri
```

`runWith` uses an isolated locale scope inherited through async continuations.
Nested scopes restore the previous locale after completion or exceptions.
`configure(config)` sets isolate-wide startup defaults and returns the previous
configuration for resetting; use `runWith` for concurrent requests.

English and Italian cover the complete built-in code vocabulary, including date
bounds/differences, literal values, imported contracts and legacy code constants.
Date bounds use the configured ISO 8601 string; durations use microseconds, as in
transport parameters. Formatting a relative-date issue says "now" without
reading the clock again or rerunning validation. Unknown application codes still
need application translations.

Locale matching is case-insensitive, accepts `_` or `-`, and falls back from a
region to its base language. Supply partial catalogs for application overrides:

```dart
final config = AcanthisLocaleConfig.forLocale('it-CH', overrides: {
  'it': AcanthisMessageCatalog({
    'minLength': (p) => 'Almeno ${p['value']} caratteri',
  }),
  'it-CH': AcanthisMessageCatalog({'required': (_) => 'Campo obbligatorio'}),
});
final fields = AcanthisI18n.runWith(config, () => result.issues.formatFields());
```

`AcanthisMessageCatalogs.forLocale(locale, overrides: ...)` returns the same
resolved catalog without configuring a scope. Lookup tries the exact locale,
then its base-language override, then the bundled language. Each override's own
fallback is preserved. A formatter returning null continues lookup; an empty
string is a valid translation. The overrides map is snapshotted and catalog
lookup invokes no formatters. Other languages can be supplied through overrides;
missing translations in an active scope retain schema/English fallback.

Extend a catalog to translate application rule codes:

```dart
final italian = AcanthisMessageCatalogs.italian.extend({
  'passwordMismatch': (_) => 'Le password non corrispondono',
});
final config = AcanthisLocaleConfig(locale: 'it', catalog: italian);
```

Message precedence is an explicit `formatMessage(catalog:)` / `toJson(catalog:)`
catalog, otherwise the active locale, the issue's schema catalog, then English.
Explicit catalogs preserve the existing replacement behavior: unknown codes
render as their code unless the supplied catalog configures a fallback.
`resolve(code, parameters)` returns null for a missing or declined translation,
while `format` returns the code as its final fallback.

Messages are resolved at presentation time. Format a caught `ValidationError`
inside the desired locale scope, or format its issues with an explicit catalog;
the exception does not capture a request's locale or context.

See `example/localization.dart` for a runnable example using date diagnostics,
regional overrides and field formatting.
