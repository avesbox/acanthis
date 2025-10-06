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
class AcanthisUnion<T> extends AcanthisType<T> {
  final List<AcanthisType<T>> _types;
  final List<AcanthisVariant<T>> _variants;

  const AcanthisUnion._({
    required List<AcanthisType<T>> types,
    required List<AcanthisVariant<T>> variants,
    super.operations = const [],
    super.isAsync,
    super.key,
    super.metadataEntry,
  }) : _types = types,
       _variants = variants;

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
    if (!base.success) return base;
    if (operations.isEmpty) return base;
    T newValue = base.value;
    for (final op in operations) {
      switch (op) {
        case AcanthisCheck<T>():
          if (op is CustomCauseCheck<T>) {
            final cause = op.cause(newValue);
            if (cause != null) {
              return AcanthisParseResult(
                value: newValue,
                errors: {op.name: cause},
                success: false,
                metadata: metadataEntry,
              );
            }
            break;
          }
          if (!op(newValue)) {
            return AcanthisParseResult(
              value: newValue,
              errors: {op.name: op.error},
              success: false,
              metadata: metadataEntry,
            );
          }
          break;
        case AcanthisTransformation<T>():
          newValue = op(newValue);
          break;
        case AcanthisAsyncCheck<T>():
          // Should not happen in sync path (guarded by isAsync)
          throw AsyncValidationException(
            'Async check encountered in sync parse',
          );
        default:
          break;
      }
    }
    return AcanthisParseResult(
      value: newValue,
      errors: const {},
      success: true,
      metadata: metadataEntry,
    );
  }

  @override
  AcanthisParseResult<T> parse(dynamic value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use parse() with async union; use parseAsync()',
      );
    }
    // Try guarded variants first (in order)
    for (final v in _variants) {
      if (v.guard(value)) {
        try {
          final r = v.schema.tryParse(value);
          if (r.success) {
            return _applyOwnOperations(
              AcanthisParseResult<T>(
                value: r.value,
                success: true,
                metadata: metadataEntry,
              ),
            );
          }
        } catch (_) {}
      }
    }
    // Then plain types
    for (final t in _types) {
      try {
        final r = t.parse(value);
        if (r.success) {
          return _applyOwnOperations(
            AcanthisParseResult<T>(
              value: r.value,
              success: true,
              metadata: metadataEntry,
            ),
          );
        }
      } catch (_) {}
    }
    throw ValidationError('Value does not match any union entry');
  }

  @override
  Future<AcanthisParseResult<T>> parseAsync(dynamic value) async {
    // Try guarded variants
    for (final v in _variants) {
      if (v.guard(value)) {
        try {
          final r =
              v.schema.isAsync
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
                  if(op is CustomCauseCheck<T>){
                    final cause = op.cause(base.value);
                    if(cause != null){
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
                if(op is CustomCauseCheck<T>){
                  final cause = op.cause(base.value);
                  if(cause != null){
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

  @override
  Future<AcanthisParseResult<T>> tryParseAsync(dynamic value) async {
    final errors = <String, String>{};
    int idx = 0;
    // Variants
    for (final v in _variants) {
      if (v.guard(value)) {
        try {
          final r =
              v.schema.isAsync
                  ? await v.schema.tryParseAsync(value)
                  : v.schema.tryParse(value);
          if (r.success) {
            // Apply own ops asynchronously
            T newVal = r.value;
            for (final op in operations) {
              switch (op) {
                case AcanthisCheck<T>():
                  if (op is CustomCauseCheck<T>) {
                    final cause = op.cause(newVal);
                    if (cause != null) {
                      errors[op.name] = cause;
                    }
                    break;
                  }
                  if (!op(newVal)) {
                    errors[op.name] = op.error;
                  }
                  break;
                case AcanthisTransformation<T>():
                  newVal = op(newVal);
                  break;
                case AcanthisAsyncCheck<T>():
                  if (!(await op(newVal))) {
                    errors[op.name] = op.error;
                  }
                  break;
                default:
                  break;
              }
            }
            if (errors.isEmpty) {
              return AcanthisParseResult<T>(
                value: newVal,
                success: true,
                metadata: metadataEntry,
              );
            }
            return AcanthisParseResult<T>(
              value: newVal,
              success: false,
              errors: errors,
              metadata: metadataEntry,
            );
          } else {
            errors[v.name.isEmpty ? 'variant[$idx]' : v.name] =
                'Failed variant schema';
          }
        } catch (_) {}
      }
      idx++;
    }
    // Plain types
    idx = 0;
    for (final t in _types) {
      try {
        final r = t.isAsync ? await t.tryParseAsync(value) : t.tryParse(value);
        if (r.success) {
          T newVal = r.value;
          for (final op in operations) {
            switch (op) {
              case AcanthisCheck<T>():
                if (op is CustomCauseCheck<T>) {
                  final cause = op.cause(newVal);
                  if (cause != null) {
                    errors[op.name] = cause;
                  }
                  break;
                }
                if (!op(newVal)) {
                  errors[op.name] = op.error;
                }
                break;
              case AcanthisTransformation<T>():
                newVal = op(newVal);
                break;
              case AcanthisAsyncCheck<T>():
                if (!(await op(newVal))) {
                  errors[op.name] = op.error;
                }
                break;
              default:
                break;
            }
          }
          if (errors.isEmpty) {
            return AcanthisParseResult<T>(
              value: newVal,
              success: true,
              metadata: metadataEntry,
            );
          }
          return AcanthisParseResult<T>(
            value: newVal,
            success: false,
            errors: errors,
            metadata: metadataEntry,
          );
        } else {
          errors['type[$idx]'] = 'Failed type schema';
        }
      } catch (_) {}
      idx++;
    }
    errors['union'] = 'Value does not match any union entry';
    return AcanthisParseResult<T>(
      value: value,
      errors: errors,
      success: false,
      metadata: metadataEntry,
    );
  }

  @override
  AcanthisParseResult<T> tryParse(dynamic value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse() with async union; use tryParseAsync()',
      );
    }
    final errors = <String, String>{};
    int idx = 0;
    for (final v in _variants) {
      if (v.guard(value)) {
        try {
          final r = v.schema.tryParse(value);
          if (r.success) {
            final applied = _applyOwnOperations(
              AcanthisParseResult<T>(
                value: r.value,
                success: true,
                metadata: metadataEntry,
              ),
            );
            return applied;
          } else {
            errors[v.name.isEmpty ? 'variant[$idx]' : v.name] =
                'Failed variant schema';
          }
        } catch (_) {}
      }
      idx++;
    }
    idx = 0;
    for (final t in _types) {
      try {
        final r = t.tryParse(value);
        if (r.success) {
          final applied = _applyOwnOperations(
            AcanthisParseResult<T>(
              value: r.value,
              success: true,
              metadata: metadataEntry,
            ),
          );
          return applied;
        } else {
          errors['type[$idx]'] = 'Failed type schema';
        }
      } catch (_) {}
      idx++;
    }
    errors['union'] = 'Value does not match any union entry';
    return AcanthisParseResult<T>(
      value: value,
      errors: errors,
      success: false,
      metadata: metadataEntry,
    );
  }

  @override
  AcanthisUnion<T> withAsyncCheck(AcanthisAsyncCheck<T> check) {
    return AcanthisUnion._(
      types: _types,
      variants: _variants,
      operations: [...operations, check],
      isAsync: true,
      key: key,
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
    );
  }
}

/// Factory for union of types / variants.
AcanthisUnion<T> union<T>(List<dynamic> elements) => AcanthisUnion<T>(elements);
