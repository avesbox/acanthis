import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';
import '../common/map_schema.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';

/// A dictionary whose entries share a key schema and a value schema.
/// This represents a Dart map, rather than a Dart positional/named record.
final class RecordSchema<K, V> extends MapSchemaBase<K, V, RecordSchema<K, V>>
    implements SchemaGraphNode {
  RecordSchema(this.key, this.value);
  RecordSchema._(
    this.key,
    this.value,
    MapOperations<K, V> operations,
    Map<K, V>? defaultValue,
  ) : super(operations: operations, defaultValue: defaultValue);

  final Schema<Object?, K> key;
  final Schema<Object?, V> value;

  @override
  bool get childrenAreAsync => schemaIsAsync(key) || schemaIsAsync(value);
  @override
  bool get hasLocalAsync => operations.isAsync;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [key, value];
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  RecordSchema<K, V> rebuild(
    MapOperations<K, V> operations,
    Map<K, V>? defaultValue,
  ) => copySchemaMetadata(
    this,
    RecordSchema._(key, value, operations, defaultValue),
  );

  @override
  AcanthisOutcome<Map<K, V>> parseChildren(Object? input, bool collect) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    if (input is! Map<Object?, Object?>) return _invalidInput();
    final run = MapParseState<K, V>();
    var index = 0;
    var unchangedKeys = true;
    for (final entry in input.entries) {
      scope.throwIfCancelled();
      final path = _path(entry.key, index++);
      final parsedKey = collect
          ? key.tryParse(entry.key)
          : key.parseOutcome(entry.key);
      scope.throwIfCancelled();
      final keyHasValue = run.addChild(path, parsedKey);
      if (stop && !parsedKey.isValid) return run.finish(complete: false);
      final parsedValue = collect
          ? value.tryParse(entry.value)
          : value.parseOutcome(entry.value);
      scope.throwIfCancelled();
      final valueHasValue = run.addChild(path, parsedValue);
      if (stop && !parsedValue.isValid) return run.finish(complete: false);
      if (keyHasValue && valueHasValue) {
        unchangedKeys = unchangedKeys && identical(parsedKey.value, entry.key);
        _put(run, path, parsedKey.value, parsedValue.value);
      }
      if (stop && run.sink.isNotEmpty) return run.finish(complete: false);
    }
    return run.finish(
      reuseInput: !hasOperations && unchangedKeys ? input : null,
    );
  }

  @override
  Future<AcanthisOutcome<Map<K, V>>> parseChildrenAsync(
    Object? input,
    bool collect,
  ) async {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    final stop =
        !collect || scope.objectPolicy == AcanthisCollectionPolicy.first;
    if (input is! Map<Object?, Object?>) return _invalidInput();
    final run = MapParseState<K, V>();
    var index = 0;
    var unchangedKeys = true;
    for (final entry in input.entries) {
      scope.throwIfCancelled();
      final path = _path(entry.key, index++);
      final parsedKey = await parseMapChildAsync(key, entry.key, collect);
      scope.throwIfCancelled();
      final keyHasValue = run.addChild(path, parsedKey);
      if (stop && !parsedKey.isValid) return run.finish(complete: false);
      final parsedValue = await parseMapChildAsync(value, entry.value, collect);
      scope.throwIfCancelled();
      final valueHasValue = run.addChild(path, parsedValue);
      if (stop && !parsedValue.isValid) return run.finish(complete: false);
      if (keyHasValue && valueHasValue) {
        unchangedKeys = unchangedKeys && identical(parsedKey.value, entry.key);
        _put(run, path, parsedKey.value, parsedValue.value);
      }
      if (stop && run.sink.isNotEmpty) return run.finish(complete: false);
    }
    return run.finish(
      reuseInput: !hasOperations && unchangedKeys ? input : null,
    );
  }

  // Diagnostic paths always refer to submitted keys. Other Dart key types use
  // the entry's insertion index so paths remain strings and integers.
  Object _path(Object? rawKey, int index) =>
      rawKey is String || rawKey is int ? rawKey! : index;

  void _put(MapParseState<K, V> run, Object path, K parsedKey, V parsedValue) {
    if (run.output.containsKey(parsedKey)) {
      run.sink.addIssue('duplicateKey', path: [path]);
      run.hasValue = false;
    } else {
      run.output[parsedKey] = parsedValue;
    }
  }

  AcanthisOutcome<Map<K, V>> _invalidInput() {
    final run = MapParseState<K, V>();
    run.sink.addIssue('type', parameters: const {'expected': 'Map'});
    return run.finish(complete: false);
  }
}

RecordSchema<K, V> record<K, V>(
  Schema<Object?, K> key,
  Schema<Object?, V> value,
) => RecordSchema(key, value);
