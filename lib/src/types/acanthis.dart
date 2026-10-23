import 'package:acanthis/src/types/date.dart';
import 'package:acanthis/src/types/string.dart';
import 'package:acanthis/src/types/number.dart';

import '../schema_import.dart' as contracts;
import '../common/schema.dart';
import 'list.dart';
import 'object.dart';
import 'record.dart';
import 'lazy.dart';
import 'boolean.dart';
import 'literal.dart';
import 'nullable.dart';
import 'union.dart';
import 'tuple.dart';
import 'template.dart';
import 'instance.dart';
import 'class_schema.dart';

abstract class Acanthis {
  static InstanceType<T> instance<T>() => InstanceType<T>();
  static ClassSchemaBuilder<I, T> classSchema<I, T>() =>
      ClassSchemaBuilder<I, T>();
  static AcanthisUnion<T> union<T>(List<Object?> elements) =>
      AcanthisUnion<T>(elements);
  static AcanthisTuple tuple(List<Schema<Object?, Object?>> elements) =>
      AcanthisTuple(elements);
  static AcanthisTemplate template(List<Object?> parts) =>
      AcanthisTemplate(parts);
  static contracts.AcanthisJsonContract importJsonSchema(Object? document) =>
      contracts.fromJsonSchema(document);
  static contracts.AcanthisJsonContract importOpenApiSchema(Object? document) =>
      contracts.fromOpenApiSchema(document);
  static LazyEntry<O> lazy<O>(
    Schema<Object?, O> Function(ObjectSchema parent) resolver,
  ) => LazyEntry(resolver);
  static AcanthisString string() => AcanthisString();
  static AcanthisNumber number() => AcanthisNumber();
  static AcanthisInt integer() => AcanthisInt();
  static AcanthisDouble doubleType() => AcanthisDouble();
  static AcanthisBoolean boolean() => AcanthisBoolean();
  static AcanthisLiteral<T> literal<T>(T value) => AcanthisLiteral<T>(value);
  static AcanthisNullable<T> nullable<T>(
    Schema<Object?, T> element, {
    T? defaultValue,
  }) => AcanthisNullable<T>(element, defaultValue: defaultValue);
  static AcanthisList<T> list<T>(Schema<Object?, T> element) =>
      AcanthisList<T>(element);
  static AcanthisDate date() => AcanthisDate();
  static ObjectSchema object(Map<String, Schema<Object?, Object?>> fields) =>
      ObjectSchema(fields);
  static RecordSchema<K, V> record<K, V>(
    Schema<Object?, K> key,
    Schema<Object?, V> value,
  ) => RecordSchema(key, value);
  static contracts.AcanthisJsonContract fromJsonSchema(Object? document) =>
      contracts.fromJsonSchema(document);
  static contracts.AcanthisJsonContract fromOpenApiSchema(Object? document) =>
      contracts.fromOpenApiSchema(document);
}

typedef AcanthisType = Acanthis;
