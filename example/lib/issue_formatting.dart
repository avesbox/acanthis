import 'package:acanthis/acanthis.dart';

void main() {
  final result = object({
    'name': string().min(3).min(5),
    'contacts': object({'email': string().email()}).list(),
  }).tryParse({
    'name': 'A',
    'contacts': [
      {'email': 'invalid'}
    ],
  });

  final catalog = AcanthisMessageCatalogs.italian;
  print(result.issues.formatFields(catalog: catalog));
  final tree = result.issues.formatTree(catalog: catalog);
  print(tree.children['contacts']!.children[0]!.children['email']!.messages);
  print(result.issues.formatJson(catalog: catalog));
  print(result.issues.toTransport());
}
