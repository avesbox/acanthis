import 'dart:io';

import 'package:acanthis_analyzer_plugin/src/assists.dart';
import 'package:acanthis_analyzer_plugin/src/rules.dart';
import 'package:acanthis_analyzer_plugin/src/schema.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late Harness harness;
  setUp(() => harness = Harness.create());
  tearDown(() => harness.dispose());

  test(
    'shared rule lifecycle: aliases, nested async and both parse calls',
    () async {
      final result = await harness.resolve(
        harness.write('schema', stressSource(0)),
      );
      expect(
        result.diagnostics.where(
          (e) => e.diagnosticCode.lowerCaseName != 'unused_import',
        ),
        isEmpty,
      );
      final diagnostics = runRules(result, AcanthisRules());
      expect(
        diagnostics.where((d) => d.code == 'acanthis_unknown_key'),
        hasLength(1),
      );
      expect(
        diagnostics.where((d) => d.code == 'acanthis_sync_parse_async_schema'),
        hasLength(2),
      );
    },
  );

  test('checked-in passthrough example reports only the async guard', () async {
    final source = File('example/lib/example.dart').readAsStringSync();
    final result = await harness.resolve(
      harness.write('example_regression', source),
    );
    expect(result.diagnostics, isEmpty);
    final diagnostics = runRules(result, AcanthisRules());
    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.code, 'acanthis_sync_parse_async_schema');
    expect(
      diagnostics.single.offset,
      source.indexOf('userSchema.parse') + 'userSchema.'.length,
    );
  });

  test('example DTO assist accepts the name, final keyword and declaration selections', () async {
    final source = File('example/lib/example.dart').readAsStringSync();
    final start = source.indexOf('final userSchema');
    final end = source.indexOf(';', start) + 1;
    final selections = [
      (start + 'final '.length, 'userSchema'.length),
      (start, 0),
      (start, source.indexOf('\n', start) - start),
      (start, end - start),
      (start, end - start + 1),
    ];
    for (var i = 0; i < selections.length; i++) {
      final (offset, length) = selections[i];
      final assist = await _assist(
        harness,
        'selection_$i',
        source,
        offset: offset,
        length: length,
      );
      expect(assist.edits, hasLength(1), reason: 'selection $i');
      expect(assist.edits.single.edits.single.replacement, contains('UserDto'));
    }
  });

  test(
    'pick, omit, optionals and dependencies use the effective upstream shape',
    () async {
      final result = await harness.resolve(
        harness.write('keys', '''
import 'package:acanthis/acanthis.dart';
final schema = object({'a': string(), 'b': integer()})
 .pick(['a', 'badPick']).omit(['badOmit']).optionals(['badOptional'])
 .addFieldDependency(dependent: 'b', dependendsOn: 'missing', dependency: (a,b) => true);
'''),
      );
      expect(runRules(result, AcanthisRules()), hasLength(5));
    },
  );

  test(
    'foreign object calls, unknown spreads and mutable aliases are skipped',
    () async {
      final result = await harness.resolve(
        harness.write('foreign', '''
import 'package:acanthis/acanthis.dart' as a;
class Foreign {
 Foreign object(Map<String, Object?> value) => this;
 Foreign pick(List<String> names) => this;
}
final foreign = Foreign().object({'x': 1}).pick(['bad']);
final fields = {'a': a.string()};
final spread = a.object({...fields}).pick(['bad']);
var mutable = a.object({'a': a.string()});
void f() { mutable.pick(['bad']); }
'''),
      );
      expect(runRules(result, AcanthisRules()), isEmpty);
    },
  );

  for (final typed in [false, true]) {
    test('passthrough suppresses unknown keys, typed=$typed', () async {
      final passthrough = typed
          ? 'passthrough(type: string())'
          : 'passthrough()';
      final result = await harness.resolve(
        harness.write('passthrough_$typed', '''
import 'package:acanthis/acanthis.dart';
final base = object({'name': string()});
final open = base.refineAsync(CallbackAsyncCheck((_, _) async {})).$passthrough;
final alias = open.pick(['extra']).omit(['omitted']).optionals(['optional'])
 .addFieldDependency(dependent: 'dependent', dependendsOn: 'dependency',
   dependency: (a, b) => true);
final before = base.pick(['before']).$passthrough;
void f() {
 object({'name': string()}).$passthrough.pick(['inline']);
 alias.pick(['alias']);
 base.pick(['closed']);
 open.parse({});
 alias.tryParse({});
}
'''),
      );
      expect(result.diagnostics, isEmpty);
      final diagnostics = runRules(result, AcanthisRules());
      final keys = diagnostics.where((d) => d.code == 'acanthis_unknown_key');
      expect(keys, hasLength(2));
      expect(keys.any((d) => d.message.contains('before')), isTrue);
      expect(keys.any((d) => d.message.contains('closed')), isTrue);
      expect(
        diagnostics.where((d) => d.code == 'acanthis_sync_parse_async_schema'),
        hasLength(2),
      );
      final assist = await _assist(harness, 'passthrough_dto_$typed', '''
import 'package:acanthis/acanthis.dart';
final userSchema = object({'name': string()}).$passthrough;
''');
      expect(
        assist.edits.single.edits.single.replacement,
        contains('String get name'),
      );
    });
  }

  test(
    'assist accepts prefixed factories and declines non-object schemas',
    () async {
      final prefixed = await _assist(harness, 'prefixed', '''
import 'package:acanthis/acanthis.dart' as a;
final userSchema = a.object({'name': a.string()});
''');
      expect(prefixed.edits, hasLength(1));
      final scalar = await _assist(harness, 'scalar', '''
import 'package:acanthis/acanthis.dart';
final userSchema = string().refineAsync(CallbackAsyncCheck((_, _) async {}));
void f() { userSchema.parse('x'); }
''');
      expect(scalar.edits, isEmpty);
      final scalarPath = harness.write('scalar_guard', '''
import 'package:acanthis/acanthis.dart';
final value = string().refineAsync(CallbackAsyncCheck((_, _) async {}));
void f() { value.tryParse('x'); }
''');
      expect(
        runRules(await harness.resolve(scalarPath), AcanthisRules()),
        hasLength(1),
      );
    },
  );

  test('no Acanthis import installs no listeners', () async {
    final result = await harness.resolve(
      harness.write('plain', 'final value = 1;'),
    );
    expect(importsAcanthis(result.libraryElement), isFalse);
    expect(runRules(result, AcanthisRules()), isEmpty);
  });

  test(
    'unknown shape or key lists do not hide a definite async refinement',
    () async {
      final result = await harness.resolve(
        harness.write('unknown_async', '''
import 'package:acanthis/acanthis.dart';
final fields = {'name': string()};
final keys = ['name'];
final one = object(fields).refineAsync(CallbackAsyncCheck((_, _) async {}));
final two = object({'name': string()}).pick(keys)
 .refineAsync(CallbackAsyncCheck((_, _) async {}));
void f() { one.parse({}); two.tryParse({}); }
'''),
      );
      final diagnostics = runRules(result, AcanthisRules());
      expect(diagnostics, hasLength(2));
      expect(
        diagnostics.every((d) => d.code == 'acanthis_sync_parse_async_schema'),
        isTrue,
      );
    },
  );

  test(
    'Schema output types include nullable, generic and nested map values',
    () async {
      final result = await harness.resolve(
        harness.write('types', '''
import 'package:acanthis/acanthis.dart';
final userSchema = object({'name': string(), 'age': integer(),
 'maybe': nullable<String>(string()), 'items': list(integer()),
 'nested': object({'value': string()})});
'''),
      );
      final finder = _ObjectFinder();
      result.unit.accept(finder);
      final fields = extractFields(finder.calls.first)!;
      expect(fields.map((f) => f.typeDisplayString), [
        'String',
        'int',
        'String?',
        'List<int>',
        'Map<String, Object?>',
      ]);
      expect(fields[2].isNullable, isTrue);
      final dto = generateDto('UserDto', fields)!;
      final generated = await harness.resolve(harness.write('generated', dto));
      expect(generated.diagnostics, isEmpty);
    },
  );

  test(
    'generator rejects invalid or conflicting getters and escapes dollars',
    () {
      Field field(String key) =>
          (fieldName: key, typeDisplayString: 'String', isNullable: false);
      expect(generateDto('Dto', [field('bad-key')]), isNull);
      expect(generateDto('Dto', [field('length')]), isNull);
      expect(generateDto('Dto', [field('class')]), isNull);
      expect(generateDto('Dto', [field(r'$value')]), contains(r'\$value'));
    },
  );

  test(
    'SDK assist creates and syncs a DTO; async fix uses SDK change builder',
    () async {
      const source = '''
import 'package:acanthis/acanthis.dart';
final userSchema = object({'name': string()});
final result = object({'x': string()}).refineAsync(CallbackAsyncCheck((_, _) async {})).parse({});
''';
      final path = harness.write('assist', source);
      final result = await harness.resolve(path);
      final library = await result.session.getResolvedLibrary(
        path,
      ) as ResolvedLibraryResult;
      final context = CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: result,
        selectionOffset: source.indexOf('userSchema'),
      );
      final builder = ChangeBuilder(session: result.session);
      await GenerateDto(context: context).compute(builder);
      final changed = SourceEdit.applySequence(
        source,
        builder.sourceChange.edits.single.edits,
      );
      expect(changed, contains('extension type const UserDto'));
      expect(changed, contains('String get name'));
      final updated = changed
          .replaceAll('\n', '\r\n')
          .replaceFirst("'name': string()", "'age': integer()");
      final syncPath = harness.write('sync', updated);
      final sync = await harness.resolve(syncPath);
      final syncLibrary = await sync.session.getResolvedLibrary(
        syncPath,
      ) as ResolvedLibraryResult;
      final syncBuilder = ChangeBuilder(session: sync.session);
      final syncStart = updated.indexOf('final userSchema');
      await GenerateDto(
        context: CorrectionProducerContext.createResolved(
          libraryResult: syncLibrary,
          unitResult: sync,
          selectionOffset: syncStart,
          selectionLength: updated.indexOf(';', syncStart) - syncStart + 1,
        ),
      ).compute(syncBuilder);
      final synced = SourceEdit.applySequence(
        updated,
        syncBuilder.sourceChange.edits.single.edits,
      );
      expect(synced, contains('int get age'));
      expect(synced, isNot(contains('String get name')));
      final fixBuilder = ChangeBuilder(session: result.session);
      await UseAsyncParse(
        context: CorrectionProducerContext.createResolved(
          libraryResult: library,
          unitResult: result,
          selectionOffset: source.indexOf('.parse') + 1,
        ),
      ).compute(fixBuilder);
      expect(
        SourceEdit.applySequence(
          source,
          fixBuilder.sourceChange.edits.single.edits,
        ),
        contains('.parseAsync({})'),
      );
    },
  );
}

Future<SourceChange> _assist(
  Harness harness,
  String fileName,
  String source, {
  int? offset,
  int length = 0,
}) async {
  final path = harness.write(fileName, source);
  final result = await harness.resolve(path);
  final library =
      await result.session.getResolvedLibrary(path) as ResolvedLibraryResult;
  final builder = ChangeBuilder(session: result.session);
  await GenerateDto(
    context: CorrectionProducerContext.createResolved(
      libraryResult: library,
      unitResult: result,
      selectionOffset: offset ?? source.indexOf('userSchema'),
      selectionLength: length,
    ),
  ).compute(builder);
  return builder.sourceChange;
}

class _ObjectFinder extends RecursiveAstVisitor<void> {
  final calls = <MethodInvocation>[];
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'object') calls.add(node);
    super.visitMethodInvocation(node);
  }
}
