import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

// Subclasses deliberately use the generic validator path.
class _GenericString extends AcanthisString {}

class _CustomMap extends AcanthisMap<dynamic> {
  _CustomMap() : super({'a': AcanthisString()});

  @override
  Map<String, dynamic> coerceInput(dynamic value) => {'custom': true};
}

class _CustomString extends AcanthisString {
  final _calls = [0];
  int get calls => _calls[0];
  @override
  String parseInternal(dynamic value) {
    _calls[0]++;
    return super.parseInternal(value);
  }

  @override
  String tryParseInternal(
    dynamic value, {
    required Map<String, dynamic> errors,
  }) {
    _calls[0]++;
    return super.tryParseInternal(value, errors: errors);
  }
}

void main() {
  test(
    'specialized objects match generic output, ordering and diagnostics',
    () {
      for (final nested in [false, true]) {
        AcanthisMap schema(bool generic) {
          AcanthisType leaf() => generic ? _GenericString() : string();
          return object({
            'a': leaf(),
            'b': nested ? object({'c': leaf(), 'd': leaf()}) : leaf(),
          });
        }

        final fast = schema(false);
        final generic = schema(true);
        final second = nested ? {'c': 'C', 'd': 'D', 'extra': true} : 'B';
        for (final payload in [
          {'b': second, 'a': 'A'},
          {'extra': true, 'b': second, 'a': 'A'},
          {'b': second},
          {'a': null, 'b': second},
          {'a': 42, 'b': second},
          {
            'a': 'A',
            'b': nested ? {'c': 42, 'd': null} : 42,
          },
        ]) {
          final expected = generic.tryParse(payload);
          final actual = fast.tryParse(payload);
          expect(actual.success, expected.success);
          expect(actual.errors, expected.errors);
          expect(actual.value, expected.value);
          expect(actual.value.keys.toList(), expected.value.keys.toList());
          if (actual.success) {
            final parsed = fast.parse(payload).value;
            expect(parsed, generic.parse(payload).value);
            expect(
              identical(parsed, payload),
              !nested && !payload.containsKey('extra'),
            );
            parsed['a'] = 'changed';
            expect(
              payload['a'],
              nested || payload.containsKey('extra') ? 'A' : 'changed',
            );
          }
        }
        expect(fast.tryParse({'a': 'A', 'b': second}).success, isTrue);
      }
    },
  );

  test('primitive kinds retain their exact accepted types', () {
    final schema = object({
      'text': string(),
      'flag': boolean(),
      'integer': AcanthisNumeric<int>(),
      'double': AcanthisNumeric<double>(),
      'number': AcanthisNumeric<num>(),
    });
    final valid = <String, dynamic>{
      'text': 'ok',
      'flag': true,
      'integer': 1,
      'double': 1.5,
      'number': 2,
    };
    expect(schema.parse(valid).value, valid);
    expect(schema.tryParse(valid).success, isTrue);
    for (final field in valid.keys) {
      expect(schema.tryParse({...valid, field: null}).success, isFalse);
      expect(schema.tryParse({...valid}..remove(field)).success, isFalse);
    }
    expect(schema.tryParse({...valid, 'integer': 1.5}).success, isFalse);
    expect(schema.tryParse({...valid, 'double': '1.5'}).success, isFalse);
  });

  test('optional, nullable, defaults, coercion and transforms use normal semantics', () {
    final schema = object({
      'optional': string(),
      'nullable': string().nullable(),
      'default': string().min(2).withDefault('fallback'),
      'coerced': string().coerce(),
      'transformed': string().transform((v) => '$v!'),
    }).optionals(['optional']);
    final result = schema.tryParse({
      'nullable': null,
      'default': '',
      'coerced': 42,
      'transformed': 'ok',
    });
    expect(result.success, isFalse);
    expect(result.value['default'], 'fallback');
    expect(result.value['coerced'], '42');
    expect(result.value['transformed'], 'ok!');
    expect(result.errors.keys, ['default']);
  });

  test('custom subclasses and object refinements are never bypassed', () {
    expect(_CustomMap().parse({'a': 'ok'}).value, {'custom': true});
    expect(_CustomMap().tryParse({'a': 'ok'}).value, {'custom': true});
    final child = _CustomString();
    final schema = object({'a': child});
    schema.parse({'a': 'ok'});
    schema.tryParse({'a': 'ok'});
    expect(child.calls, 2);
    var calls = 0;
    final refined = object({'a': string()}).refine(
      onCheck: (_) {
        calls++;
        return false;
      },
      error: 'rejected',
      name: 'rule',
    );
    expect(refined.tryParse({'a': 'ok'}).success, isFalse);
    expect(calls, 1);
  });

  test('flattened traversal handles deep objects and sibling branches', () {
    final schema = object({
      'left': object({
        'inner': object({'text': string()}),
      }),
      'right': object({'flag': boolean()}),
      'last': string(),
    });
    final payload = {
      'left': {
        'inner': {'text': 'ok'},
      },
      'right': {'flag': true},
      'last': 'ok',
    };
    expect(schema.parse(payload).value, payload);
    expect(
      schema
          .tryParse({
            ...payload,
            'right': {'flag': 42},
          })
          .errors
          .keys,
      ['right'],
    );
    expect(schema.tryParse(payload).success, isTrue);
  });

  test('generic map keys and empty schemas retain copy/stripping behavior', () {
    final schema = object({'a': string()});
    expect(schema.parse(<dynamic, dynamic>{'a': 'ok'}).value, {'a': 'ok'});
    expect(
      () => schema.parse(<dynamic, dynamic>{'a': 'ok', 1: 'bad'}),
      throwsA(isA<TypeError>()),
    );
    expect(object({}).parse({'unknown': true}).value, isEmpty);
  });
}
