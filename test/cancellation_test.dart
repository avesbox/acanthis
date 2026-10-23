import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _External extends Schema<Object?, Object?>
    with AsyncSchema<Object?, Object?> {
  _External(this.callback);
  final AcanthisOutcome<Object?> Function() callback;
  @override
  Object? parse(Object? input) => callback().valueOrThrow;
  @override
  AcanthisOutcome<Object?> tryParse(Object? input) => callback();
  @override
  Future<Object?> parseAsync(Object? input) async => parse(input);
  @override
  Future<AcanthisOutcome<Object?>> tryParseAsync(Object? input) async =>
      callback();
}

void main() {
  test(
    'every native parse entry observes cancellation inside an active scope',
    () async {
      final tree = object({'children': lazy((parent) => parent.list())});
      final schemas = <Schema<Object?, Object?>>[
        string(),
        number(),
        AcanthisDate(),
        boolean(),
        literal(true),
        boolean().nullable(),
        list(boolean()),
        object({}),
        record(string(), boolean()),
        tuple([boolean()]),
        union<Object?>([boolean(), string()]),
        template(['hello']),
        tree,
        fromJsonSchema({'type': 'boolean'}),
      ];
      for (final schema in schemas) {
        final signal = AcanthisCancellationSignal();
        AcanthisValidationScope(cancellation: signal).run(() {
          signal.cancel();
          expect(
            () => schema.tryParse(null),
            throwsA(isA<AcanthisValidationCancelled>()),
            reason: '${schema.runtimeType}',
          );
          expect(
            () => schema.parse(null),
            throwsA(isA<AcanthisValidationCancelled>()),
          );
        });
        if (schema is AsyncSchema<Object?, Object?>) {
          final active = AcanthisCancellationSignal();
          await AcanthisValidationScope(cancellation: active).run(() async {
            active.cancel();
            await expectLater(
              schema.tryParseAsync(null),
              throwsA(isA<AcanthisValidationCancelled>()),
            );
            await expectLater(
              schema.parseAsync(null),
              throwsA(isA<AcanthisValidationCancelled>()),
            );
          });
        }
      }
    },
  );

  test(
    'collection and union boundaries stop after external schemas cancel',
    () async {
      for (final kind in ['object', 'list', 'record', 'tuple', 'union']) {
        final signal = AcanthisCancellationSignal();
        var later = 0;
        final first = _External(() {
          signal.cancel();
          return AcanthisInvalid.withoutValue([
            AcanthisIssue(path: [], code: 'failed'),
          ]);
        });
        final second = _External(() {
          later++;
          return const AcanthisValid(null);
        });
        final Schema<Object?, Object?> schema = switch (kind) {
          'object' => object({'first': first, 'second': second}),
          'list' => list(first),
          'record' => record(string(), first),
          'tuple' => tuple([first, second]),
          _ => union<Object?>([first, second]),
        };
        final input = kind == 'object'
            ? {'first': null, 'second': null}
            : kind == 'record'
            ? {'a': null, 'b': null}
            : [null, null];
        await expectLater(
          AcanthisValidationScope(cancellation: signal).run(
            () =>
                (schema as AsyncSchema<Object?, Object?>).tryParseAsync(input),
          ),
          throwsA(isA<AcanthisValidationCancelled>()),
        );
        expect(later, 0, reason: kind);
      }
    },
  );

  test('cancellation from variant guards never tries another branch', () {
    final signal = AcanthisCancellationSignal();
    var later = 0;
    final schema = union<Object?>([
      variant(
        guard: (_) {
          signal.cancel();
          return false;
        },
        schema: boolean(),
      ),
      variant(
        guard: (_) {
          later++;
          return true;
        },
        schema: string(),
      ),
    ]);
    expect(
      () =>
          AcanthisValidationScope(cancellation: signal)
              .run(() => schema.tryParse('a')),
      throwsA(isA<AcanthisValidationCancelled>()),
    );
    expect(later, 0);
  });
}
