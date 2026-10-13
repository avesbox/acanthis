import 'package:acanthis/acanthis.dart';
import 'contracts.dart';

AcanthisMap<dynamic> shippingSchema(SchemaRegistry schemas) =>
    object({'shipping': schemas.get(addressKey)});
