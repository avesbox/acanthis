import 'package:acanthis/acanthis.dart';

void main(List<String> arguments) async {
      object({
        'number': number(),
        'negNumber': number(),
        'infiniteNumber': number(),
        'string': string(),
        'longString': string(),
        'boolean': boolean(),
        
        'deeplyNested': object({
          'foo': string(),
          'num': number(),
          'bool': boolean(),
          'deeplyNested2': object({
            'foo2': string(),
            'num2': number(),
            'bool2': boolean(),
          }).list(),
        }).list(),
      }).list().tryParse([
  {
    'number': 123,
    'negNumber': -123,
    'infiniteNumber': double.infinity,
    'string': 'Hello, World!',
    'longString': 'This is a long string that exceeds the normal length.',
    'boolean': true,

    'deeplyNested': [
      {
        'foo': 'bar',
        'num': 456,
        'bool': false,
        'deeplyNested2': [
          {
            'foo2': 'baz',
            'num2': 789,
            'bool2': true,
          },
          {
            'foo2': 'qux',
            'num2': 101112,
            'bool2': false,
          },
        ],
      },
      {
        'foo': 'quux',
        'num': 131415,
        'bool': true,
        'deeplyNested2': [
          {
            'foo2': 'corge',
            'num2': 161718,
            'bool2': false,
          },
          {
            'foo2': 'grault',
            'num2': 192021,
            'bool2': true,
          },
        ],
      },
    ],
  },
  {
    'number': 456,
    'negNumber': -456,
    'infiniteNumber': double.infinity,
    'string': 'Goodbye, World!',
    'longString': 'This is another long string that exceeds the normal length.',
    'boolean': false,

    'deeplyNested': [
      {
        'foo': 'qux',
        'num': 101112,
        'bool': true,
        'deeplyNested2': [
          {
            'foo2': 'quux',
            'num2': 131415,
            'bool2': false,
          },
          {
            'foo2': 'corge',
            'num2': 161718,
            'bool2': true,
          },
        ],
      },
      {
        'foo': 'grault',
        'num': 192021,
        'bool': false,
        'deeplyNested2': [
          {
            'foo2': 'garply',
            'num2': 222324,
            'bool2': true,
          },
          {
            'foo2': 'waldo',
            'num2': 252627,
            'bool2': false,
          },
        ],
      },
    ],
  },
]);

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
