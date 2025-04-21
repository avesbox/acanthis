import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/types/tuple.dart';
import 'package:nanoid2/nanoid2.dart';

import 'list.dart';
import 'types.dart';
import 'union.dart';

class AcanthisBoolean extends AcanthisType<bool> {
  const AcanthisBoolean({
    super.operations,
    super.isAsync,
    super.key,
  });

  /// Add a check to the boolean to check if it is true
  AcanthisBoolean isTrue() {
    return withCheck(AcanthisCheck<bool>(
        onCheck: (value) => value,
        error: 'Value must be true',
        name: 'isTrue'));
  }

  /// Add a check to the boolean to check if it is false
  AcanthisBoolean isFalse() {
    return withCheck(AcanthisCheck<bool>(
        onCheck: (value) => !value,
        error: 'Value must be false',
        name: 'isFalse'));
  }

  /// Create a list of booleans
  AcanthisList<bool> list() {
    return AcanthisList(this);
  }

  /// Create a union from the nullable
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  /// Create a tuple from the nullable
  AcanthisTuple tuple(List<AcanthisType> elements) {
    return AcanthisTuple([this, ...elements]);
  }

  @override
  AcanthisBoolean withAsyncCheck(AcanthisAsyncCheck<bool> check) {
    return AcanthisBoolean(
      operations: operations.add(check),
      isAsync: true,
      key: key,
    );
  }

  @override
  AcanthisBoolean withCheck(AcanthisCheck<bool> check) {
    return AcanthisBoolean(
      operations: operations.add(check),
      key: key,
      isAsync: isAsync,
    );
  }

  @override
  AcanthisBoolean withTransformation(
      AcanthisTransformation<bool> transformation) {
    return AcanthisBoolean(
      operations: operations.add(transformation),
      key: key,
      isAsync: isAsync,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final metadata = MetadataRegistry().get(key);
    return {
      'type': 'boolean',
      if (metadata != null) ...metadata.toJson(),
    };
  }

  @override
  AcanthisBoolean meta(MetadataEntry<bool> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisBoolean(
      operations: operations,
      isAsync: isAsync,
      key: key,
    );
  }
}

/// Create a boolean validator
AcanthisBoolean boolean() => AcanthisBoolean();
