import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'support/primitive_export.dart';

void main() {
  final tree = object({
    'tag': literal('node'),
    'enabled': boolean().withDefault(false),
    'next': lazy((parent) => parent.nullable()),
  });
  testPrimitiveExports('nullable', {
    'nullable_bool': boolean().nullable(),
    'nullable_true': boolean().isTrue().nullable(),
    'nullable_false_default': boolean().nullable().withDefault(false),
    'nullable_inherited': boolean().withDefault(true).nullable(),
    'nullable_override_null': boolean()
        .withDefault(true)
        .nullable()
        .withDefault(null),
    'nullable_literal': literal('ok').nullable(),
    'nullable_literal_enum': literal('ok')
        .nullable()
        .enumerated(['ok', 'other']),
    'nullable_number_enum': number().nullable().enumerated([1, 2]),
    'nullable_empty_enum': number().nullable().enumerated([]),
    'nullable_enum_default': number()
        .nullable()
        .enumerated([1, 2])
        .withDefault(1),
    'nullable_child_default': string().withDefault('ok').nullable(),
    'nullable_list': list(boolean()).nullable(),
    'list_nullable': list(boolean().nullable()),
    'unique_nullable': list(boolean().nullable()).unique(),
    'unique_default_nullable': list(boolean().nullable().withDefault(false))
        .unique(),
    'contains_null': list(boolean().nullable()).contains(null),
    'contains_default': list(boolean().nullable().withDefault(false))
        .contains(false),
    'excludes_default_null': list(boolean().nullable().withDefault(false))
        .contains(null),
    'nullable_every': list(boolean().nullable().withDefault(false))
        .everyOf([false]),
    'object_nullable': object({'enabled': boolean().nullable()}),
    'object_null_default': object({
      'enabled': boolean().nullable().withDefault(null),
    }),
    'nullable_object': object({'enabled': boolean()}).nullable(),
    'recursive': tree,
  });

  test('nullable defaults have exact null output and presence contracts', () {
    final plain = boolean().nullable();
    final substituted = plain.withDefault(false);
    expect(
      fromJsonSchema(plain.toJsonSchema(mode: AcanthisSchemaMode.output))
          .validate(null),
      isTrue,
    );
    expect(
      fromJsonSchema(substituted.toJsonSchema(mode: AcanthisSchemaMode.output))
          .validate(null),
      isFalse,
    );
    expect(
      fromJsonSchema(substituted.toJsonSchema(mode: AcanthisSchemaMode.input))
          .validate(null),
      isTrue,
    );
    final schema = object({'value': literal(null).withDefault(null)});
    expect(
      schema.toOpenApiSchema(mode: AcanthisSchemaMode.input)['required'],
      isNull,
    );
    expect(
      schema.toOpenApiSchema(mode: AcanthisSchemaMode.output)['required'],
      ['value'],
    );
  });

  test('cached nullable contracts recheck mutable defaults and return fresh definitions', () {
    final nested = <String, Object?>{'enabled': true};
    final schema = object({'enabled': boolean()})
        .nullable()
        .withDefault(nested);
    for (var i = 0; i < 3; i++) {
      schema.toJsonSchema(mode: AcanthisSchemaMode.input).clear();
    }
    nested['enabled'] = 1;
    expect(
      () => schema.toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
  });

  test('nullable unsafe or opaque schemas reject export without callbacks', () {
    var calls = 0;
    final candidates = <Schema<Object?, Object?>>[
      string().nullable().refine(
        onCheck: (_) {
          calls++;
          return true;
        },
      ),
      boolean().nullable().refineAsync(
        CallbackAsyncCheck((_, _) async {
          calls++;
        }),
      ),
      list(number()).nullable().enumerated([
        [1],
      ]),
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
