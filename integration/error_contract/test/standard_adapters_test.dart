import 'package:acanthis/acanthis.dart' as a;
import 'package:enhanced_standard_schema/enhanced_standard_schema.dart' as e;
import 'package:standard_schema/standard_schema.dart' as s;
import 'package:test/test.dart';
import 'package:acanthis_error_contract_integration/standard_adapters.dart';

void main() {
  test('JSON Schema capability preserves audited dialect and rejection', () {
    final adapter = JsonAdapter(a.string());
    const options = s.StandardJsonSchemaOptions(
      target: s.JsonSchemaTarget.draft202012,
    );
    expect(adapter.standard.jsonSchema.input(options)['type'], 'string');
    expect(adapter.standard.jsonSchema.output(options)['type'], 'string');
    expect(
      () => adapter.standard.jsonSchema.input(
        const s.StandardJsonSchemaOptions(target: s.JsonSchemaTarget.draft07),
      ),
      throwsUnsupportedError,
    );
    expect(
      () =>
          JsonAdapter(a.string().transform((s) => s)).standard.jsonSchema
              .input(options),
      throwsA(isA<a.AcanthisSchemaExportException>()),
    );
  });
  test(
    'typed success and async validation in both nominal contracts',
    () async {
      for (final schema in [
        a.string(),
        a.string().refineAsync(
          onCheck: (_) async => true,
          name: 'pass',
          error: '',
        ),
      ]) {
        final standard = await StandardAdapter(schema).standard.validate('ok');
        final enhanced = await EnhancedAdapter(schema).$standard.validate('ok');
        final String value = (standard as s.StandardSuccess<String>).value;
        final String other =
            (enhanced as e.StandardSchemaSuccess<String>).value;
        expect(value, other);
      }
    },
  );
  test(
    'string and integer paths survive; rich metadata requires enhanced issues',
    () async {
      final schema = a.object({'0': a.string().min(3).list()});
      final standard = await StandardAdapter(schema).standard.validate({
        '0': ['x'],
      }) as s.StandardFailure;
      final enhanced = await EnhancedAdapter(schema).$standard.validate({
        '0': ['x'],
      }) as e.StandardSchemaFailure;
      expect(standard.issues.single.path, ['0', 0]);
      final issue = enhanced.issues.single as EnhancedIssue;
      expect(issue.path![0], isA<e.StandardSchemaPropertyKey>());
      expect(issue.path![1], isA<e.StandardSchemaListIndex>());
      expect(issue.code, 'minLength');
      expect(issue.metadata.parameters, {'value': 3});
      expect(StandardAdapter(schema), isNot(isA<e.StandardSchema>()));
      expect(EnhancedAdapter(schema), isNot(isA<s.StandardSchemaV1>()));
    },
  );
  test('published contracts differ in defensive copying', () {
    final standardPath = <Object>['x'];
    final si = s.StandardIssue(message: 'failure', path: standardPath);
    standardPath.add(0);
    expect(si.path, ['x']);
    final list = <e.StandardSchemaIssue>[];
    final failure = e.StandardSchemaFailure(list);
    list.add(
      EnhancedIssue(
        a.AcanthisIssue(path: [], code: 'type', message: 'failure'),
      ),
    );
    expect(failure.issues, hasLength(1));
  });
}
