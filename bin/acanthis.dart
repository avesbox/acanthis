import 'package:acanthis/acanthis.dart';

class User {
  final String name;
  final int age;
  final String email;
  final DateTime birthDate;

  User({
    required this.name,
    required this.age,
    required this.email,
    required this.birthDate,
  });

  @override
  String toString() {
    return 'User(name: $name, age: $age, email: $email, birthDate: $birthDate)';
  }
}

AcanthisMap<dynamic> get registerSchema => object({
  'name': string().min(3).max(100).toUpperCase(),
  'businessName': string().min(3).max(150).toUpperCase(),
  'mobileNumber': string().length(10),
  'email': string().email(),
  'password': string().min(6).max(128),
});
AcanthisMap<dynamic> get updateSchema => object({
  'name': string().min(3).max(100).toUpperCase().nullable(),
  'businessName': string().min(3).max(150).toUpperCase().nullable(),
  'mobileNumber': string().length(10).nullable(),
  'email': string().email().nullable(),
  'password': string().min(6).max(128).nullable(),
});

abstract class Payment {}

class CreditCard extends Payment {
  final String number;

  CreditCard({required this.number});
}

class WireTransfer extends Payment {
  final String iban;

  WireTransfer({required this.iban});
}

void main(List<String> arguments) async {
  final userValidator = instance<User>()
      .field('name', (u) => u.name, .string().contains('Doe'))
      .field('age', (u) => u.age, .integer())
      .field('email', (u) => u.email, .string().email())
      .field('birthDate', (u) => u.birthDate, .date())
      .withRefs(
        (refs) =>
            refs.ref('birthDate', (u) => u.birthDate).ref('age', (u) => u.age),
      )
      .refineWithCause((u, r) {
        return u.name == 'John Doe' ? '${u.name} is not allowed' : null;
      });
  final user = User(
    name: 'John Doe',
    age: 30,
    email: 'john.doe@example.com',
    birthDate: DateTime(2015, 1, 1),
  );
  final result = userValidator.tryParse(user);
  print(result.errors);

  final usersMapper = classSchema<List, List<User>>()
      .input(
        object({
          'name': .string().min(1),
          'age': .integer().gte(0),
          'email': .string().email(),
          'birthDate': .string().dateTime().pipe(
            .date(),
            transform: (value) => DateTime.parse(value),
          ),
        }).list(),
      )
      .map((m) {
        return m.map((item) {
          return User(
            name: item['name'],
            age: item['age'],
            email: item['email'],
            birthDate: item['birthDate'],
          );
        }).toList();
      })
      .build();
  final usersResult = usersMapper.tryParse([
    {
      'name': 'Jane Doe',
      'age': 25,
      'email': 'jane.doe@example.com',
      'birthDate': DateTime(1995, 5, 15).toIso8601String(),
    },
    {
      'name': 'John Smith',
      'age': 30,
      'email': 'john.smith@example.com',
      'birthDate': DateTime(1990, 10, 20).toIso8601String(),
    },
  ]);
  print(usersResult.value);

  final creditCard = CreditCard(number: '4111111111111111');
  final wireTransfer = WireTransfer(iban: 'DE89370400440532013000');

  final unionWithVariants = union<Payment>([
    variant<CreditCard>(
      guard: (p) => p is CreditCard,
      schema: instance<CreditCard>().field(
        'number',
        (c) => c.number,
        .string().min(13).max(19),
      ),
    ),
    variant<WireTransfer>(
      guard: (p) => p is WireTransfer,
      schema: instance<WireTransfer>().field(
        'iban',
        (w) => w.iban,
        .string().min(15).max(34),
      ),
    ),
  ]);
  print(unionWithVariants.parse(creditCard));
  print(unionWithVariants.parse(wireTransfer));
  final literalSchemaVariantUnion = AcanthisType.union([
    literal('credit_card'),
    literal('wire_transfer'),
    variant<CreditCard>(
      guard: (p) => p is CreditCard,
      schema: .instance<CreditCard>().field(
        'number',
        (c) => c.number,
        .string().min(13).max(19),
      ),
    ),
    object({
      'type': .string().contained(['credit_card', 'wire_transfer']),
      'data': .union([
        AcanthisType.instance<CreditCard>(),
        AcanthisType.instance<WireTransfer>(),
      ]),
    }),
  ]);
  print(
    literalSchemaVariantUnion.parse({
      'type': 'credit_card',
      'data': creditCard,
    }),
  );
  print(
    literalSchemaVariantUnion.parse({
      'type': 'wire_transfer',
      'data': wireTransfer,
    }),
  );
  print(literalSchemaVariantUnion.parse('credit_card'));
  print(literalSchemaVariantUnion.parse('wire_transfer'));
  print(literalSchemaVariantUnion.parse(creditCard));

  final numericInput = AcanthisType.union([
    AcanthisType.literal(1),
    AcanthisType.literal(2),
    AcanthisType.string().min(3),
  ]);

  print(numericInput.parse(1)); // passes
  print(numericInput.parse(2)); // passes
  print(numericInput.parse('hello')); // passes

  final mapWithLiterals = AcanthisType.object({
    'type': .literal('Acanthis'),
    'name': .string(),
  });

  print(mapWithLiterals.parse({'type': 'Acanthis', 'name': 'Example'}));

  final mapWithDefault = AcanthisType.object({
    'type': .string().withDefault('Acanthis'),
    'name': .string().withDefault('Unknown'),
  });
  print(mapWithDefault.tryParse({}));
  final listWithDefault = AcanthisType.string().list().min(1).withDefault([
    'Acanthis',
  ]);
  print(listWithDefault.tryParse([]));
  final name = AcanthisType.string().min(2).max(100).withDefault('Unknown');
  print(name.tryParse(''));
  print(name.tryParse('Acanthis'));
  final literalTemplate = template(['user_', literal(5), '_end']);
  print(literalTemplate.pattern);
  print(literalTemplate.parse('user_5_end'));
  final res = updateSchema.tryParse({
    'name': 'John Doe',
    'businessName': 'Acme Corp',
    'mobileNumber': '1234567890',
    'email': 'john.doe@example.com',
    'password': 'password123',
  });
  print(res.value);
}
