import 'package:acanthis/acanthis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('field uses widget locale and reformats without revalidation', (
    tester,
  ) async {
    var calls = 0;
    final schema = object({
      'email': string().refine(
        onCheck: (_) {
          calls++;
          return false;
        },
        name: 'minLength',
        error: 'fallback',
        parameters: {'value': 3},
      ),
    });
    final issues = schema.tryParse({'email': 'x'}).issues;
    final before = calls;
    expect(before, 1);
    Future<void> show(String locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('it')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              final resolver = AcanthisMessageCatalogs.forLocale(
                Localizations.localeOf(context).languageCode,
              );
              return Scaffold(
                body: TextFormField(
                  initialValue: 'x',
                  decoration: InputDecoration(
                    errorText: issues
                        .formatFields(resolver: resolver)['/email']
                        ?.first,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show('en');
    expect(
      find.text('Value must contain at least 3 characters'),
      findsOneWidget,
    );
    await show('it');
    expect(
      find.text('Il valore deve contenere almeno 3 caratteri'),
      findsOneWidget,
    );
    expect(calls, before);
    expect(issues.single.code, AcanthisIssueCodes.minLength);
    expect(issues.single.jsonPointer, '/email');
  });
}
