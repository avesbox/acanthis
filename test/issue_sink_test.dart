import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/common/issue_sink.dart';
import 'package:test/test.dart';

AcanthisIssue issue(String code, {List<Object> path = const []}) =>
    AcanthisIssue(path: path, code: code);

class _ThrowingIssues extends ListBase<AcanthisIssue> {
  @override
  int get length => 2;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  AcanthisIssue operator [](int index) =>
      index == 0 ? issue('partial') : throw StateError('source failed');
  @override
  void operator []=(int index, AcanthisIssue value) =>
      throw UnsupportedError('read only');
}

void main() {
  test('empty sink and empty publication remain reusable', () {
    final sink = IssueSink();
    expect(sink.isEmpty, isTrue);
    expect(sink.isNotEmpty, isFalse);
    expect(sink.length, 0);
    expect(sink.issueCount, 0);
    expect(sink, isEmpty);
    expect(sink.issues, isEmpty);
    expect(sink.takeIssues(), isEmpty);
    sink.addIssue('type');
    expect(sink.length, 1);
  });

  test('emission preserves duplicate codes, paths and insertion order', () {
    final sink = IssueSink()
      ..addIssue('min', path: ['a'], parameters: {'limit': 3})
      ..addIssue('min', path: ['a'], parameters: {'limit': 5})
      ..add(issue('third', path: ['b']));
    expect(sink.map((i) => i.code), ['min', 'min', 'third']);
    expect(sink.issues.map((i) => i.parameters), [
      {'limit': 3},
      {'limit': 5},
      {},
    ]);
    expect(sink.isNotEmpty, isTrue);
    expect(sink.issues, hasLength(3));
    expect(sink, isNot(isA<Map>()));
  });

  test('snapshot is cached, immutable and isolated from later mutation', () {
    final sink = IssueSink()..add(issue('first'));
    final first = sink.issues;
    expect(sink.issues, same(first));
    expect(() => first.add(issue('bad')), throwsUnsupportedError);
    expect(() => first[0] = issue('bad'), throwsUnsupportedError);
    sink.add(issue('second'));
    final second = sink.issues;
    expect(first.map((i) => i.code), ['first']);
    expect(second.map((i) => i.code), ['first', 'second']);
    expect(second, isNot(same(first)));
    sink.clear();
    sink.add(issue('third'));
    expect(second, hasLength(2));
    expect(sink.issues.single.code, 'third');
  });

  test('ownership transfer publishes without copying and resets state', () {
    final sink = IssueSink()..add(issue('first'));
    final drained = sink.takeIssues();
    expect(sink.isEmpty, isTrue);
    expect(() => drained.clear(), throwsUnsupportedError);
    sink.add(issue('second'));
    expect(drained.single.code, 'first');
    final outcome = AcanthisInvalid<int>(drained, value: 0);
    expect(outcome.issues, same(drained));
    expect(outcome.isValid, isFalse);
  });

  test('ownership transfer reuses an already published snapshot', () {
    final sink = IssueSink()..add(issue('first'));
    final published = sink.issues;
    expect(sink.takeIssues(), same(published));
    expect(sink.issues, isEmpty);
    expect(sink.takeIssues(), isEmpty);
    sink.clear();
    expect(published.single.code, 'first');
  });

  test(
    'external lists and unmodifiable views cannot bypass outcome freezing',
    () {
      final source = [issue('original')];
      final externallyFrozen = UnmodifiableListView(source);
      final result = AcanthisInvalid<int>(externallyFrozen, value: 0);
      source[0] = issue('changed');
      expect(result.issues.single.code, 'original');
      expect(() => result.issues.clear(), throwsUnsupportedError);
      final noValue = AcanthisInvalid<int>.withoutValue(source);
      source.clear();
      expect(noValue.issues.single.code, 'changed');
      expect(noValue.hasValue, isFalse);
      expect(() => noValue.value, throwsStateError);
    },
  );

  test('nullable recovery is distinct from missing recovery', () {
    final result = AcanthisInvalid<int?>([issue('wrong')], value: null);
    expect(result.hasValue, isTrue);
    expect(result.value, isNull);
    expect(const AcanthisValid<int?>(null).issues, isEmpty);
  });

  test('bulk append accepts lists, sinks and lazy native iterables', () {
    final source = IssueSink.fromIssues([issue('one'), issue('two')]);
    final target = IssueSink.fromIssues(const <AcanthisIssue>[])
      ..addAll(source)
      ..addAll([issue('three')])
      ..addAll([issue('four')].where((i) => i.code == 'four'));
    source.clear();
    expect(target.issues.map((i) => i.code), ['one', 'two', 'three', 'four']);
    final old = target.issues;
    target.addAll(IssueSink());
    target.addAll(const <AcanthisIssue>[]);
    expect(target.issues, same(old));
  });

  test('bulk append and child merge handle self-aliasing exactly once', () {
    final sink = IssueSink()
      ..add(issue('one'))
      ..add(issue('two'));
    sink.addAll(sink);
    expect(sink.issues.map((i) => i.code), ['one', 'two', 'one', 'two']);
    sink.addChild('child', sink);
    expect(sink, hasLength(8));
    expect(sink.issues.take(4).every((i) => i.path.isEmpty), isTrue);
    expect(sink.issues.skip(4).every((i) => i.path.single == 'child'), isTrue);
  });

  test('partially throwing iterable invalidates a previous snapshot', () {
    final sink = IssueSink()..add(issue('existing'));
    final before = sink.issues;
    Iterable<AcanthisIssue> failing() sync* {
      yield issue('partial');
      throw StateError('source failed');
    }

    expect(() => sink.addAll(failing()), throwsStateError);
    expect(before.single.code, 'existing');
    expect(sink.issues.map((i) => i.code), ['existing', 'partial']);
  });

  test('partially throwing list does not leave a stale snapshot', () {
    final sink = IssueSink()..add(issue('existing'));
    final before = sink.issues;
    expect(() => sink.addAll(_ThrowingIssues()), throwsStateError);
    expect(before.single.code, 'existing');
    expect(sink.issues.map((i) => i.code), ['existing', 'partial']);
    final empty = IssueSink();
    expect(() => empty.addAll(_ThrowingIssues()), throwsStateError);
    expect(empty.isNotEmpty, isTrue);
    expect(empty.issues.single.code, 'partial');
  });

  test(
    'child merge preserves typed paths, nested branches and child reuse',
    () {
      final original = AcanthisIssue(
        path: ['0', 0],
        code: 'union',
        parameters: {'limit': 3},
        branches: [
          [
            issue('branch', path: ['0', 0, 'inside']),
          ],
        ],
      );
      final child = IssueSink.fromIssues([original]);
      final parent = IssueSink()..addChild('a/b~', child);
      child.clear();
      child.add(issue('later'));
      final merged = parent.issues.single;
      expect(merged.path, ['a/b~', '0', 0]);
      expect(merged.branches.single.single.path, ['a/b~', '0', 0, 'inside']);
      expect(merged.jsonPointer, '/a~1b~0/0/0');
      expect(merged.parameters, same(original.parameters));
      expect(original.path, ['0', 0]);
      expect(() => merged.branches.single.clear(), throwsUnsupportedError);
    },
  );

  test('invalid prefix rejects even when the child is empty', () {
    final sink = IssueSink();
    expect(() => sink.addChild(true, IssueSink()), throwsArgumentError);
    expect(() => issue('x').prefixed(true), throwsArgumentError);
    expect(() => AcanthisIssue(path: [true], code: 'x'), throwsArgumentError);
    sink.addChild('', IssueSink());
    expect(sink.isEmpty, isTrue);
  });

  test(
    'deep shared paths have correct length, iteration, indexing and equality',
    () {
      AcanthisIssue nested = issue('deep', path: ['leaf']);
      for (var i = 0; i < 2000; i++) {
        nested = nested.prefixed(i);
      }
      final expected = <Object>[for (var i = 1999; i >= 0; i--) i, 'leaf'];
      expect(nested.path.length, 2001);
      expect(nested.path.toList(), expected);
      expect(nested.path[0], 1999);
      expect(nested.path[1500], 499);
      expect(nested.path.last, 'leaf');
      expect(() => nested.path[-1], throwsRangeError);
      expect(() => nested.path[2001], throwsRangeError);
      final flat = issue('deep', path: expected);
      expect(nested, flat);
      expect(nested.hashCode, flat.hashCode);
      expect(nested.jsonPointer, flat.jsonPointer);
      expect(jsonDecode(jsonEncode(nested.toJson()))['path'], expected);
    },
  );

  test('issue construction snapshots data and bounds cyclic parameters', () {
    final path = <Object>['x'];
    final limits = <Object?>[1, 2];
    final cycle = <Object?>[];
    cycle.add(cycle);
    final diagnostic = AcanthisIssue(
      path: path,
      code: 'x',
      parameters: {
        'limits': limits,
        'cycle': cycle,
        'infinity': double.infinity,
      },
    );
    path[0] = 'changed';
    limits[0] = 99;
    expect(diagnostic.path, ['x']);
    expect(diagnostic.parameters['limits'], [1, 2]);
    expect(diagnostic.parameters['cycle'], ['<cycle>']);
    expect(diagnostic.parameters['infinity'], 'Infinity');
    expect(
      () => (diagnostic.parameters['limits'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => diagnostic.path.clear(), throwsUnsupportedError);
    expect(() => jsonEncode(diagnostic.toJson()), returnsNormally);
  });

  test(
    'issue metadata equality is map-order-independent and paths remain typed',
    () {
      final first = AcanthisIssue(
        path: [0],
        code: 'x',
        parameters: {'a': 1, 'b': 2},
      );
      final second = AcanthisIssue(
        path: [0],
        code: 'x',
        parameters: {'b': 2, 'a': 1},
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(issue('x', path: ['0'])));
      expect(
        first.formatMessage(
          catalog: AcanthisMessageCatalog({'x': (p) => 'limit ${p['a']}'}),
        ),
        'limit 1',
      );
      expect(first.toTransport().containsKey('message'), isFalse);
    },
  );

  test(
    'seeded append, merge, snapshot and drain sequences match a flat oracle',
    () {
      final random = Random(20261014);
      final sink = IssueSink();
      final expected = <AcanthisIssue>[];
      final snapshots = <(List<AcanthisIssue>, List<AcanthisIssue>)>[];
      for (var step = 0; step < 1000; step++) {
        switch (random.nextInt(6)) {
          case 0:
            final next = issue('$step', path: [random.nextBool() ? '0' : 0]);
            sink.add(next);
            expected.add(next);
          case 1:
            final child = IssueSink.fromIssues([
              issue('child$step', path: ['x']),
            ]);
            final Object segment = random.nextBool() ? 'a/b' : 2;
            sink.addChild(segment, child);
            expected.addAll(child.map((i) => i.prefixed(segment)));
          case 2:
            snapshots.add((sink.issues, List.of(expected)));
          case 3:
            expect(sink.takeIssues(), expected);
            expected.clear();
          case 4:
            sink.clear();
            expected.clear();
          case 5:
            sink.addAll(sink);
            expected.addAll(List.of(expected));
        }
        expect(sink.issues, expected, reason: 'step $step');
        expect(sink.length, expected.length);
        expect(sink.isEmpty, expected.isEmpty);
      }
      for (final (actual, original) in snapshots) {
        expect(actual, original);
      }
    },
  );
}
