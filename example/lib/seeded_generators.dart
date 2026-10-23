import 'package:acanthis/acanthis.dart';

void main() {
  final sku = string().pattern(RegExp(r'^SKU-\d{3}$'));
  final length = string().min(2).max(12).pipe(
        integer().gte(2).lte(12),
        transform: (s) => s.length,
      );
  final schema = object({
    'id': string().uuid(),
    'url': string().url(),
    'created': string().dateTime(),
    'payload': string().base64().length(12),
    'lengths': list(length).length(3),
    'sku': sku,
  });
  final generators = <Schema<Object?, Object?>, AcanthisMockGenerator>{
    sku: (random) => 'SKU-${100 + random.nextInt(900)}',
  };
  final sample = schema.mockSeeded(seed: 42, generators: generators);
  final repeated = schema.mockSeeded(seed: 42, generators: generators);
  if (sample.toString() != repeated.toString() ||
      !sku.validate(sample['sku']) ||
      !(sample['lengths'] as List<int>).every((i) => i >= 2 && i <= 12)) {
    throw StateError('Mock generation must remain typed and reproducible');
  }
  print(sample);
}
