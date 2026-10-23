class Payloads {
  static Map<String, dynamic> get objectArrayPayload => {
    'contacts': [
      {'type': 'email', 'value': 'foo@bar.com'},
      {'type': 'phone', 'value': '12345678'},
    ],
  };

  static Map<String, dynamic> get nestedObjectPayload => {
    'username': 'John Doe',
    'password': 'secret',
    'contact': {'name': 'John Doe', 'address': '123 Main St'},
  };

  static Map<String, dynamic> get flatObjectPayload => {
    'firstname': 'John',
    'lastname': 'Doe',
  };

  static String get longStringPayload => 'long' * 256;

  static String get fixedLengthStringPayload => 'long';

  static String get emptyStringPayload => '';

  static String get emailStringPayload => 'email@example.com';

  static String get uuidStringPayload => '550e8400-e29b-41d4-a716-446655440000';
}
