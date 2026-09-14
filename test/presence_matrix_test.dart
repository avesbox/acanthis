import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/presence_matrix.dart';

void main() {
  test(
    'presence matrix characterizes parsing modes and both exports',
    () async {
      final expected = jsonDecode(
        await File('test/fixtures/presence_matrix.json').readAsString(),
      );
      expect(await presenceMatrix(), expected);
    },
  );
}
