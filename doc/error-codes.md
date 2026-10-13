# Error-code contract and migration

Implemented for the working tree's `2.1.0` release, verified 2026-10-13. The original investigation is retained
in [error-codes-analysis.md](error-codes-analysis.md). This is the current contract.

## Stable codes and paths

`AcanthisIssueCodes` exports typed `String` constants for every built-in code;
`doubleType` represents the wire code `double`. `values` is the complete set.
Codes remain open strings. Use `app.*` or an organization prefix for application
rules; unprefixed names and `acanthis.*` are reserved for the library. No global
registration is needed or enforced.

Code meaning, parameter keys/types/units, string-versus-integer path segments,
duplicate retention, and declaration/union-branch order are compatibility
commitments. English wording is a fallback, not an identifier. Do not branch on
message text or the lossy legacy `errors` map. Unknown application codes survive
formatting and transport unchanged.

Paths identify submitted data, never checks or registry IDs. Union branch paths
are absolute from the root. A pointer escapes `~` and `/`, but the segment list
is authoritative: string property `'0'` and list index `0` are distinct.
Missing required object fields can synthesize check diagnostics without running
their predicates. Such issues describe constraints, not proof of execution.

## Presentation

Messages remain required and non-null. Resolver precedence is explicit resolver,
then scoped resolver or isolate-local default, then stored message. An explicit
resolver returning null falls directly back to the stored message; an empty
string is a valid resolution. Resolver exceptions propagate. A scope with a
null resolver suppresses the default resolver.

`AcanthisI18n.runWith` isolates concurrent asynchronous requests and restores
nested scopes on success or failure. Use `configure` for startup defaults only;
new isolates have independent defaults. English/Italian catalogs normalize locale
tags and support exact override, base-language override, then bundled fallback.
Unknown codes and malformed required parameters return null. These catalogs do
not provide general plural/date/number formatting.

```dart
final schema = string().min(3);
final issues = schema.tryParse('x').issues;
final english = issues.formatFields(resolver: AcanthisMessageCatalogs.english);
final italian = issues.formatFields(resolver: AcanthisMessageCatalogs.italian);
// Both render the same issues without rerunning validation.
```

## Locale-independent transport, version 1

Use `issues.toTransport()` to produce `{version: 1, issues: [...]}`. Each node
contains `code`, segment `path`, `parameters`, and optional ordered `branches`.
`issue.toTransport()` produces one unversioned node for that envelope. Messages,
recovery values, and submitted input are not automatically included. Existing
`toJson`/`formatJson` retain resolved messages and their existing field names.

```dart
final result = object({'email': string().min(3)}).tryParse({'email': 'x'});
final payload = result.issues.toTransport();
// {version: 1, issues: [{path: [email], code: minLength,
//                       parameters: {value: 3}}]}
```

Always JSON-encode the envelope at the boundary. Clients reject unknown envelope
versions or explicitly negotiate them. Custom parameters must contain constraints,
not credentials or submitted values: transport cannot redact secrets supplied by
application callbacks. It is not a codec for arbitrary Dart objects and does not
provide `AcanthisIssue.fromJson`.

Parameter containers are copied into immutable JSON-safe data. Dates become ISO
text, durations become integer microseconds, enum members become names, regexes
become patterns, and non-finite doubles become strings. Unsupported objects use
`<runtimeType>` labels, which are neither stable domain identities nor reversible
serialization. Traversal uses identity-based cycle detection, depth 32, at most
1,024 iterable elements/map entries, and a 4,096-node budget per parameter value.
Limit markers are `<cycle>`, `<max-depth>`, `<truncated>`, `<truncated-map>`, and
`<max-nodes>`. Repeated acyclic references are allowed within those bounds.
Custom iterators/getters can still throw; this is not a sandbox for arbitrary code.

## Migration from 2.0

The working tree and changelog select 2.1.0 and explicitly label these changes
as breaking. They are not source/behavior compatible with all 2.0 consumers;
applications must account for the following changes when upgrading:

- Invalid input conversions in throwing parsers now raise `ValidationError`
  with code `type` (or the existing specialized code). `validate` returns the
  resolved message instead of leaking the conversion's `TypeError`. Update
  catches to inspect `error.issue`. This does not normalize all application
  exceptions: throwing-parser transformation failures still propagate; legacy
  collecting hooks and custom refinements retain their exception handling.
- Instance fields run their complete child schema, including nested validation,
  child transformations and async children. The getter runs once per field and
  the original instance is returned; transformed field values are not assigned
  back to it. Replace root codes such as `email.minLength` with path `['email']`
  and code `minLength`. Parameters and union branches are preserved. Optional
  fields skip null getters. Defaults remain unsuccessful recovery on failure.
- Typed passthrough assignment failures use `passthrough` in both throwing and
  collecting modes. Child validator failures retain their own codes.
- Enum-string issues retain `enumValues` for compatibility and add `values` with
  the accepted, transformed names. Catalogs also accept old enum-only payloads.
  Name transformers should be pure; diagnostic construction may call them.
- `everyOf` now says that input elements must belong to the allowed list. It
  does not require every allowed value to appear. Oversized/cyclic custom
  metadata is represented by the documented markers.

## Built-in vocabulary and parameter schemas

Constraints are frozen as described above; `{}` means no parameters. Unless
explicitly stated, failures retain the path of the value being checked.

| Family / codes | Failure condition and parameters |
| --- | --- |
| String `minLength`, `maxLength`, `exactLength` | UTF-16 length below, above, or unequal to bound; `{value}` |
| String `email` | `EmailValidator.validate` false; `{}` |
| String `uri` | `Uri.tryParse` returns null; relative URIs may pass; `{}` |
| String `url` | Empty, unparsable, no scheme, or empty host; `{}` |
| String `uncompromised` | Password hash suffix found in remote range response; `{}`; asynchronous, network failures can throw |
| String `letters`, `digits`, `alphanumeric`, `alphanumericWithSpaces`, `specialCharacters`, `allCharacters` | Respective regex does not match; `{strict}` selects pattern behavior |
| String `cuid`, `cuid2`, `ulid`, `uuid`, `nanoid`, `jwt`, `base64`, `time` | Respective built-in regex does not match; `{}`; these are pattern checks, not semantic/security verification |
| String `hexColor` | Not seven characters starting with `#` followed by hex digits; `{}` |
| String `enumerated` (enum API) | No enum name, optionally transformed by `nameTransformer`, matches; `{enumValues, values}`: original enum names plus accepted transformed names |
| String `enumerated` (contained API) | Not a member of supplied strings; `{values}` |
| String `required`, `notEmpty` | Empty string; `{}`; distinct operations with equivalent predicates |
| String `contains`, `startsWith`, `endsWith` | Missing substring, prefix, suffix respectively; `{value}` |
| String `card` | After removing non-digits, length outside 13–19 or Luhn failure; `{}` |
| String `upperCase`, `lowerCase`, `mixedCase` | Not equal to uppercase/lowercase form, or equal to either form for mixed-case check; `{}` |
| String `dateTime` | `DateTime.tryParse` null; `{}` |
| String `pattern` | Pattern does not match; `{regExp}`; regex stored as its pattern text |
| Number `lte`, `gte`, `gt`, `lt` | Fails corresponding comparison; `{value}` |
| Number `between` | Outside inclusive bounds; `{min, max}` |
| Number `positive`, `negative`, `nonpositive`, `nonnegative` | Fails `> 0`, `< 0`, `<= 0`, `>= 0` respectively; `{}` |
| Number `multipleOf` | Remainder is nonzero; `{value}` |
| Number `integer`, `double` | `integer` requires Dart `int`; `double` rejects `int`; `{}`; representation checks, not JSON mathematical-integer semantics |
| Number `finite`, `infinite`, `nan`, `notNaN` | Fails corresponding numeric predicate; `{}` |
| Number `enumerated` | Not in allowed numeric values; `{values}` |
| Boolean `isTrue`, `isFalse` | Opposite boolean; `{}` |
| Common `exact` | Dart equality with constraint fails; `{value}` |
| List `minItems`, `maxItems`, `length` | Below minimum, above maximum, or unequal length; `{minItems}`, `{maxItems}`, `{length}` respectively |
| List `uniqueItems` | `toSet()` reduces length; Dart equality; `{}` |
| List `contains` | Missing item; `{item}` |
| List `anyOf` | No input element belongs to allowed list; `{items}` |
| List `everyOf` | Some input element is outside allowed list; `{items}`; does not require every allowed item to occur |
| Map `minProperties`, `maxProperties`, `lengthProperties` | Wrong property count; `{constraintValue}` |
| Date `min`, `max` | Earlier/later than inclusive bound; `{value}` as ISO string |
| Date `differsFromNow`, `differsFrom` | Absolute time difference less than threshold; `{difference}` in microseconds, plus `{fromDate}` ISO string for explicit origin |
| Nullable `enumerated` | Non-null value outside allowed list; `{values}` includes the accepted null; null passes |
| Structural `type` | Wrong runtime input type or failed scalar coercion; usually `{}`, no uniform `expected`/`received` fields |
| Structural `date` | Date input cannot be converted/parsed; `{}` |
| Structural `required` | Missing required map field; `{}` and field path; collection may additionally emit that field's check codes without running their predicates |
| Structural `unknownKey` | Extra key in strict object; `{}` and extra-key path |
| Structural `passthrough` | Extra value cannot satisfy map value type; `{}` and extra-key path |
| Structural `dependency` | Pairwise dependency fails or an input is unavailable; `{dependsOn}` and dependent path |
| Structural `literal` | Value unequal to literal; `{expected}`; wrong type can produce `type` first |
| Structural `templateLiteral` | Template regex mismatch; `{pattern}`; wrong input type produces `type` |
| Structural `tuple` | Fixed tuple length mismatch; `{length}`; children retain index paths |
| Structural `union` | No branch succeeds; `{}`, with ordered branch issues |
| Structural `variantGuard` | Guard did not select the variant; `{name}`, recorded in union branch diagnostics |
| Structural `transform` | Pipeline converter throws; `{}`; throwing fallback can include exception text |
| Instance fields | Complete child-schema validation; original code/parameters and branches, prefixed with the field name |
| Custom `custom` or supplied name/code | Empty check name uses `custom`; refinements use supplied names and parameters; selected-field rules return caller-created issues with declared output paths |

## Verification and integrations

The producer matrix is in [error_code_inventory_test.dart](../test/error_code_inventory_test.dart);
structural and deterministic HTTP-backed async fixtures are in
[error_structural_producers_test.dart](../test/error_structural_producers_test.dart).
[error_contract_test.dart](../test/error_contract_test.dart) verifies metadata,
instance execution, bounded transport and localization scopes. Existing suites
cover defaults, collection policies, duplicate branches and live revisions.

Final package verification on 2026-10-13: 583 tests passed and static analysis
reported no issues. The documentation site also builds successfully.

[Integration instructions](../integration/README.md) include a real Flutter
field and a Serinus HTTP endpoint consumed by Node. Serinus 2.1.12 requires the
documented integration-only Dart 3.13 compilation workaround; this is not a claim
that the unmodified published dependency passes. See
[JIT/AOT evidence](../benchmark/error-contract/README.md) for measured costs and
comparison with the existing rules/live baseline.

