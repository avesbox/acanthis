import 'package:acanthis/acanthis.dart';

/// Represents a guarded variant inside a union.
/// The [guard] decides if this variant should be attempted for a given value.
class AcanthisVariant<T> {
  final bool Function(dynamic value) guard;
  final AcanthisType<T> schema;
  final String name;

  const AcanthisVariant({
    required this.guard,
    required this.schema,
    this.name = '',
  });
}

/// Factory to create a variant.
AcanthisVariant<T> variant<T>({
  required bool Function(dynamic value) guard,
  required AcanthisType<T> schema,
  String name = '',
}) => AcanthisVariant<T>(guard: guard, schema: schema, name: name);
