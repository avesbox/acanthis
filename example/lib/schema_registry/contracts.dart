import 'package:acanthis/acanthis.dart';

const addressKey =
    SchemaKey<Map<String, Object?>, ObjectSchema>('common.address.v1');
final addressSchema = object({'city': string().notEmpty()});
