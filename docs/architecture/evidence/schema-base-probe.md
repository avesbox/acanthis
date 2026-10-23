# Schema base compiler experiment

Design-only experiment executed on Dart 3.13.3. Root `lib` was empty and the prior implementation was under `v1/lib`; a temporary copy of `.dart_tool/package_config.json` was written as `.dart_tool/schema-base-package-config.json`, resolving all package roots absolutely and pointing only `acanthis` at the existing `v1/` directory. No production source, original package configuration or dependency was changed.

The experiment uses constructor-supplied typed executors to implement the four methods once. It tests an input/output base, not the complete proposed fluent library. `compose` is deliberately naive to expose Dart covariance; `mapOutput` is a compiler helper, not a proposed rename of `.pipe` or `.transform`. The alias is a reduced compatibility experiment, not proof that the old base can be replaced transparently.

## Source

```dart
import 'package:acanthis/acanthis.dart';
import 'package:meta/meta.dart';

// Design experiment only. Production classes and exports are unchanged.
abstract class Schema<I, O> {
  Schema({
    required O Function(Object?) parseSync,
    required AcanthisOutcome<O> Function(Object?) collectSync,
    Future<O> Function(Object?)? parseAsync,
    Future<AcanthisOutcome<O>> Function(Object?)? collectAsync,
  }) : _parseSync = parseSync,
       _collectSync = collectSync,
       _parseAsync = parseAsync,
       _collectAsync = collectAsync {
    if ((_parseAsync == null) != (_collectAsync == null)) {
      throw ArgumentError('Async throwing and collecting executors must be paired');
    }
  }

  final O Function(Object?) _parseSync;
  final AcanthisOutcome<O> Function(Object?) _collectSync;
  final Future<O> Function(Object?)? _parseAsync;
  final Future<AcanthisOutcome<O>> Function(Object?)? _collectAsync;

  bool get isAsync => _parseAsync != null;
  Type get inputType => I;
  Type get outputType => O;

  void _requireSync() {
    if (isAsync) throw AsyncValidationException('Use an async parse method');
  }

  @nonVirtual
  O parse(Object? input) {
    _requireSync();
    return _parseSync(input);
  }

  @nonVirtual
  AcanthisOutcome<O> tryParse(Object? input) {
    _requireSync();
    return _collectSync(input);
  }

  @nonVirtual
  Future<O> parseAsync(Object? input) {
    final execute = _parseAsync;
    return execute == null
        ? Future<O>.sync(() => _parseSync(input))
        : Future<O>.sync(() => execute(input));
  }

  @nonVirtual
  Future<AcanthisOutcome<O>> tryParseAsync(Object? input) {
    final execute = _collectAsync;
    return execute == null
        ? Future<AcanthisOutcome<O>>.sync(() => _collectSync(input))
        : Future<AcanthisOutcome<O>>.sync(() => execute(input));
  }
}

class DemoSchema<I, O> extends Schema<I, O> {
  DemoSchema({required super.parseSync, required super.collectSync,
    super.parseAsync, super.collectAsync});
}

Schema<I, N> mapOutput<I, O, N>(Schema<I, O> first, N Function(O) transform) {
  N throwing(Object? input) => transform(first.parse(input));
  AcanthisOutcome<N> collecting(Object? input) => switch (first.tryParse(input)) {
    AcanthisValid<O>(:final value) => AcanthisValid(transform(value)),
    AcanthisInvalid<O>(:final issues) => AcanthisInvalid<N>.withoutValue(issues),
  };
  Future<N> throwingAsync(Object? input) async => transform(await first.parseAsync(input));
  Future<AcanthisOutcome<N>> collectingAsync(Object? input) async => switch (await first.tryParseAsync(input)) {
    AcanthisValid<O>(:final value) => AcanthisValid(transform(value)),
    AcanthisInvalid<O>(:final issues) => AcanthisInvalid<N>.withoutValue(issues),
  };
  return DemoSchema<I, N>(parseSync: throwing, collectSync: collecting,
    parseAsync: first.isAsync ? throwingAsync : null,
    collectAsync: first.isAsync ? collectingAsync : null);
}

typedef LegacySchema<O> = Schema<Object?, O>;
class LegacySubclass extends LegacySchema<String> {
  LegacySubclass() : super(parseSync: string().parse, collectSync: string().tryParse);
}

// Deliberately naive signature: the probe below demonstrates its variance limit.
Schema<I, N> compose<I, O, N>(Schema<I, O> first, Schema<O, N> next) {
  O runFirst(Object? input) => first.parse(input);
  N throwing(Object? input) => next.parse(runFirst(input));
  AcanthisOutcome<N> collecting(Object? input) {
    final previous = first.tryParse(input);
    return switch (previous) {
      AcanthisValid<O>(:final value) => next.tryParse(value),
      AcanthisInvalid<O>(:final issues) => AcanthisInvalid<N>.withoutValue(issues),
    };
  }
  Future<N> throwingAsync(Object? input) async =>
      next.parseAsync(await first.parseAsync(input));
  Future<AcanthisOutcome<N>> collectingAsync(Object? input) async {
    final previous = await first.tryParseAsync(input);
    return switch (previous) {
      AcanthisValid<O>(:final value) => next.tryParseAsync(value),
      AcanthisInvalid<O>(:final issues) => AcanthisInvalid<N>.withoutValue(issues),
    };
  }
  final async = first.isAsync || next.isAsync;
  return DemoSchema<I, N>(parseSync: throwing, collectSync: collecting,
    parseAsync: async ? throwingAsync : null,
    collectAsync: async ? collectingAsync : null);
}

Future<void> main() async {
  final source = string().min(2);
  final text = DemoSchema<String, String>(
    parseSync: source.parse, collectSync: source.tryParse);
  final Schema<Object?, String> widened = text;
  print('Unknown boundary rejects wrong input through diagnostics: ${!widened.tryParse(42).isValid}');
  print('Sync schema async output: ${await text.parseAsync("ok")}');
  print('Sync schema async collecting output: ${(await text.tryParseAsync("ok")).value}');

  final legacyAsync = string().refineAsync(onCheck: (_) async => false,
    error: 'remote rejection', name: 'remote');
  final remote = DemoSchema<String, String>(parseSync: source.parse,
    collectSync: source.tryParse, parseAsync: legacyAsync.parseAsync,
    collectAsync: legacyAsync.tryParseAsync);
  try { remote.parse('ok'); } on AsyncValidationException {
    print('Async schema sync parse rejects: true');
  }
  print('Actual async rejection: ${!(await remote.tryParseAsync("ok")).isValid}');

  var called = 0;
  final mapped = DemoSchema<String, int>(
    parseSync: (v) { called++; return (v as String).length; },
    collectSync: (v) { called++; return AcanthisValid((v as String).length); });
  final Schema<String, int> pipeline = compose(text, mapped);
  final invalid = pipeline.tryParse('x');
  print('Invalid input skips next stage: ${!invalid.isValid && called == 0}');
  final int exact = pipeline.parse('okay');
  print('Exact nonnullable pipeline output: $exact');
  final Schema<String, int> mappedOutput = mapOutput(text, (s) => s.length);
  final LegacySchema<int> legacyView = mappedOutput;
  print('Input/output mapping and output-only alias: ${legacyView.parse("okay") == 4 && LegacySubclass().parse("ok") == "ok"}');

  final numberSource = number();
  final producer = DemoSchema<Object?, num>(parseSync: numberSource.parse,
    collectSync: numberSource.tryParse);
  final integerTarget = integer().pipe(string(), transform: (v) => v.toString());
  final onlyInt = DemoSchema<int, String>(
    parseSync: (v) => integerTarget.parse(v)!,
    collectSync: (v) {
      final r = integerTarget.tryParse(v);
      return r is AcanthisValid<String?>
          ? AcanthisValid(r.value!)
          : AcanthisInvalid<String>.withoutValue(r.issues);
    });
  final Schema<Object?, String> unsafeStaticComposition = compose(producer, onlyInt);
  print('Narrower-input composition compiles but needs runtime validation: ${!unsafeStaticComposition.tryParse(1.5).isValid}');

  try { DemoSchema<String, String>(parseSync: source.parse,
    collectSync: source.tryParse, parseAsync: source.parseAsync); }
  on ArgumentError { print('Incomplete async capability rejected at construction: true'); }
}
```

## Runtime result

Command: `dart --packages=.dart_tool/schema-base-package-config.json .dart_tool/schema_base_design_probe.dart`

```text
Unknown boundary rejects wrong input through diagnostics: true
Sync schema async output: ok
Sync schema async collecting output: ok
Async schema sync parse rejects: true
Actual async rejection: true
Invalid input skips next stage: true
Exact nonnullable pipeline output: 4
Input/output mapping and output-only alias: true
Narrower-input composition compiles but needs runtime validation: true
Incomplete async capability rejected at construction: true
```

## Negative compiler fixtures

Each fixture imports the source above and the archived `package:acanthis/acanthis.dart`, then constructs `text` with `DemoSchema<String,String>(parseSync: string().parse, collectSync: string().tryParse)`.

The mapper fixture contains `final bad = mapOutput(text, (int value) => value);`. Command: `dart compile kernel --packages=.dart_tool/schema-base-package-config.json .dart_tool/schema_base_negative_mapper.dart -o .dart_tool/schema-base-negative.dill`.

```text
Error: The argument type 'int Function(int)' can't be assigned to the parameter type 'int Function(String)'.
```

The output fixture contains `final String bad = mapOutput(text, (value) => value.length).parse('okay');`. Command: `dart compile kernel --packages=.dart_tool/schema-base-package-config.json .dart_tool/schema_base_negative_output.dart -o .dart_tool/schema-base-negative.dill`.

```text
Error: A value of type 'int' can't be assigned to a variable of type 'String'.
```

Both final compiler retries exited 1 for the intended diagnostics, after sandbox telemetry failures were removed by permitted retries. The positive runtime example exited 0. No benchmark was performed and no current root-package test-suite result is claimed. Temporary Dart sources were removed after their contents and outputs were recorded here.

