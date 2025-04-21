import 'package:acanthis/acanthis.dart';
import 'package:nanoid2/nanoid2.dart';

class AcanthisTuple extends AcanthisType<List<dynamic>> {
  final List<AcanthisType> elements;

  const AcanthisTuple(this.elements,
      {super.operations, super.isAsync, super.key});

  @override
  Future<AcanthisParseResult<List>> parseAsync(List value) async {
    if (value.length != elements.length) {
      throw ValidationError('Value must have ${elements.length} elements');
    }
    final parsed = <dynamic>[];
    for (var i = 0; i < value.length; i++) {
      try {
        final parsedElement = await elements[i].parseAsync(value[i]);
        parsed.add(parsedElement.value);
      } on TypeError catch (e) {
        throw ValidationError(e.toString());
      }
    }
    return Future.value(AcanthisParseResult(
        value: parsed, metadata: MetadataRegistry().get(key)));
  }

  @override
  Future<AcanthisParseResult<List>> tryParseAsync(List value) async {
    if (value.length != elements.length) {
      return AcanthisParseResult(
          value: value,
          errors: {'tuple': 'Value must have ${elements.length} elements'},
          success: false);
    }
    final parsed = <dynamic>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      try {
        final parsedElement = await elements[i].tryParseAsync(value[i]);
        parsed.add(parsedElement.value);
        if (parsedElement.errors.isNotEmpty) {
          errors[i.toString()] = parsedElement.errors;
        }
      } on TypeError catch (e) {
        errors[i.toString()] = e.toString();
      }
    }
    return Future.value(AcanthisParseResult(
        value: parsed,
        errors: errors,
        success: errors.isEmpty,
        metadata: MetadataRegistry().get(key)));
  }

  @override
  AcanthisParseResult<List<dynamic>> parse(List<dynamic> value) {
    if (value.length != elements.length) {
      throw ValidationError('Value must have ${elements.length} elements');
    }
    final parsed = <dynamic>[];
    for (var i = 0; i < value.length; i++) {
      try {
        final parsedElement = elements[i].parse(value[i]);
        parsed.add(parsedElement.value);
      } on TypeError catch (e) {
        throw ValidationError(e.toString());
      }
    }
    return AcanthisParseResult(
        value: parsed, metadata: MetadataRegistry().get(key));
  }

  @override
  AcanthisParseResult<List<dynamic>> tryParse(List<dynamic> value) {
    if (value.length != elements.length) {
      return AcanthisParseResult(
          value: value,
          errors: {'tuple': 'Value must have ${elements.length} elements'},
          success: false);
    }
    final parsed = <dynamic>[];
    final errors = <String, dynamic>{};
    for (var i = 0; i < value.length; i++) {
      try {
        final parsedElement = elements[i].tryParse(value[i]);
        parsed.add(parsedElement.value);
        if (parsedElement.errors.isNotEmpty) {
          errors[i.toString()] = parsedElement.errors;
        }
      } on TypeError catch (e) {
        errors[i.toString()] = e.toString();
      }
    }
    return AcanthisParseResult(
        value: parsed,
        errors: errors,
        success: errors.isEmpty,
        metadata: MetadataRegistry().get(key));
  }

  @override
  AcanthisNullable nullable({List<dynamic>? defaultValue}) {
    for (var element in elements) {
      if (element is AcanthisNullable) {
        return element;
      }
      return element.nullable(defaultValue: defaultValue);
    }
    return AcanthisNullable(this, defaultValue: defaultValue);
  }

  @override
  AcanthisTuple withAsyncCheck(AcanthisAsyncCheck check) {
    return AcanthisTuple(
      elements,
      operations: operations.add(check),
      isAsync: true,
      key: key,
    );
  }

  @override
  AcanthisTuple withCheck(AcanthisCheck check) {
    return AcanthisTuple(
      elements,
      operations: operations.add(check),
      key: key,
      isAsync: isAsync,
    );
  }

  @override
  AcanthisTuple withTransformation(AcanthisTransformation transformation) {
    return AcanthisTuple(
      elements,
      operations: operations.add(transformation),
      key: key,
      isAsync: isAsync,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final metadata = MetadataRegistry().get(key);
    return {
      'type': 'array',
      'prefixItems': elements.map((e) => e.toJsonSchema()).toList(),
      if (metadata != null) ...metadata.toJson(),
    };
  }

  @override
  AcanthisTuple meta(MetadataEntry metadata) {
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
    );
  }
}

AcanthisTuple tuple(List<AcanthisType> elements) {
  return AcanthisTuple(elements);
}
