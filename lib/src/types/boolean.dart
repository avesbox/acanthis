import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/validators/boolean.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

class AcanthisBoolean extends AcanthisType<bool> {
  const AcanthisBoolean({
    super.operations,
    super.isAsync,
    super.key,
    super.metadataEntry
  });

  /// Add a check to the boolean to check if it is true
  AcanthisBoolean isTrue({String? message}) {
    return withCheck(IsTrueCheck(message: message));
  }

  /// Add a check to the boolean to check if it is false
  AcanthisBoolean isFalse({String? message}) {
    return withCheck(IsFalseCheck(message: message));
  }

  @override
  AcanthisBoolean withAsyncCheck(AcanthisAsyncCheck<bool> check) {
    return AcanthisBoolean(
      operations: [
        ...operations,
        check,
      ],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisBoolean withCheck(AcanthisCheck<bool> check) {
    return AcanthisBoolean(
      operations: [
        ...operations,
        check,
      ],
      key: key,
      isAsync: isAsync,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisBoolean withTransformation(
      AcanthisTransformation<bool> transformation) {
    return AcanthisBoolean(
      operations: [
        ...operations,
        transformation,
      ],
      key: key,
      isAsync: isAsync,
      metadataEntry: metadataEntry,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return {
      'type': 'boolean',
      if (metadataEntry != null) ...metadataEntry!.toJson(),
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
      metadataEntry: metadata,
    );
  }
}

/// Create a boolean validator
AcanthisBoolean boolean() => AcanthisBoolean();
