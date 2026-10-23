# Runtime and compiler probes

Executed 2026-10-13 with Dart 3.13.3 against the reviewed working tree. This is analysis-only evidence; no existing source or tests were edited. The probe deliberately records current behavior rather than asserting it is correct. Save the following block as `.dart_tool/architecture_review_probe.dart` and run `dart run .dart_tool/architecture_review_probe.dart` from the package root.

```dart
import 'dart:async';
import 'package:acanthis/acanthis.dart';

class Box {}
class PermissiveString extends AcanthisString {
  @override
  String parseInternal(dynamic value) => 'accepted';
  @override
  String tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) => 'accepted';
}
Future<void> probe(String name, FutureOr<Object?> Function() run) async {
  try { print('$name => ${await run()}'); }
  catch (e) { print('$name => THREW ${e.runtimeType}: $e'); }
}
Future<void> main() async {
  final lit = literal('a').refine(onCheck: (_) => false, error: 'reject', name: 'reject');
  await probe('literal.parse false refinement', () => lit.parse('a'));
  await probe('literal.tryParse false refinement', () => lit.tryParse('a').isValid);
  final tpl = template(['a']).refineAsync(onCheck: (_) async => true, error: '', name: 'pass');
  await probe('template.parseAsync wrong literal', () => tpl.parseAsync('b'));
  await probe('template.tryParseAsync wrong literal', () async => (await tpl.tryParseAsync('b')).isValid);
  final duplicate = string().min(3).min(4);
  await probe('direct duplicate issues', () => duplicate.tryParse('x').issues.formatJson());
  final pipe = duplicate.pipe(integer(), transform: (s) => s.length);
  await probe('pipeline duplicate issues', () => pipe.tryParse('x').issues.formatJson());
  await probe('pipeline refine', () => pipe.refine(onCheck: (_) => true, error: '', name: 'pass'));
  await probe('tuple duplicate issues', () => tuple([duplicate]).tryParse(['x']).issues.formatJson());
  await probe('nullable async duplicate issues', () async => (await duplicate.nullable().refineAsync(onCheck: (_) async => true, error: '', name: 'pass').tryParseAsync('x')).issues.formatJson());
  await probe('nested union without recovery', () => object({'box': union<Box>([instance<Box>()])}).tryParse({'box': 'wrong'}).isValid);
  await probe('list instance without recovery async', () async => (await instance<Box>().refineAsync(onCheck: (_) async => true, error: '', name: 'pass').list().tryParseAsync(['wrong'])).isValid);
  await probe('list instance without recovery sync', () => instance<Box>().list().tryParse(['wrong']).isValid);
  await probe('pipeline instance output without recovery', () => string().pipe(instance<Box>(), transform: (_) => Box()).tryParse('ok').isValid);
  final fields = <String, AcanthisType>{'a': string()};
  final map = object(fields);
  fields['b'] = string();
  await probe('mutable object keys versus parse', () => '${map.fields.keys} / ${map.tryParse({'a': 'ok'}).isValid}');
  final elements = <AcanthisType>[string()];
  final tup = tuple(elements); elements.add(integer());
  await probe('mutable tuple elements', () => tup.tryParse(['ok']).isValid);
  final variadic = tuple([string()]).variadic();
  await probe('variadic original', () => variadic.tryParse(['a','b']).isValid);
  await probe('variadic after refine', () => variadic.refine(onCheck: (_) => true, error: '', name: 'pass').tryParse(['a','b']).isValid);
  await probe('transform TypeError parse', () => string().transform((s) => (42 as dynamic) as String).parse('ok'));
  await probe('transform TypeError tryParse', () => string().transform((s) => (42 as dynamic) as String).tryParse('ok').issues.formatJson());
  await probe('default instance wrong input', () => instance<Box>().withDefault(Box()).tryParse('wrong').isValid);
  var calls = 0;
  final ruled = object({'a': string()}).checkFields(['a'], at:'a', name:'app.rule', error:'rule', check: (_) { calls++; return true; });
  await probe('seeded mock opaque rule', () { ruled.mockSeeded(seed: 1); return 'callback calls=$calls'; });
  var lazyCalls = 0;
  final lazyField = lazy<String>((_) => string()).refine(onCheck: (_) { lazyCalls++; return false; }, error:'reject', name:'reject');
  await probe('lazy refinement ignored', () => '${object({'a': lazyField}).tryParse({'a':'ok'}).isValid} / callback calls=$lazyCalls');
  final ref = instance<int>().withRefs((b) => b.ref('x', (v) => v)).field('x', (v) => v, integer());
  await probe('instance refs after field', () => ref.refineWithRefs((v,r) => r<int>('x') == v, 'missing').tryParse(1).isValid);
  await probe('numeric fluent generic', () => integer().positive().runtimeType);
  final typedMap = AcanthisMap<int>({'a': string()});
  await probe('incompatible map generic validity', () => typedMap.tryParse({'a':'ok'}).isValid);
  await probe('incompatible map generic output access', () => typedMap.tryParse({'a':'ok'}).value['a']);
  final hiddenAsync = object({'a': lazy<String>((_) => string().refineAsync(onCheck: (_) async => false, error:'reject', name:'remote'))});
  await probe('lazy hidden async check', () => '${hiddenAsync.isAsync} / ${hiddenAsync.tryParse({'a':'ok'}).isValid}');
  var lateCalls = 0;
  final withRule = object({'a': string().min(3), 'b': string().refine(onCheck: (_) { lateCalls++; return true; }, error:'', name:'count')}).checkFields(['a'], at:'a', name:'rule', error:'rule', check: (_) => true);
  await probe('object parse with rules stops first', () { try { withRule.parse({'a':'x','b':'ok'}); } catch (_) {} return 'later field calls=$lateCalls'; });
  await probe('custom schema audited export', () => '${PermissiveString().tryParse(42).isValid} / ${PermissiveString().exportJsonSchema(mode:AcanthisSchemaMode.input)}');
}
```

## Observed output

```text
literal.parse false refinement => a
literal.tryParse false refinement => false
template.parseAsync wrong literal => b
template.tryParseAsync wrong literal => false
direct duplicate issues => [{"path":[],"code":"minLength","parameters":{"value":3},"message":"Value must be greater than or equal to 3 characters long"},{"path":[],"code":"minLength","parameters":{"value":4},"message":"Value must be greater than or equal to 4 characters long"}]
pipeline duplicate issues => [{"path":[],"code":"minLength","parameters":{"value":3},"message":"Value must be greater than or equal to 3 characters long"},{"path":[],"code":"minLength","parameters":{"value":4},"message":"Value must be greater than or equal to 4 characters long"}]
pipeline refine => THREW UnimplementedError: UnimplementedError
tuple duplicate issues => [{"path":[0],"code":"minLength","parameters":{"value":3},"message":"Value must be greater than or equal to 3 characters long"},{"path":[0],"code":"minLength","parameters":{"value":4},"message":"Value must be greater than or equal to 4 characters long"}]
nullable async duplicate issues => [{"path":[],"code":"minLength","parameters":{"value":3},"message":"Value must be greater than or equal to 3 characters long"},{"path":[],"code":"minLength","parameters":{"value":4},"message":"Value must be greater than or equal to 4 characters long"}]
nested union without recovery => THREW StateError: Bad state: Validation failed without a recovery value
list instance without recovery async => THREW StateError: Bad state: Validation failed without a recovery value
list instance without recovery sync => THREW UnimplementedError: UnimplementedError: Mocking is not supported for InstanceType
pipeline instance output without recovery => true
mutable object keys versus parse => (a, b) / true
mutable tuple elements => false
variadic original => true
variadic after refine => false
transform TypeError parse => THREW _TypeError: type 'int' is not a subtype of type 'String' in type cast
transform TypeError tryParse => [{"path":[],"code":"type","parameters":{},"message":"Invalid type: String, expected String"}]
default instance wrong input => false
seeded mock opaque rule => callback calls=2
lazy refinement ignored => true / callback calls=0
instance refs after field => false
numeric fluent generic => AcanthisNumeric<int>
incompatible map generic validity => true
incompatible map generic output access => THREW _TypeError: type 'String' is not a subtype of type 'int?' in type cast
lazy hidden async check => false / true
object parse with rules stops first => later field calls=1
custom schema audited export => true / {$schema: https://json-schema.org/draft/2020-12/schema, type: string}
```

## Compiler probes

`dart compile kernel .dart_tool/architecture_review_numeric_negative.dart -o .dart_tool/architecture-review-negative.dill` rejected `final int value = integer().positive().parse(1);`: **A value of type 'num' can't be assigned to a variable of type 'int'.**

`dart compile kernel .dart_tool/architecture_review_pipeline_negative.dart -o .dart_tool/architecture-review-negative.dill` rejected `final int value = string().pipe(integer(), transform: int.parse).parse('1');`: **A value of type 'int?' can't be assigned to a variable of type 'int'.**

Both fixtures imported `package:acanthis/acanthis.dart` and placed the assignment in `void main()`. Final retries outside the sandbox exited 1 due to the intended type errors, without telemetry failures. The existing registry runner separately checked three bound-error fixtures and a successful AOT example.

## Interpretation limits

The probes are reduced counterexamples, not a coverage report. The duplicate-issue probes are controls that **pass**, disproving the assumption that native `.errors` merges necessarily lose structured diagnostics. The pipeline instance-output probe is another successful control. Legacy regex mock nontermination was inferred from its unbounded append loop and incompatible anchored target length, not executed. Metadata copy omissions and legacy export-state contamination are source-backed findings; they are not claimed as executed probes here.

