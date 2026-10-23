import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'support/primitive_export.dart';

void main() {
  testPrimitiveExports('boolean', {
    'boolean': boolean(),
    'true': boolean().isTrue(),
    'false': boolean().isFalse(),
    'contradictory': boolean().isTrue().isFalse(),
    'false_default': boolean().withDefault(false),
  });

  test('boolean unsafe or opaque schemas reject export without callbacks', () {
    var calls = 0;
    final candidates = <Schema<Object?, Object?>>[
      boolean().coerce(),
      boolean().isTrue().withDefault(false),
      boolean().refine(
        onCheck: (_) {
          calls++;
          return true;
        },
      ),
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
