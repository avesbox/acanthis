import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  final email = acanthis.string().email().min(5).max(20);
  final result = email.tryParse('test@test.com');

  if (result.isValid) {
    print('Email is valid');
  } else {
    print('Email is invalid');
  }
}
