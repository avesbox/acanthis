// Feasibility probes, not a new public Acanthis dependency or adapter API.
import 'package:acanthis/acanthis.dart' as a;
import 'package:standard_schema/standard_schema.dart' as s;
import 'package:enhanced_standard_schema/enhanced_standard_schema.dart' as e;

class StandardAdapter<T> implements s.StandardSchemaV1<Object?, T> {
  StandardAdapter(this.schema);
  final a.AcanthisType<T> schema;
  s.StandardResult<T> _convert(a.AcanthisOutcome<T> result) => result.isValid
      ? s.StandardSuccess(result.value)
      : s.StandardFailure([
          for (final issue in result.issues)
            s.StandardIssue(message: issue.message, path: issue.path),
        ]);
  @override
  late final standard = s.StandardSchemaPropsV1<Object?, T>(
    vendor: 'acanthis',
    validate: (value, [options]) => schema.isAsync
        ? schema.tryParseAsync(value).then(_convert)
        : _convert(schema.tryParse(value)),
  );
}

typedef DiagnosticMetadata = ({
  Map<String, Object?> parameters,
  List<List<a.AcanthisIssue>> branches,
});

class JsonAdapter<T> implements s.StandardJsonSchemaV1<Object?, T> {
  JsonAdapter(this.schema);
  final a.AcanthisType<T> schema;
  Map<String, Object?> _export(
    s.StandardJsonSchemaOptions options,
    a.AcanthisSchemaMode mode,
  ) {
    if (options.target != s.JsonSchemaTarget.draft202012) {
      throw UnsupportedError('Only audited JSON Schema 2020-12 is supported');
    }
    return schema.exportJsonSchema(mode: mode);
  }

  @override
  late final standard = s.StandardJsonSchemaPropsV1<Object?, T>(
    vendor: 'acanthis',
    jsonSchema: s.StandardJsonSchemaConverter(
      input: (options) => _export(options, a.AcanthisSchemaMode.input),
      output: (options) => _export(options, a.AcanthisSchemaMode.output),
    ),
  );
}

final class EnhancedIssue
    extends e.DetailedStandardSchemaIssue<DiagnosticMetadata> {
  EnhancedIssue(a.AcanthisIssue issue)
    : super(
        message: issue.message,
        code: issue.code,
        path: List.unmodifiable([
          for (final part in issue.path)
            if (part is String)
              e.StandardSchemaPropertyKey(part)
            else
              e.StandardSchemaListIndex(part as int),
        ]),
        metadata: (parameters: issue.parameters, branches: issue.branches),
      );
}

class EnhancedAdapter<T> implements e.StandardSchema<T> {
  EnhancedAdapter(this.schema);
  final a.AcanthisType<T> schema;
  e.StandardSchemaResult<T> _convert(a.AcanthisOutcome<T> result) =>
      result.isValid
      ? e.StandardSchemaSuccess(result.value)
      : e.StandardSchemaFailure(
          List.unmodifiable(result.issues.map(EnhancedIssue.new)),
        );
  @override
  late final $standard = e.StandardSchemaProps<T>(
    vendor: 'acanthis',
    validate: (value, [options]) => schema.isAsync
        ? schema.tryParseAsync(value).then(_convert)
        : _convert(schema.tryParse(value)),
  );
}
