import 'package:acanthis/acanthis.dart';
import 'contracts.dart';

ObjectSchema shippingSchema(SchemaRegistry schemas) =>
    object({'shipping': schemas.get(addressKey)});
