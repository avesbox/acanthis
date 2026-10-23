import 'package:acanthis/acanthis.dart';
import 'contracts.dart';

// Resolve dependencies once during setup, then retain the composed validator.
ObjectSchema billingSchema(SchemaRegistry schemas) =>
    object({'billing': schemas.get(addressKey)});
