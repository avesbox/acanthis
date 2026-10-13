import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';

int sink = 0;
void main(List<String> args) {
  final schema = object({'email': string().min(3), 'age': integer().gte(18)});
  final input = {'email': 'x', 'age': 12};
  final issues = schema.tryParse(input).issues;
  final workloads = <String, void Function()>{
    'collect': () {
      sink += schema.tryParse(input).issues.length;
    },
    'fallback': () {
      sink += issues.formatJson().length;
    },
    'english': () {
      sink += issues
          .formatJson(resolver: AcanthisMessageCatalogs.english)
          .length;
    },
    'italian': () {
      sink += issues
          .formatJson(resolver: AcanthisMessageCatalogs.italian)
          .length;
    },
    'transport': () {
      sink += jsonEncode(issues.toTransport()).length;
    },
    'validateFallback': () {
      sink += schema.validate(input)!.length;
    },
    'validateItalian': () {
      sink += schema
          .validate(input, resolver: AcanthisMessageCatalogs.italian)!
          .length;
    },
  };
  final samples = <String, Object?>{};
  for (final entry in workloads.entries) {
    for (var i = 0; i < 5000; i++) {
      entry.value();
    }
    final timings = <double>[];
    for (var sample = 0; sample < 7; sample++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 20000; i++) {
        entry.value();
      }
      watch.stop();
      timings.add(watch.elapsedMicroseconds / 20000);
    }
    final ordered = [...timings]..sort();
    samples[entry.key] = {
      'microsecondsPerOperation': timings,
      'median': ordered[3],
    };
  }
  final output = const JsonEncoder.withIndent('  ').convert({
    'runtime': Platform.version,
    'os': Platform.operatingSystem,
    'processors': Platform.numberOfProcessors,
    'samples': samples,
    'sink': sink,
  });
  if (args.isNotEmpty) {
    File(args.first).writeAsStringSync('$output\n');
  }
  print(output);
}
