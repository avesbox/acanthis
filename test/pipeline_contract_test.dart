import 'dart:async';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'source output is converted once and target transforms run afterwards',
    () {
      var conversions = 0;
      final pipeline = string().trim().pipe(
        integer().gte(1).transform((v) => v + 1),
        transform: (v) {
          conversions++;
          return int.parse(v);
        },
      );
      final int parsed = pipeline.parse(' 2 ');
      expect(parsed, 3);
      expect(conversions, 1);
      expect(pipeline.validate('0'), isFalse);
      final failed = pipeline.tryParse('0') as AcanthisInvalid<int>;
      expect(failed.hasValue, isTrue);
      expect(failed.value, 0);
      expect(failed.issues.single.code, 'gte');
    },
  );

  test('invalid source stops conversion even when it has typed recovery', () {
    var conversions = 0;
    var targetCalls = 0;
    final pipeline = string()
        .min(2)
        .pipe(
          integer().refine(
            onCheck: (_) {
              targetCalls++;
              return true;
            },
          ),
          transform: (v) {
            conversions++;
            return v.length;
          },
        );
    for (final value in ['x', 1]) {
      final result = pipeline.tryParse(value) as AcanthisInvalid<int>;
      expect(result.hasValue, isFalse);
      expect(() => result.value, throwsStateError);
      expect(() => pipeline.parse(value), throwsA(isA<ValidationError>()));
    }
    expect(conversions, 0);
    expect(targetCalls, 0);
  });

  test(
    'format failures are diagnostics while programming errors propagate',
    () async {
      final parse = string().pipe(integer(), transform: int.parse);
      expect(parse.tryParse('bad').issues.single.code, 'transform');
      expect(
        (await parse.tryParseAsync('bad')).issues.single.code,
        'transform',
      );
      final throwing = string().pipe(
        integer(),
        transform: (_) => throw StateError('bug'),
      );
      expect(() => throwing.tryParse('ok'), throwsStateError);
      await expectLater(throwing.tryParseAsync('ok'), throwsStateError);
      expect(
        object({'age': parse}).tryParse({'age': 'bad'}).issues.single.path,
        ['age'],
      );
    },
  );

  test('defaults bypass conversion and are still checked and transformed by the target', () async {
    var conversions = 0;
    final pipeline = string().pipe(
      integer().gte(1).transform((v) => v + 1),
      transform: (s) {
        conversions++;
        return int.parse(s);
      },
      defaultValue: 2,
    );
    expect(pipeline.parse(null), 3);
    expect(await pipeline.parseAsync(null), 3);
    expect(object({'age': pipeline}).parse({})['age'], 3);
    expect(pipeline.withDefault(0).validate(null), isFalse);
    expect(conversions, 0);
    // An explicit input equal to the output default still passes through the source.
    expect(pipeline.tryParse(2).isValid, isFalse);
  });

  test(
    'nullable output and explicit null defaults remain correctly typed',
    () async {
      final pipeline = string()
          .pipe(
            integer().nullable(),
            transform: (s) => s == 'null' ? null : int.parse(s),
          )
          .withDefault(null);
      final int? parsed = pipeline.parse('null');
      expect(parsed, isNull);
      expect(await pipeline.parseAsync(null), isNull);
      expect(object({'age': pipeline}).parse({}), {'age': null});
      expect(pipeline.list().parse(['1', 'null']), <int?>[1, null]);
      expect(pipeline.nullable().parse(null), isNull);
    },
  );

  test(
    'async stages preserve order, context, and post-pipeline operations',
    () async {
      final order = <String>[];
      final source = string().refineAsync(
        CallbackAsyncCheck((v, c) async {
          order.add('input:${c.context}');
        }),
      );
      final target = integer().refineAsync(
        CallbackAsyncCheck((v, c) async {
          order.add('target');
          if (v < 0) c.addIssue('negative');
        }),
      );
      final pipeline = source
          .pipe(
            target,
            transform: (s) {
              order.add('convert');
              return int.parse(s);
            },
          )
          .transform((v) {
            order.add('outer');
            return v + 1;
          });
      expect(pipeline.isAsync, isTrue);
      expect(() => pipeline.parse('1'), throwsStateError);
      expect(
        await const AcanthisValidationScope(context: 'tenant')
            .run(() => pipeline.parseAsync('1')),
        2,
      );
      expect(order, ['input:tenant', 'convert', 'target', 'outer']);
      order.clear();
      expect(await pipeline.validateAsync('-1'), isFalse);
      expect(order, ['input:null', 'convert', 'target']);
    },
  );

  test(
    'cancellation between input and conversion stops both later stages',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final cancellation = AcanthisCancellationSignal();
      var conversions = 0;
      final pipeline = string()
          .refineAsync(
            CallbackAsyncCheck((v, c) async {
              entered.complete();
              await release.future;
            }),
          )
          .pipe(
            integer(),
            transform: (s) {
              conversions++;
              return int.parse(s);
            },
          );
      final future = AcanthisValidationScope(cancellation: cancellation)
          .run(() => pipeline.parseAsync('2'));
      final assertion = expectLater(
        future,
        throwsA(isA<AcanthisValidationCancelled>()),
      );
      await entered.future;
      cancellation.cancel();
      release.complete();
      await assertion;
      expect(conversions, 0);
    },
  );

  test(
    'pipe composes in live objects, chains, and carries its own metadata',
    () {
      final source = string().pipe(integer(), transform: int.parse);
      final pipeline = source
          .pipe(string(), transform: (n) => 'age:$n')
          .meta(const MetadataEntry<String>(title: 'Age'))
          .transform((s) => s.toUpperCase());
      expect(pipeline.metadataEntry!.title, 'Age');
      final session = object({'age': pipeline, 'name': string()})
          .watch({'age': '2', 'name': 'Ada'});
      session.set('name', 'Grace');
      expect(session.validated, {'age': 'AGE:2', 'name': 'Grace'});
      session.set('age', '3');
      expect(session.validated!['age'], 'AGE:3');
    },
  );

  test('strict export rejects opaque conversion without calling it', () {
    var conversions = 0;
    final pipeline = string().pipe(
      integer(),
      transform: (s) {
        conversions++;
        return int.parse(s);
      },
    );
    for (final mode in AcanthisSchemaMode.values) {
      expect(
        () => pipeline.toJsonSchema(mode: mode),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    }
    expect(conversions, 0);
  });
}
