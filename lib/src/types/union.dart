import 'package:acanthis/src/results.dart';
import 'package:acanthis/src/issue_sink.dart';
import 'package:acanthis/src/exceptions/validation_error.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/types/types.dart';
import 'package:nanoid2/nanoid2.dart';

import '../exceptions/async_exception.dart';
import 'variant.dart';

/// A union that can validate a value against multiple element types
/// and/or guarded variants.
/// Parsing succeeds with the first matching element / variant.
///
/// Matching order is declaration-based and stable:
/// guarded variants are evaluated first in the order they were declared,
/// then plain types are evaluated in the order they were declared.
/// This is especially relevant when coercive schemas are mixed into a union.
class AcanthisUnion<T> extends AcanthisType<T> {
  final List<AcanthisType<T>> _types;
  final List<AcanthisVariant<T>> _variants;

  List<AcanthisType<T>> get alternatives => List.unmodifiable(_types);
  bool get hasGuards => _variants.isNotEmpty;

  AcanthisUnion._({
    required this._types,
    required this._variants,
    super.operations = const [],
    super.isAsync,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  });

  factory AcanthisUnion(List<dynamic> elements) {
    final types = <AcanthisType<T>>[];
    final variants = <AcanthisVariant<T>>[];
    for (final e in elements) {
      if (e is AcanthisType<T>) {
        types.add(e);
      } else if (e is AcanthisVariant<T>) {
        variants.add(e);
      } else {
        throw ArgumentError(
          'Unsupported union element type: ${e.runtimeType}. Expected AcanthisType<$T>, AcanthisVariant<$T> or AcanthisLiteral<$T>.',
        );
      }
    }
    final isAsync = [
      ...types.map((t) => t.isAsync),
      ...variants.map((v) => v.schema.isAsync),
    ].any((b) => b);
    return AcanthisUnion._(
      types: types,
      variants: variants,
      operations: const [],
      isAsync: isAsync,
    );
  }

  AcanthisParseResult<T> _applyOwnOperations(AcanthisParseResult<T> base) {
    final errors = IssueSink();
    final value = compiledTryParseInternal(base.value, errors);
    return AcanthisParseResult(
      value: value,
      errors: errors,
      success: errors.isEmpty,
      metadata: metadataEntry,
    );
  }

  @override
  AcanthisParseResult<T> parse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use parse() with async union; use parseAsync()',
      );
    }
    final result = tryParse(value);
    if (!result.success) {
      throw ValidationError(
        result.errors['union']?.toString() ?? 'Value does not match union',
      );
    }
    return result;
  }

  @override
  T parseInternal(dynamic value) => parse(value).value;

  @override
  T tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    value ??= defaultValue;
    final result = tryParse(value);
    errors.addAll(result.errors);
    return result.value;
  }

  @override
  Future<AcanthisParseResult<T>> parseAsync(dynamic value) async {
    value ??= defaultValue;
    // Try guarded variants
    for (final v in _variants) {
      if (v.guard(value)) {
        try {
          final r = v.schema.isAsync
              ? await v.schema.tryParseAsync(value)
              : v.schema.tryParse(value);
          if (r.success) {
            var base = AcanthisParseResult<T>(
              value: r.value,
              success: true,
              metadata: metadataEntry,
            );
            // Apply own ops (may include async)
            for (final op in operations) {
              switch (op) {
                case AcanthisCheck<T>():
                  if (op is CustomCauseCheck<T>) {
                    final cause = op.cause(base.value);
                    if (cause != null) {
                      throw ValidationError(cause, key: op.name);
                    }
                    break;
                  }
                  if (!op(base.value)) {
                    throw ValidationError(op.error, key: op.name);
                  }
                  break;
                case AcanthisTransformation<T>():
                  base = AcanthisParseResult<T>(
                    value: (op(base.value)),
                    success: true,
                    metadata: metadataEntry,
                  );
                  break;
                case AcanthisAsyncCheck<T>():
                  if (!(await op(base.value))) {
                    throw ValidationError(op.error, key: op.name);
                  }
                  break;
                default:
                  break;
              }
            }
            return AcanthisParseResult<T>(
              value: base.value,
              success: true,
              metadata: metadataEntry,
            );
          }
        } catch (_) {}
      }
    }
    // Plain types
    for (final t in _types) {
      try {
        final r = t.isAsync ? await t.tryParseAsync(value) : t.tryParse(value);
        if (r.success) {
          var base = AcanthisParseResult<T>(
            value: r.value,
            success: true,
            metadata: metadataEntry,
          );
          for (final op in operations) {
            switch (op) {
              case AcanthisCheck<T>():
                if (op is CustomCauseCheck<T>) {
                  final cause = op.cause(base.value);
                  if (cause != null) {
                    throw ValidationError(cause, key: op.name);
                  }
                  break;
                }
                if (!op(base.value)) {
                  throw ValidationError(op.error, key: op.name);
                }
                break;
              case AcanthisTransformation<T>():
                base = AcanthisParseResult<T>(
                  value: (op(base.value)),
                  success: true,
                  metadata: metadataEntry,
                );
                break;
              case AcanthisAsyncCheck<T>():
                if (!(await op(base.value))) {
                  throw ValidationError(op.error, key: op.name);
                }
                break;
              default:
                break;
            }
          }
          return AcanthisParseResult<T>(
            value: base.value,
            success: true,
            metadata: metadataEntry,
          );
        }
      } catch (_) {}
    }
    throw ValidationError('Value does not match any union entry');
  }

  AcanthisParseResult<T> _failedUnion(
    dynamic value,
    List<List<AcanthisIssue>> branches,
  ) {
    final errors = IssueSink()
      ..addIssue(
        'union',
        'Value does not match any union entry',
        branches: branches,
      );
    return AcanthisParseResult(
      value: valueOnFailure(value),
      errors: errors,
      success: false,
      metadata: metadataEntry,
    );
  }

  @override
  Future<AcanthisParseResult<T>> tryParseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return tryParse(value);
    final branches = <List<AcanthisIssue>>[];
    for (final variant in _variants) {
      if (!variant.guard(value)) {
        branches.add([
          AcanthisIssue(
            path: [],
            code: 'variantGuard',
            message: 'Variant guard did not match',
            parameters: {'name': variant.name},
          ),
        ]);
        continue;
      }
      final result = await variant.schema.tryParseAsync(value);
      if (result.success) return tryParseAsyncOperations(result.value);
      branches.add(result.issues);
    }
    for (final type in _types) {
      final result = await type.tryParseAsync(value);
      if (result.success) return tryParseAsyncOperations(result.value);
      branches.add(result.issues);
    }
    return _failedUnion(value, branches);
  }

  @override
  AcanthisParseResult<T> tryParse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse() with async union; use tryParseAsync()',
      );
    }
    final branches = <List<AcanthisIssue>>[];
    for (final variant in _variants) {
      if (!variant.guard(value)) {
        branches.add([
          AcanthisIssue(
            path: [],
            code: 'variantGuard',
            message: 'Variant guard did not match',
            parameters: {'name': variant.name},
          ),
        ]);
        continue;
      }
      final result = variant.schema.tryParse(value);
      if (result.success) return _applyOwnOperations(result);
      branches.add(result.issues);
    }
    for (final type in _types) {
      final result = type.tryParse(value);
      if (result.success) return _applyOwnOperations(result);
      branches.add(result.issues);
    }
    return _failedUnion(value, branches);
  }

  @override
  AcanthisUnion<T> withAsyncCheck(AcanthisAsyncCheck<T> check) {
    return AcanthisUnion._(
      types: _types,
      variants: _variants,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisUnion<T> withCheck(AcanthisCheck<T> check) {
    return AcanthisUnion._(
      types: _types,
      variants: _variants,
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisUnion<T> withTransformation(
    AcanthisTransformation<T> transformation,
  ) {
    return AcanthisUnion._(
      types: _types,
      variants: _variants,
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      defaultValue: defaultValue,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final schemas = [
      ..._variants.map((v) => v.schema.toJsonSchema()),
      ..._types.map((t) => t.toJsonSchema()),
    ];
    return {
      'anyOf': schemas,
      if (metadataEntry != null) ...metadataEntry!.toJson(),
    };
  }

  @override
  AcanthisUnion<T> meta(MetadataEntry<T> metadata) {
    String k = key;
    if (k.isEmpty) {
      k = nanoid();
    }
    MetadataRegistry().add(k, metadata);
    return AcanthisUnion._(
      types: _types,
      variants: _variants,
      operations: operations,
      isAsync: isAsync,
      key: k,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisType<T> withDefault(T value) {
    return AcanthisUnion._(
      types: _types,
      variants: _variants,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    final schemas = [
      ..._variants.map((v) => v.schema.toOpenApiSchema()),
      ..._types.map((t) => t.toOpenApiSchema()),
    ];
    // Alternatives may overlap; successful parsing requires at least one match.
    return {'anyOf': schemas};
  }

  @override
  T mock([int? seed]) {
    if (_variants.isNotEmpty) {
      return _variants.first.schema.mock(seed);
    }
    if (_types.isNotEmpty) {
      return _types.first.mock(seed);
    }
    throw UnimplementedError('Cannot mock empty union');
  }
}

/// Factory for union of types / variants.
AcanthisUnion<T> union<T>(List<dynamic> elements) => AcanthisUnion<T>(elements);
