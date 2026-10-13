// Existing-behavior checks for doc/schema-registry-analysis.md.
import 'dart:convert';

import 'package:acanthis/acanthis.dart';

void verify(bool condition, String description) {
  if (!condition) throw StateError(description);
  print('PASS: $description');
}

void main() {
  final address = object({'city': string().notEmpty()});
  final order = object({'billing': address, 'shipping': address});
  verify(
    identical(order.fields['billing'], address) &&
        identical(order.fields['shipping'], address),
    'composition reuses the original schema instance',
  );
  final failed = order.tryParse({
    'billing': {'city': ''},
    'shipping': {'city': 'Rome'},
  });
  verify(
    failed.issues.single.jsonPointer == '/billing/city',
    'reused schema diagnostics retain the use-site path',
  );
  final base = string();
  final derived = base.notEmpty();
  verify(
    !identical(base, derived) &&
        base.tryParse('').isValid &&
        !derived.tryParse('').isValid,
    'fluent derivation leaves the base string schema unchanged',
  );
  final exported = order.exportJsonSchema(mode: AcanthisSchemaMode.input);
  final properties = exported['properties'] as Map;
  verify(
    !exported.containsKey(r'$defs') &&
        (properties['billing'] as Map)['type'] == 'object' &&
        (properties['shipping'] as Map)['type'] == 'object',
    'repeated non-recursive schema is exported inline twice',
  );
  final tree = object({'children': lazy((parent) => parent.list())});
  verify(
    jsonEncode(tree.exportJsonSchema(mode: AcanthisSchemaMode.input))
        .contains(r'"$ref":"#/$defs/schema0"'),
    'stable recursion already uses local definitions',
  );
  final fields = <String, AcanthisType>{'city': string()};
  final externallyMutable = object(fields);
  fields['city'] = number();
  verify(
    identical(externallyMutable.fields['city'], fields['city']),
    'object construction retains the caller-owned field map',
  );
}
