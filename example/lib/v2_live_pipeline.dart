import 'package:acanthis/acanthis.dart';

Future<void> main() async {
  final schema = object({
    'age': string().trim().pipe(integer().gte(18), transform: int.parse),
    'name': string().min(1),
  });
  final session = await schema.watchAsync(
    {'age': '21', 'name': 'Ada'},
    debounce: const Duration(milliseconds: 25),
  );
  try {
    final result = await session.batch([
      AcanthisEdit.set('age', '24'),
      AcanthisEdit.set('name', 'Grace'),
    ]);
    assert(result.isCurrent && result.settled);
    assert(result.validated!['age'] == 24);
    final invalid = await session.set('age', '17');
    assert(invalid.addedIssues.single.code == 'gte');
    final corrected = await session.set('age', '18');
    assert(corrected.removedIssues.single.code == 'gte');
    print(corrected.validated);
  } finally {
    session.dispose();
  }
}
