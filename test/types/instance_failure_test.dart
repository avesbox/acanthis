import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:test/test.dart';

class _Payment {}

class _Card extends _Payment {}

class _Transfer extends _Payment {}

void main() {
  test('instance mismatch reports diagnostics without mocking', () {
    final schema = instance<_Card>();
    for (final input in [null, 'card', _Transfer()]) {
      final result = schema.tryParse(input) as AcanthisInvalid<_Card>;
      expect(result.hasValue, isFalse);
      expect(result.issues.single.code, 'type');
      expect(() => result.value, throwsStateError);
    }
    final card = _Card();
    expect(schema.tryParse(card).value, same(card));
    expect(schema.withDefault(card).tryParse('card').value, same(card));
  });

  test('instance unions continue past a mismatched first branch', () {
    final schema = union<_Payment>([instance<_Card>(), instance<_Transfer>()]);
    final transfer = _Transfer();
    expect(schema.parse(transfer), same(transfer));
    expect(schema.tryParse(transfer).value, same(transfer));
    expect(object({'payment': schema}).parse({'payment': transfer}), {
      'payment': transfer,
    });
    final invalid = schema.tryParse('payment') as AcanthisInvalid<_Payment>;
    expect(invalid.hasValue, isFalse);
    expect(invalid.issues.single.code, 'union');
    expect(invalid.issues.single.branches, hasLength(2));
    expect(() => schema.parse('payment'), throwsA(isA<ValidationError>()));
  });

  test('async instance unions continue past mismatched branches', () async {
    final cardSchema = instance<_Card>().withAsyncCheck(
      CustomAsyncCheck((_) async => true, error: 'card', name: 'card'),
    );
    final schema = union<_Payment>([cardSchema, instance<_Transfer>()]);
    final transfer = _Transfer();
    expect(await schema.parseAsync(transfer), same(transfer));
    expect((await schema.tryParseAsync(transfer)).value, same(transfer));
    final invalid = await schema.tryParseAsync('payment');
    expect(invalid, isA<AcanthisInvalid<_Payment>>());
    expect(invalid.issues.single.branches, hasLength(2));
    expect(
      await cardSchema.tryParseAsync(transfer),
      isA<AcanthisInvalid<_Card>>(),
    );
  });
}
