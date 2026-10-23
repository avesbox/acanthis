import 'package:acanthis/acanthis.dart';
import 'billing.dart';
import 'contracts.dart';
import 'shipping.dart';

void main() {
  final schemas =
      (SchemaRegistryBuilder()..add(addressKey, addressSchema)).build();
  final ObjectSchema address = schemas.get(addressKey);
  final billing = billingSchema(schemas);
  final shipping = shippingSchema(schemas);
  if (!identical(address, addressSchema) ||
      !identical(billing.fields['billing'], address) ||
      !identical(shipping.fields['shipping'], address)) {
    throw StateError('Registry lookup must preserve schema identity');
  }
  billing.parse({
    'billing': {'city': 'Rome'}
  });
  shipping.parse({
    'shipping': {'city': 'Milan'}
  });
  print('Cross-module registry reuse passed');
}
