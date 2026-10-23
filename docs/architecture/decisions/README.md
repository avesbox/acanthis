# Architecture Decision Records

All records here are **proposed**, pending implementation review. They complement the existing native-issues, presence, and audited-export decisions under [`doc/decisions`](../../../doc/decisions); those decisions remain the established baseline. Numbering is local to this architecture proposal.

| ADR | Decision |
| --- | --- |
| [001](001-shared-semantics-distinct-executors.md) | Shared semantics with distinct sync/async and throwing/collecting executors |
| [002](002-output-types-and-recovery.md) | Preserve output generics; make recovery absence composable |
| [003](003-immutable-definitions.md) | Freeze definition containers and centralize typed family-local copying |
| [004](004-independent-capabilities.md) | Keep independent integration adapters; reject opaque semantics |
| [005](005-library-boundaries.md) | Acyclic library boundaries with compatible schema identity and factories |
| [006](006-lazy-binding.md) | Treat lazy parent binding and async eligibility as explicit contracts |
