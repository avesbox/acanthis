import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'imported patterns and tuple prefixes validate their own boundaries',
    () {
      final pattern = Acanthis.fromJsonSchema({'pattern': '^a'});
      expect(pattern.tryParse('abc').isValid, isTrue);
      expect(pattern.tryParse('b').isValid, isFalse);
      expect(pattern.tryParse(1).isValid, isTrue);
      final prefix = Acanthis.fromJsonSchema({
        'prefixItems': [
          {'type': 'string'},
        ],
      });
      expect(prefix.tryParse(['a', 1]).isValid, isTrue);
      expect(prefix.tryParse([1]).issues.single.path, [0]);
    },
  );
  test('tuple throwing traversal stops before later callbacks', () {
    var calls = 0;
    final schema = Acanthis.tuple([
      Acanthis.number(),
      Acanthis.string().refine(
        onCheck: (_) {
          calls++;
          return false;
        },
      ),
    ]);
    expect(() => schema.parse([false, 'x']), throwsA(isA<ValidationError>()));
    expect(calls, 0);
    expect(schema.tryParse([false, 'x']).issues.length, 2);
    expect(calls, 1);
  });
  test(
    'unions prioritize guards, retain branch errors and freeze definitions',
    () {
      final parts = <Object?>[
        Acanthis.string().coerce(),
        variant<num>(guard: (v) => v is num, schema: Acanthis.number()),
      ];
      final schema = Acanthis.union<Object?>(parts);
      parts.clear();
      expect(schema.parse(4), 4);
      final failed = Acanthis.union<String>([
        Acanthis.literal('a'),
        variant<String>(
          guard: (_) => false,
          schema: Acanthis.string(),
          name: 'skip',
        ),
      ]).tryParse(3);
      expect(failed.issues.single.branches.first.single.code, 'variantGuard');
      expect(failed.issues.single.branches.length, 2);
      expect((failed as AcanthisInvalid).hasValue, isFalse);
      expect(Acanthis.union([]).tryParse('x').isValid, isFalse);
      expect(() => Acanthis.union<String>([3]), throwsArgumentError);
    },
  );
  test('tuple shape, variadic prefix, snapshots and immutable derivations', () {
    final elements = <Schema<Object?, Object?>>[
      Acanthis.string(),
      Acanthis.number(),
    ];
    final schema = Acanthis.tuple(elements)
        .variadic()
        .withDefault(['x'])
        .refine(onCheck: (_) => true);
    elements.clear();
    expect(schema.parse(null), ['x']);
    expect(schema.parse(['x', 1, 2]), ['x', 1, 2]);
    expect(schema.tryParse([]).isValid, isFalse);
    expect(Acanthis.tuple([]).parse([]), isEmpty);
    expect(() => Acanthis.tuple([]).variadic(), throwsStateError);
    expect(
      Acanthis.tuple([Acanthis.string()])
          .tryParse(['x', 'y'])
          .issues
          .single
          .code,
      'tuple',
    );
  });
  test(
    'nested collecting errors preserve indices without fabricated output',
    () {
      final schema = Acanthis.object({
        'items': Acanthis.tuple([
          Acanthis.union<String>([Acanthis.literal('a')]),
          Acanthis.number(),
        ]),
      });
      final result = schema.tryParse({
        'items': [false, false],
      });
      expect(result.issues.map((i) => i.path), [
        ['items', 0],
        ['items', 1],
      ]);
      expect(result.issues.first.branches.single.single.path, ['items', 0]);
      expect(
        () => schema.parse({
          'items': [false, false],
        }),
        throwsA(isA<ValidationError>()),
      );
    },
  );
  test('own operations execute once and stop at failed transformations', () {
    var calls = 0;
    final schema = Acanthis.union<String>([Acanthis.string()])
        .transform((v) {
          calls++;
          return v.toUpperCase();
        })
        .refine(onCheck: (_) => false)
        .transform((v) => throw StateError('unreachable'));
    expect(schema.tryParse('a').isValid, isFalse);
    expect(calls, 1);
    expect(
      () => Acanthis.union([
        variant(
          guard: (_) => throw StateError('guard'),
          schema: Acanthis.string(),
        ),
      ]).tryParse('a'),
      throwsStateError,
    );
  });
  test(
    'async branches, tuples and own operations propagate capability',
    () async {
      final child = Acanthis.string().refineAsync(
        CallbackAsyncCheck((v, c) async {
          if (v != 'ok') c.addIssue('custom');
        }),
      );
      final schema = Acanthis.tuple([
        Acanthis.union<String>([child]),
      ]).variadic();
      expect(schema.isAsync, isTrue);
      expect(() => schema.parse(['ok']), throwsStateError);
      expect(await schema.parseAsync(['ok', 'ok']), ['ok', 'ok']);
      expect((await schema.tryParseAsync(['bad'])).issues.single.path, [0]);
      final own = Acanthis.union<String>([Acanthis.string()])
          .transformAsync(CallbackAsyncTransform((v) async => v.toUpperCase()));
      expect(await own.parseAsync('ok'), 'OK');
    },
  );
  test(
    'template shapes escape text, support scalars, patterns and operations',
    () async {
      final schema = Acanthis.template([
        'id.',
        Acanthis.integer(),
        '-',
        Acanthis.union([Acanthis.literal('a'), Acanthis.literal('b')]),
      ]);
      expect(schema.parse('id.12-a'), 'id.12-a');
      expect(schema.tryParse('idX12-a').isValid, isFalse);
      expect(schema.tryParse('id.12-a\n').isValid, isFalse);
      expect(
        Acanthis.template([Acanthis.string().pattern(RegExp(r'^[a-z]+$'))])
            .tryParse('123')
            .isValid,
        isFalse,
      );
      expect(Acanthis.template([Acanthis.boolean()]).parse('true'), 'true');
      var calls = 0;
      final transformed = schema.transform((v) {
        calls++;
        return v.toUpperCase();
      });
      expect(await transformed.parseAsync('id.1-b'), 'ID.1-B');
      expect(calls, 1);
      expect(transformed.tryParse('bad').isValid, isFalse);
      expect(calls, 1);
      expect(() => Acanthis.template([]), throwsArgumentError);
      expect(() => Acanthis.template([1]), throwsArgumentError);
    },
  );
  test(
    'audited composition exports round trip and reject opaque callbacks',
    () {
      for (final schema in <Schema<Object?, Object?>>[
        Acanthis.union([Acanthis.string(), Acanthis.number()]),
        Acanthis.tuple([Acanthis.string(), Acanthis.number()]),
        Acanthis.tuple([Acanthis.string(), Acanthis.number()]).variadic(),
        Acanthis.template(['id-', Acanthis.number()]),
      ]) {
        final imported = Acanthis.fromJsonSchema(
          schema.toJsonSchema(mode: AcanthisSchemaMode.input),
        );
        for (final input in <Object?>[
          'a',
          'id-12',
          ['x'],
          ['x', 1],
          ['x', 1, 2],
          false,
          null,
        ]) {
          expect(
            imported.tryParse(input).isValid,
            schema.tryParse(input).isValid,
          );
        }
      }
      expect(
        () => Acanthis.union([
          variant(guard: (_) => true, schema: Acanthis.string()),
        ]).toJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    },
  );
}
