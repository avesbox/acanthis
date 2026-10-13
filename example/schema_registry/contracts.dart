import 'package:acanthis/acanthis.dart';

const addressKey =
    SchemaKey<Map<String, dynamic>, AcanthisMap<dynamic>>('common.address.v1');
final addressSchema = object({'city': string().notEmpty()});
