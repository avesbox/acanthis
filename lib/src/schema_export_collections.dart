part of 'schema_export.dart';

String _exportPath(String path, Object segment) =>
    '$path/${segment.toString().replaceAll('~', '~0').replaceAll('/', '~1')}';

final class _DefaultAudit {
  _DefaultAudit(this.schema, this.value, this.path);
  final Schema<Object?, Object?> schema;
  final Object? value;
  final String path;
}

/// Per-export graph state. Only recursive nodes need definitions; normal fields
/// stay inline. No input callbacks are invoked while auditing a collection.
final class _CollectionExport {
  _CollectionExport(this.mode, {this.auditDefaults = true});
  final AcanthisSchemaMode mode;
  final bool auditDefaults;
  bool hasMetadata = false;
  final _ids = HashMap<Schema<Object?, Object?>, String>.identity();
  final _active = HashSet<Schema<Object?, Object?>>.identity();
  final _recursive = HashSet<Schema<Object?, Object?>>.identity();
  final _bodies =
      HashMap<Schema<Object?, Object?>, Map<String, Object?>>.identity();
  final _rawBodies =
      HashMap<Schema<Object?, Object?>, Map<String, Object?>>.identity();
  final _defs = <String, Object?>{};
  final _defaults = <_DefaultAudit>[];
  final _validators = <(AcanthisJsonContract, _DefaultAudit)>[];

  Never bad(String path, String reason) =>
      throw AcanthisSchemaExportException(path, reason);

  Map<String, Object?> build(Schema<Object?, Object?> root) {
    final body = node(root, '');
    final result = <String, Object?>{
      ...body,
      if (_defs.isNotEmpty) r'$defs': _defs,
    };
    if (auditDefaults && _defaults.isNotEmpty) {
      final input = mode == AcanthisSchemaMode.input
          ? this
          : _CollectionExport(AcanthisSchemaMode.input, auditDefaults: false);
      if (!identical(input, this)) input.build(root);
      for (final entry in _defaults) {
        final definition = {
          ...input._rawBodies[entry.schema]!,
          if (input._defs.isNotEmpty) r'$defs': input._defs,
        };
        // Validate against the audited input program, without executing the
        // native parser. Descendant defaults are audited independently.
        try {
          _validators.add((fromJsonSchema(definition), entry));
        } on AcanthisSchemaImportException {
          bad(
            entry.path,
            'The default contract exceeds the supported audit limits.',
          );
        }
      }
      revalidateDefaults();
    }
    return result;
  }

  void revalidateDefaults() {
    for (final (contract, entry) in _validators) {
      if (!contract.validate(entry.value)) {
        bad(
          entry.path,
          'The default is not a valid JSON input for its schema.',
        );
      }
    }
  }

  Map<String, Object?> ref(Schema<Object?, Object?> schema) => {
    r'$ref': '#/\$defs/${_ids[schema]}',
  };

  Map<String, Object?> node(Schema<Object?, Object?> schema, String path) {
    if (_active.contains(schema)) {
      _recursive.add(schema);
      return ref(schema);
    }
    final existing = _bodies[schema];
    if (existing != null) {
      return _recursive.contains(schema)
          ? ref(schema)
          : _compileCopy(existing)();
    }
    _ids[schema] = 's${_ids.length}';
    if (_ids.length > 4096 || _active.length > 64) {
      bad(path, 'Schema graph exceeds the 4096-node/64-level export limit.');
    }
    _active.add(schema);
    try {
      final described = describe(schema, path);
      hasMetadata = hasMetadata || schema.metadataEntry != null;
      final annotations = _metadataAnnotations(schema, path);
      final body = annotations.isEmpty
          ? described
          : {...described, ...annotations};
      _bodies[schema] = body;
      if (_recursive.contains(schema)) _defs[_ids[schema]!] = body;
      return body;
    } on AcanthisSchemaExportException catch (error) {
      if (error.path.isNotEmpty || path.isEmpty) rethrow;
      throw AcanthisSchemaExportException(path, error.reason);
    } finally {
      _active.remove(schema);
    }
  }

  Map<String, Object?> withDefault(
    Schema<Object?, Object?> schema,
    Map<String, Object?> body,
    String path, {
    bool? own,
  }) {
    _rawBodies[schema] = body;
    final hasDefault =
        own ?? (schema is DefaultSchema<Object?, Object?> && schema.hasDefault);
    if (!hasDefault) return body;
    final value = (schema as DefaultSchema<Object?, Object?>).defaultValue;
    _defaults.add(_DefaultAudit(schema, value, path));
    return mode == AcanthisSchemaMode.input
        ? {
            'anyOf': [
              body,
              {'type': 'null'},
            ],
          }
        : body;
  }

  // Native size checks observe the parsed map. Input contracts therefore count
  // declared keys after stripping, and materialized defaults before checking.
  List<Map<String, Object?>> objectCounts(
    ObjectSchema schema,
    List<String> required,
    List<String> defaulted,
    String path,
  ) {
    var min = 0;
    int? max;
    for (var i = 0; i < schema.checks.length; i++) {
      final check = schema.checks[i];
      final at = _exportPath(_exportPath(path, 'allOf'), i);
      if (check is! ObjectCheck) {
        bad(at, 'Custom object checks have no audited JSON contract.');
      }
      final count = check.constraintValue;
      if (count < -9007199254740991 || count > 9007199254740991) {
        bad(at, 'Object count bounds must fit the JSON safe integer range.');
      }
      if (check is MinPropertiesCheck || check is LengthPropertiesCheck) {
        if (count > min) min = count;
      }
      if (check is MaxPropertiesCheck || check is LengthPropertiesCheck) {
        if (max == null || count < max) max = count;
      }
    }
    if (max != null && max < min) {
      return [
        {'not': <String, Object?>{}},
      ];
    }
    if (min == 0 && max == null) return [];
    if (mode == AcanthisSchemaMode.output) {
      return [
        {
          if (min > 0) 'minProperties': min,
          if (max != null) 'maxProperties': max,
        },
      ];
    }
    if (schema.unknownKeyPolicy != AcanthisUnknownKeys.preserve) {
      final fixed = {...required, ...defaulted};
      final variable = schema.fields.keys
          .where((key) => !fixed.contains(key))
          .toList();
      final lower = min - fixed.length;
      final upper = max == null ? null : max - fixed.length;
      if (lower > variable.length || (upper != null && upper < 0)) {
        return [
          {'not': <String, Object?>{}},
        ];
      }
      return [
        if (lower > 0) presentAtLeast(variable, lower, path),
        if (upper != null && upper < variable.length)
          {'not': presentAtLeast(variable, upper + 1, path)},
      ];
    }
    // Preserved keys already contribute to raw length. Each absent defaulted
    // field contributes one extra parsed property; enumerate its presence only.
    if (min <= required.length + defaulted.length) min = 0;
    if (min == 0 && max == null) return [];
    if (defaulted.isEmpty) {
      return [
        {
          if (min > 0) 'minProperties': min,
          if (max != null) 'maxProperties': max,
        },
      ];
    }
    if (defaulted.length > 12) {
      bad(
        path,
        'Object count/default expansion exceeds the 4096-branch export limit.',
      );
    }
    final alternatives = <Map<String, Object?>>[];
    for (var mask = 0; mask < (1 << defaulted.length); mask++) {
      final present = <String>[];
      final absent = <String>[];
      for (var i = 0; i < defaulted.length; i++) {
        ((mask & (1 << i)) == 0 ? absent : present).add(defaulted[i]);
      }
      final lower = min - absent.length;
      final upper = max == null ? null : max - absent.length;
      if (upper != null && upper < 0) continue;
      alternatives.add({
        if (present.isNotEmpty) 'required': present,
        if (absent.isNotEmpty)
          'not': {
            'anyOf': [
              for (final key in absent)
                {
                  'required': [key],
                },
            ],
          },
        if (lower > 0) 'minProperties': lower,
        if (upper != null) 'maxProperties': upper,
      });
    }
    return [
      alternatives.isEmpty
          ? {'not': <String, Object?>{}}
          : {'anyOf': alternatives},
    ];
  }

  Map<String, Object?> presentAtLeast(
    List<String> names,
    int count,
    String path,
  ) {
    if (count == 1) {
      return {
        'anyOf': [
          for (final name in names)
            {
              'required': [name],
            },
        ],
      };
    }
    if (count == names.length) return {'required': names};
    // Build combinations iteratively, with a hard limit before large allocation.
    final indices = List.generate(count, (index) => index);
    final alternatives = <Map<String, Object?>>[];
    while (true) {
      if (alternatives.length == 4096) {
        bad(
          path,
          'Object count projection exceeds the 4096-branch export limit.',
        );
      }
      alternatives.add({
        'required': [for (final index in indices) names[index]],
      });
      var cursor = count - 1;
      while (cursor >= 0 && indices[cursor] == names.length - count + cursor) {
        cursor--;
      }
      if (cursor < 0) break;
      indices[cursor]++;
      for (var i = cursor + 1; i < count; i++) {
        indices[i] = indices[i - 1] + 1;
      }
    }
    return {'anyOf': alternatives};
  }

  Map<String, Object?> describe(Schema<Object?, Object?> schema, String path) {
    if (schema is AcanthisUnion<Object?>) {
      if (schema.hasGuards || schema.hasOperations) {
        bad(
          path,
          'Guarded unions and union operations have no audited JSON contract.',
        );
      }
      return withDefault(
        schema,
        schema.alternatives.isEmpty
            ? {'not': <String, Object?>{}}
            : {
                'anyOf': [
                  for (var i = 0; i < schema.alternatives.length; i++)
                    node(
                      schema.alternatives[i],
                      _exportPath(_exportPath(path, 'anyOf'), i),
                    ),
                ],
              },
        path,
      );
    }
    if (schema is AcanthisTuple) {
      if (schema.hasOperations) {
        bad(path, 'Tuple operations have no audited JSON contract.');
      }
      final prefix = schema.isVariadic
          ? schema.elements.length - 1
          : schema.elements.length;
      return withDefault(schema, {
        'type': 'array',
        if (prefix > 0)
          'prefixItems': [
            for (var i = 0; i < prefix; i++)
              node(
                schema.elements[i],
                _exportPath(_exportPath(path, 'prefixItems'), i),
              ),
          ],
        'minItems': prefix,
        if (!schema.isVariadic) 'maxItems': prefix,
        'items': schema.isVariadic
            ? node(schema.elements.last, _exportPath(path, 'items'))
            : false,
      }, path);
    }
    if (schema is AcanthisTemplate) {
      if (schema.hasOperations ||
          schema.coercionEnabled ||
          !schema.hasAuditedSegments) {
        bad(
          path,
          'Template operations or coercion have no audited JSON contract.',
        );
      }
      return withDefault(schema, {
        'type': 'string',
        'pattern': schema.pattern,
      }, path);
    }
    if (schema is AcanthisLiteral<Object?>) {
      if (schema.hasOperations) {
        bad(
          path,
          'Literal checks or transformations have no audited JSON contract.',
        );
      }
      final value = schema.value;
      if (!_scalar(value)) {
        bad(
          path,
          'Dart object/container equality is not JSON structural const equality.',
        );
      }
      if (value is num && !schema.hasJsonNumericEquality) {
        bad(
          path,
          'The literal restricts Dart int/double representation, unlike JSON const.',
        );
      }
      values([value], path); // Finite, safe-range scalar equality only.
      return withDefault(schema, {'const': value}, path);
    }
    if (schema is AcanthisNullable<Object?>) {
      if (schema.transformations.isNotEmpty || schema.hasLocalAsync) {
        bad(
          path,
          'Nullable transformations or async checks cannot be represented.',
        );
      }
      final child = node(
        schema.element,
        _exportPath(
          _exportPath(_exportPath(_exportPath(path, 'anyOf'), 0), 'allOf'),
          0,
        ),
      );
      final constraints = <Map<String, Object?>>[];
      for (var i = 0; i < schema.checks.length; i++) {
        final check = schema.checks[i];
        final at = _exportPath(_exportPath(path, 'allOf'), i);
        if (check is! EnumeratedNullableCheck<Object?>) {
          bad(at, 'Custom nullable checks have no audited JSON contract.');
        }
        if (!scalar(schema.element)) {
          bad(at, 'Only JSON scalar nullable enumeration is audited.');
        }
        constraints.add({
          'enum': values([...check.values, null], at),
        });
      }
      return withDefault(schema, {
        'anyOf': [
          {
            'allOf': [
              child,
              {
                'not': {'type': 'null'},
              },
            ],
          },
          if (schema.defaultValue == null) {'type': 'null'},
        ],
        if (constraints.isNotEmpty) 'allOf': constraints,
      }, path);
    }
    if (schema is LazyEntry) {
      bad(path, 'A lazy definition must be bound to its parent before export.');
    }
    if (schema is ResolvedSchema) {
      final bound = schema as ResolvedSchema;
      if (bound.hasWrapperOperations) {
        bad(
          path,
          'Lazy checks or transformations have no audited JSON contract.',
        );
      }
      final Schema<Object?, Object?> target;
      try {
        target = bound.resolvedSchema;
      } catch (_) {
        bad(path, 'Lazy resolution failed.');
      }
      return withDefault(
        schema,
        node(target, path),
        path,
        own: bound.hasOwnDefault,
      );
    }
    if (schema is InstanceType) {
      if (schema.checks.isNotEmpty ||
          schema.transformations.isNotEmpty ||
          schema.hasLocalAsync) {
        bad(
          path,
          'Instance checks, transformations or async operations cannot be represented by fields.',
        );
      }
      final properties = <String, Object?>{};
      final required = <String>{};
      for (final field in schema.fieldDefinitions) {
        properties[field.name] = node(
          field.schema,
          _exportPath(_exportPath(path, 'properties'), field.name),
        );
        if (!field.optional) required.add(field.name);
      }
      // V1's field description is a JSON projection, not a Dart constructor.
      return {
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required.toList(),
      };
    }
    if (schema is ObjectSchema) {
      if (schema.hasCrossFieldRules) {
        bad(
          path,
          'Cross-field rules and dependencies have no audited JSON contract.',
        );
      }
      if (schema.transformations.isNotEmpty || schema.hasLocalAsync) {
        bad(
          path,
          'Object transformations or async validation cannot be represented.',
        );
      }
      final properties = <String, Object?>{};
      final required = <String>[];
      final defaultedFields = <String>[];
      for (final entry in schema.fields.entries) {
        final child = entry.value is LazyEntry
            ? (entry.value as LazyEntry<Object?>).call(schema)
            : entry.value;
        properties[entry.key] = node(
          child,
          _exportPath(_exportPath(path, 'properties'), entry.key),
        );
        final defaulted =
            child is DefaultSchema<Object?, Object?> && child.hasDefault;
        if (!schema.isPatch && defaulted) defaultedFields.add(entry.key);
        if (!schema.isPatch &&
            (mode == AcanthisSchemaMode.input
                ? !schema.isOptionalField(entry.key) && !defaulted
                : !schema.isOptionalField(entry.key) || defaulted)) {
          required.add(entry.key);
        }
      }
      final additional = schema.resolvedAdditionalValueType;
      final constraints = objectCounts(schema, required, defaultedFields, path);
      return withDefault(schema, {
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
        'additionalProperties': additional != null
            ? node(additional, _exportPath(path, 'additionalProperties'))
            : schema.unknownKeyPolicy == AcanthisUnknownKeys.preserve ||
                  (mode == AcanthisSchemaMode.input &&
                      schema.unknownKeyPolicy == AcanthisUnknownKeys.strip),
        if (constraints.isNotEmpty) 'allOf': constraints,
      }, path);
    }
    if (schema is AcanthisList<Object?>) {
      if (schema.transformations.isNotEmpty || schema.hasLocalAsync) {
        bad(
          path,
          'List transformations or async validation cannot be represented.',
        );
      }
      final item = node(schema.element, _exportPath(path, 'items'));
      final constraints = <Map<String, Object?>>[];
      for (var i = 0; i < schema.checks.length; i++) {
        final check = schema.checks[i];
        final at = _exportPath(_exportPath(path, 'allOf'), i);
        final Map<String, Object?> constraint;
        switch (check) {
          case MinItemsListCheck<Object?>():
            constraint = check.minItems < 0 ? {} : {'minItems': check.minItems};
          case MaxItemsListCheck<Object?>():
            constraint = check.maxItems < 0
                ? {'not': <String, Object?>{}}
                : {'maxItems': check.maxItems};
          case LengthListCheck<Object?>():
            constraint = check.length < 0
                ? {'not': <String, Object?>{}}
                : {'minItems': check.length, 'maxItems': check.length};
          case UniqueItemsListCheck<Object?>():
            if (!scalar(schema.element)) {
              bad(
                at,
                'Dart container identity differs from JSON structural uniqueItems equality.',
              );
            }
            final replacement = scalarDefault(schema.element);
            constraint = mode == AcanthisSchemaMode.input && replacement != null
                ? {
                    'allOf': [
                      {'uniqueItems': true},
                      {
                        'not': {
                          'allOf': [
                            {
                              'contains': {'type': 'null'},
                            },
                            {
                              'contains': {
                                'enum': values([replacement], at),
                              },
                            },
                          ],
                        },
                      },
                    ],
                  }
                : {'uniqueItems': true};
          case ContainsListCheck<Object?>():
            if (!scalar(schema.element)) {
              bad(at, 'Only JSON scalar membership is audited.');
            }
            final entries = membership([check.item], schema.element, at);
            constraint = entries.isEmpty
                ? {'not': <String, Object?>{}}
                : {
                    'contains': {'enum': entries},
                  };
          case AnyOfListCheck<Object?>():
            if (!scalar(schema.element)) {
              bad(at, 'Only JSON scalar membership is audited.');
            }
            final entries = membership(check.items, schema.element, at);
            constraint = entries.isEmpty
                ? {'not': <String, Object?>{}}
                : {
                    'contains': {'enum': entries},
                  };
          case EveryOfListCheck<Object?>():
            if (!scalar(schema.element)) {
              bad(at, 'Only JSON scalar membership is audited.');
            }
            final entries = membership(check.items, schema.element, at);
            constraint = {
              'items': entries.isEmpty ? false : {'enum': entries},
            };
          default:
            bad(at, 'Custom list checks have no audited JSON contract.');
        }
        constraints.add(constraint);
      }
      return withDefault(schema, {
        'type': 'array',
        'items': item,
        if (constraints.isNotEmpty) 'allOf': constraints,
      }, path);
    }
    if (schema is RecordSchema<Object?, Object?>) {
      if (schema.hasOperations) {
        bad(
          path,
          'Record checks or transformations have no audited JSON contract.',
        );
      }
      if (!stringKey(schema.key)) {
        bad(
          _exportPath(path, 'propertyNames'),
          'JSON record keys must have an audited string schema.',
        );
      }
      return withDefault(schema, {
        'type': 'object',
        'propertyNames': node(schema.key, _exportPath(path, 'propertyNames')),
        'additionalProperties': node(
          schema.value,
          _exportPath(path, 'additionalProperties'),
        ),
      }, path);
    }
    if (schema is AcanthisJsonContract) {
      final definition = schema.exportDefinition();
      final name = 'import${_ids[schema]}';
      var hasReferences = false;
      Object? rebase(Object? value) {
        if (value is! Map<String, Object?>) return value;
        return {
          for (final entry in value.entries)
            entry.key: switch (entry.key) {
              r'$ref' => (() {
                hasReferences = true;
                return '#/\$defs/$name${(entry.value as String).substring(1)}';
              })(),
              'properties' || r'$defs' => {
                for (final child
                    in (entry.value as Map<String, Object?>).entries)
                  child.key: rebase(child.value),
              },
              'allOf' || 'anyOf' => [
                for (final child in entry.value as List) rebase(child),
              ],
              'not' ||
              'items' ||
              'additionalProperties' ||
              'propertyNames' ||
              'contains' => rebase(entry.value),
              _ => entry.value,
            },
        };
      }

      final rebased = rebase(definition) as Map<String, Object?>;
      if (!hasReferences) return rebased;
      _defs[name] = rebased;
      return {r'$ref': '#/\$defs/$name'};
    }
    return _exportPrimitive(schema, mode);
  }

  bool scalar(Schema<Object?, Object?> schema) {
    final seen = HashSet<Schema<Object?, Object?>>.identity();
    while (schema is ResolvedSchema || schema is AcanthisNullable<Object?>) {
      if (!seen.add(schema)) return false;
      schema = schema is AcanthisNullable<Object?>
          ? schema.element
          : (schema as ResolvedSchema).resolvedSchema;
    }
    return schema is AcanthisString ||
        schema is AcanthisNumeric<num> ||
        schema is AcanthisBoolean ||
        (schema is AcanthisLiteral<Object?> && _scalar(schema.value));
  }

  bool stringKey(Schema<Object?, Object?> schema) {
    final seen = HashSet<Schema<Object?, Object?>>.identity();
    while (schema is ResolvedSchema) {
      if (!seen.add(schema)) return false;
      schema = (schema as ResolvedSchema).resolvedSchema;
    }
    return schema is AcanthisString ||
        (schema is AcanthisLiteral<Object?> && schema.value is String);
  }

  List<Object?> values(Iterable<Object?> entries, String path) {
    final result = <Object?>{};
    for (final value in entries) {
      if (value != null &&
          value is! String &&
          value is! bool &&
          value is! num) {
        bad(path, 'Membership values must be JSON scalars.');
      }
      if (value is num && (!value.isFinite || value.abs() > 9007199254740991)) {
        bad(
          path,
          'Numeric membership values must be finite and within the safe integer range.',
        );
      }
      result.add(value);
    }
    return result.toList();
  }

  Object? scalarDefault(Schema<Object?, Object?> schema) {
    Object? value;
    final seen = HashSet<Schema<Object?, Object?>>.identity();
    while (schema is ResolvedSchema) {
      if (!seen.add(schema)) return null;
      final bound = schema as ResolvedSchema;
      if (value == null && bound.hasOwnDefault) {
        value = (schema as DefaultSchema<Object?, Object?>).defaultValue;
      }
      schema = bound.resolvedSchema;
    }
    return value ??
        (schema is DefaultSchema<Object?, Object?>
            ? schema.defaultValue
            : null);
  }

  List<Object?> membership(
    Iterable<Object?> entries,
    Schema<Object?, Object?> element,
    String path,
  ) {
    final result = values(entries, path);
    final replacement = scalarDefault(element);
    if (mode == AcanthisSchemaMode.input && replacement != null) {
      final acceptsDefault = result.contains(replacement);
      result.remove(null);
      if (acceptsDefault) result.add(null);
    }
    return result;
  }
}
