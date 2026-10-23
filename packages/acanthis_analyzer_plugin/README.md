# Acanthis analyzer plugin

Uses the native Dart `analysis_server_plugin` lifecycle (Dart 3.13+).
Ponytail is the development skill used to implement this package, not a Dart
dependency. Analyzer dependencies stay in this separate development package.

Enable it in a consumer's `analysis_options.yaml`, then restart the analysis
server:

```yaml
plugins:
  acanthis_analyzer_plugin:
    path: /absolute/path/to/acanthis/packages/acanthis_analyzer_plugin
```

After editing this local plugin's Dart sources, restart the IDE's Dart Analysis
Server to load the new plugin code. Existing server instances can keep running
the previously loaded plugin even when the example's source diagnostics refresh.

`lib/main.dart` exports the required `plugin` instance. It registers one warning
rule with two diagnostics, an async parse quick fix, and a DTO assist. Warnings
are enabled by default; use the plugin's `diagnostics` configuration or the
standard ignore comments to disable individual diagnostics.

* `acanthis_unknown_key`: checks `pick`, `omit`, `optionals`, and both named key
  arguments to `addFieldDependency`, against the shape at that chain position.
  After `passthrough()` (including typed passthrough), unknown-key diagnostics
  are suppressed through subsequent chains and supported final aliases.
* `acanthis_sync_parse_async_schema`: suggests `parseAsync` / `tryParseAsync`.
  Its quick fix renames the method. The caller must handle the resulting Future
  (for example, await it in an async function).

Place the cursor on a top-level schema declaration (including `final`), or select
the declaration, and invoke **Generate or sync typed schema DTO** from the IDE's
code actions/refactor menu. It is an assist, so a menu filtered to diagnostic
quick fixes will not show it. `userSchema` generates `UserDto` with a `Map<String, dynamic>`
representation, typed getters, and `implements Map<String, dynamic>`. Output
types come from the second argument of `Schema<Input, Output>`, including inherited
implementations. `optionals` makes generated getters nullable for absent keys.

The `// acanthis:begin variable` / `// acanthis:end variable` region is entirely
generator-owned and replaced on sync. Put manual code outside it. Existing
unmarked declarations with the same name are left alone. Invalid Dart field
names and names that conflict with Map members suppress the assist. The
constructor expects a map validated by the schema; unchecked maps can throw in
typed getters. Unqualified output type names must be in scope. Prefixed
`acanthis.object` calls are supported; DTO output types available only via a
prefix suppress the assist rather than generating invalid code.

## Scope and conservative bailouts

This is static literal inspection, not arbitrary Dart program evaluation.
Schemas must use string-literal map keys and literal key lists. Unknown map
spreads, collection control flow, and unknown schema transformations stop shape
inference. Final/const aliases already visited in the same library analysis
request are supported; mutable, forward, and cross-library schema aliases are
not followed. No initializer is evaluated. Async refinements are detected in
inline fluent chains and nested object/list/nullable fields (and known final
child aliases), without entering callback bodies. This does not attempt to
infer arbitrary callback, lazy schema, union, or runtime-dependent async behavior.

## Checks

From this package directory:

```sh
dart pub get
dart analyze
dart test test/plugin_test.dart
```

Run the opt-in stress test with access to the local VM service (PowerShell):

```powershell
$env:RUN_MEMORY_BENCHMARK = '1'
dart --enable-vm-service=0 test test/memory_benchmark_test.dart --reporter expanded
```

The benchmark resolves 1,000 different synthetic compilation units, invokes the
same rule registration / SDK node-dispatch / reporter lifecycle as normal
analysis, and retains one rule instance across all ten batches. Each batch
disposes its analysis context. It requests GC via `getAllocationProfile(gc: true)`
and samples live heap plus external memory and process RSS after every batch.
The final half must remain within 24 MiB of its initial post-GC live memory and
128 MiB RSS; all late heap samples must remain within 32 MiB. The generous RSS
bound accommodates allocator high-water marks and JIT activity. Failures are
regression signals; a finite plateau test cannot mathematically prove zero leaks.

## Memory audit

* The plugin has no analysis state. Rule subclasses add no fields; producer
  subclasses add no fields. The SDK necessarily holds a reporter on its rule
  base and a request context on each newly constructed correction producer.
  Only producer constructors are registered, never producer instances.
* Before registering any node listeners, a library import scan checks for
  `package:acanthis`. This costs O(import count) once per library, not per node;
  the public API has no constant-time import-membership lookup. On a miss no
  plugin AST inspection runs. Other plugins and analyzer work remain unaffected.
* Both diagnostics share the SDK's single traversal with only MethodInvocation
  and VariableDeclaration subscriptions. There are no recursive full-tree lint
  visitors. Assists walk only the requested unit, on demand.
* Visitors belong to one analysis request. Their maps contain only string symbol
  keys, integer offsets, booleans, and lists of primitive field records. No
  AST, Element, DartType, session, result, or context is stored in those maps.
* `extractFields` immediately converts resolved output types to strings and
  nullable flags. Chain stacks and type references live only during a call.
  Chain walking and nested async inspection are iterative; no recursive chain
  traversal or persistent semantic caches exist.
* Change-builder callbacks capture primitive text and ranges, and are used
  within the current request. Generated DTOs have no runtime wrapper allocation.

The native framework itself and analyzer context caches are outside this
package's ownership. The benchmark tests disposal across fresh contexts; it does
not assert that a server holding an ever-growing workspace has constant RSS.

Verified on Windows, Dart 3.13.3: 1,000 units passed. Post-GC live memory at 500 /
1,000 units was 112,295,840 / 115,395,376 bytes; RSS was 866,992,128 /
859,385,856 bytes. RSS includes the analyzer, SDK, test compiler, JIT and VM, not
just this plugin. These are observations from this run, not portable memory caps.

`example/` is a standalone consumer with the plugin enabled. Run `dart pub get`
and `dart analyze` there. Its `passthrough()` suppresses the unknown-key diagnostic
on `pick(['unknown'])`; only the intentional async-parse diagnostic is expected.
