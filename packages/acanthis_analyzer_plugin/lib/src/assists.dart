import 'dart:convert';

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import 'rules.dart';
import 'schema.dart';

class UseAsyncParse extends ResolvedCorrectionProducer {
  UseAsyncParse({required super.context});
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;
  @override
  FixKind get fixKind => const FixKind(
    'acanthis.useAsyncParse',
    30,
    'Use asynchronous validation',
  );
  @override
  Future<void> compute(ChangeBuilder builder) async {
    final call = node.thisOrAncestorOfType<MethodInvocation>();
    if (call == null) return;
    final name = call.methodName.name;
    if (name != 'parse' && name != 'tryParse') return;
    final offset = call.methodName.offset;
    await builder.addDartFileEdit(file, (edit) {
      edit.addSimpleReplacement(
        SourceRange(offset, name.length),
        '${name}Async',
      );
    });
  }
}

/// No fields: the SDK's producer context is owned by this one assist request.
class GenerateDto extends ResolvedCorrectionProducer {
  GenerateDto({required super.context});
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;
  @override
  AssistKind get assistKind => const AssistKind(
    'acanthis.generateDto',
    30,
    'Generate or sync typed schema DTO',
  );
  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (!importsAcanthis(unitResult.libraryElement)) return;
    var variable = node.thisOrAncestorOfType<VariableDeclaration>();
    // `final` and selections spanning the initializer cover the declaration
    // list or its wrapper, rather than the VariableDeclaration itself.
    if (variable == null) {
      for (final declaration in unit.declarations) {
        if (declaration is TopLevelVariableDeclaration &&
            declaration.variables.variables.length == 1 &&
            selectionOffset >= declaration.offset &&
            selectionOffset <= declaration.end &&
            (selectionEnd <= declaration.end ||
                unitResult.content
                    .substring(declaration.end, selectionEnd)
                    .trim()
                    .isEmpty)) {
          variable = declaration.variables.variables.single;
          break;
        }
      }
    }
    if (variable == null ||
        variable.parent?.parent is! TopLevelVariableDeclaration) {
      return;
    }
    final visitor = SchemaVisitor((_) {});
    unit.accept(_AssistWalk(visitor));
    final shape = visitor.declarations[variable.offset];
    if (shape?.fields == null) return;
    final sourceName = variable.name.lexeme;
    final base = sourceName.endsWith('Schema')
        ? sourceName.substring(0, sourceName.length - 6)
        : sourceName;
    if (base.isEmpty) return;
    final name = '${base[0].toUpperCase()}${base.substring(1)}Dto';
    final generated = generateDto(name, shape!.fields!);
    if (generated == null) return;
    // Type display strings are unqualified. Do not insert a type that is only
    // available through an import prefix or hidden behind a library boundary.
    final types = _TypeNames();
    parseString(content: generated).unit.accept(types);
    final visible = <String>{'dynamic', 'void'};
    for (final fragment in unitResult.libraryElement.fragments) {
      for (final import in fragment.libraryImports) {
        if (import.prefix == null) {
          visible.addAll(import.namespace.definedNames2.keys);
        }
      }
    }
    for (final declaration in unit.declarations) {
      final declaredName = declaration.declaredFragment?.element.name;
      if (declaredName != null) visible.add(declaredName);
    }
    if (!visible.containsAll(types.names)) return;
    final content = unitResult.content;
    final eol = content.contains('\r\n') ? '\r\n' : '\n';
    final startMarker = '// acanthis:begin $sourceName$eol';
    final endMarker = '// acanthis:end $sourceName';
    final start = content.indexOf(startMarker);
    final end = start < 0 ? -1 : content.indexOf(endMarker, start);
    if (start >= 0 && end < 0) return;
    if (start < 0) {
      for (final declaration in unit.declarations) {
        if (declaration.declaredFragment?.element.name == name) return;
      }
    } else {
      // The marked region is generator-owned; user code belongs outside it.
      final old = content.substring(start + startMarker.length, end);
      if (!old.startsWith('extension type const $name(')) return;
      var ownsDeclaration = false;
      for (final declaration in unit.declarations) {
        if (declaration is ExtensionTypeDeclaration &&
            declaration.declaredFragment?.element.name == name &&
            declaration.offset >= start + startMarker.length &&
            declaration.end <= end) {
          ownsDeclaration = true;
          break;
        }
      }
      if (!ownsDeclaration) return;
    }
    final text = '$startMarker${generated.replaceAll('\n', eol)}$endMarker';
    final offset = start < 0 ? unit.end : start;
    final length = start < 0 ? 0 : end + endMarker.length - start;
    await builder.addDartFileEdit(file, (edit) {
      edit.addSimpleReplacement(
        SourceRange(offset, length),
        start < 0 ? '$eol$eol$text$eol' : text,
      );
    });
  }
}

// Only assists perform this additional walk, on demand, never in lint analysis.
class _AssistWalk extends RecursiveAstVisitor<void> {
  final SchemaVisitor visitor;
  _AssistWalk(this.visitor);
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    visitor.visitVariableDeclaration(node);
    super.visitVariableDeclaration(node);
  }
}

class _TypeNames extends RecursiveAstVisitor<void> {
  final names = <String>{};
  @override
  void visitNamedType(NamedType node) {
    names.add(node.name.lexeme);
    super.visitNamedType(node);
  }
}

String? generateDto(String name, List<Field> fields) {
  const mapMembers = {
    '_data',
    'length',
    'keys',
    'values',
    'entries',
    'isEmpty',
    'isNotEmpty',
    'hashCode',
    'runtimeType',
    'cast',
    'addAll',
    'addEntries',
    'clear',
    'containsKey',
    'containsValue',
    'forEach',
    'map',
    'putIfAbsent',
    'remove',
    'removeWhere',
    'update',
    'updateAll',
    'toString',
    'noSuchMethod',
  };
  final buffer = StringBuffer(
    'extension type const $name('
    'Map<String, dynamic> _data) implements Map<String, dynamic> {\n',
  );
  for (final field in fields) {
    if (!RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(field.fieldName) ||
        mapMembers.contains(field.fieldName) ||
        field.typeDisplayString == 'void') {
      return null;
    }
    final key = jsonEncode(field.fieldName).replaceAll(r'$', r'\$');
    buffer.writeln(
      '  ${field.typeDisplayString} get ${field.fieldName} => '
      '_data[$key] as ${field.typeDisplayString};',
    );
  }
  buffer.writeln('}');
  final source = buffer.toString();
  if (parseString(
    content: source,
    throwIfDiagnostics: false,
  ).errors.isNotEmpty) {
    return null;
  }
  return source;
}
