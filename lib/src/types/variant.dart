import '../common/schema.dart';

/// A guarded union branch. Guards run before plain alternatives.
final class AcanthisVariant<T> {
  const AcanthisVariant({
    required this.guard,
    required this.schema,
    this.name = '',
  });
  final bool Function(Object?) guard;
  final Schema<Object?, T> schema;
  final String name;
}

AcanthisVariant<T> variant<T>({
  required bool Function(Object?) guard,
  required Schema<Object?, T> schema,
  String name = '',
}) => AcanthisVariant(guard: guard, schema: schema, name: name);
