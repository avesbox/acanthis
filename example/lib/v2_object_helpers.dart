import 'package:acanthis/acanthis.dart';

void main() {
  final contact = object({
    'name': string().trim(),
    'address': object({'city': string(), 'country': string()}),
  });
  final stored = contact.extend({'active': boolean().withDefault(true)});
  print(stored.pick(['name', 'active']).parse({'name': ' Ada '}));
  // {name: Ada, active: true}

  final update = stored.patch(deep: true);
  print(update.parse({
    'address': {'city': 'Rome'}
  }));
  // {address: {city: Rome}}

  final flags = object({'label': string()})
      .passthrough(type: boolean())
      .minProperties(1)
      .maxProperties(3);
  print(flags.parse({'label': 'Features', 'enabled': true}));
  print(flags.toJsonSchema(mode: AcanthisSchemaMode.input));
}
