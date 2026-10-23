import 'package:acanthis/acanthis.dart';

Future<void> main() async {
  final schema = object({'country': string(), 'confirm': string()}).checkFields(
      ['country', 'confirm'],
      at: 'confirm',
      name: 'mismatch',
      check: (fields) =>
          fields['country'] == fields['confirm']).rule(
      AcanthisRule<Set<String>>.async(
    id: 'countryUnavailable',
    inputs: ['country'],
    outputs: ['country'],
    check: (fields, countries) async => countries.contains(fields['country'])
        ? []
        : [
            AcanthisIssue(path: ['country'], code: 'countryUnavailable')
          ],
  ));
  final result = await AcanthisValidationScope(context: {'IT', 'FR'})
      .run(() => schema.tryParseAsync({'country': 'IT', 'confirm': 'FR'}));
  final catalog = AcanthisMessageCatalogs.italian.extend({
    'mismatch': (_) => 'I campi non corrispondono',
    'countryUnavailable': (_) => 'Paese non disponibile',
  });
  final rendered = AcanthisI18n.runWith(
    AcanthisLocaleConfig(locale: 'it-IT', catalog: catalog),
    () => [for (final issue in result.issues) issue.toJson()],
  );
  print(rendered);
}
