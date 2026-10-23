import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

typedef Field = ({String fieldName, String typeDisplayString, bool isNullable});
typedef Shape = ({List<Field>? fields, bool isAsync, bool isPassthrough});
typedef Issue = ({String code, int offset, int length, String argument});

bool isAcanthisUri(Uri? uri) =>
    uri?.scheme == 'package' && uri!.path.startsWith('acanthis/');

// A once-per-library O(imports) check; no AST listeners are installed on a miss.
bool importsAcanthis(LibraryElement? library) {
  if (library == null) return false;
  for (final fragment in library.fragments) {
    for (final import in fragment.libraryImports) {
      if (isAcanthisUri(import.importedLibrary?.uri)) return true;
    }
  }
  return false;
}

Expression unwrap(Expression expression) {
  while (expression is ParenthesizedExpression) {
    expression = expression.expression;
  }
  return expression;
}

bool isAcanthisCall(MethodInvocation node) =>
    isAcanthisUri(node.methodName.element?.library?.uri);

/// Only primitive descriptors escape this function. Unknown map entries bail
/// out instead of producing an incomplete DTO or false unknown-key warnings.
List<Field>? extractFields(MethodInvocation node) {
  if (node.methodName.name != 'object' || !isAcanthisCall(node)) return null;
  final arguments = node.argumentList.arguments;
  if (arguments.length != 1) return null;
  final literal = unwrap(arguments.first);
  if (literal is! SetOrMapLiteral || !literal.isMap) return null;
  final fields = <Field>[];
  final names = <String>{};
  for (final entry in literal.elements) {
    if (entry is! MapLiteralEntry) return null;
    final key = entry.key;
    if (key is! StringLiteral || key.stringValue == null) return null;
    final name = key.stringValue!;
    if (!names.add(name)) return null;
    final type = entry.value.staticType;
    if (type is! InterfaceType) return null;
    InterfaceType? schema;
    if (_isSchema(type)) schema = type;
    for (final supertype in type.allSupertypes) {
      if (_isSchema(supertype)) {
        schema = supertype;
        break;
      }
    }
    if (schema == null || schema.typeArguments.length != 2) return null;
    final output = schema.typeArguments[1];
    fields.add((
      fieldName: name,
      typeDisplayString: output.getDisplayString(),
      isNullable:
          output.nullabilitySuffix == NullabilitySuffix.question ||
          output is DynamicType ||
          output is VoidType,
    ));
  }
  return fields;
}

bool _isSchema(InterfaceType type) =>
    type.element.name == 'Schema' && isAcanthisUri(type.element.library.uri);

/// Iterative inspection of inline child schemas, without entering callbacks.
bool containsAsync(MethodInvocation object, Map<String, Shape> known) {
  final pending = <Expression>[object];
  while (pending.isNotEmpty) {
    var current = unwrap(pending.removeLast());
    while (current is MethodInvocation) {
      final name = current.methodName.name;
      if (name == 'refineAsync' && isAcanthisCall(current)) return true;
      if (name == 'object' && isAcanthisCall(current)) {
        for (final argument in current.argumentList.arguments) {
          if (argument is SetOrMapLiteral) {
            for (final entry in argument.elements) {
              if (entry is MapLiteralEntry) pending.add(entry.value);
            }
          }
        }
      } else if ((name == 'list' || name == 'nullable') &&
          isAcanthisCall(current)) {
        for (final argument in current.argumentList.arguments) {
          if (argument is! NamedExpression) pending.add(argument);
        }
      }
      final target = current.target;
      if (target == null) break;
      current = unwrap(target);
    }
    if (current is SimpleIdentifier) {
      final element = current.element;
      if (element != null && known[symbolKey(element)]?.isAsync == true) {
        return true;
      }
    }
  }
  return false;
}

/// One fluent chain, inner to outer, in O(chain length + literal key count).
/// The invocation list is request-local and never escapes this function.
Shape? inspectChain(
  Expression expression,
  Map<String, Shape> known,
  void Function(Issue) report,
) {
  final root = unwrap(expression);
  if (root is! MethodInvocation && root is! SimpleIdentifier) return null;
  final chain = <MethodInvocation>[];
  var current = root;
  while (current is MethodInvocation) {
    chain.add(current);
    final target = current.target;
    if (target == null) break;
    current = unwrap(target);
  }
  Shape? shape;
  if (current is SimpleIdentifier) {
    final element = current.element;
    if (element != null) shape = known[symbolKey(element)];
  }
  Map<String, Field>? fields;
  var async = shape?.isAsync ?? false;
  var passthrough = shape?.isPassthrough ?? false;
  if (shape?.fields != null) {
    fields = {for (final field in shape!.fields!) field.fieldName: field};
  }
  for (var i = chain.length - 1; i >= 0; i--) {
    final call = chain[i];
    final name = call.methodName.name;
    if (name == 'object') {
      if (!isAcanthisCall(call)) return null;
      final extracted = extractFields(call);
      fields = extracted == null
          ? null
          : {for (final field in extracted) field.fieldName: field};
      async = containsAsync(call, known);
      passthrough = false;
      continue;
    }
    if (name == 'string' ||
        name == 'number' ||
        name == 'integer' ||
        name == 'doubleType' ||
        name == 'boolean' ||
        name == 'date' ||
        name == 'literal' ||
        name == 'list' ||
        name == 'nullable') {
      if (!isAcanthisCall(call)) return null;
      fields = null;
      async = containsAsync(call, known);
      passthrough = false;
      continue;
    }
    // Lexical filtering precedes semantic access.
    if (name != 'pick' &&
        name != 'omit' &&
        name != 'optionals' &&
        name != 'addFieldDependency' &&
        name != 'passthrough' &&
        name != 'refineAsync' &&
        name != 'parse' &&
        name != 'tryParse') {
      // shortcut: unknown transforms invalidate shape, add explicit semantics
      // here when supporting further schema transformations.
      return null;
    }
    if (!isAcanthisCall(call)) return null;
    if (name == 'passthrough') {
      passthrough = true;
      continue;
    }
    if (name == 'refineAsync') {
      async = true;
      continue;
    }
    if (name == 'parse' || name == 'tryParse') {
      if (async) {
        report((
          code: 'async',
          offset: call.methodName.offset,
          length: name.length,
          argument: '${name}Async',
        ));
      }
      return null;
    }
    if (fields == null) continue;
    final keys = <String>{};
    var complete = true;
    for (final argument in call.argumentList.arguments) {
      Iterable<Expression> values;
      if (name == 'addFieldDependency') {
        if (argument is! NamedExpression ||
            (argument.name.label.name != 'dependent' &&
                argument.name.label.name != 'dependendsOn')) {
          continue;
        }
        values = [argument.expression];
      } else {
        if (argument is! ListLiteral) {
          complete = false;
          continue;
        }
        final items = <Expression>[];
        for (final item in argument.elements) {
          if (item is Expression) {
            items.add(item);
          } else {
            complete = false;
          }
        }
        values = items;
      }
      for (final value in values) {
        if (value is! StringLiteral || value.stringValue == null) {
          complete = false;
          continue;
        }
        final key = value.stringValue!;
        keys.add(key);
        if (!passthrough && !fields.containsKey(key)) {
          report((
            code: 'key',
            offset: value.offset,
            length: value.length,
            argument: key,
          ));
        }
      }
    }
    if (name == 'addFieldDependency') continue;
    if (!complete) {
      fields = null;
      continue;
    }
    if (name == 'pick') {
      final selected = <String, Field>{};
      for (final key in keys) {
        final field = fields[key];
        if (field != null) selected[key] = field;
      }
      fields = selected;
    }
    if (name == 'omit') {
      for (final key in keys) {
        fields.remove(key);
      }
    }
    if (name == 'optionals') {
      for (final key in keys) {
        final field = fields[key];
        if (field != null && !field.isNullable) {
          fields[key] = (
            fieldName: key,
            typeDisplayString: '${field.typeDisplayString}?',
            isNullable: true,
          );
        }
      }
    }
  }
  return fields == null && !async
      ? null
      : (
          fields: fields?.values.toList(),
          isAsync: async,
          isPassthrough: passthrough,
        );
}

String symbolKey(Element element) {
  if (element is PropertyAccessorElement) element = element.variable;
  return '${element.firstFragment.libraryFragment?.source.fullName}:'
      '${element.firstFragment.nameOffset}';
}
