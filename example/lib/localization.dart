import 'package:acanthis/acanthis.dart';

void main() {
  final schema = object({
    'name': string().min(3),
    'startsAt': date().min(DateTime.utc(2030)),
    'email': string().email(),
  });
  final result = schema.tryParse({'name': 'A', 'startsAt': DateTime.utc(2029)});
  print(result.issues.formatFields());

  final config = AcanthisLocaleConfig.forLocale('it-CH', overrides: {
    'it': AcanthisMessageCatalog({
      'minLength': (p) => 'Almeno ${p['value']} caratteri',
    }),
    'it-CH': AcanthisMessageCatalog({'required': (_) => 'Campo obbligatorio'}),
  });
  AcanthisI18n.runWith(config, () {
    print(result.issues.formatFields());
    print(result.issues.formatJson());
  });
}
