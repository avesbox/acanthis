import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/issue_sink.dart';
import 'package:test/test.dart';

void main() {
  test('legacy extension writes produce ordered data-only issues', () {
    final Map<String, dynamic> errors = IssueSink();
    errors['email'] = 'First';
    errors['email'] = 'Second';
    errors['child'] = <String, dynamic>{'required': 'Missing'};
    final result = outcomeFromDiagnostics(value: null, errors: errors);
    expect(result.issues.map((issue) => issue.path), [
      [],
      [],
      ['child'],
    ]);
    expect(result.issues.map((issue) => issue.code), [
      'email',
      'email',
      'required',
    ]);
    expect(Map<String, dynamic>.of(result.errors), {
      'email': 'Second',
      'child': {'required': 'Missing'},
    });
  });

  test('legacy round trip never guesses integer indices', () {
    final result = outcomeFromDiagnostics(
      value: null,

      issues: [
        AcanthisIssue(path: ['items', 0], code: 'type', message: 'Invalid'),
      ],
    );
    final projected = Map<String, dynamic>.of(result.errors);
    final restored = outcomeFromDiagnostics(value: null, errors: projected);
    expect(result.issues.single.path, ['items', 0]);
    expect(restored.issues.single.path, ['items', '0']);
  });
}
