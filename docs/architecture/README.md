# Architecture review and refactoring proposal

Reviewed on **2026-10-13**, against the actual working tree based on commit `517d2a6eb8ff66fcfc6d7932dea0cf7e6b332276` (package version 2.1.0, Dart 3.13.3). This checkout already contained substantial tracked and untracked changes. Those files, rather than the commit alone or older design documents, are the source of truth. No library, existing test, dependency, or benchmark implementation was changed for this review.

**Recommendation:** repair execution and composition contracts incrementally. Preserve the output-generic fluent API, native issues, compiled synchronous operations, object specialization, and live revision machinery. A replacement engine, universal schema AST, and package-wide input/output generic migration are not justified by this assessment.

| Document | Purpose |
| --- | --- |
| [Current architecture](current-architecture.md) | Implementation map, lifecycle, strengths, and extension change surface |
| [Architectural findings](architectural-findings.md) | Ranked, source-backed defects and risks, with reproduced counterexamples |
| [Proposed architecture](proposed-architecture.md) | Contracts, responsibility boundaries, dependency diagram, directory layout, and alternatives |
| [Type safety](type-safety-analysis.md) | Actual Dart guarantees, inference limits, checked boundaries, and compatibility choices |
| [Performance and testing](performance-and-testing.md) | Baseline, existing coverage, missing tests, and measurement gates |
| [Migration roadmap](migration-roadmap.md) | Ordered implementation phases, acceptance criteria, compatibility, and rollback |
| [Internal rewrite alternative](internal-rewrite-proposal.md) | Follow-up design for replacing internal orchestration while retaining the fluent API and proven execution kernels |
| [Zod/ArkType and Schema base](zod-arktype-schema-contract.md) | Researched follow-up selecting an extensible `Schema<I,O>` base, its four methods, Dart type limits and compatibility choices |
| [Decisions](decisions/README.md) | Proposed ADRs and relationships to existing decisions |
| [Evidence](evidence/README.md) | Reproducible probes, raw benchmark samples, and source fingerprints |

The findings distinguish **confirmed defects**, **architectural risks**, and **optional enhancements**. P0 means a correctness problem, unsafe schema contract, or blocker under the requested review rubric; it does not imply every user encounters the defect or that this is a security severity classification. Passing tests and clean analysis do not prove coverage of unsupported fluent combinations.

Baseline: **583 tests passed**, analyzer reported **no issues** and completed successfully after a sandbox telemetry retry; all three existing negative registry fixtures and the AOT cross-module registry example passed their checks. Fresh JIT and AOT lifecycle benchmarks completed, plus JIT error-contract and selected-rule/live benchmarks. Allocation totals remain unavailable; these measurements establish observations, not refactor speedup claims.

Implementation readiness: start with phase 0 in [the roadmap](migration-roadmap.md). Changes to nullable pipeline output types and removal of legacy recovery access require separate compatibility decisions; neither is a prerequisite for fixing skipped validation.

The follow-up [internal rewrite proposal](internal-rewrite-proposal.md) evaluates a broader replacement of definitions and orchestration under explicit API and execution-continuity constraints. It is a distinct architectural alternative with feasibility gates; the original review evidence and proposed incremental roadmap remain available for comparison. No rewrite has been implemented.

The subsequent [Zod/ArkType comparison](zod-arktype-schema-contract.md) refines the rewrite target to an extensible `Schema<I,O>` base with shared parsing methods. The original output-only recommendation remains the compatibility-first alternative for patching the old implementation. The implementation has since been moved to `v1/lib`; original source links and baseline records describe their paths at review time. The empty current root library was not changed by this documentation work.
