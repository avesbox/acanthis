import 'dart:convert';

import '../common/operations.dart';

final class EncodeStringTransform implements Transform<String, String> {
  const EncodeStringTransform();

  @override
  String apply(String value) => base64.encode(utf8.encode(value));
}

/// The execution engine reports malformed base64/UTF-8 as a transform issue.
final class DecodeStringTransform implements Transform<String, String> {
  const DecodeStringTransform();

  @override
  String apply(String value) => utf8.decode(base64.decode(value));
}

final class UpperCaseStringTransform implements Transform<String, String> {
  const UpperCaseStringTransform();

  @override
  String apply(String value) => value.toUpperCase();
}

final class LowerCaseStringTransform implements Transform<String, String> {
  const LowerCaseStringTransform();

  @override
  String apply(String value) => value.toLowerCase();
}

final class TrimStringTransform implements Transform<String, String> {
  const TrimStringTransform();

  @override
  String apply(String value) => value.trim();
}
