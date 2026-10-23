import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/common/issue_sink.dart';
import 'package:test/test.dart';

void main() {
  test('sink records codes and parameters without accepting a message', () {
    final sink = IssueSink.single('minLength', parameters: {'value': 3});
    final issue = sink.issues.single;
    expect(issue.code, 'minLength');
    expect(issue.message, 'Value must contain at least 3 characters');
    expect(
      AcanthisIssue(
        path: const [],
        code: 'exactLength',
        parameters: {'value': 1},
      ).message,
      'Value must contain exactly 1 character',
    );
    sink.addIssue('');
    expect(sink.issues.last.code, 'custom');
    expect(sink.issues.last.message, 'Invalid value');
  });

  test('extended catalogs override defaults and add application codes', () {
    final additions = <String, AcanthisMessageBuilder>{
      'minLength': (p) => 'Almeno ${p['value']} caratteri',
      'app.passwordMismatch': (_) => 'Le password non corrispondono',
    };
    final italian = AcanthisMessageCatalog.english.extend(additions);
    additions.clear();
    expect(italian.format('minLength', {'value': 3}), 'Almeno 3 caratteri');
    expect(
      italian.format('app.passwordMismatch', const {}),
      'Le password non corrispondono',
    );
    expect(italian.format('required', const {}), 'A value is required');
    expect(
      AcanthisMessageCatalog.english.format('minLength', {'value': 3}),
      'Value must contain at least 3 characters',
    );
  });

  test(
    'provided catalogs are snapshots and can completely replace defaults',
    () {
      final map = <String, AcanthisMessageBuilder>{
        'type': (_) => 'Tipo errato',
      };
      final catalog = AcanthisMessageCatalog(map);
      map['type'] = (_) => 'changed';
      expect(catalog.format('type', const {}), 'Tipo errato');
      expect(catalog.format('required', const {}), 'required');
      expect(catalog.format('app.unknown', const {}), 'app.unknown');
    },
  );

  test('missing or declined messages use an explicit fallback', () {
    final fallback = AcanthisMessageCatalog({'app.rule': (_) => 'Fallback'});
    final catalog = AcanthisMessageCatalog({
      'app.rule': (_) => null,
    }, fallback: fallback);
    expect(catalog.format('app.rule', const {}), 'Fallback');
    expect(catalog.format('app.unknown', const {}), 'app.unknown');
    expect(catalog.extend(const {}).format('app.rule', const {}), 'Fallback');
    expect(
      AcanthisMessageCatalog.english.format('minLength', {'value': 'bad'}),
      'minLength',
    );
  });

  test('collection, prefixing, equality and transport do no message work', () {
    var calls = 0;
    final catalog = AcanthisMessageCatalog({
      'app.rule': (p) {
        calls++;
        expect(() => p.clear(), throwsUnsupportedError);
        return 'Limit ${p['limit']}';
      },
    });
    final child = IssueSink()..addIssue('app.rule', parameters: {'limit': 3});
    final sink = IssueSink()..addChild('field', child);
    final diagnostic = sink.takeIssues().single;
    final equal = AcanthisIssue(
      path: ['field'],
      code: 'app.rule',
      parameters: {'limit': 3},
    );
    expect(diagnostic, equal);
    expect(diagnostic.hashCode, equal.hashCode);
    expect(diagnostic.toTransport(), {
      'path': ['field'],
      'code': 'app.rule',
      'parameters': {'limit': 3},
    });
    expect(calls, 0);
    expect(diagnostic.formatMessage(catalog: catalog), 'Limit 3');
    expect(calls, 1);
  });

  test('JSON uses the supplied catalog for the issue and all branches', () {
    final catalog = AcanthisMessageCatalog({
      'union': (_) => 'Nessuna alternativa',
      'minLength': (p) => 'Almeno ${p['value']} caratteri',
    });
    final diagnostic = AcanthisIssue(
      path: const [],
      code: 'union',
      branches: [
        [
          AcanthisIssue(
            path: ['name'],
            code: 'minLength',
            parameters: {'value': 3},
          ),
        ],
      ],
    ).prefixed(0);
    final rendered = jsonDecode(
      jsonEncode(diagnostic.toJson(catalog: catalog)),
    );
    expect(rendered['message'], 'Nessuna alternativa');
    expect(rendered['branches'][0][0]['message'], 'Almeno 3 caratteri');
    expect(rendered['branches'][0][0]['path'], [0, 'name']);
    expect(diagnostic.message, 'Value does not match any union entry');
    expect(jsonEncode(diagnostic.toTransport()), isNot(contains('message')));
  });

  test(
    'the same issue can be rendered concurrently with independent maps',
    () async {
      final issue = AcanthisIssue(path: const [], code: 'required');
      final italian = AcanthisMessageCatalog({
        'required': (_) => 'Obbligatorio',
      });
      final french = AcanthisMessageCatalog({'required': (_) => 'Obligatoire'});
      final rendered = await Future.wait([
        Future(() => issue.formatMessage(catalog: italian)),
        Future(() => issue.formatMessage(catalog: french)),
      ]);
      expect(rendered, ['Obbligatorio', 'Obligatoire']);
      expect(issue.message, 'A value is required');
    },
  );

  test('message formatter exceptions remain presentation errors', () {
    final issue = AcanthisIssue(path: const [], code: 'type');
    final catalog = AcanthisMessageCatalog({
      'type': (_) => throw StateError('broken formatter'),
    });
    expect(() => issue.formatMessage(catalog: catalog), throwsStateError);
    expect(issue.code, 'type');
  });
}
