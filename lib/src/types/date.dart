import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/validators/date.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// A class to validate date types
class AcanthisDate extends AcanthisType<DateTime> {
  const AcanthisDate({
    super.operations,
    super.isAsync,
    super.key,
  });

  /// Add a check to the date to check if it is before or equal to [value]
  AcanthisDate min(DateTime value) {
    return withCheck(MinDateCheck(value));
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFromNow(Duration difference) {
    return withCheck(DiffersFromNowCheck(difference));
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFrom(DateTime fromDate, Duration difference) {
    return withCheck(DiffersFromCheck(fromDate, difference));
  }

  /// Add a check to the date to check if it is less than or equal to [value]
  AcanthisDate max(DateTime value) {
    return withCheck(MaxDateCheck(value));
  }

  @override
  AcanthisDate withAsyncCheck(AcanthisAsyncCheck<DateTime> check) {
    return AcanthisDate(operations: [
      ...operations,
      check,
    ], isAsync: true, key: key);
  }

  @override
  AcanthisDate withCheck(AcanthisCheck<DateTime> check) {
    return AcanthisDate(operations: [
      ...operations,
      check,
    ], isAsync: isAsync, key: key);
  }

  @override
  AcanthisDate withTransformation(
      AcanthisTransformation<DateTime> transformation) {
    return AcanthisDate(operations: [
      ...operations,
      transformation,
    ], isAsync: isAsync, key: key);
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
    if (key.isEmpty) {
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
