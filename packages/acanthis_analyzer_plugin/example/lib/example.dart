import 'package:acanthis/acanthis.dart';

// On the schema declaration below, invoke "Generate or sync typed schema DTO".
final userSchema = object({
  'name': string(),
  'age': integer(),
}).passthrough().refineAsync(CallbackAsyncCheck((_, _) async {}));

void demonstrateWarnings() {
  userSchema.pick(['unknown']);
  userSchema.parse({});
}
