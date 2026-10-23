import 'package:acanthis/acanthis.dart';

void main() {
  final num amount = number().coerce().finite().gte(0).parse('12.5');
  final int squared = integer().coerce().positive().pow(2).parse('3');
  final double ratio = doubleType().coerce().between(0.0, 1.0).parse('0.5');
  print('$amount, $squared, $ratio');

  final result = integer().pow(-1).tryParse(2);
  final messages = AcanthisMessageCatalog.english.extend({
    'transform': (p) =>
        'Impossibile applicare ${p['operation']} al tipo intero',
  });
  print(result.issues.single.formatMessage(catalog: messages));
}
