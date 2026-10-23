# ADR 006: Explicit lazy binding and async eligibility

**Status:** Proposed; capability propagation strategy requires a phase 3 prototype. **Finding:** F03. **Phase:** 3 after outcome-aware composition.

**Context:** `LazyEntry` resolves against a parent object, discards its own stored operations, and advertises an async flag independent of its resolved descendants. Resolving recursively to inspect flags can recurse through parents or execute user callbacks repeatedly. An unbound lazy schema cannot fulfill ordinary standalone parse calls safely.

**Decision:** make parent binding an internal definition operation, retaining wrapper operations and a stable resolver identity. Determine async eligibility before sync execution can ignore any async check; an unresolved or inconsistent capability must produce a clear restriction rather than silently accepting input. Keep parent-dependent lazy public APIs as compatibility adapters; do not generalize them into standalone recursive schemas during this refactor.

**Alternatives:** repeatedly resolving on every check adds side effects/cost and does not solve recursive capabilities; trusting the current false flag is incorrect; always marking lazy async breaks existing synchronous recursive schemas. A bound graph with cycle-aware capability propagation is strongest but more complex. An explicit async declaration plus validation of inconsistent resolutions can be an initial compatibility solution, provided limitations are documented and tested.

**Consequences:** fixes skipped operations and async validation while preserving recursion. Binding adds construction/first-use work and requires cycle handling. Cache only definition-derived resolution, never input validation outcomes. Stable identity also helps the existing audited exporter; rebuilding parent schemas remains outside its bounded contract. Public unbound/unsupported operations need descriptive errors or a future capability-specific API.

**Acceptance:** attached lazy checks/transforms execute exactly once; hidden async descendants cannot succeed through sync validation; direct/mutual recursive test schemas resolve without unbounded setup recursion; parse and export retain stable behavior. Choose the propagation algorithm only after prototype and construction/warmed measurements; this ADR does not assert a graph algorithm has already been implemented or benchmarked.
