import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import '../../example/schema_registry/billing.dart';
import '../../example/schema_registry/contracts.dart';
import '../../example/schema_registry/shipping.dart';

extension type _Email(String value) {}

extension type _Name(String value) {}

void main() {
  test('two consumer modules reuse a schema from a contract library', () {
    final registry = (SchemaRegistryBuilder()..add(addressKey, addressSchema))
        .build();
    final billing = billingSchema(registry);
    final shipping = shippingSchema(registry);
    expect(billing.fields['billing'], same(addressSchema));
    expect(shipping.fields['shipping'], same(addressSchema));
    expect(
      billing
          .tryParse({
            'billing': {'city': ''},
          })
          .issues
          .single
          .jsonPointer,
      '/billing/city',
    );
    expect(
      shipping.parse({
        'shipping': {'city': 'Rome'},
      }),
      {
        'shipping': {'city': 'Rome'},
      },
    );
  });

  test('erased brands retain separate domain tokens', () {
    final emailKey = SchemaKey<_Email, InstanceType<_Email>>('email');
    final nameKey = SchemaKey<_Name, InstanceType<_Name>>('name');
    final email = instance<_Email>();
    final name = instance<_Name>();
    final registry =
        (SchemaRegistryBuilder()
              ..add(emailKey, email)
              ..add(nameKey, name))
            .build();
    expect(registry.get(emailKey), same(email));
    expect(registry.get(nameKey), same(name));
    // Runtime type checks cannot establish nominal identity for erased brands.
    final impostor = SchemaKey<_Name, InstanceType<_Name>>('email');
    expect(registry.contains(impostor), isFalse);
    expect(
      () => registry.find(impostor),
      throwsA(
        isA<SchemaRegistryException>().having(
          (error) => error.reason,
          'reason',
          SchemaRegistryError.tokenConflict,
        ),
      ),
    );
  });

  test('defaults, optional fields and union behavior match direct reuse', () {
    const key = SchemaKey<Map<String, dynamic>, AcanthisMap<dynamic>>('record');
    final schema = object({
      'name': string().withDefault('guest'),
      'note': string(),
      'choice': union([literal('yes'), integer()]),
    }).optionals(['note']);
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    for (final input in [
      {'choice': 'yes'},
      {'choice': 3, 'note': 'ok'},
      {'choice': false},
    ]) {
      final direct = schema.tryParse(input);
      final actual = registry.get(key).tryParse(input);
      expect(actual.isValid, direct.isValid);
      expect(actual.value, direct.value);
      expect(actual.issues, direct.issues);
    }
    expect(registry.get(key).parse({'choice': 'yes'}), {
      'name': 'guest',
      'choice': 'yes',
    });
  });

  test('live sessions retain independent revisions and issues', () {
    const key = SchemaKey<Map<String, dynamic>, AcanthisMap<dynamic>>('form');
    final schema = object({'name': string().min(2)});
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    final direct = schema.watch({'name': 'Ada'});
    final reused = registry.get(key).watch({'name': 'Ada'});
    final expected = direct.set('name', '');
    final actual = reused.set('name', '');
    expect(actual.revision, expected.revision);
    expect(actual.issues, expected.issues);
    expect(actual.executedFields, expected.executedFields);
    reused.set('name', 'Grace');
    expect(reused.validated, {'name': 'Grace'});
    expect(direct.validated, isNull);
    expect(direct.revision, 1);
  });

  test(
    'concurrent validation contexts are not captured by the registry',
    () async {
      final entered = Completer<void>();
      var calls = 0;
      final schema = string().refineAsync(
        onCheck: (value) async {
          if (++calls == 2) entered.complete();
          await entered.future;
          return value == AcanthisValidationScope.current.context;
        },
        name: 'context',
        error: 'wrong context',
      );
      const key = SchemaKey<String, AcanthisType<String>>('context');
      final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
      final results = await Future.wait([
        const AcanthisValidationScope(context: 'first')
            .run(() => registry.get(key).tryParseAsync('first')),
        const AcanthisValidationScope(context: 'second')
            .run(() => registry.get(key).tryParseAsync('second')),
      ]);
      expect(results.every((result) => result.isValid), isTrue);
      expect(AcanthisValidationScope.current.context, isNull);
    },
  );

  test('registration leaves metadata and all existing exporters unchanged', () {
    const key = SchemaKey<String, AcanthisType<String>>('catalog.email');
    final schema = string().meta(MetadataEntry(title: 'Email'));
    final metadata = schema.metadataEntry;
    final legacy = schema.toJsonSchema();
    final legacyOpenApi = schema.toOpenApiSchema();
    final json = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
    final openApi = schema.exportOpenApiSchema(mode: AcanthisSchemaMode.input);
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    expect(registry.get(key).metadataEntry, same(metadata));
    expect(registry.get(key).toJsonSchema(), legacy);
    expect(registry.get(key).toOpenApiSchema(), legacyOpenApi);
    expect(
      registry.get(key).exportJsonSchema(mode: AcanthisSchemaMode.input),
      json,
    );
    expect(
      registry.get(key).exportOpenApiSchema(mode: AcanthisSchemaMode.input),
      openApi,
    );
    expect(MetadataRegistry().has(key.id), isFalse);
  });

  test('registration preserves unsupported export errors', () {
    const key = SchemaKey<String, AcanthisString>('email');
    final schema = string().email();
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    for (final candidate in [schema, registry.get(key)]) {
      expect(
        () => candidate.exportJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    }
  });
}
