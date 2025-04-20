import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:nanoid2/nanoid2.dart';

import 'list.dart';
import 'types.dart';
import 'union.dart';

/// A class to validate date types
class AcanthisDate extends AcanthisType<DateTime> {
  const AcanthisDate({
    super.operations,
    super.isAsync,
    super.key,
  });

  /// Add a check to the date to check if it is before or equal to [value]
  AcanthisDate min(DateTime value) {
    return withCheck(AcanthisCheck<DateTime>(
        onCheck: (toTest) =>
            toTest.isAfter(value) || toTest.isAtSameMomentAs(value),
        error: 'The date must be greater than or equal to $value',
        name: 'min'));
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFromNow(Duration difference) {
    return withCheck(AcanthisCheck<DateTime>(
        onCheck: (toTest) =>
            toTest.difference(DateTime.now()).abs() >= difference,
        error: 'The date must differ from now by $difference or more',
        name: 'differsFromNow'));
  }

  /// Add a check to the date to check if it is less than or equal to [value]
  AcanthisDate max(DateTime value) {
    return withCheck(AcanthisCheck<DateTime>(
        onCheck: (toTest) =>
            toTest.isBefore(value) || toTest.isAtSameMomentAs(value),
        error: 'The date must be less than or equal to $value',
        name: 'max'));
  }

  /// Create a list of dates
  AcanthisList<DateTime> list() {
    return AcanthisList<DateTime>(this);
  }

  /// Create a union from the string
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  @override
  AcanthisDate withAsyncCheck(AcanthisAsyncCheck<DateTime> check) {
    return AcanthisDate(
      operations: operations.add(check),
      isAsync: true,
      key: key
    );
  }

  @override
  AcanthisDate withCheck(AcanthisCheck<DateTime> check) {
    return AcanthisDate(
      operations: operations.add(check),
      isAsync: isAsync,
      key: key
    );
  }

  @override
  AcanthisDate withTransformation(
      AcanthisTransformation<DateTime> transformation) {
    return AcanthisDate(
      operations: operations.add(transformation),
      isAsync: isAsync,
      key: key
    );
  }
  
  @override
  Map<String, dynamic> toJsonSchema() {
    final metadata = MetadataRegistry().get(key);
    return {
      'type': 'string',
      'format': 'date-time',
      if (metadata != null) ...metadata.toJson(),
    };
  }

  @override
  AcanthisDate meta(MetadataEntry<DateTime> metadata) {
    String key = this.key;
    if(key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisDate(
      operations: operations,
      isAsync: isAsync,
      key: key,
    );
  }

}

/// Create a new date type
AcanthisDate date() => AcanthisDate();
