import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

Matcher registryError(SchemaRegistryError reason, String id) =>
    isA<SchemaRegistryException>()
        .having((error) => error.reason, 'reason', reason)
        .having((error) => error.id, 'id', id);

void main() {
  const name = SchemaKey<String, AcanthisString>('name');
  const other = SchemaKey<String, AcanthisString>('other');

  test(
    'nested output types survive lookup, composition and module imports',
    () {
      const key =
          SchemaKey<List<Map<String, int>>, AcanthisList<Map<String, int>>>(
            'counts',
          );
      final schema = AcanthisMap<int>({'count': integer()}).list();
      final module = (SchemaRegistryBuilder()..add(key, schema)).build();
      final registry = (SchemaRegistryBuilder()..addAll(module)).build();
      final retrieved = registry.get(key);
      final found = registry.find(key);
      final List<Map<String, int>> parsed = retrieved.parse([
        {'count': 3},
      ]);
      final int count = parsed.single['count']!;
      final AcanthisList<Map<String, int>>? typedFound = found;
      final AcanthisType<Map<String, int>> element = retrieved.element;
      final composed = object({'counts': registry.get(key)});
      expect(count, 3);
      expect(typedFound, same(schema));
      expect(element, same(schema.element));
      expect(composed.fields['counts'], same(schema));
    },
  );

  test('widening cannot erase nested or output-only token constraints', () {
    const nested = SchemaKey<List<List<int>>, AcanthisList<List<int>>>(
      'nested',
    );
    const outputOnly = SchemaKey<String, AcanthisType<String>>('output');
    for (final key in <SchemaKey<Object?, AcanthisType<Object?>>>[
      nested,
      outputOnly,
    ]) {
      final builder = SchemaRegistryBuilder();
      expect(
        () => builder.add(key, string().list().list()),
        throwsA(registryError(SchemaRegistryError.incompatibleSchema, key.id)),
      );
      expect(builder.build().entries, isEmpty);
    }
    final schema = integer().list().list();
    final registry = (SchemaRegistryBuilder()..add(nested, schema)).build();
    final List<List<int>> value = registry.get(nested).parse([
      [1, 2],
    ]);
    expect(value.single, [1, 2]);
  });

  test('lookup preserves concrete static type and schema identity', () {
    final schema = string();
    final registry = (SchemaRegistryBuilder()..add(name, schema)).build();
    final retrieved = registry.get(name);
    final found = registry.find(name);
    expect(retrieved, same(schema));
    expect(found, same(schema));
    expect(retrieved.email().tryParse('a@example.com').isValid, isTrue);
    expect(registry.contains(name), isTrue);
  });

  test('missing lookup differs from a conflicting token', () {
    final registry = (SchemaRegistryBuilder()..add(name, string())).build();
    expect(registry.find(other), isNull);
    expect(registry.contains(other), isFalse);
    expect(
      () => registry.get(other),
      throwsA(registryError(SchemaRegistryError.missingBinding, 'other')),
    );
    final impostor = SchemaKey<String, AcanthisString>('name');
    expect(identical(impostor, name), isFalse);
    expect(registry.contains(impostor), isFalse);
    for (final lookup in [registry.get, registry.find]) {
      expect(
        () => lookup(impostor),
        throwsA(registryError(SchemaRegistryError.tokenConflict, 'name')),
      );
    }
  });

  test(
    'duplicate token, ID and schema alias are rejected without mutation',
    () {
      final original = string();
      final builder = SchemaRegistryBuilder()..add(name, original);
      for (final schema in [original, string().email()]) {
        expect(
          () => builder.add(name, schema),
          throwsA(registryError(SchemaRegistryError.duplicateToken, 'name')),
        );
      }
      expect(
        () => builder.add(SchemaKey<String, AcanthisString>('name'), string()),
        throwsA(registryError(SchemaRegistryError.duplicateId, 'name')),
      );
      expect(
        () => builder.add(other, original),
        throwsA(registryError(SchemaRegistryError.duplicateSchema, 'other')),
      );
      expect(builder.build().entries, hasLength(1));
      expect(builder.build().get(name), same(original));
      builder.add(other, string());
      expect(builder.build().entries, hasLength(2));
    },
  );

  test('invalid IDs are rejected at registration', () {
    final builder = SchemaRegistryBuilder();
    for (final id in ['', ' ', '1name', 'a/b', 'a b', 'é', 'a\n', 'a\r']) {
      expect(
        () => builder.add(SchemaKey<String, AcanthisString>(id), string()),
        throwsA(registryError(SchemaRegistryError.invalidId, id)),
      );
    }
    expect(builder.build().entries, isEmpty);
    for (final id in ['Name', 'name', '_name', 'accounts.email-v1']) {
      builder.add(SchemaKey<String, AcanthisString>(id), string());
    }
    expect(builder.build().entries.map((entry) => entry.id), [
      'Name',
      'name',
      '_name',
      'accounts.email-v1',
    ]);
  });

  test('widened and dynamic bindings retain token type checks', () {
    final builder = SchemaRegistryBuilder();
    final SchemaKey<dynamic, AcanthisType<dynamic>> widened = name;
    dynamic erased = name;
    for (final attempt in <void Function()>[
      () => builder.add(widened, integer()),
      () => builder.add<dynamic, AcanthisType<dynamic>>(erased, integer()),
      () => (builder as dynamic).add(erased, integer()),
    ]) {
      expect(
        attempt,
        throwsA(registryError(SchemaRegistryError.incompatibleSchema, 'name')),
      );
      expect(builder.build().entries, isEmpty);
    }
    final schema = string();
    builder.add(widened, schema);
    expect(builder.build().get(name), same(schema));
    expect(builder.build().get(widened), same(schema));
  });

  test('general schema keys deliberately expose a general interface', () {
    const key = SchemaKey<String, AcanthisType<String>>('general');
    final schema = string().email();
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    final AcanthisType<String> retrieved = registry.get(key);
    expect(retrieved, same(schema));
  });

  test('build takes independent snapshots with immutable ordered entries', () {
    final schema = string();
    final builder = SchemaRegistryBuilder()..add(name, schema);
    final before = builder.build();
    builder.add(other, string());
    final after = builder.build();
    expect(before.contains(other), isFalse);
    expect(after.contains(other), isTrue);
    expect(before.entries.single.key, same(name));
    expect(before.entries.single.schema, same(schema));
    expect(after.entries.map((entry) => entry.id), ['name', 'other']);
    expect(() => after.entries.clear(), throwsUnsupportedError);
    expect(() => after.entries[0] = after.entries[1], throwsUnsupportedError);
    expect(SchemaRegistryBuilder().build().find(name), isNull);
  });

  test('module import preserves order and identity', () {
    final schema = string();
    final module = (SchemaRegistryBuilder()..add(other, schema)).build();
    final builder = SchemaRegistryBuilder()..add(name, string());
    builder.addAll(module);
    final registry = builder.build();
    expect(registry.entries.map((entry) => entry.id), ['name', 'other']);
    expect(registry.get(other), same(schema));
    expect(module.entries, hasLength(1));
  });

  for (final reason in [
    SchemaRegistryError.duplicateToken,
    SchemaRegistryError.duplicateId,
    SchemaRegistryError.duplicateSchema,
  ]) {
    test('module import is atomic on ${reason.name}', () {
      final original = string();
      final builder = SchemaRegistryBuilder()..add(name, original);
      final collisionKey = switch (reason) {
        SchemaRegistryError.duplicateToken => name,
        SchemaRegistryError.duplicateId => SchemaKey<String, AcanthisString>(
          'name',
        ),
        _ => const SchemaKey<String, AcanthisString>('alias'),
      };
      final module =
          (SchemaRegistryBuilder()
                ..add(other, string())
                ..add(
                  collisionKey,
                  reason == SchemaRegistryError.duplicateSchema
                      ? original
                      : string(),
                ))
              .build();
      expect(
        () => builder.addAll(module),
        throwsA(registryError(reason, collisionKey.id)),
      );
      final unchanged = builder.build();
      expect(unchanged.entries, hasLength(1));
      expect(unchanged.get(name), same(original));
      expect(unchanged.find(other), isNull);
      builder.add(other, string());
      expect(builder.build().entries, hasLength(2));
    });
  }

  test('registration and lookup execute no callbacks; transforms run once', () {
    var calls = 0;
    final schema = string().transform((value) {
      calls++;
      return value.toUpperCase();
    });
    const key = SchemaKey<String, AcanthisType<String>>('transformed');
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    final imported = (SchemaRegistryBuilder()..addAll(registry)).build();
    imported.find(key);
    expect(calls, 0);
    expect(imported.get(key).parse('ada'), 'ADA');
    expect(calls, 1);
    const instanceKey = SchemaKey<Object, InstanceType<Object>>('instance');
    final instanceSchema = instance<Object>();
    expect(
      (SchemaRegistryBuilder()..add(instanceKey, instanceSchema)).build().get(
        instanceKey,
      ),
      same(instanceSchema),
    );
  });

  test('deriving a schema does not replace the registered base', () {
    final registry = (SchemaRegistryBuilder()..add(name, string())).build();
    final derived = registry.get(name).notEmpty();
    expect(derived.tryParse('').isValid, isFalse);
    expect(registry.get(name).tryParse('').isValid, isTrue);
  });

  test('reuse preserves ordered diagnostics at use-site paths', () {
    const key = SchemaKey<Map<String, dynamic>, AcanthisMap<dynamic>>(
      'common.address.v1',
    );
    final address = object({'city': string().min(2).min(3)});
    final registry = (SchemaRegistryBuilder()..add(key, address)).build();
    final reused = object({
      'billing': registry.get(key),
      'shipping': registry.get(key),
    });
    final direct = object({'billing': address, 'shipping': address});
    final input = {
      'billing': {'city': ''},
      'shipping': {'city': 'Rome'},
    };
    final result = reused.tryParse(input);
    expect(result.issues, direct.tryParse(input).issues);
    expect(result.issues.map((issue) => issue.jsonPointer), [
      '/billing/city',
      '/billing/city',
    ]);
    expect(reused.fields['billing'], same(address));
    expect(reused.fields['shipping'], same(address));
  });

  test('async validation and sync rejection are preserved', () async {
    var calls = 0;
    final schema = string().refineAsync(
      onCheck: (value) async {
        calls++;
        return value == 'valid';
      },
      name: 'remote',
      error: 'unavailable',
    );
    const key = SchemaKey<String, AcanthisType<String>>('remote');
    final registry = (SchemaRegistryBuilder()..add(key, schema)).build();
    final retrieved = registry.get(key);
    expect(calls, 0);
    expect(retrieved.isAsync, isTrue);
    expect(
      () => retrieved.tryParse('valid'),
      throwsA(isA<AsyncValidationException>()),
    );
    expect((await retrieved.tryParseAsync('valid')).isValid, isTrue);
    expect(
      (await retrieved.tryParseAsync('invalid')).issues,
      (await schema.tryParseAsync('invalid')).issues,
    );
    expect(calls, 3);
  });

  test('recursive schemas remain usable and export is unchanged', () {
    const key = SchemaKey<Map<String, dynamic>, AcanthisMap<dynamic>>('tree');
    final tree = object({'children': lazy((parent) => parent.list())});
    final before = tree.exportJsonSchema(mode: AcanthisSchemaMode.input);
    final registry = (SchemaRegistryBuilder()..add(key, tree)).build();
    final input = {
      'children': [
        {'children': <dynamic>[]},
      ],
    };
    expect(registry.get(key).parse(input), tree.parse(input));
    expect(
      registry.get(key).exportJsonSchema(mode: AcanthisSchemaMode.input),
      before,
    );
  });
}
