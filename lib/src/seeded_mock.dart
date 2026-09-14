import 'dart:math';

import 'package:acanthis/acanthis.dart';

import 'operations/checks.dart';
import 'validators/boolean.dart';
import 'validators/common.dart';
import 'validators/list.dart';
import 'validators/number.dart';
import 'validators/string.dart';

/// A bounded generator failure, distinct from a validation failure.
class AcanthisMockException implements Exception {
  const AcanthisMockException(this.reason);
  final String reason;
  @override
  String toString() => 'AcanthisMockException: $reason';
}

extension AcanthisSeededMock<T> on AcanthisType<T> {
  /// Generate a reproducible, validated value for the documented subset.
  /// Opaque callbacks are rejected without execution. Resource limits are hard
  /// bounds, not a claim that all satisfiable constraints can be solved.
  T mockSeeded({
    int seed = 0,
    int maxAttempts = 64,
    int maxDepth = 16,
    int maxCollectionLength = 256,
    int maxNodes = 4096,
  }) {
    if (maxAttempts < 1 ||
        maxDepth < 1 ||
        maxCollectionLength < 1 ||
        maxNodes < 1) {
      throw ArgumentError('Generator limits must be positive');
    }
    final generator = _Generator(
      Random(seed),
      maxDepth,
      maxCollectionLength,
      maxNodes,
    );
    generator.check(this, 0);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      generator.remaining = maxNodes;
      final candidate = generator.generate(this, 0);
      final result = tryParse(candidate);
      if (result.success && tryParse(result.value).success) return result.value;
    }
    throw AcanthisMockException(
      'No valid value found after $maxAttempts attempts: constraints are contradictory or outside the bounded search domain',
    );
  }
}

class _Generator {
  _Generator(this.random, this.maxDepth, this.maxLength, this.remaining);
  final Random random;
  final int maxDepth;
  final int maxLength;
  int remaining;

  void check(AcanthisType schema, int depth) {
    if (--remaining < 0) {
      throw const AcanthisMockException("Schema node budget exceeded");
    }
    if (depth >= maxDepth) {
      throw const AcanthisMockException('Maximum schema depth exceeded');
    }
    final type = schema.runtimeType;
    const supported = <Type>{
      AcanthisString,
      AcanthisLiteral<dynamic>,
      AcanthisLiteral<String>,
      AcanthisLiteral<int>,
      AcanthisLiteral<double>,
      AcanthisLiteral<num>,
      AcanthisLiteral<bool>,
      AcanthisBoolean,
      AcanthisNumeric<int>,
      AcanthisNumeric<double>,
      AcanthisNumeric<num>,
      AcanthisMap<dynamic>,
      AcanthisTuple,
      AcanthisList<String>,
      AcanthisList<int>,
      AcanthisList<double>,
      AcanthisList<num>,
      AcanthisList<bool>,
      AcanthisList<dynamic>,
      AcanthisList<Map<String, dynamic>>,
      AcanthisNullable<String>,
      AcanthisNullable<int>,
      AcanthisNullable<double>,
      AcanthisNullable<num>,
      AcanthisNullable<bool>,
    };
    if (!supported.contains(type)) {
      throw AcanthisMockException('Unsupported or opaque schema: $type');
    }
    if (schema.isAsync) {
      throw const AcanthisMockException(
        'Async schemas and callbacks are unsupported',
      );
    }
    if (schema is AcanthisLiteral &&
        schema.value != null &&
        schema.value is! String &&
        schema.value is! num &&
        schema.value is! bool) {
      throw const AcanthisMockException(
        'Only primitive literal values are supported',
      );
    }
    const checks = <Type>{
      MinStringLengthCheck,
      MaxStringLengthCheck,
      ExactStringLengthCheck,
      EmailStringCheck,
      NotEmptyStringCheck,
      RequiredStringCheck,
      ExactCheck<String>,
      ExactCheck<int>,
      ExactCheck<double>,
      ExactCheck<num>,
      ExactCheck<bool>,
      IsTrueCheck,
      IsFalseCheck,
      GteNumberCheck<int>,
      GteNumberCheck<double>,
      GteNumberCheck<num>,
      LteNumberCheck<int>,
      LteNumberCheck<double>,
      LteNumberCheck<num>,
      MinItemsListCheck<String>,
      MinItemsListCheck<int>,
      MinItemsListCheck<dynamic>,
      MaxItemsListCheck<String>,
      MaxItemsListCheck<int>,
      MaxItemsListCheck<dynamic>,
      LengthListCheck<String>,
      LengthListCheck<int>,
      LengthListCheck<dynamic>,
      UniqueItemsListCheck<String>,
      UniqueItemsListCheck<int>,
      UniqueItemsListCheck<dynamic>,
    };
    for (final op in schema.operations) {
      if (!checks.contains(op.runtimeType)) {
        throw AcanthisMockException(
          'Unsupported or opaque operation: ${op.runtimeType}; callbacks and transformations are not executed',
        );
      }
    }
    if (schema is AcanthisMap) {
      if (schema.hasCrossFieldDependencies) {
        throw const AcanthisMockException(
          'Opaque cross-field dependencies are unsupported',
        );
      }
      for (final child in schema.fields.values) {
        check(child, depth + 1);
      }
    } else if (schema is AcanthisList) {
      check(schema.element, depth + 1);
    } else if (schema is AcanthisNullable) {
      check(schema.element, depth + 1);
    } else if (schema is AcanthisTuple) {
      for (final child in schema.elements) {
        check(child, depth + 1);
      }
    }
  }

  dynamic generate(AcanthisType schema, int depth) {
    if (--remaining < 0) {
      throw const AcanthisMockException("Generated value node budget exceeded");
    }
    final checks = schema.operations.whereType<AcanthisCheck>().toList();
    if (schema is AcanthisLiteral) return schema.value;
    for (final check in checks) {
      if (check is ExactCheck) return check.value;
    }
    if (schema is AcanthisNullable) {
      return random.nextBool() ? null : generate(schema.element, depth + 1);
    }
    if (schema is AcanthisMap) {
      return <String, dynamic>{
        for (final entry in schema.fields.entries)
          entry.key: generate(entry.value, depth + 1),
      };
    }
    if (schema is AcanthisTuple) {
      return [for (final child in schema.elements) generate(child, depth + 1)];
    }
    if (schema is AcanthisBoolean) {
      if (checks.any((c) => c is IsTrueCheck)) return true;
      if (checks.any((c) => c is IsFalseCheck)) return false;
      return random.nextBool();
    }
    if (schema is AcanthisNumeric) {
      num low = -1000, high = 1000;
      for (final check in checks) {
        if (check is GteNumberCheck) low = max(low, check.value);
        if (check is LteNumberCheck) high = min(high, check.value);
      }
      if (low > high) {
        throw const AcanthisMockException(
          'Contradictory numeric bounds or bounds outside [-1000, 1000]',
        );
      }
      if (schema is AcanthisNumeric<int>) {
        return low.ceil() + random.nextInt(high.floor() - low.ceil() + 1);
      }
      return low.toDouble() + random.nextDouble() * (high - low);
    }
    var low = 0, high = maxLength;
    for (final check in checks) {
      if (check is MinStringLengthCheck) low = max(low, check.value);
      if (check is MaxStringLengthCheck) high = min(high, check.value);
      if (check is ExactStringLengthCheck) {
        low = max(low, check.value);
        high = min(high, check.value);
      }
      if (check is MinItemsListCheck) low = max(low, check.minItems);
      if (check is MaxItemsListCheck) high = min(high, check.maxItems);
      if (check is LengthListCheck) {
        low = max(low, check.length);
        high = min(high, check.length);
      }
      if (check is NotEmptyStringCheck || check is RequiredStringCheck) {
        low = max(low, 1);
      }
    }
    if (low > high || low > maxLength || high < 0) {
      throw const AcanthisMockException(
        'Contradictory length bounds or configured generation limit exceeded',
      );
    }
    final length = low + random.nextInt(high - low + 1);
    if (schema is AcanthisList) {
      return List.generate(length, (_) => generate(schema.element, depth + 1));
    }
    if (checks.any((c) => c is EmailStringCheck)) {
      return 'u${random.nextInt(100000)}@example.com';
    }
    return String.fromCharCodes(
      List.generate(length, (_) => 97 + random.nextInt(26)),
    );
  }
}
