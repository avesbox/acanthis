// Current V2 observations derived from the original V1 reports in
// doc/error-codes-analysis.md and doc/branding-analysis.md.
import 'dart:convert';

import 'package:acanthis/acanthis.dart';

extension type Email(String value) {}

enum Choice { first }

final class WrappedEmail {
  WrappedEmail(this.value);
  final String value;
}

void observe(String name, Object? Function() action) {
  try {
    print('$name: ${action()}');
  } catch (error) {
    print('$name: ${error.runtimeType}: $error');
  }
}

Future<void> main() async {
  final email = string().email().pipe<Email>(
    instance<Email>(),
    transform: Email.new,
  );
  final Email? parsed = email.parse('a@example.com');
  final List<Email?> list = email.list().parse(['a@example.com']);
  observe('typed pipeline/list', () => '${parsed?.value}/${list.first?.value}');
  observe('nullable', () => email.nullable().parse(null));
  observe(
    'optional',
    () => object({'email': email}).optionals(['email']).parse({}),
  );
  observe(
    'nested object',
    () => object({'email': email}).parse({'email': 'a@example.com'}),
  );
  observe('tuple', () => tuple([email]).parse(['a@example.com']));
  observe('union', () => union<Email?>([email]).parse('a@example.com'));
  observe(
    'transform before pipe',
    () => string()
        .transform((s) => s.trim())
        .pipe<Email>(instance<Email>(), transform: Email.new)
        .parse(' a@example.com '),
  );
  observe('transform after pipe', () => email.transform((e) => e));
  observe('legacy export', email.toJsonSchema);
  observe(
    'explicit export',
    () => email.exportJsonSchema(mode: AcanthisSchemaMode.input),
  );
  observe(
    'uuid explicit export',
    () => string().uuid().exportJsonSchema(mode: AcanthisSchemaMode.input),
  );
  observe('extension JSON', () => jsonEncode({'email': parsed, 'list': list}));
  observe('wrapper JSON', () => jsonEncode(WrappedEmail('a@example.com')));
  dynamic raw = 'not an email';
  observe('dynamic bypass', () => (raw as Email).value);
  observe('runtime check', () => raw is Email);
  observe(
    'pattern',
    () => switch (raw) {
      Email(:final value) => value,
      _ => 'no match',
    },
  );
  observe('equality', () => Email('x') == Email('x'));
  observe('runtime type', () => (parsed as Object).runtimeType);
  observe(
    'instance is not validation',
    () => instance<Email>().parse('invalid').value,
  );
  observe(
    'instance field diagnostic',
    () => instance<WrappedEmail>()
        .field('email', (e) => e.value, string().min(3))
        .tryParse(WrappedEmail('x'))
        .issues
        .formatJson(),
  );
  observe('throwing list wrong type', () => string().list().parse(42));
  observe(
    'collecting list wrong type',
    () => string().list().tryParse(42).issues.formatJson(),
  );
  final invalid = email.tryParse('invalid');
  observe('underlying failure', () => invalid.issues.formatJson());
  observe('enum catalog', () {
    final issue = string()
        .enumerated(Choice.values)
        .tryParse('other')
        .issues
        .single;
    return '${issue.parameters} => ${AcanthisMessageCatalogs.italian.format(issue.code, issue.parameters)}';
  });
  final nested = object({'a/b~': string().min(3).list()});
  final result = nested.tryParse({
    'a/b~': ['x'],
  });
  observe(
    'nested issue/pointer',
    () => '${result.issues.formatJson()} ${result.issues.first.jsonPointer}',
  );
  observe(
    'round trip transport',
    () => jsonEncode(jsonDecode(result.issues.formatJson())),
  );
  observe(
    'parameter freezing',
    () => AcanthisIssue(
      path: [],
      code: 'app.test',
      defaultCatalog: AcanthisMessageCatalog({'app.test': (_) => 'fallback'}),
      parameters: {
        'date': DateTime.utc(2026),
        'uri': Uri.parse('https://example.com'),
        'enum': Choice.first,
        'duration': const Duration(seconds: 1),
        'nan': double.nan,
      },
    ).toJson(),
  );
  final localized = await Future.wait([
    for (final locale in ['it', 'en'])
      AcanthisI18n.runWith(AcanthisLocaleConfig.forLocale(locale), () async {
        await Future<void>.delayed(Duration.zero);
        return string().min(3).tryParse('x').issues.single.message;
      }),
  ]);
  print('concurrent locale scopes: $localized');
  print('async pipeline: ${(await email.parseAsync('a@example.com'))?.value}');
}
