import 'dart:convert';

import 'i18n.dart';
import 'issue.dart';

/// A presentation tree that keeps field names distinct from list indices.
final class AcanthisIssueTree {
  final List<String> messages = [];
  final Map<Object, AcanthisIssueTree> children = {};
}

extension AcanthisIssueFormatting on Iterable<AcanthisIssue> {
  /// Locale-independent transport, without messages or submitted values.
  Map<String, Object?> toTransport() => {
    'version': 1,
    'issues': [for (final issue in this) issue.toTransport()],
  };

  Map<String, List<String>> formatFields({AcanthisMessageCatalog? catalog}) {
    final fields = <String, List<String>>{};
    for (final issue in this) {
      (fields[issue.jsonPointer] ??= []).add(
        issue.formatMessage(catalog: catalog),
      );
    }
    return fields;
  }

  AcanthisIssueTree formatTree({AcanthisMessageCatalog? catalog}) {
    final root = AcanthisIssueTree();
    for (final issue in this) {
      var node = root;
      for (final segment in issue.path) {
        node = node.children.putIfAbsent(segment, AcanthisIssueTree.new);
      }
      node.messages.add(issue.formatMessage(catalog: catalog));
    }
    return root;
  }

  String formatJson({AcanthisMessageCatalog? catalog}) =>
      jsonEncode([for (final issue in this) issue.toJson(catalog: catalog)]);
}
