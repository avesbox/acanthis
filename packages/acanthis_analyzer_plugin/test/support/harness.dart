import 'dart:io';

import 'package:acanthis_analyzer_plugin/src/rules.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/listener.dart';
// The SDK does not expose a public standalone rule runner. These test-only
// imports are pinned to analyzer 12.0.0 by pubspec.yaml.
import 'package:analyzer/src/analysis_rule/rule_context.dart';
import 'package:analyzer/src/lint/linter_visitor.dart';

final packageRoot = Directory.current.absolute.path;

class Harness {
  final Directory directory;
  final AnalysisContextCollection collection;
  Harness._(this.directory, this.collection);

  static Harness create() {
    final directory = Directory(
      '$packageRoot${Platform.pathSeparator}.dart_tool',
    ).createTempSync('plugin_');
    return Harness._(
      directory,
      AnalysisContextCollection(includedPaths: [directory.path]),
    );
  }

  String write(String name, String source) {
    final file = File('${directory.path}${Platform.pathSeparator}$name.dart');
    file.writeAsStringSync(source);
    return file.path;
  }

  Future<ResolvedUnitResult> resolve(String path) async {
    final result = await collection
        .contextFor(path)
        .currentSession
        .getResolvedUnit(path);
    if (result is! ResolvedUnitResult) throw StateError('$result');
    return result;
  }

  Future<void> dispose() async {
    await collection.dispose();
    directory.deleteSync(recursive: true);
  }
}

List<({String code, int offset, String message})> runRules(
  ResolvedUnitResult result,
  AcanthisRules rule,
) {
  final listener = RecordingDiagnosticListener();
  final reporter = DiagnosticReporter(
    listener,
    result.unit.declaredFragment!.source,
  );
  final unit = RuleContextUnit(
    file: result.file,
    content: result.content,
    diagnosticReporter: reporter,
    unit: result.unit,
  );
  final context = RuleContextWithResolvedResults(
    [unit],
    unit,
    result.typeProvider,
    result.typeSystem,
    null,
  )..currentUnit = unit;
  final registry = RuleVisitorRegistryImpl(enableTiming: false);
  rule.reporter = reporter;
  rule.registerNodeProcessors(registry, context);
  final visitor = AnalysisRuleVisitor(
    registry,
    shouldPropagateExceptions: true,
  );
  result.unit.accept(visitor);
  visitor.afterLibrary();
  return [
    for (final error in listener.diagnostics)
      (
        code: error.diagnosticCode.lowerCaseName,
        offset: error.offset,
        message: error.message,
      ),
  ];
}

String stressSource(int iteration) =>
    '''
import 'package:acanthis/acanthis.dart';
final schema$iteration = object({
  'name': string(),
  'age': integer(),
  'nested': object({'label': string().refineAsync(CallbackAsyncCheck((_, _) async {}))}),
}).pick(['name', 'age', 'nested']).omit(['age']).optionals(['name'])
 .addFieldDependency(dependent: 'name', dependendsOn: 'nested',
   dependency: (a, b) => true);
void validate$iteration() {
 schema$iteration.pick(['missing']);
 schema$iteration.parse({});
 schema$iteration.tryParse({});
}
''';
