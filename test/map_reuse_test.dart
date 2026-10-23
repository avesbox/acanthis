import 'support/parse_result.dart';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'primitive objects reuse typed input at every plan size and key order',
    () {
      for (final size in [0, 1, 2, 3, 4, 32]) {
        final schema = object({
          for (var i = 0; i < size; i++) 'n$i': integer(),
        });
        for (final reverse in [false, true]) {
          final indexes = List.generate(size, (i) => i);
          final input = <String, Object?>{
            for (final i in reverse ? indexes.reversed : indexes) 'n$i': i,
          };
          for (final policy in AcanthisUnknownKeys.values) {
            final configured = schema.unknownKeys(policy);
            expect(configured.parseResult(input).value, same(input));
            expect(configured.tryParse(input).value, same(input));
            expect(configured.parseResult(input).value.keys, input.keys);
          }
        }
      }
    },
  );

  test('checked nested objects and lists reuse every unchanged container', () {
    final child = object({'n': integer().gte(0)});
    for (final size in [1, 2, 3, 4]) {
      final schema = object({for (var i = 0; i < size; i++) 'child$i': child});
      final input = <String, Object?>{
        for (var i = 0; i < size; i++) 'child$i': <String, Object?>{'n': i},
      };
      expect(schema.tryParse(input).value, same(input));
    }
    final schema = object({'items': list(child)});
    final input = <String, Object?>{
      'items': <Map<String, Object?>>[
        {'n': 1},
      ],
    };
    expect(schema.parseResult(input).value, same(input));
  });

  test(
    'only changed ancestors are copied and unchanged siblings are shared',
    () {
      final changed = object({'name': string().trim()});
      final unchanged = object({'n': integer()});
      final schema = object({'changed': changed, 'unchanged': unchanged});
      final input = <String, Object?>{
        'changed': <String, Object?>{'name': ' Ada '},
        'unchanged': <String, Object?>{'n': 1},
      };
      final output = schema.parseResult(input).value;
      expect(output, isNot(same(input)));
      expect(output['changed'], isNot(same(input['changed'])));
      expect(output['unchanged'], same(input['unchanged']));
      expect((output['changed']! as Map)['name'], 'Ada');
      expect((input['changed']! as Map)['name'], ' Ada ');
    },
  );

  test(
    'stripping and defaults copy, while preserved and omitted fields reuse',
    () {
      final schema = object({'n': integer()});
      final extra = <String, Object?>{'n': 1, 'extra': true};
      expect(schema.parseResult(extra).value, {'n': 1});
      expect(extra['extra'], isTrue);
      expect(
        schema
            .unknownKeys(AcanthisUnknownKeys.preserve)
            .parseResult(extra)
            .value,
        same(extra),
      );
      expect(
        schema
            .unknownKeys(AcanthisUnknownKeys.reject)
            .parseResult(extra)
            .isValid,
        isFalse,
      );
      final empty = <String, Object?>{};
      expect(schema.optionals(['n']).parseResult(empty).value, same(empty));
      expect(schema.partial().parseResult(empty).value, same(empty));
      final defaulted = object({'n': integer().withDefault(1)})
          .parseResult(empty)
          .value;
      expect(defaulted, {'n': 1});
      expect(defaulted, isNot(same(empty)));
      expect(empty, isEmpty);
    },
  );

  test(
    'map callbacks receive a separate root even when children are unchanged',
    () async {
      final input = <String, Object?>{'n': 1};
      final schema = object({'n': integer()}).transform((value) {
        value['n'] = 2;
        return value;
      });
      expect(schema.parseResult(input).value, {'n': 2});
      expect(input['n'], 1);
      final checked = object({'n': integer()}).refine(
        onCheck: (value) {
          value['n'] = 3;
          return true;
        },
      );
      expect((await checked.tryParseAsync(input)).value, {'n': 3});
      expect(input['n'], 1);
    },
  );

  test(
    'untyped maps are rebuilt and read-only typed maps retain mutability',
    () {
      final schema = object({'n': integer()});
      final untyped = <Object?, Object?>{'n': 1};
      final output = schema.parseResult(untyped).value;
      expect(output, isA<Map<String, Object?>>());
      expect(output, isNot(same(untyped)));
      final immutable = Map<String, Object?>.unmodifiable({'n': 1});
      expect(schema.parseResult(immutable).value, same(immutable));
      expect(
        () => schema.parseResult(immutable).value['n'] = 2,
        throwsUnsupportedError,
      );
    },
  );

  test('records reuse typed keys and values and copy converted entries', () {
    final schema = record(string(), integer());
    final input = <String, int>{'a': 1, 'b': 2};
    expect(schema.parseResult(input).value, same(input));
    expect(schema.tryParse(input).value, same(input));
    final converted = record(string().trim(), integer().coerce());
    final raw = <String, Object?>{' a ': '1'};
    expect(converted.parseResult(raw).value, {'a': 1});
    expect(raw, {' a ': '1'});
    final untyped = <Object?, Object?>{'a': 1};
    expect(schema.parseResult(untyped).value, isNot(same(untyped)));
  });

  test(
    'async child parsing reuses unchanged maps and copies converted values',
    () async {
      final checked = integer().refineAsync(
        CallbackAsyncCheck<int>((value, context) async {
          if (value < 0) context.addIssue('positive');
        }),
      );
      final input = <String, Object?>{'n': 1};
      final schema = object({'n': checked});
      expect((await schema.parseResultAsync(input)).value, same(input));
      expect((await schema.tryParseAsync(input)).value, same(input));
      final converted = object({'n': checked.transform((value) => value + 1)});
      final changed = (await converted.parseResultAsync(input)).value;
      expect(changed, {'n': 2});
      expect(changed, isNot(same(input)));
      expect(input['n'], 1);
      final transformed = schema.transformAsync(
        CallbackAsyncTransform((value) async {
          value['n'] = 3;
          return value;
        }),
      );
      expect((await transformed.tryParseAsync(input)).value, {'n': 3});
      expect(input['n'], 1);
      final typed = <String, int>{'a': 1};
      expect(
        (await record(string(), checked).parseResultAsync(typed)).value,
        same(typed),
      );
    },
  );

  test(
    'recursive lazy objects share unchanged trees without skipping checks',
    () {
      final schema = object({
        'n': integer().gte(0),
        'children': lazy((parent) => list(parent)),
      });
      final input = <String, Object?>{
        'n': 1,
        'children': <Map<String, Object?>>[
          {'n': 2, 'children': <Map<String, Object?>>[]},
        ],
      };
      expect(schema.parseResult(input).value, same(input));
      final child = (input['children']! as List).single as Map;
      child['n'] = -1;
      expect(schema.tryParse(input).isValid, isFalse);
    },
  );
}
