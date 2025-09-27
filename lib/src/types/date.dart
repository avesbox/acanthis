import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/validators/date.dart';
import 'package:nanoid2/nanoid2.dart';

import '../exceptions/validation_error.dart';
import 'types.dart';

/// A class to validate date types
class AcanthisDate extends AcanthisType<DateTime> {
  const AcanthisDate({
    super.operations,
    super.isAsync,
    super.key,
    super.metadataEntry,
  });

  @override
  AcanthisParseResult<DateTime> parse(dynamic value) {
    final date = _convertToDate(value);
    return super.parse(date);
  }

  @override
  Future<AcanthisParseResult<DateTime>> parseAsync(dynamic value) async {
    final date = _convertToDate(value);
    return super.parseAsync(date);
  }

  @override
  Future<AcanthisParseResult<DateTime>> tryParseAsync(dynamic value) async {
    try {
      final date = _convertToDate(value);
      return super.tryParseAsync(date);
    } on ValidationError catch (e) {
      return AcanthisParseResult(errors: {
        'date': e.message,
      }, value: DateTime.now(), success: false);
    }
  }

  @override
  AcanthisParseResult<DateTime> tryParse(dynamic value) {
    try {
      final date = _convertToDate(value);
      return super.tryParse(date);
    } on ValidationError catch (e) {
      return AcanthisParseResult(errors: {
        'date': e.message,
      }, value: DateTime.now(), success: false);
    }
  }

  DateTime _convertToDate(dynamic value) {
    if (value is! String && value is! DateTime && value is! int) {
      throw ValidationError(
        'Invalid type: ${value.runtimeType}, expected date-like value',
      );
    }
    DateTime? date;
    if (value is DateTime) {
      date = value;
    } else if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(value);
    } else {
      date = DateTime.tryParse(value);
    }
    if (date == null) {
      throw ValidationError('Invalid date format: $value');
    }
    return date;
  }

  /// Add a check to the date to check if it is before or equal to [value]
  AcanthisDate min(
    DateTime value, {
    String? message,
    String Function(DateTime value)? messageBuilder,
  }) {
    return withCheck(
      MinDateCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFromNow(
    Duration difference, {
    String? message,
    String Function(Duration difference)? messageBuilder,
  }) {
    return withCheck(
      DiffersFromNowCheck(
        difference,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the date to check if it is after or equal to [value]
  AcanthisDate differsFrom(
    DateTime fromDate,
    Duration difference, {
    String? message,
    String Function(DateTime fromDate, Duration difference)? messageBuilder,
  }) {
    return withCheck(
      DiffersFromCheck(
        fromDate,
        difference,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the date to check if it is less than or equal to [value]
  AcanthisDate max(
    DateTime value, {
    String? message,
    String Function(DateTime value)? messageBuilder,
  }) {
    return withCheck(
      MaxDateCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  @override
  AcanthisDate withAsyncCheck(AcanthisAsyncCheck<DateTime> check) {
    return AcanthisDate(
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisDate withCheck(AcanthisCheck<DateTime> check) {
    return AcanthisDate(
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisDate withTransformation(
    AcanthisTransformation<DateTime> transformation,
  ) {
    return AcanthisDate(
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return {
      'type': 'string',
      'format': 'date-time',
      if (metadataEntry != null) ...metadataEntry!.toJson(),
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
      metadataEntry: metadata,
    );
  }
}

/// Create a new date type
AcanthisDate date() => AcanthisDate();
