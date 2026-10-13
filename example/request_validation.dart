import 'dart:convert';

import 'package:acanthis/acanthis.dart';

class Account {
  final String name;
  final String email;
  final String? nickname;

  const Account(this.name, this.email, this.nickname);

  Map<String, Object?> toJson() => {
        'name': name,
        'email': email,
        'nickname': nickname,
      };
}

typedef ApiResponse = ({int status, Map<String, Object?> body});

final accountInput = object({
  'name': string().min(2),
  'email': string().email(),
  'nickname': string().nullable(),
}).optionals(['nickname']).unknownKeys(AcanthisUnknownKeys.reject);

final accountPatch = accountInput.patch();

ApiResponse handleAccount(String body, {Account? existing}) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return (status: 400, body: {'error': 'Malformed JSON'});
  }
  if (decoded is! Map<String, dynamic>) {
    return (status: 400, body: {'error': 'Expected a JSON object'});
  }

  final result =
      (existing == null ? accountInput : accountPatch).tryParse(decoded);
  if (!result.isValid) {
    return (
      status: 422,
      body: {'issues': result.issues.map((issue) => issue.toJson()).toList()},
    );
  }

  final values = result.value;
  final account = Account(
    values.containsKey('name') ? values['name'] as String : existing!.name,
    values.containsKey('email') ? values['email'] as String : existing!.email,
    values.containsKey('nickname')
        ? values['nickname'] as String?
        : existing?.nickname,
  );
  return (status: existing == null ? 201 : 200, body: account.toJson());
}

void main() {
  print(handleAccount('{"name":"Ada","email":"ada@example.com"}'));
  print(handleAccount('{"name":"A","email":"invalid"}'));
  print(handleAccount('['));
  print(handleAccount('[]'));
  const existing = Account('Ada', 'ada@example.com', 'Countess');
  print(handleAccount('{"nickname":null}', existing: existing));
  print(handleAccount('{}', existing: existing));
}
