# ADR 002: Preserve output generics and represent absent recovery

**Status:** Proposed. **Findings:** F04, F05, F06, F13. **Phases:** 2, 3; optional 6.

**Follow-up scope:** the [Zod/ArkType schema-base proposal](../zod-arktype-schema-contract.md) selects `Schema<I,O>` for the comprehensive rewrite requested after this original incremental decision. The output-only migration preference below remains the compatibility-first option for the old implementation. The decisions to preserve exact successful outputs and existing outcomes, handle absent recovery, and avoid unchecked composition remain applicable to either route.

**Context:** Output-generic schemas already type mapper/validator connections and list outputs. Sealed valid/invalid outcomes already exist, including invalid without recovery. Composites assume `.value` exists; pipelines widen successful output to nullable; typed map children are unrelated to their promised value type. Numeric fluent declarations lose static precision.

**Decision:** retain public `AcanthisType<O>` and existing outcomes. Introduce the smallest internal outcome-aware boundary needed for composites; never fabricate an output through mocks/null casts. Preserve compatible typed recovery, propagate absence when a complete parent cannot be assembled, and enforce typed-map setup/output compatibility. Fix raw numeric returns. Complete legacy pipelines first; exact `O` pipeline output is a separately versioned API decision.

**Alternatives:** `Schema<I,O>` throughout the package could constrain a single accepted input type, but coercion has heterogeneous raw inputs and current typed mappers already constrain stage connections. Globally nullable outputs weaken successful types. Removing recovery immediately breaks existing code; a new result hierarchy duplicates existing diagnostics/outcomes.

**Consequences:** maintains static successful output and closes invalid composition. Runtime unknown-input checks remain necessary; Dart cannot infer arbitrary record outputs or general union inputs. General composite invalid evaluation may allocate more outcomes, while fast valid loops should stay specialized. Migration is substantial because legacy `tryParseInternal` returns `O`; maintain a checked adapter for third-party implementations. Do not remove base `.value` during this migration.

**Acceptance:** nested invalid instance/union inputs return invalid outcomes without incidental crashes; output-typed map success is readable without deferred wrong-field casts; mapper callbacks never receive invalid recovery; compiler fixtures preserve numeric precision and identify legacy pipeline nullability explicitly.
