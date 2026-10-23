# ADR 001: Shared semantics, distinct executors

**Status:** Proposed. **Findings:** F01, F02, F09, F10. **Phases:** 1, 5.

**Context:** Existing typed synchronous closures and object/list specializations are valuable. Separate overrides currently omit literal/template validation and differ in exception/collection behavior. Rule-enabled throwing execution delegates to collecting execution, so later callbacks run after a failure.

**Decision:** retain synchronous throwing, synchronous collecting, and sequential async execution. Share input conversion, shape preconditions, presence/default decisions, operation semantics, issue construction and finishing. A future helper extraction must keep user-operation order and per-field collection policy explicit. Implement a true fail-fast rule-enabled object path.

**Alternatives:** one universal `FutureOr` executor reduces textual duplication but adds mode branching and uncertain hot-path overhead; code generation adds tooling and a second implementation source; no extraction perpetuates repeated semantic fixes. None is justified before simpler correction/shared helpers.

**Consequences:** maintainability improves because semantics have named tested owners; supported check extensions retain typed callbacks. Loops still differ physically and require equivalence tests. No speedup is claimed. Helper-call/closure costs and construction allocation must be measured. Public parse names and raw success return types stay intact; correcting skipped checks and callback exception normalization changes defective behavior and needs release notes.

**Acceptance:** rejecting literal/template examples fail in all applicable modes; callback TypeError is not mislabeled as input failure; mappers/transforms execute once; specialization/ordinary-path issues, values, order, and sharing remain equivalent for unchanged behavior.
