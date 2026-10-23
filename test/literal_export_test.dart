import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'support/primitive_export.dart';

void main() {
  testPrimitiveExports('literal', {
    'literal_string': literal('ok'),
    'literal_bool': literal(false),
    'literal_null': literal(null),
    'literal_numeric': literal<num>(1),
    'literal_default': literal('ok').withDefault('ok'),
    'literal_list': list(literal(null)).contains(null),
    'record_literal_key': record(literal('kind'), boolean().nullable()),
  });

  test('literal unsafe or opaque schemas reject export without callbacks', () {
    var calls = 0;
    final candidates = <Schema<Object?, Object?>>[
      literal<int>(1),
      literal<double>(1.0),
      literal<num>(double.nan),
      literal<num>(9007199254740992),
      literal([1]),
      literal(DateTime(2026)),
      literal('ok').withDefault('bad'),
      literal('ok').transform((value) {
        calls++;
        return value;
      }),
    ];
    for (final candidate in candidates) {
      for (final mode in AcanthisSchemaMode.values) {
        expect(
          () => candidate.toJsonSchema(mode: mode),
          throwsA(isA<AcanthisSchemaExportException>()),
        );
      }
    }
    expect(calls, 0);
  });
}
