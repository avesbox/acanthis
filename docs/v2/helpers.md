# Public helpers

`AcanthisIssueCodes` provides the stable built-in string constants and a const
`values` set. V1 names and values remain available, including legacy vocabulary
that a current validator may no longer emit. V2 adds `containsItem`,
`duplicateKey`, `jsonSchemaFalse` (`jsonSchema.false`) and `jsonSchemaNot`
(`jsonSchema.not`). These do not rename existing codes. Custom application
codes remain open strings; use a namespace such as `app.*`.

```dart
if (issue.code == AcanthisIssueCodes.required) {
  // Display the field's required-value hint.
}
```

`schema.toPrettyJsonSchema(indent: 2, mode: AcanthisSchemaMode.input)` formats
the same result as `toJsonSchema`. Indentation is a nonnegative number of spaces;
the default is two. Mode defaults to input, matching `toJsonSchema`, and output
mode is supported. Strict export errors and callback-free auditing are unchanged.
This is a formatting helper, not a second exporter.

`AcanthisIssueFormatting` adds presentation methods to any
`Iterable<AcanthisIssue>`:

```dart
final issues = string().min(3).min(5).tryParse('x').issues;
final catalog = AcanthisMessageCatalogs.italian;
final fields = issues.formatFields(catalog: catalog);
final tree = issues.formatTree(catalog: catalog);
final json = issues.formatJson(catalog: catalog);
final transport = issues.toTransport();
```

Field maps group every message by JSON pointer. `AcanthisIssueTree` has `messages`
at each node and `children` keyed by the original string or integer segment.
Root messages use the empty pointer or the root tree's messages. Duplicates keep
their emission order. Field/tree views show union summaries; JSON and transport
retain nested branches. Returned maps and trees can be edited independently of
the immutable issues.

`formatJson` serializes the ordered issue records with localized messages.
`toTransport` returns `{version: 1, issues: [...]}` and never formats messages or
includes recovery values. Presentation methods accept V2's `catalog:` parameter
and inherit the existing locale/catalog precedence. Formatting never reruns
validation. See `example/issue_formatting.dart` for a complete example.
