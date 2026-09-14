# Selected-field rules before incremental scheduling

Design date: 2026-09-12. Proposal only; the APIs below are not implemented.
No live-session scheduling changes are part of this design.

## Problem and existing behavior

`addFieldDependency` accepts two string queries and a callback over raw values.
It does not distinguish absent from null or gate the callback on selected field
validity. Object refinements likewise do not declare field dependencies. Live
sessions consequently revalidate the complete object for either kind of rule.
Keep these existing APIs' semantics; add an explicit rule abstraction.

## Proposed execution contract

A rule declares a stable unique ID, immutable input paths, allowed issue paths,
an execution policy, and a callback. Paths reuse the string/integer data-only
contract. Reject duplicate IDs and reads/writes outside declared paths. Report
unknown static fields during schema construction; resolve dynamic list indices
at validation time, where an absent index is missing rather than null.

Store a field snapshot with explicit `missing`, `invalid`, `pending`, or
`valid(value)` state. A valid nullable field can contain null; a missing optional
field is still missing. Never provide a recovery value as a valid rule input.
Provide presence from the original input separately from the parsed result so
defaults do not erase the ability to ask whether a value was submitted.

Validate children once, retaining their parsed values and field states. Run
selected-field rules after child validation and before whole-object transforms
or refinements. Field transforms run once; callbacks consume parsed values.
Ordinary rules run only when all selected inputs are valid, regardless of errors
on unrelated fields. Presence rules may inspect missing states explicitly.
Invalid or pending prerequisites skip the rule; a skip is not a successful
evaluation. Preserve declaration order in diagnostics, even if future execution
becomes concurrent. Rule errors do not feed other rules in the first version;
this avoids cycles and declaration-order-dependent eligibility.

Callbacks return issues rather than mutate the object. Rule identity is separate
from public issue code: two rules can report `required` at the same path without
losing independent invalidation. Store ownership internally. Parameters contain
constraints or rule IDs, never passwords or raw field values. Callback exceptions
propagate as application errors in this new API; do not silently translate
programming failures into user validation failures.

## Password confirmation

Proposed declaration (pseudocode):

```text
id: passwordConfirmation
reads: [password], [confirmPassword]
writes: [confirmPassword]
when: allSelectedValid
check: password == confirmPassword
issue: code=passwordMismatch, message="Passwords do not match"
```

Neither password is trimmed implicitly. Any normalization must be explicitly
declared in its field schema. Password values never enter issue parameters.

| Scenario | Expected behavior |
| --- | --- |
| Valid equal passwords | Run once; no rule issue |
| Valid unequal passwords, valid email | One mismatch at confirmPassword |
| Valid unequal passwords, invalid email | Email issue plus the same mismatch |
| Invalid password type or failed password constraint | Skip comparison; retain field issues |
| Invalid confirmation | Skip comparison; retain confirmation issue |
| Pending async password check | Pending rule; do not compare a recovery/stale value |
| Input field transformation | Compare parsed values; transformation runs once |

## Conditional required field

Use `accountType` with a constrained set of tags and an optional, non-nullable
`businessId` string whose own schema checks non-empty content. Proposed rule:

```text
id: businessIdRequired
reads: [accountType], [businessId]
writes: [businessId]
when: accountType is valid; inspect businessId presence
check: if accountType == "business" and businessId is missing, emit required
```

This rule needs presence access; forcing all inputs to be present and valid would
prevent it from ever reporting a missing required field.

| Scenario | Expected behavior |
| --- | --- |
| Business account, absent businessId | Emit required at businessId |
| Personal account, absent businessId | No rule issue; preserve omission |
| Business account, explicit null | Field type issue; no duplicate required issue |
| Business account, empty string | Field min-length issue; no duplicate required issue |
| Business account, valid ID, invalid unrelated email | No rule issue; retain email issue |
| Invalid/missing accountType | Skip conditional rule; retain accountType issue |
| Business becomes personal while ID remains absent | Remove only this rule's required issue |
| Defaulted businessId | Use declared policy: this rule tests submitted presence, so still required |

An application that accepts defaulted presence should explicitly test effective
presence instead. That choice must not be inferred from whether a map contains
a recovery value.

## Reference evaluator and later live integration

Implement full-object evaluation and the truth tables first. Verify sync and
async parity with controlled futures, rule invocation counts, exception
propagation, multiple issues at one path, and unrelated invalid fields.
Require successful regression tests before exposing incremental execution.

Later, index rule input paths by rule ID. A change affects paths that are equal,
ancestors, or descendants, including removals and batch updates. Revalidate
affected fields and dependent rules once per revision; replace issues by owner,
not merely path/code. Clear old rule issues when eligibility is lost and expose
pending state. Revisions prevent stale async completion from publishing; optional
cooperative cancellation saves work but does not replace revision checks.

Unknown dependencies and arbitrary object operations continue to force full
validation. A settled incremental result must equal the reference evaluator's
ordered issues and parsed output for that revision. Context changes invalidate
rules declaring that context dependency. No automatic dependency discovery,
rule-to-rule dependencies, or parallel execution is required for the first API.
