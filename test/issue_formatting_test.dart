import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'field and tree views preserve duplicates, roots and typed path segments',
    () {
      final catalog = AcanthisMessageCatalog({
        'first': (_) => 'First',
        'second': (_) => 'Second',
      });
      final issues = [
        AcanthisIssue(path: [], code: 'first'),
        AcanthisIssue(path: ['a/b', '~', 0], code: 'first'),
        AcanthisIssue(path: ['a/b', '~', 0], code: 'second'),
        AcanthisIssue(path: ['a/b', '~', '0'], code: 'second'),
      ];
      expect(issues.formatFields(catalog: catalog), {
        '': ['First'],
        '/a~1b/~0/0': ['First', 'Second', 'Second'],
      });
      final tree = issues.formatTree(catalog: catalog);
      expect(tree.messages, ['First']);
      final children = tree.children['a/b']!.children['~']!.children;
      expect(children.keys, [0, '0']);
      expect(children[0]!.messages, ['First', 'Second']);
      expect(children['0']!.messages, ['Second']);
      children[0]!.messages.clear();
      expect(
        issues
            .formatTree(catalog: catalog)
            .children['a/b']!
            .children['~']!
            .children[0]!
            .messages,
        ['First', 'Second'],
      );
    },
  );

  test(
    'locale and explicit catalogs format existing issues without validation',
    () {
      var calls = 0;
      final result = string()
          .refine(
            onCheck: (_) {
              calls++;
              return false;
            },
            name: 'app.invalid',
            error: 'Schema message',
          )
          .tryParse('submitted-secret');
      final italian = AcanthisMessageCatalog({
        'app.invalid': (_) => 'Non valido',
      });
      final empty = AcanthisMessageCatalog({'app.invalid': (_) => ''});
      expect(result.issues.formatFields(), {
        '': ['Schema message'],
      });
      AcanthisI18n.runWith(
        AcanthisLocaleConfig(locale: 'it', catalog: italian),
        () {
          expect(result.issues.formatTree().messages, ['Non valido']);
          expect(result.issues.formatFields(catalog: empty), {
            '': [''],
          });
          expect(
            result.issues.formatFields(catalog: AcanthisMessageCatalog({})),
            {
              '': ['app.invalid'],
            },
          );
        },
      );
      expect(result.issues.formatTree().messages, ['Schema message']);
      expect(calls, 1);
      expect(
        result.issues.toTransport().toString(),
        isNot(contains('submitted-secret')),
      );
    },
  );

  test(
    'JSON and transport retain union branches without flattening summaries',
    () {
      final result = object({
        'item': union<Object?>([integer(), boolean()]),
      }).tryParse({'item': 'bad'});
      final catalog = AcanthisMessageCatalog({
        'union': (_) => 'No match',
        'type': (_) => 'Wrong type',
      });
      final decoded = jsonDecode(result.issues.formatJson(catalog: catalog));
      expect(decoded, [
        for (final issue in result.issues) issue.toJson(catalog: catalog),
      ]);
      expect(decoded.single['branches'], hasLength(2));
      expect(result.issues.formatFields(catalog: catalog), {
        '/item': ['No match'],
      });
      expect(
        result.issues.formatTree(catalog: catalog).children['item']!.messages,
        ['No match'],
      );
      final transport = result.issues.toTransport();
      expect(transport, {
        'version': 1,
        'issues': [for (final issue in result.issues) issue.toTransport()],
      });
      expect(jsonEncode(transport), isNot(contains('message')));
    },
  );

  test(
    'empty iterables produce empty presentation views and a versioned envelope',
    () {
      final Iterable<AcanthisIssue> issues = const <AcanthisIssue>[];
      expect(issues.formatFields(), isEmpty);
      expect(issues.formatTree().messages, isEmpty);
      expect(issues.formatTree().children, isEmpty);
      expect(issues.formatJson(), '[]');
      expect(issues.toTransport(), {'version': 1, 'issues': <Object?>[]});
    },
  );
}
