import 'dart:async';

/// Formats constraint parameters, or returns null to try the fallback catalog.
/// Formatters should be pure; submitted input is not included in parameters.
typedef AcanthisMessageBuilder = String? Function(
  Map<String, Object?> parameters,
);

/// Immutable code-to-message map, supplied at the presentation boundary.
///
/// Use [extend] to override or add messages, or construct a complete replacement.
/// No catalog lookup or formatting is performed while collecting issues.
final class AcanthisMessageCatalog {
  AcanthisMessageCatalog(
    Map<String, AcanthisMessageBuilder> messages, {
    this._fallback,
  }) : _messages = Map.unmodifiable(messages);

  final Map<String, AcanthisMessageBuilder> _messages;
  final AcanthisMessageCatalog? _fallback;

  /// Bundled defaults for the V2 diagnostic codes.
  static final english = AcanthisMessageCatalog({
    'custom': (_) => 'Invalid value',
    'isTrue': (_) => 'Value must be true',
    'isFalse': (_) => 'Value must be false',
    'literal': (p) => p.containsKey('expected')
        ? 'Value must equal ${p['expected']}'
        : 'Value does not match literal',
    'jsonSchema.false': (_) => 'Value is not allowed by this contract',
    'jsonSchema.not': (_) => 'Value matches an excluded contract',
    'minItems': (p) => 'The list must have at least ${p['minItems']} elements',
    'maxItems': (p) => 'The list must have at most ${p['maxItems']} elements',
    'uniqueItems': (_) => 'The list must have unique items',
    'length': (p) => 'The list must have exactly ${p['length']} elements',
    'containsItem': (p) => 'The list must contain ${p['item']}',
    'anyOf': (p) =>
        'The list must have at least one of the values in ${p['items']}',
    'everyOf': (p) => 'The list must contain only values from ${p['items']}',
    'minProperties': (p) =>
        'The object must have at least ${p['constraintValue']} properties',
    'maxProperties': (p) =>
        'The object must have at most ${p['constraintValue']} properties',
    'lengthProperties': (p) =>
        'The object must have exactly ${p['constraintValue']} properties',
    'type': (_) => 'Invalid value type',
    'required': (_) => 'A value is required',
    'unknownKey': (_) => 'Unknown field',
    'duplicateKey': (_) => 'Multiple entries produce the same key',
    'dependency': (_) => 'Field dependency is not satisfied',
    'union': (_) => 'Value does not match any union entry',
    'variantGuard': (_) => 'Variant guard did not match',
    'tuple': (p) =>
        'Value must have ${p['variadic'] == true ? 'at least ' : ''}${p['length']} elements',
    'templateLiteral': (_) => 'Value does not match template literal',
    'transform': (_) => 'Could not transform the value',
    'minLength': (p) => _lengthMessage(p, 'at least'),
    'maxLength': (p) => _lengthMessage(p, 'at most'),
    'exactLength': (p) => _lengthMessage(p, 'exactly'),
    'lte': (p) => _valueMessage(p, 'be less than or equal to'),
    'gte': (p) => _valueMessage(p, 'be greater than or equal to'),
    'lt': (p) => _valueMessage(p, 'be less than'),
    'gt': (p) => _valueMessage(p, 'be greater than'),
    'between': (p) => p.containsKey('min') && p.containsKey('max')
        ? 'Value must be between ${p['min']} and ${p['max']}'
        : null,
    'positive': (_) => 'Value must be positive',
    'negative': (_) => 'Value must be negative',
    'nonpositive': (_) => 'Value must be nonpositive',
    'nonnegative': (_) => 'Value must be nonnegative',
    'integer': (_) => 'Value must be an integer',
    'double': (_) => 'Value must be a double',
    'multipleOf': (p) => _valueMessage(p, 'be a multiple of'),
    'finite': (_) => 'Value must be finite',
    'infinite': (_) => 'Value must be infinite',
    'nan': (_) => 'Value must be NaN',
    'notNaN': (_) => 'Value must not be NaN',
    'email': (_) => 'Value must be a valid email address',
    'uri': (_) => 'Value must be a valid URI',
    'url': (_) => 'Value must be a valid URL',
    'uncompromised': (_) => 'Value must not be compromised',
    'notEmpty': (_) => 'Value must not be empty',
    'upperCase': (_) => 'Value must be uppercase',
    'lowerCase': (_) => 'Value must be lowercase',
    'mixedCase': (_) => 'Value must be mixed case',
    'dateTime': (_) => 'Value must be a valid date time',
    'date': (_) => 'Invalid date',
    'min': (p) => _dateBoundMessage(p, 'on or after'),
    'max': (p) => _dateBoundMessage(p, 'on or before'),
    'differsFrom': (p) => _dateDifferenceMessage(p, false, false),
    'differsFromNow': (p) => _dateDifferenceMessage(p, true, false),
    'passthrough': (_) => 'Invalid extra field value',
    'time': (_) => 'Value must be a valid time',
    'hexColor': (_) => 'Value must be a valid hex color',
    'cuid': (_) => 'Value must be a valid CUID',
    'cuid2': (_) => 'Value must be a valid CUID2',
    'ulid': (_) => 'Value must be a valid ULID',
    'uuid': (_) => 'Value must be a valid UUID',
    'nanoid': (_) => 'Value must be a valid Nano ID',
    'jwt': (_) => 'Value must be a valid JWT',
    'base64': (_) => 'Value must be valid Base64',
    'card': (_) => 'Value must be a valid card number',
    'pattern': (_) => 'Value must match the pattern',
    'letters': (p) => _characterMessage(p, 'letters'),
    'digits': (p) => _characterMessage(p, 'digits'),
    'alphanumeric': (p) => _characterMessage(p, 'alphanumeric characters'),
    'alphanumericWithSpaces': (p) =>
        _characterMessage(p, 'alphanumeric characters and spaces'),
    'specialCharacters': (p) => _characterMessage(p, 'special characters'),
    'allCharacters': (_) => 'Value contains unsupported characters',
    'contains': (p) => p.containsKey('value')
        ? _valueMessage(p, 'contain')
        : 'The list must contain a matching item',
    'startsWith': (p) => _valueMessage(p, 'start with'),
    'endsWith': (p) => _valueMessage(p, 'end with'),
    'exact': (p) => _valueMessage(p, 'be exactly'),
    'enumerated': (p) {
      final values = p['values'];
      return values is List
          ? 'Value must be one of: ${values.join(', ')}'
          : null;
    },
  });

  /// Unknown codes, including missing fallback entries, render as their code.
  String format(String code, Map<String, Object?> parameters) =>
      resolve(code, parameters) ?? code;

  /// A missing translation can fall back to the schema's own message.
  String? resolve(String code, Map<String, Object?> parameters) =>
      _messages[code]?.call(parameters) ?? _fallback?.resolve(code, parameters);

  /// Snapshots additions and overrides without changing this catalog.
  AcanthisMessageCatalog extend(Map<String, AcanthisMessageBuilder> messages) =>
      AcanthisMessageCatalog({..._messages, ...messages}, fallback: _fallback);

  AcanthisMessageCatalog _orElse(AcanthisMessageCatalog catalog) =>
      AcanthisMessageCatalog(
        _messages,
        fallback: _fallback?._orElse(catalog) ?? catalog,
      );
}

final class AcanthisLocaleConfig {
  const AcanthisLocaleConfig({required this.locale, this.catalog});
  factory AcanthisLocaleConfig.forLocale(
    String locale, {
    Map<String, AcanthisMessageCatalog> overrides = const {},
  }) => AcanthisLocaleConfig(
    locale: locale,
    catalog: AcanthisMessageCatalogs.forLocale(locale, overrides: overrides),
  );
  final String locale;
  final AcanthisMessageCatalog? catalog;
}

abstract final class AcanthisI18n {
  static final _key = Object();
  static AcanthisLocaleConfig _defaults = const AcanthisLocaleConfig(
    locale: '',
  );
  static AcanthisLocaleConfig get defaults => _defaults;
  static AcanthisLocaleConfig get current =>
      Zone.current[_key] as AcanthisLocaleConfig? ?? _defaults;
  static AcanthisLocaleConfig configure(AcanthisLocaleConfig config) {
    final previous = _defaults;
    _defaults = config;
    return previous;
  }

  static R runWith<R>(AcanthisLocaleConfig config, R Function() action) =>
      runZoned(action, zoneValues: {_key: config});
}

/// English and Italian catalogs for the built-in diagnostic vocabulary.
abstract final class AcanthisMessageCatalogs {
  static final english = AcanthisMessageCatalog.english;
  static final italian = AcanthisMessageCatalog({
    'custom': (_) => 'Valore non valido',
    'type': (_) => 'Tipo di valore non valido',
    'required': (_) => 'È richiesto un valore',
    'unknownKey': (_) => 'Campo sconosciuto',
    'duplicateKey': (_) => 'Più voci producono la stessa chiave',
    'dependency': (_) => 'La dipendenza tra i campi non è soddisfatta',
    'isTrue': (_) => 'Il valore deve essere vero',
    'isFalse': (_) => 'Il valore deve essere falso',
    'literal': (p) => p.containsKey('expected')
        ? 'Il valore deve essere uguale a ${p['expected']}'
        : 'Il valore non corrisponde al valore letterale',
    'jsonSchema.false': (_) => 'Il valore non è consentito da questo contratto',
    'jsonSchema.not': (_) => 'Il valore corrisponde a un contratto escluso',
    'notEmpty': (_) => 'Il valore non deve essere vuoto',
    'email': (_) => 'Il valore deve essere un indirizzo email valido',
    'union': (_) => 'Il valore non corrisponde ad alcuna alternativa',
    'minLength': (p) => _italianLength(p, 'almeno'),
    'maxLength': (p) => _italianLength(p, 'al massimo'),
    'exactLength': (p) => _italianLength(p, 'esattamente'),
    'minProperties': (p) =>
        'L’oggetto deve avere almeno ${p['constraintValue']} proprietà',
    'maxProperties': (p) =>
        'L’oggetto deve avere al massimo ${p['constraintValue']} proprietà',
    'lengthProperties': (p) =>
        'L’oggetto deve avere esattamente ${p['constraintValue']} proprietà',
    'minItems': (p) => 'La lista deve avere almeno ${p['minItems']} elementi',
    'maxItems': (p) =>
        'La lista deve avere al massimo ${p['maxItems']} elementi',
    'length': (p) => 'La lista deve avere esattamente ${p['length']} elementi',
    'uniqueItems': (_) => 'La lista deve avere elementi unici',
    'containsItem': (p) => 'La lista deve contenere ${p['item']}',
    'anyOf': (p) =>
        'La lista deve contenere almeno uno dei valori in ${p['items']}',
    'everyOf': (p) => 'La lista deve contenere solo valori da ${p['items']}',
    'variantGuard': (_) => 'Il guardiano della variante non corrisponde',
    'tuple': (p) =>
        'Il valore deve avere ${p['variadic'] == true ? 'almeno ' : ''}${p['length']} elementi',
    'templateLiteral': (_) => 'Il valore non corrisponde al modello letterale',
    'transform': (_) => 'Impossibile trasformare il valore',
    'lte': (p) => _valueMessage(p, 'essere minore o uguale a'),
    'gte': (p) => _valueMessage(p, 'essere maggiore o uguale a'),
    'lt': (p) => _valueMessage(p, 'essere minore di'),
    'gt': (p) => _valueMessage(p, 'essere maggiore di'),
    'between': (p) => p.containsKey('min') && p.containsKey('max')
        ? 'Il valore deve essere tra ${p['min']} e ${p['max']}'
        : null,
    'positive': (_) => 'Il valore deve essere positivo',
    'negative': (_) => 'Il valore deve essere negativo',
    'nonpositive': (_) => 'Il valore deve essere non positivo',
    'nonnegative': (_) => 'Il valore deve essere non negativo',
    'integer': (_) => 'Il valore deve essere un intero',
    'double': (_) => 'Il valore deve essere un double',
    'multipleOf': (p) => _valueMessage(p, 'essere un multiplo di'),
    'finite': (_) => 'Il valore deve essere finito',
    'infinite': (_) => 'Il valore deve essere infinito',
    'nan': (_) => 'Il valore deve essere NaN',
    'notNaN': (_) => 'Il valore non deve essere NaN',
    'uri': (_) => 'Il valore deve essere un URI valido',
    'url': (_) => 'Il valore deve essere un URL valido',
    'uncompromised': (_) => 'Il valore non deve essere compromesso',
    'upperCase': (_) => 'Il valore deve essere in maiuscolo',
    'lowerCase': (_) => 'Il valore deve essere in minuscolo',
    'mixedCase': (_) => 'Il valore deve essere in caso misto',
    'dateTime': (_) => 'Il valore deve essere un datetime valido',
    'date': (_) => 'Data non valida',
    'min': (p) => _dateBoundMessage(p, 'successiva o uguale a', italian: true),
    'max': (p) => _dateBoundMessage(p, 'precedente o uguale a', italian: true),
    'differsFrom': (p) => _dateDifferenceMessage(p, false, true),
    'differsFromNow': (p) => _dateDifferenceMessage(p, true, true),
    'passthrough': (_) => 'Valore del campo aggiuntivo non valido',
    'time': (_) => 'Il valore deve essere un tempo valido',
    'hexColor': (_) => 'Il valore deve essere un colore hex valido',
    'cuid': (_) => 'Il valore deve essere un CUID valido',
    'cuid2': (_) => 'Il valore deve essere un CUID2 valido',
    'ulid': (_) => 'Il valore deve essere un ULID valido',
    'uuid': (_) => 'Il valore deve essere un UUID valido',
    'nanoid': (_) => 'Il valore deve essere un Nano ID valido',
    'jwt': (_) => 'Il valore deve essere un JWT valido',
    'base64': (_) => 'Il valore deve essere Base64 valido',
    'card': (_) => 'Il valore deve essere un numero di carta valido',
    'pattern': (_) => 'Il valore deve corrispondere al pattern',
    'letters': (p) => _characterMessage(p, 'lettere'),
    'digits': (p) => _characterMessage(p, 'cifre'),
    'alphanumeric': (p) => _characterMessage(p, 'caratteri alfanumerici'),
    'alphanumericWithSpaces': (p) =>
        _characterMessage(p, 'caratteri alfanumerici e spazi'),
    'specialCharacters': (p) => _characterMessage(p, 'caratteri speciali'),
    'allCharacters': (_) => 'Il valore contiene caratteri non supportati',
    'contains': (p) => p.containsKey('value')
        ? _valueMessage(p, 'contenere')
        : 'La lista deve contenere almeno un elemento corrispondente',
    'startsWith': (p) => _valueMessage(p, 'iniziare con'),
    'endsWith': (p) => _valueMessage(p, 'finire con'),
    'exact': (p) => _valueMessage(p, 'essere esattamente'),
    'enumerated': (p) {
      final values = p['values'];
      return values is List
          ? 'Il valore deve essere uno di: ${values.join(', ')}'
          : null;
    },
  });

  /// Snapshot normalized overrides, trying exact locale before base language.
  static AcanthisMessageCatalog forLocale(
    String locale, {
    Map<String, AcanthisMessageCatalog> overrides = const {},
  }) {
    String normalize(String value) =>
        value.trim().replaceAll('_', '-').toLowerCase();
    final tag = normalize(locale);
    final language = tag.split('-').first;
    var catalog = switch (language) {
      'en' => english,
      'it' => italian,
      _ => AcanthisMessageCatalog(const {}),
    };
    final normalized = {
      for (final entry in overrides.entries) normalize(entry.key): entry.value,
    };
    final base = tag == language ? null : normalized[language];
    if (base != null) catalog = base._orElse(catalog);
    return normalized[tag]?._orElse(catalog) ?? catalog;
  }
}

String? _dateBoundMessage(
  Map<String, Object?> parameters,
  String relation, {
  bool italian = false,
}) {
  final value = parameters['value'];
  if (value is! String || DateTime.tryParse(value) == null) return null;
  return italian
      ? 'La data deve essere $relation $value'
      : 'The date must be $relation $value';
}

String? _dateDifferenceMessage(
  Map<String, Object?> parameters,
  bool fromNow,
  bool italian,
) {
  final difference = parameters['difference'];
  final from = parameters['fromDate'];
  if (difference is! int ||
      (!fromNow && (from is! String || DateTime.tryParse(from) == null))) {
    return null;
  }
  final origin = fromNow ? (italian ? 'adesso' : 'now') : from;
  return italian
      ? 'La data deve differire da $origin di almeno $difference ${difference == 1 ? 'microsecondo' : 'microsecondi'}'
      : 'The date must differ from $origin by at least $difference ${difference == 1 ? 'microsecond' : 'microseconds'}';
}

String? _italianLength(Map<String, Object?> parameters, String relation) {
  final limit = parameters['value'];
  return limit is int
      ? 'Il valore deve contenere $relation $limit ${limit == 1 ? 'carattere' : 'caratteri'}'
      : null;
}

String? _lengthMessage(Map<String, Object?> parameters, String relation) {
  final limit = parameters['value'];
  if (limit is! int) return null;
  return 'Value must contain $relation $limit '
      '${limit == 1 ? 'character' : 'characters'}';
}

String _characterMessage(Map<String, Object?> p, String characters) =>
    'Value must contain ${p['strict'] == true ? 'only ' : ''}$characters';

String? _valueMessage(Map<String, Object?> p, String relation) =>
    p.containsKey('value') ? 'Value must $relation ${p['value']}' : null;
