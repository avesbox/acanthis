# ADR 003: Immutable definition containers and reliable copying

**Status:** Proposed. **Findings:** F07, F08. **Phases:** 1, 4.

**Context:** Base operation lists, issues, rules, and registry bindings already snapshot their containers. Object/tuple/enum constructors retain aliases; object key caches can disagree with public fields/export. Manually forwarding configuration loses tuple variadic state, instance references, and metadata.

**Decision:** shallow-snapshot schema and check definition collections and expose unmodifiable containers. Centralize typed family-local copying with unchanged-by-default settings. Preserve a distinct typed presence marker for explicit-null defaults. Consider a shared immutable object definition only after construction cost is measured.

**Alternatives:** deep-freezing every object would change DTO/default ownership and cannot freeze callback state. A universal configuration map loses typing. A copy-generation dependency increases tool/dependency cost without a concrete need. Continuing manual copies leaves every new flag vulnerable to omissions.

**Consequences:** deterministic schema caches and smaller change surface; adding a setting should require updating one family's definition/copy path and its matrix tests. O(n) copies increase construction work, mitigated by immutable sharing where useful. Validation must not deep-copy pure input or alter existing identity/mutability guarantees. Caller mutation after schema construction intentionally stops affecting validation; document that compatibility correction.

**Acceptance:** caller mutations cannot change a built schema or its async eligibility/export; all fluent copies preserve unrelated configuration; input-sharing and builder snapshot tests remain green. No unmeasured claim that added configuration objects are allocation-free.
