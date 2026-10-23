# ADR 004: Independent adapters and explicit unsupported semantics

**Status:** Proposed. **Findings:** F06, F11, F12, F14, F15. **Phases:** 1, 3, 5; optional 6.

**Context:** Audited export and bounded generation already exist as independent services. Legacy base requirements force every custom schema to implement mocks and exporters. The audited exporter trusts custom schema inheritance, while generation misses selected-rule callbacks. Exact export/generation cannot be promised for arbitrary runtime functions.

**Decision:** keep independent services, explicit per-call state/budgets, and descriptive unsupported errors. Audited built-ins require trusted exact implementations; opaque subclasses and selected-rule generation are rejected unless an explicit supported capability is provided. Validation recovery must not call a generator. Add a typed custom capability/caller-owned adapter only for a concrete extension use case, not a universal registry now.

**Alternatives:** a mandatory visitor centralizes dispatch but makes each new schema/visitor coordinate more interfaces; a universal AST adds allocations and a second representation; a global heterogeneous callback registry adds hidden ordering/casts/state. Existing switches remain a reasonable small-team tradeoff for two bounded adapters.

**Consequences:** no integration tax in parse hot paths; custom validation can remain independent. Built-in integration support still needs adapter-specific edits, an explicit limitation rather than an extensibility claim. Legacy abstract integration members remain until a major validation-only contract change; unsupported legacy pipeline methods receive a deliberate documented behavior. Rejecting previously inaccurate exports is a compatibility correction, not a promise to export all schemas.

**Acceptance:** opaque callbacks are never executed during rejected seeded mocking; audited export rejects untrusted subclasses, retains input/output modes and local recursion state, and passes independent validators for its supported corpus when available. Native diagnostics are reused rather than mapped to a parallel issue model.
