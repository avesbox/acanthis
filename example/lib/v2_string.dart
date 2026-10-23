import 'package:acanthis/acanthis.dart';

void main() {
  final schema = string().trim().toLowerCase().email().max(254);
  final accepted = schema.parse(' Person@Example.com ');
  print(accepted);

  final italian = AcanthisMessageCatalog.english.extend({
    'email': (_) => 'Inserisci un indirizzo email valido',
  });
  final rejected = schema.tryParse('invalid');
  for (final issue in rejected.issues) {
    print(issue.formatMessage(catalog: italian));
  }

  final String coerced = string().coerce().parse(42);
  print(coerced);
}
