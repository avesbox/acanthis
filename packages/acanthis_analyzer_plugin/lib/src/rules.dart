import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'schema.dart';

class AcanthisRules extends MultiAnalysisRule {
  static const keyCode = LintCode(
    'acanthis_unknown_key',
    'The upstream object schema has no field named "{0}".',
  );
  static const asyncCode = LintCode(
    'acanthis_sync_parse_async_schema',
    'This schema has async refinements. Use {0}().',
  );

  AcanthisRules()
    : super(
        name: 'acanthis_schemas',
        description: 'Check Acanthis schema keys and async parse calls.',
      );

  @override
  List<DiagnosticCode> get diagnosticCodes => const [keyCode, asyncCode];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    if (!importsAcanthis(context.libraryElement)) return;
    final visitor = SchemaVisitor((issue) {
      reportAtOffset(
        issue.offset,
        issue.length,
        diagnosticCode: issue.code == 'key' ? keyCode : asyncCode,
        arguments: [issue.argument],
      );
    });
    registry.addMethodInvocation(this, visitor);
    registry.addVariableDeclaration(this, visitor);
  }
}

/// Owned by the current analysis request. All stored schema data is primitive;
/// no context, node, element, type, session, or result is retained here.
class SchemaVisitor extends SimpleAstVisitor<void> {
  final void Function(Issue) report;
  final known = <String, Shape>{};
  final declarations = <int, Shape>{};

  SchemaVisitor(this.report);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer == null) return;
    final shape = inspectChain(initializer, known, report);
    if (shape == null) return;
    declarations[node.offset] = shape;
    final element = node.declaredFragment?.element;
    // Mutable aliases cannot be trusted after an assignment.
    if (element != null && (element.isFinal || element.isConst)) {
      known[symbolKey(element)] = shape;
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    AstNode outer = node;
    while (outer.parent is ParenthesizedExpression) {
      outer = outer.parent!;
    }
    final parent = outer.parent;
    if (parent is MethodInvocation && identical(parent.target, outer)) return;
    if (parent is VariableDeclaration && identical(parent.initializer, outer)) {
      return;
    }
    final name = node.methodName.name;
    if (name != 'pick' &&
        name != 'omit' &&
        name != 'optionals' &&
        name != 'addFieldDependency' &&
        name != 'parse' &&
        name != 'tryParse') {
      return;
    }
    inspectChain(node, known, report);
  }
}
