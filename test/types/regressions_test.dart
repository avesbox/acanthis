import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('async object and list entry points transform exactly once', () async {
    for (final asyncChild in [false, true]) {
      var calls = 0;
      final leaf = string().transform((v) {
        calls++;
        return '$v!';
      });
      final child = asyncChild
          ? leaf.refineAsync(
              onCheck: (_) async => true,
              name: 'remote',
              error: 'rejected',
            )
          : leaf;
      final map = object({'a': child});
      expect((await map.parseAsync({'a': 'v'})).value, {'a': 'v!'});
      expect((await map.tryParseAsync({'a': 'v'})).value, {'a': 'v!'});
      expect((await child.list().parseAsync(['v'])).value, ['v!']);
      expect((await child.list().tryParseAsync(['v'])).value, ['v!']);
      expect(calls, 4);
    }
  });

  test(
    'nested stripping copies only changed ancestors in all entry points',
    () async {
      for (final constrained in [false, true]) {
        final child = object({'a': constrained ? string().min(1) : string()});
        final schema = object({'child': child, 'items': child.list()});
        final nested = {'a': 'ok', 'extra': true};
        final input = {
          'child': nested,
          'items': [nested],
        };
        final expected = {
          'child': {'a': 'ok'},
          'items': [
            {'a': 'ok'},
          ],
        };
        for (final result in [
          schema.parse(input),
          schema.tryParse(input),
          await schema.parseAsync(input),
          await schema.tryParseAsync(input),
        ]) {
          expect(result.success, isTrue);
          expect(result.value, expected);
          expect(identical(result.value, input), isFalse);
          expect(nested['extra'], isTrue);
        }
        final clean = {
          'child': {'a': 'ok'},
          'items': [
            {'a': 'ok'},
          ],
        };
        expect(identical(schema.parse(clean).value, clean), isTrue);
      }
    },
  );

  test('non-throwing APIs report wrong container types and map keys', () async {
    final asyncLeaf = string().refineAsync(
      onCheck: (_) async => true,
      name: 'remote',
      error: 'rejected',
    );
    for (final leaf in [string(), asyncLeaf]) {
      final map = object({'a': leaf});
      final list = leaf.list();
      for (final value in [42, null, 'wrong']) {
        expect((await map.tryParseAsync(value)).success, isFalse);
        expect((await list.tryParseAsync(value)).success, isFalse);
      }
      expect(
        (await map.tryParseAsync(<dynamic, dynamic>{1: true})).success,
        isFalse,
      );
      final parent = object({'child': map, 'items': list});
      final invalid = {'child': 42, 'items': 42};
      final result = await parent.tryParseAsync(invalid);
      expect(result.errors.keys, containsAll(['child', 'items']));
      if (!parent.isAsync) {
        expect(
          parent.tryParse(invalid).errors.keys,
          containsAll(['child', 'items']),
        );
      }
    }
  });

  test('passthrough preserves extras at its own level', () async {
    final schema = object({
      'child': object({'a': string()}).passthrough(),
    });
    final input = {
      'child': {'a': 'ok', 'extra': true},
      'rootExtra': true,
    };
    expect(schema.parse(input).value, {
      'child': {'a': 'ok', 'extra': true},
    });
    final remote = string().refineAsync(
      onCheck: (_) async => true,
      error: 'bad',
      name: 'remote',
    );
    final result = await object({'a': remote})
        .passthrough(type: string())
        .tryParseAsync({'a': 'ok', 'extra': 'ok'});
    expect(result.success, isTrue);
  });
}
