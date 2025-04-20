import 'package:acanthis/acanthis.dart' as acanthis;
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/types/map.dart';

void main(List<String> arguments) async {
  final jsonObject = acanthis
        .object({
          'name': acanthis.string().min(5).max(10).encode(),
          'names': lazy((element) => element.list())
        })
        .passthrough();
    final parsed = jsonObject.parse({
      'name': 'Hello',
      'names': [{
        'name': 'World',
        'names': [
          {'name': '!!!!!', 'names': []}
        ]
      }],
    });
    print(jsonObject.toJsonSchema());
    print(jsonObject.toJsonSchemaString());
//   final list = acanthis
//       .string()
//       .max(5)
//       .list()
//       .max(3)
//       .transform((value) => value.map((e) => e.toUpperCase()).toList());

//   final parsedList = list.tryParse(['Hello', 'World', 'hello']);

//   final number = acanthis.number().pow(2).gte(5);
//   print(number.tryParse(3));
//   print(parsed);
//   print(parsedList);

//   final union = acanthis.union([
//     acanthis.number(),
//     acanthis.string(),
//   ]);

//   print(union.tryParse(DateTime.now()));

//   // final schema = acanthis.object({
//   //   'email': acanthis.string().email(),
//   //   'password': acanthis.string().min(8).allCharacters().mixedCase().uncompromised(),
//   //   'confirmPassword': acanthis.string().min(8).allCharacters().mixedCase().uncompromised()
//   // }).addFieldDependency(
//   //   dependent: 'password',
//   //   dependendsOn: 'confirmPassword',
//   //   dependency: (password, confirmPassword) => password == confirmPassword
//   // );

//   // final result = await schema.tryParseAsync({
//   //   'email': 'test@example.com',
//   //   'password': r'Nq;CRa7rZ)%pGm5$MB_j].',
//   //   'confirmPassword': r'Nq;CRa7rZ)%pGm5$MB_j].'
//   // });

//   // print(result);

//   final schema = acanthis.object({
//     'name': acanthis.string().min(5),
//     'subcategories': lazy((parent) => parent.list().min(1)),
//   });

//   final r = schema.tryParse({
//     'name': 'Hello',
//     'subcategories': [
//       {
//         'name': 'World',
//         'subcategories': [
//           {'name': '!', 'subcategories': []},
//           {'name': '!!!!!', 'subcategories': []}
//         ]
//       }
//     ]
//   });
//   final encoder = JsonEncoder.withIndent('  ');
//   print('''value: ${encoder.convert(r.value)}
// errors: ${encoder.convert(r.errors)}
//     ''');

//   final stringDate = acanthis.string().pipe(
//         acanthis.date().min(DateTime.now()),
//         transform: (value) => DateTime.parse(value),
//       );
//   final result = stringDate.tryParse('aaaaa');
//   print(result);
}
