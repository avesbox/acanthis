# ADR 005: Acyclic libraries without changing schema identity

**Status:** Proposed. **Finding:** F14. **Phase:** 5 only after correctness stabilization.

**Context:** Internal imports of the public barrel pull integrations into schema dependencies. Static base factories reference subclasses that inherit that base; replacing barrel imports alone cannot eliminate this cycle while retaining those APIs. Results/sink/i18n also refer back to each other.

**Decision:** use one schema Dart library with implementation parts for base, built-ins, compilers and object details; keep optional audited export, bounded mocks, live sessions and schema registry as outward consumers. Diagnostics and the native legacy sink can share a library; locale resolver contracts become leaf definitions. Public `acanthis.dart` only exports. Old `src` paths remain selective export shims after moves.

**Alternatives:** deleting/deprecating static factories could break the base/concrete cycle in a future major release but offers little immediate user value. A facade/core class hierarchy complicates public class identity and custom subclasses. Ignoring all cycles leaves optional integrations coupled to parsing and makes internal visibility unclear.

**Consequences:** file decomposition can preserve private plans without exposing them. There is no additional runtime dispatch or wrapper allocation. The schema library has a broader private namespace and more parts; naming and ownership discipline are necessary. This is a medium-size mechanical migration and should not share a PR with execution semantic changes. Preserve externally used check/validator import paths too.

**Acceptance:** import graph is acyclic at Dart library level; internal code never imports the public barrel; public class identities/static factory names and supported extension imports compile; timing/semantic baselines remain equivalent for mechanical moves.
