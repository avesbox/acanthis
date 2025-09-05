import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:nanoid2/nanoid2.dart';

class AcanthisTuple extends AcanthisType<List<dynamic>> {
  final List<AcanthisType> elements;

  final bool _variadic;

  const AcanthisTuple(
    this.elements, {
    super.operations,
    super.isAsync,
    super.key,
    super.metadataEntry,
  }) : _variadic = false;

  AcanthisTuple._(
    this.elements, {
    super.operations,
    super.isAsync,
    super.key,
    bool variadic = false,
    super.metadataEntry,
  }) : _variadic = variadic;

  @override
  Future<AcanthisParseResult<List>> parseAsync(List value) async {
    if (value.length != elements.length && !_variadic) {
      throw ValidationError('Value must have ${elements.length} elements');
    }
    final parsed = <dynamic>[];
    for (var i = 0; i < value.length; i++) {
      try {
        final element = i < elements.length ? elements[i] : elements.last;
        final parsedElement = await element.parseAsync(value[i]);
        parsed.add(parsedElement.value);
      } on TypeError catch (e) {
        throw ValidationError(e.toString());
      }
    }
    return super.parseAsync(parsed);
  }

  @override
  Future<AcanthisParseResult<List>> tryParseAsync(List value) async {
    if (value.length != elements.length && !_variadic) {
      return AcanthisParseResult(
        value: value,
        errors: {'tuple': 'Value must have ${elements.length} elements'},
        success: false,
      );
    }
    final parsed = <dynamic>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      try {
        final element = i < elements.length ? elements[i] : elements.last;
        final parsedElement = await element.tryParseAsync(value[i]);
        parsed.add(parsedElement.value);
        if (parsedElement.errors.isNotEmpty) {
          errors[i.toString()] = parsedElement.errors;
        }
      } on TypeError catch (e) {
        errors[i.toString()] = e.toString();
      }
    }
    final result = await super.tryParseAsync(parsed);
    if (result.errors.isNotEmpty) {
      errors.addAll(result.errors);
    }
    return AcanthisParseResult(
      value: result.value,
      errors: errors,
      success: errors.isEmpty,
      metadata: result.metadata,
    );
  }

  @override
  AcanthisParseResult<List<dynamic>> parse(List<dynamic> value) {
    if (value.length != elements.length && !_variadic) {
      throw ValidationError('Value must have ${elements.length} elements');
    }
    final parsed = <dynamic>[];
    for (var i = 0; i < value.length; i++) {
      try {
        final element = i < elements.length ? elements[i] : elements.last;
        final parsedElement = element.parse(value[i]);
        parsed.add(parsedElement.value);
      } on TypeError catch (e) {
        throw ValidationError(e.toString());
      }
    }
    return super.parse(parsed);
  }

  @override
  AcanthisParseResult<List<dynamic>> tryParse(List<dynamic> value) {
    if (value.length != elements.length && !_variadic) {
      return AcanthisParseResult(
        value: value,
        errors: {'tuple': 'Value must have ${elements.length} elements'},
        success: false,
      );
    }
    final parsed = <dynamic>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      try {
        final element = i < elements.length ? elements[i] : elements.last;
        final parsedElement = element.tryParse(value[i]);
        parsed.add(parsedElement.value);
        if (parsedElement.errors.isNotEmpty) {
          errors[i.toString()] = parsedElement.errors;
        }
      } on TypeError catch (e) {
        errors[i.toString()] = e.toString();
      }
    }
    final result = super.tryParse(parsed);
    if (result.errors.isNotEmpty) {
      errors.addAll(result.errors);
    }
    return AcanthisParseResult(
      value: result.value,
      errors: errors,
      success: errors.isEmpty,
      metadata: result.metadata,
    );
  }

  @override
  AcanthisTuple withAsyncCheck(AcanthisAsyncCheck<List<dynamic>> check) {
    return AcanthisTuple(
      elements,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisTuple withCheck(AcanthisCheck<List<dynamic>> check) {
    return AcanthisTuple(
      elements,
      operations: [...operations, check],
      key: key,
      isAsync: isAsync,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisTuple withTransformation(
    AcanthisTransformation<List<dynamic>> transformation,
  ) {
    return AcanthisTuple(
      elements,
      operations: [...operations, transformation],
      key: key,
      isAsync: isAsync,
      metadataEntry: metadataEntry,
    );
  }

  /// Returns a new tuple with the last element as variadic
  AcanthisTuple variadic() {
    return AcanthisTuple._(
      elements,
      operations: operations,
      key: key,
      isAsync: isAsync,
      variadic: true,
      metadataEntry: metadataEntry,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return {
      'type': 'array',
      'prefixItems': elements.map((e) => e.toJsonSchema()).toList(),
      if (metadataEntry != null) ...metadataEntry!.toJson(),
    };
  }

  @override
  AcanthisTuple meta(MetadataEntry<List<dynamic>> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisTuple(
      elements,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadata,
    );
  }
}

/// Creates a new [AcanthisTuple] with the given elements.
AcanthisTuple tuple(List<AcanthisType> elements) {
  return AcanthisTuple(elements);
}
