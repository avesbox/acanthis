import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'common/schema.dart';
import 'common/schema_graph.dart';
import 'common/validation_scope.dart';
import 'common/results.dart';
import 'types/boolean.dart';
import 'types/date.dart';
import 'types/list.dart';
import 'types/lazy.dart';
import 'types/instance.dart';
import 'types/pipeline.dart';
import 'types/literal.dart';
import 'types/nullable.dart';
import 'types/number.dart';
import 'types/object.dart';
import 'types/record.dart';
import 'types/string.dart';
import 'types/template.dart';
import 'types/tuple.dart';
import 'types/union.dart';
import 'validators/boolean.dart';
import 'validators/common.dart';
import 'validators/date.dart';
import 'validators/list.dart';
import 'validators/nullable.dart';
import 'validators/number.dart';
import 'validators/object.dart';
import 'validators/string.dart';

final class AcanthisMockException implements Exception {
  const AcanthisMockException(this.reason);
  final String reason;
  @override
  String toString() => 'AcanthisMockException: $reason';
}

/// Supplies a raw input candidate using the mock run's seeded random stream.
typedef AcanthisMockGenerator = Object? Function(Random random);

extension AcanthisSeededMock<I, O> on Schema<I, O> {
  O mock([int? seed]) => mockSeeded(seed: seed ?? Random().nextInt(1 << 30));

  /// Generates bounded, validated samples. Instance construction needs a factory.
  ///
  /// [generators] supplies raw input candidates for exact schema identities.
  /// Each provider shares the seeded random stream and opts its subtree into
  /// synchronous validation, including custom checks and transforms. Candidates
  /// and results are bounded; callbacks must be pure and terminate themselves.
  O mockSeeded({
    int seed = 0,
    int maxAttempts = 64,
    int maxDepth = 16,
    int maxCollectionLength = 256,
    int maxNodes = 4096,
    Map<Schema<Object?, Object?>, AcanthisMockGenerator> generators = const {},
  }) {
    if (maxAttempts < 1 ||
        maxDepth < 1 ||
        maxDepth > 128 ||
        maxCollectionLength < 1 ||
        maxNodes < 1) {
      throw ArgumentError(
        'Limits must be positive; maxDepth must not exceed 128',
      );
    }
    final generator = _Generator(
      Random(seed),
      maxDepth,
      maxCollectionLength,
      maxNodes,
      HashMap.identity()..addAll(generators),
    );
    final pipeline =
        this is AcanthisPipeline && !generator.generators.containsKey(this)
        ? this as AcanthisPipeline
        : null;
    generator.audit(this, 0, HashSet.identity());
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      generator.remaining = maxNodes;
      try {
        final result = pipeline == null
            ? tryParse(generator.generate(this, 0))
            : generator.pipelineCandidate(pipeline, 0);
        if (result.isValid &&
            (generator.hasConversions || tryParse(result.value).isValid)) {
          generator.remaining = maxNodes;
          generator.auditValue(
            result.value,
            0,
            HashSet.identity(),
            schema: pipeline?.outType ?? this,
          );
          return result.value as O;
        }
      } on _RejectedMockCandidate {
        continue;
      }
    }
    throw AcanthisMockException(
      'No valid value found after $maxAttempts attempts; constraints are contradictory or outside the bounded search domain',
    );
  }
}

final class _RejectedMockCandidate implements Exception {
  const _RejectedMockCandidate();
}

final class _Generator {
  _Generator(
    this.random,
    this.maxDepth,
    this.maxLength,
    this.remaining,
    this.generators,
  );
  final Random random;
  final int maxDepth;
  final int maxLength;
  int remaining;
  final Map<Schema<Object?, Object?>, AcanthisMockGenerator> generators;
  bool hasConversions = false;
  Never fail(String reason) => throw AcanthisMockException(reason);
  void spend(int depth) {
    AcanthisValidationScope.current.throwIfCancelled();
    if (--remaining < 0) fail('Node budget exceeded');
    if (depth >= maxDepth) fail('Maximum depth exceeded');
  }

  List<Object> checks(Schema<Object?, Object?> schema) =>
      schema is CheckableSchema<Object?, Object?> ? schema.checks : const [];

  void auditPipelineInput(
    Schema<Object?, Object?> schema,
    int depth,
    Set<Schema<Object?, Object?>> seen,
  ) {
    if (schema is AcanthisPipeline) {
      if (generators.containsKey(schema)) {
        audit(schema, depth, seen);
        return;
      }
      hasConversions = true;
      spend(depth);
      if (!seen.add(schema)) return;
      if (schema.hasLocalAsync) fail('Async callbacks are unsupported');
      auditOutputOperations(schema, depth);
      auditPipelineInput(schema.inType, depth + 1, seen);
      auditOutputShape(schema.outType, depth + 1, HashSet.identity());
    } else {
      audit(schema, depth, seen);
    }
  }

  void auditOutputOperations(Schema<Object?, Object?> schema, int depth) {
    for (final _ in checks(schema)) {
      spend(depth);
    }
    if (schema is TransformableSchema<Object?, Object?>) {
      for (final _ in schema.transformations) {
        spend(depth);
      }
    }
  }

  // Output callbacks validate mapped values; audit their budget without running them.
  void auditOutputShape(
    Schema<Object?, Object?> schema,
    int depth,
    Set<Schema<Object?, Object?>> seen,
  ) {
    spend(depth);
    if (!seen.add(schema)) return;
    if (schema is LazyEntry ||
        schema is ResolvedSchema && schema is! MetadataSchemaView) {
      fail(
        'Lazy resolvers require a finite, explicitly resolved source schema',
      );
    }
    if (schema is SchemaGraphNode
        ? (schema as SchemaGraphNode).hasLocalAsync
        : schema is AsyncSchema<Object?, Object?> && schema.isAsync) {
      fail('Async callbacks are unsupported');
    }
    auditOutputOperations(schema, depth);
    for (final child in children(schema)) {
      auditOutputShape(child, depth + 1, seen);
    }
  }

  AcanthisOutcome<Object?> pipelineCandidate(
    Schema<Object?, Object?> schema,
    int depth,
  ) {
    if (generators.containsKey(schema)) {
      return schema.tryParse(generate(schema, depth));
    }
    if (schema is AcanthisPipeline) {
      spend(depth);
      final input = pipelineCandidate(schema.inType, depth + 1);
      if (!input.isValid) return AcanthisInvalid.withoutValue(input.issues);
      return schema.mockFromParsedInput(input.value);
    }
    return schema.tryParse(generate(schema, depth));
  }

  bool outputMatches(
    Schema<Object?, Object?> schema,
    Object? value,
    int depth,
  ) {
    spend(depth);
    while (schema is AcanthisPipeline || schema is MetadataSchemaView) {
      spend(depth);
      schema = schema is AcanthisPipeline
          ? schema.outType
          : (schema as MetadataSchemaView).schema;
    }
    final output = schema;
    if (output is AcanthisNullable) {
      return value == null || outputMatches(output.element, value, depth + 1);
    }
    if (output is AcanthisUnion) {
      return children(output)
          .any((child) => outputMatches(child, value, depth + 1));
    }
    if (output is InstanceType) {
      return output.parseValue(value, true).isValid &&
          output.fieldDefinitions.every((field) {
            final item = field.read(value);
            return field.optional && item == null ||
                outputMatches(field.schema, item, depth + 1);
          });
    }
    if (output is AcanthisList) {
      return value is List &&
          value.every((item) => outputMatches(output.element, item, depth + 1));
    }
    if (output is AcanthisTuple) {
      if (value is! List || value.length < output.elements.length) return false;
      for (var i = 0; i < value.length; i++) {
        if (output.elements.isEmpty ||
            !outputMatches(
              output.elements[min(i, output.elements.length - 1)],
              value[i],
              depth + 1,
            )) {
          return false;
        }
      }
      return true;
    }
    if (output is ObjectSchema) {
      return value is Map &&
          output.fields.entries.every(
            (field) => !value.containsKey(field.key)
                ? output.isOptionalField(field.key)
                : outputMatches(field.value, value[field.key], depth + 1),
          );
    }
    if (output is RecordSchema) {
      return value is Map &&
          value.entries.every(
            (entry) =>
                outputMatches(output.key, entry.key, depth + 1) &&
                outputMatches(output.value, entry.value, depth + 1),
          );
    }
    // Branch inspection must not repeat validation callbacks or conversions.
    return switch (output) {
      AcanthisString() || AcanthisTemplate() => value is String,
      AcanthisNumeric<int>() => value is int,
      AcanthisNumeric<double>() => value is double,
      AcanthisNumeric() => value is num,
      AcanthisBoolean() => value is bool,
      AcanthisDate() => value is DateTime,
      AcanthisLiteral() => value == output.value,
      _ => scalar(value),
    };
  }

  bool scalar(Object? value) =>
      value == null ||
      value is String ||
      value is num ||
      value is bool ||
      value is DateTime;
  void value(Object? item) {
    if (!scalar(item)) {
      fail('Only scalar equality and membership values are supported');
    }
    if (item is String && item.length > maxLength) {
      fail('String exceeds the collection length limit');
    }
  }

  void auditValue(
    Object? item,
    int depth,
    Set<Object> active, {
    Schema<Object?, Object?>? schema,
  }) {
    spend(depth);
    while (true) {
      if (schema is MetadataSchemaView) {
        schema = schema.schema;
      } else if (schema is AcanthisNullable) {
        schema = schema.element;
      } else if (schema is AcanthisPipeline) {
        schema = schema.outType;
      } else if (schema is AcanthisUnion) {
        var matched = false;
        for (final child in children(schema)) {
          if (!outputMatches(child, item, depth)) continue;
          matched = true;
          auditValue(item, depth + 1, active, schema: child);
        }
        if (matched) return;
        schema = null;
      } else {
        break;
      }
      spend(depth);
    }
    if (scalar(item) && schema is! InstanceType) {
      value(item);
      return;
    }
    if (schema is! InstanceType && item is! Map && item is! List) {
      fail('Opaque default or generated value');
    }
    final tracked = item != null && !scalar(item);
    if (tracked && !active.add(item)) fail('Cyclic default or generated value');
    try {
      if (schema is InstanceType) {
        if (schema.fieldDefinitions.length > maxLength) {
          fail('Instance field limit exceeded');
        }
        for (final field in schema.fieldDefinitions) {
          value(field.name);
          auditValue(field.read(item), depth + 1, active, schema: field.schema);
        }
      } else if (item is List) {
        if (item.length > maxLength) fail('Collection length limit exceeded');
        for (var i = 0; i < item.length; i++) {
          final child = schema is AcanthisList
              ? schema.element
              : schema is AcanthisTuple && schema.elements.isNotEmpty
              ? schema.elements[min(i, schema.elements.length - 1)]
              : null;
          auditValue(item[i], depth + 1, active, schema: child);
        }
      } else {
        final map = item as Map;
        if (map.length > maxLength) fail('Collection length limit exceeded');
        for (final entry in map.entries) {
          auditValue(
            entry.key,
            depth + 1,
            active,
            schema: schema is RecordSchema ? schema.key : null,
          );
          final child = schema is RecordSchema
              ? schema.value
              : schema is ObjectSchema
              ? schema.fields[entry.key] ?? schema.additionalValueType
              : null;
          auditValue(entry.value, depth + 1, active, schema: child);
        }
      }
    } finally {
      if (tracked) active.remove(item);
    }
  }

  void audit(
    Schema<Object?, Object?> schema,
    int depth,
    Set<Schema<Object?, Object?>> seen,
  ) {
    if (schema is AcanthisPipeline && !generators.containsKey(schema)) {
      auditPipelineInput(schema, depth, seen);
      return;
    }
    spend(depth);
    if (!seen.add(schema)) return;
    if (generators.containsKey(schema)) {
      hasConversions = true;
      // A provider explicitly opts this subtree into synchronous validation.
      auditOutputShape(schema, depth, HashSet.identity());
      return;
    }
    if (schema is MetadataSchemaView) {
      audit(schema.schema, depth, seen);
      return;
    }
    if (schema is InstanceType) {
      if (schema.mockFactory == null) {
        fail('Instance mocks require withFactory((fields) => T(...))');
      }
      if (schema.fieldDefinitions.length > maxLength) {
        fail('Instance field limit exceeded');
      }
    }
    if (schema is! InstanceType &&
        schema is! AcanthisString &&
        schema is! AcanthisNumeric &&
        schema is! AcanthisDate &&
        schema is! AcanthisBoolean &&
        schema is! AcanthisLiteral &&
        schema is! AcanthisNullable &&
        schema is! AcanthisList &&
        schema is! ObjectSchema &&
        schema is! RecordSchema &&
        schema is! AcanthisTuple &&
        schema is! AcanthisUnion &&
        schema is! AcanthisTemplate) {
      fail(
        'Unsupported or opaque schema: ${schema.runtimeType}; lazy resolvers are not executed',
      );
    }
    if (schema is ObjectSchema && schema.hasCrossFieldRules) {
      fail('Cross-field callbacks are unsupported');
    }
    if (schema is AcanthisUnion && schema.hasGuards) {
      fail('Variant guards are opaque callbacks');
    }
    final async = schema is SchemaGraphNode
        ? (schema as SchemaGraphNode).hasLocalAsync
        : schema is AsyncSchema<Object?, Object?> && schema.isAsync;
    if (async) fail('Async callbacks are unsupported');
    if (schema is TransformableSchema<Object?, Object?> &&
        schema.transformations.isNotEmpty) {
      fail('Transformations are unsupported');
    }
    for (final check in checks(schema)) {
      spend(depth);
      if (check is! NumberCheck<num> &&
          check is! BooleanCheck &&
          check is! ListCheck<Object?> &&
          check is! ObjectCheck &&
          check is! ExactCheck<Object?> &&
          check is! EnumeratedNullableCheck<Object?> &&
          !{
            MinStringLengthCheck,
            MaxStringLengthCheck,
            ExactStringLengthCheck,
            EmailStringCheck,
            UriStringCheck,
            UrlStringCheck,
            PatternUuidStringChecks,
            DateTimeStringCheck,
            PatternBase64StringChecks,
            NotEmptyStringCheck,
            RequiredStringCheck,
            UpperCaseStringCheck,
            LowerCaseStringCheck,
            MixedCaseStringCheck,
            MinDateCheck,
            MaxDateCheck,
            DiffersFromCheck,
          }.contains(check.runtimeType) &&
          check is! EnumeratedStringCheck) {
        fail('Unsupported or opaque check: ${check.runtimeType}');
      }
      if (check is ExactCheck<Object?>) value(check.value);
      if (check is ContainsListCheck<Object?>) value(check.item);
      if (check is AnyOfListCheck<Object?>) {
        for (final item in check.items) {
          spend(depth);
          value(item);
        }
      }
      if (check is EveryOfListCheck<Object?>) {
        for (final item in check.items) {
          spend(depth);
          value(item);
        }
      }
      if (check is EnumeratedNullableCheck<Object?>) {
        for (final item in check.values) {
          spend(depth);
          value(item);
        }
      }
      if (check is EnumeratedStringCheck) {
        for (final item in check.values) {
          spend(depth);
          value(item);
        }
      }
      if (check is EnumeratedNumberCheck) {
        for (final item in check.values) {
          spend(depth);
          value(item);
        }
      }
    }
    if (schema is AcanthisLiteral) value(schema.value);
    for (final child in children(schema)) {
      audit(child, depth + 1, seen);
    }
    if (schema is DefaultSchema<Object?, Object?> && schema.hasDefault) {
      auditValue(
        schema.defaultValue,
        depth,
        HashSet.identity(),
        schema: schema,
      );
    }
  }

  Iterable<Schema<Object?, Object?>> children(
    Schema<Object?, Object?> schema,
  ) => schema is ObjectSchema
      ? [
          ...schema.fields.values,
          if (schema.additionalValueType != null) schema.additionalValueType!,
        ]
      : schema is SchemaGraphNode
      ? (schema as SchemaGraphNode).schemaChildren
      : const [];

  int length(int low, int high) {
    high = min(high, maxLength);
    low = max(low, 0);
    if (low > high) {
      fail('Contradictory length bounds or generation limit exceeded');
    }
    // shortcut: sample at most eight extra items; widen this search if sparse constraints need it.
    return low + random.nextInt(min(high - low, 8) + 1);
  }

  Object? choose(List<Object?> values) {
    if (values.isEmpty) fail('Empty finite generation domain');
    return values[random.nextInt(values.length)];
  }

  Object? generate(Schema<Object?, Object?> schema, int depth) {
    spend(depth);
    final provider = generators[schema];
    if (provider != null) {
      final candidate = provider(random);
      auditValue(
        candidate,
        depth,
        HashSet.identity(),
        schema: schema is InstanceType ? schema : null,
      );
      return candidate;
    }
    if (schema is MetadataSchemaView) return generate(schema.schema, depth);
    if (schema is AcanthisPipeline) return generate(schema.inType, depth + 1);
    final constraints = checks(schema);
    if (schema is InstanceType) {
      final fields = <String, Object?>{};
      for (final field in schema.fieldDefinitions) {
        spend(depth + 1);
        if (field.optional && random.nextBool()) continue;
        final child = field.schema.tryParse(generate(field.schema, depth + 1));
        if (!child.isValid) throw const _RejectedMockCandidate();
        fields[field.name] = child.value;
      }
      AcanthisValidationScope.current.throwIfCancelled();
      final result = schema.mockFactory!(
        Map<String, Object?>.unmodifiable(fields),
      );
      AcanthisValidationScope.current.throwIfCancelled();
      return result;
    }
    if (schema is AcanthisLiteral) return schema.value;
    for (final check in constraints) {
      if (check is ExactCheck<Object?>) return check.value;
    }
    if (schema is AcanthisNullable) {
      for (final check in constraints) {
        if (check is EnumeratedNullableCheck<Object?>) {
          return choose([null, ...check.values]);
        }
      }
      return random.nextBool() ? null : generate(schema.element, depth + 1);
    }
    if (schema is AcanthisBoolean) {
      if (constraints.any((c) => c is IsTrueCheck)) return true;
      if (constraints.any((c) => c is IsFalseCheck)) return false;
      return random.nextBool();
    }
    if (schema is AcanthisNumeric) return numeric(schema, constraints);
    if (schema is AcanthisDate) {
      var low = DateTime.utc(2000).microsecondsSinceEpoch;
      var high = DateTime.utc(2030).microsecondsSinceEpoch;
      final mins = constraints.whereType<MinDateCheck>();
      final maxs = constraints.whereType<MaxDateCheck>();
      if (mins.isNotEmpty) {
        low = mins.map((c) => c.value.microsecondsSinceEpoch).reduce(max);
      }
      if (maxs.isNotEmpty) {
        high = maxs.map((c) => c.value.microsecondsSinceEpoch).reduce(min);
      }
      if (mins.isEmpty && low > high) low = high;
      if (maxs.isEmpty && low > high) high = low;
      if (low > high) fail('Contradictory date bounds');
      final start = BigInt.from(low);
      final offset =
          (BigInt.from(high) - start) *
          BigInt.from(random.nextInt(1 << 30)) ~/
          BigInt.from(1 << 30);
      return DateTime.fromMicrosecondsSinceEpoch(
        (start + offset).toInt(),
        isUtc: true,
      );
    }
    if (schema is AcanthisString) return text(constraints);
    if (schema is AcanthisList) {
      var low = 0, high = maxLength;
      final required = <Object?>[];
      List<Object?>? domain;
      for (final check in constraints) {
        if (check is MinItemsListCheck) low = max(low, check.minItems);
        if (check is MaxItemsListCheck) high = min(high, check.maxItems);
        if (check is LengthListCheck) {
          low = max(low, check.length);
          high = min(high, check.length);
        }
        if (check is ContainsListCheck) required.add(check.item);
        if (check is AnyOfListCheck) {
          low = max(low, 1);
          required.add(choose(check.items));
        }
        if (check is EveryOfListCheck) {
          domain = check.items;
          if (domain.isEmpty) high = min(high, 0);
        }
      }
      low = max(low, required.length);
      final count = length(low, high);
      if (count > remaining) fail('Generated collection exceeds node budget');
      final output = <Object?>[];
      for (var i = 0; i < count; i++) {
        if (i < required.length) {
          spend(depth + 1);
          output.add(required[i]);
        } else if (domain != null) {
          spend(depth + 1);
          output.add(choose(domain));
        } else {
          output.add(generate(schema.element, depth + 1));
        }
      }
      return output;
    }
    if (schema is ObjectSchema) {
      var low = 0,
          high = schema.unknownKeyPolicy == AcanthisUnknownKeys.preserve
              ? maxLength
              : schema.fields.length;
      for (final check in constraints) {
        if (check is MinPropertiesCheck) low = max(low, check.constraintValue);
        if (check is MaxPropertiesCheck) {
          high = min(high, check.constraintValue);
        }
        if (check is LengthPropertiesCheck) {
          low = max(low, check.constraintValue);
          high = min(high, check.constraintValue);
        }
      }
      final required = schema.fields.keys
          .where(
            (key) =>
                !schema.isOptionalField(key) ||
                !schema.isPatch &&
                    schema.fields[key] is DefaultSchema<Object?, Object?> &&
                    (schema.fields[key] as DefaultSchema<Object?, Object?>)
                        .hasDefault,
          )
          .toList();
      final optional =
          schema.fields.keys.where((key) => !required.contains(key)).toList()
            ..shuffle(random);
      final count = length(max(low, required.length), high);
      final selected = [...required, ...optional.take(count - required.length)];
      final output = {
        for (final key in selected)
          key: generate(schema.fields[key]!, depth + 1),
      };
      for (var i = 0; output.length < count; i++) {
        final key = 'extra_$i';
        if (schema.fields.containsKey(key)) continue;
        if (schema.additionalValueType != null) {
          output[key] = generate(schema.additionalValueType!, depth + 1);
        } else {
          spend(depth + 1);
          output[key] = random.nextBool();
        }
      }
      return output;
    }
    if (schema is RecordSchema) {
      final count = length(0, maxLength);
      final output = <Object?, Object?>{};
      for (var i = 0; i < count; i++) {
        output[generate(schema.key, depth + 1)] = generate(
          schema.value,
          depth + 1,
        );
      }
      return output;
    }
    if (schema is AcanthisTuple) {
      if (schema.elements.length > maxLength) {
        fail('Tuple exceeds collection length limit');
      }
      return [for (final child in schema.elements) generate(child, depth + 1)];
    }
    if (schema is AcanthisUnion) {
      return generate(
        choose(schema.alternatives) as Schema<Object?, Object?>,
        depth + 1,
      );
    }
    if (schema is AcanthisTemplate) {
      final pieces = <String>[];
      var size = 0;
      for (final part in schema.parts) {
        final piece = part is String
            ? part
            : '${generate(part as Schema<Object?, Object?>, depth + 1)}';
        size += piece.length;
        if (size > maxLength) fail('Template exceeds string length limit');
        pieces.add(piece);
      }
      return pieces.join();
    }
    fail('Unsupported schema');
  }

  Object numeric(AcanthisNumeric schema, List<Object> constraints) {
    for (final check in constraints) {
      if (check is EnumeratedNumberCheck) return choose(check.values)!;
      if (check is NaNNumberCheck) return double.nan;
      if (check is InfiniteNumberCheck) {
        return random.nextBool() ? double.infinity : double.negativeInfinity;
      }
    }
    num low = -1000, high = 1000;
    var lowerSet = false, upperSet = false;
    var lowerOpen = false, upperOpen = false;
    int? multiple;
    void lower(num value, bool open) {
      if (!lowerSet || value > low || value == low && open) {
        low = value;
        lowerOpen = open;
      }
      lowerSet = true;
    }

    void upper(num value, bool open) {
      if (!upperSet || value < high || value == high && open) {
        high = value;
        upperOpen = open;
      }
      upperSet = true;
    }

    for (final check in constraints) {
      if (check is GteNumberCheck) lower(check.value, false);
      if (check is GtNumberCheck) lower(check.value, true);
      if (check is LteNumberCheck) upper(check.value, false);
      if (check is LtNumberCheck) upper(check.value, true);
      if (check is BetweenNumberCheck) {
        lower(check.min, false);
        upper(check.max, false);
      }
      if (check is PositiveNumberCheck) lower(0, true);
      if (check is NonNegativeNumberCheck) lower(0, false);
      if (check is NegativeNumberCheck) upper(0, true);
      if (check is NonPositiveNumberCheck) upper(0, false);
      if (check is MultipleOfCheck) multiple = check.value.abs();
    }
    if (!lowerSet && upperSet && high < low) low = high - 1000;
    if (!upperSet && lowerSet && low > high) high = low + 1000;
    if (!low.isFinite || !high.isFinite || low > high) {
      fail('Non-finite or contradictory numeric bounds');
    }
    if (multiple != null && (multiple <= 0 || multiple > 9007199254740991)) {
      fail('Multiple-of step exceeds the numeric sampling range');
    }
    if (low.abs() > 9007199254740991 || high.abs() > 9007199254740991) {
      fail('Numeric sampling bounds exceed the safe integer range');
    }
    final integral =
        schema is AcanthisNumeric<int> ||
        constraints.any((c) => c is IntegerNumberCheck) ||
        multiple != null;
    num output;
    if (integral) {
      var first = low.ceil(), last = high.floor();
      if (lowerOpen && first == low) first++;
      if (upperOpen && last == high) last--;
      if (multiple != null) {
        first = (first / multiple).ceil() * multiple;
        last = (last / multiple).floor() * multiple;
      }
      if (first > last) fail('No integer in the numeric bounds');
      final step = multiple ?? 1;
      final steps = min((last - first) ~/ step, 1000000);
      output = first + random.nextInt(steps + 1) * step;
    } else {
      if (low == high && (lowerOpen || upperOpen)) {
        fail('Empty open numeric interval');
      }
      final fraction = random.nextDouble();
      output = low.toDouble() * (1 - fraction) + high.toDouble() * fraction;
    }
    return schema is AcanthisNumeric<double> ||
            constraints.any((c) => c is DoubleNumberCheck)
        ? output.toDouble()
        : output;
  }

  String text(List<Object> constraints) {
    var low = 0, high = maxLength;
    for (final check in constraints) {
      if (check is EnumeratedStringCheck) return choose(check.values) as String;
      if (check is MinStringLengthCheck) low = max(low, check.value);
      if (check is MaxStringLengthCheck) high = min(high, check.value);
      if (check is ExactStringLengthCheck) {
        low = max(low, check.value);
        high = min(high, check.value);
      }
      if (check is NotEmptyStringCheck || check is RequiredStringCheck) {
        low = max(low, 1);
      }
    }
    String letters(int count) => String.fromCharCodes(
      List.generate(count, (_) => 97 + random.nextInt(26)),
    );
    if (constraints.any((c) => c is EmailStringCheck)) {
      final count = length(max(low, 13), high);
      return '${letters(count - 12)}@example.com';
    }
    if (constraints.any((c) => c is PatternUuidStringChecks)) {
      final bytes = List.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    }
    if (constraints.any((c) => c is UrlStringCheck || c is UriStringCheck)) {
      const prefix = 'https://example.com/';
      final count = length(max(low, prefix.length), high);
      return prefix + letters(count - prefix.length);
    }
    if (constraints.any((c) => c is DateTimeStringCheck)) {
      return DateTime.utc(
        2000 + random.nextInt(31),
        1 + random.nextInt(12),
        1 + random.nextInt(28),
        random.nextInt(24),
        random.nextInt(60),
        random.nextInt(60),
      ).toIso8601String();
    }
    if (constraints.any((c) => c is PatternBase64StringChecks)) {
      final groups = length((low + 3) ~/ 4, min(high, maxLength) ~/ 4);
      return base64Encode(
        List.generate(
          groups == 0 ? 0 : groups * 3 - random.nextInt(3),
          (_) => random.nextInt(256),
        ),
      );
    }
    final count = length(low, high);
    final upper = constraints.any((c) => c is UpperCaseStringCheck);
    var result = String.fromCharCodes(
      List.generate(count, (_) => (upper ? 65 : 97) + random.nextInt(26)),
    );
    if (constraints.any((c) => c is MixedCaseStringCheck) &&
        result.length > 1) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result;
  }
}
