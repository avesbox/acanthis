import 'package:meta/meta.dart';

import 'issue.dart';
import 'results.dart';

/// Caches belong to one live revision, never to a schema or a nested traversal.
@internal
final class ObjectEvaluation {
  ObjectEvaluation(this.fields, this.rules, {this.onFieldSettled});
  final Map<String, AcanthisOutcome<Object?>> fields;
  final Map<String, List<AcanthisIssue>> rules;
  final executedFields = <String>{};
  final executedRules = <String>{};
  final void Function(String)? onFieldSettled;

  void settle(String name, AcanthisOutcome<Object?> result) {
    if (!fields.containsKey(name)) executedFields.add(name);
    fields[name] = result;
    onFieldSettled?.call(name);
  }

  // Missing optional/required fields are assembled by ObjectSchema itself.
  void settleMissing(String name) => settle(name, AcanthisValid(null));
}
