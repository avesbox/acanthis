import '../results.dart';

/// Opt-in English and Italian diagnostic catalogs, contract version 1.
/// Unknown codes and malformed parameters return null (schema fallback).
abstract final class AcanthisMessageCatalogs {
  static const int version = 1;

  /// Locale matching is case insensitive and accepts `-` or `_` separators.
  /// Exact locale overrides are tried before the bundled base language.
  static AcanthisMessageResolver forLocale(
    String locale, {
    Map<String, AcanthisMessageResolver> overrides = const {},
  }) {
    String normalize(String value) =>
        value.trim().replaceAll('_', '-').toLowerCase();
    final tag = normalize(locale);
    final language = tag.split('-').first;
    final catalogs = {
      for (final entry in overrides.entries) normalize(entry.key): entry.value,
    };
    final exact = catalogs[tag];
    final base = tag == language ? null : catalogs[language];
    final AcanthisMessageResolver? bundled = switch (language) {
      'en' => english,
      'it' => italian,
      _ => null,
    };
    return (code, parameters) =>
        exact?.call(code, parameters) ??
        base?.call(code, parameters) ??
        bundled?.call(code, parameters);
  }

  static String? english(String code, Map<String, Object?> parameters) =>
      _resolve(code, parameters, false);

  static String? italian(String code, Map<String, Object?> parameters) =>
      _resolve(code, parameters, true);
}

const _fixed = <String, (String, String)>{
  'type': ('Invalid value type', 'Tipo di valore non valido'),
  'date': ('Invalid date', 'Data non valida'),
  'required': ('A value is required', 'È richiesto un valore'),
  'notEmpty': ('Value must not be empty', 'Il valore non deve essere vuoto'),
  'unknownKey': ('Unknown field', 'Campo sconosciuto'),
  'passthrough': (
    'Invalid extra field value',
    'Valore del campo aggiuntivo non valido',
  ),
  'union': (
    'Value does not match any union entry',
    'Il valore non corrisponde a nessuna alternativa',
  ),
  'transform': (
    'Could not transform the value',
    'Impossibile trasformare il valore',
  ),
  'isTrue': ('Value must be true', 'Il valore deve essere vero'),
  'isFalse': ('Value must be false', 'Il valore deve essere falso'),
  'positive': ('Value must be positive', 'Il valore deve essere positivo'),
  'negative': ('Value must be negative', 'Il valore deve essere negativo'),
  'nonpositive': (
    'Value must be nonpositive',
    'Il valore deve essere minore o uguale a zero',
  ),
  'nonnegative': (
    'Value must be nonnegative',
    'Il valore deve essere maggiore o uguale a zero',
  ),
  'integer': ('Value must be an integer', 'Il valore deve essere un intero'),
  'double': (
    'Value must be a double',
    'Il valore deve essere un numero double',
  ),
  'finite': ('Value must be finite', 'Il valore deve essere finito'),
  'infinite': ('Value must be infinite', 'Il valore deve essere infinito'),
  'nan': ('Value must be NaN', 'Il valore deve essere NaN'),
  'notNaN': ('Value must not be NaN', 'Il valore non deve essere NaN'),
  'uniqueItems': (
    'The list must have unique items',
    'Gli elementi della lista devono essere unici',
  ),
  'email': (
    'Value must be a valid email address',
    'Il valore deve essere un indirizzo email valido',
  ),
  'uri': ('Value must be a valid URI', 'Il valore deve essere un URI valido'),
  'url': ('Value must be a valid URL', 'Il valore deve essere un URL valido'),
  'uncompromised': (
    'Value must not be compromised',
    'Il valore non deve essere compromesso',
  ),
  'cuid': (
    'Value must be a valid CUID',
    'Il valore deve essere un CUID valido',
  ),
  'cuid2': (
    'Value must be a valid CUID2',
    'Il valore deve essere un CUID2 valido',
  ),
  'ulid': (
    'Value must be a valid ULID',
    'Il valore deve essere un ULID valido',
  ),
  'uuid': (
    'Value must be a valid UUID',
    'Il valore deve essere un UUID valido',
  ),
  'nanoid': (
    'Value must be a valid Nano ID',
    'Il valore deve essere un Nano ID valido',
  ),
  'jwt': ('Value must be a valid JWT', 'Il valore deve essere un JWT valido'),
  'base64': (
    'Value must be valid Base64',
    'Il valore deve essere Base64 valido',
  ),
  'time': (
    'Value must be a valid time',
    'Il valore deve essere un orario valido',
  ),
  'card': (
    'Value must be a valid card number',
    'Il valore deve essere un numero di carta valido',
  ),
  'upperCase': ('Value must be uppercase', 'Il valore deve essere maiuscolo'),
  'lowerCase': ('Value must be lowercase', 'Il valore deve essere minuscolo'),
  'mixedCase': (
    'Value must be mixed case',
    'Il valore deve contenere maiuscole e minuscole',
  ),
  'dateTime': (
    'Value must be a valid date time',
    'Il valore deve essere una data e ora valida',
  ),
};

String? _resolve(String code, Map<String, Object?> p, bool it) {
  final fixed = _fixed[code];
  if (fixed != null) return it ? fixed.$2 : fixed.$1;
  final value = p['value'];
  switch (code) {
    case 'minLength':
    case 'maxLength':
    case 'exactLength':
      if (value is! int) return null;
      final relation = switch (code) {
        'minLength' => it ? 'almeno' : 'at least',
        'maxLength' => it ? 'al massimo' : 'at most',
        _ => it ? 'esattamente' : 'exactly',
      };
      final unit = it
          ? (value == 1 ? 'carattere' : 'caratteri')
          : (value == 1 ? 'character' : 'characters');
      return it
          ? 'Il valore deve contenere $relation $value $unit'
          : 'Value must contain $relation $value $unit';
    case 'minItems':
    case 'maxItems':
    case 'length':
    case 'tuple':
    case 'minProperties':
    case 'maxProperties':
    case 'lengthProperties':
      final properties = code.endsWith('Properties');
      final key = properties
          ? 'constraintValue'
          : (code == 'tuple' ? 'length' : code);
      final count = p[key];
      if (count is! int) return null;
      final relation = code.startsWith('min')
          ? (it ? 'almeno' : 'at least')
          : code.startsWith('max')
          ? (it ? 'al massimo' : 'at most')
          : (it ? 'esattamente' : 'exactly');
      final unit = properties
          ? (it
                ? (count == 1 ? 'campo' : 'campi')
                : (count == 1 ? 'field' : 'fields'))
          : (it
                ? (count == 1 ? 'elemento' : 'elementi')
                : (count == 1 ? 'item' : 'items'));
      return it
          ? 'Il valore deve contenere $relation $count $unit'
          : 'Value must contain $relation $count $unit';
    case 'lte':
    case 'gte':
    case 'lt':
    case 'gt':
    case 'multipleOf':
      if (value is! num || !value.isFinite) return null;
      final relation = switch (code) {
        'lte' => it ? 'minore o uguale a' : 'less than or equal to',
        'gte' => it ? 'maggiore o uguale a' : 'greater than or equal to',
        'lt' => it ? 'minore di' : 'less than',
        'gt' => it ? 'maggiore di' : 'greater than',
        _ => it ? 'un multiplo di' : 'a multiple of',
      };
      return it
          ? 'Il valore deve essere $relation $value'
          : 'Value must be $relation $value';
    case 'between':
      final min = p['min'];
      final max = p['max'];
      if (min is! num || max is! num || !min.isFinite || !max.isFinite) {
        return null;
      }
      return it
          ? 'Il valore deve essere compreso tra $min e $max'
          : 'Value must be between $min and $max';
    case 'exact':
    case 'literal':
      final key = code == 'exact' ? 'value' : 'expected';
      if (!p.containsKey(key)) return null;
      return it
          ? 'Il valore deve essere esattamente ${p[key]}'
          : 'Value must be exactly ${p[key]}';
    case 'contains':
      final key = p.containsKey('item') ? 'item' : 'value';
      if (!p.containsKey(key) || (key == 'value' && value is! String)) {
        return null;
      }
      return it
          ? 'Il valore deve contenere ${p[key]}'
          : 'Value must contain ${p[key]}';
    case 'startsWith':
    case 'endsWith':
      if (value is! String) return null;
      return code == 'startsWith'
          ? (it
                ? 'Il valore deve iniziare con $value'
                : 'Value must start with $value')
          : (it
                ? 'Il valore deve terminare con $value'
                : 'Value must end with $value');
    case 'enumerated':
      if (p['values'] is! List) return null;
      return it
          ? 'Il valore deve essere uno dei valori consentiti'
          : 'Value must be one of the enumerated values';
    case 'anyOf':
    case 'everyOf':
      if (p['items'] is! List) return null;
      return code == 'anyOf'
          ? (it
                ? 'La lista deve contenere almeno un valore consentito'
                : 'The list must contain at least one allowed value')
          : (it
                ? 'La lista deve contenere solo valori consentiti'
                : 'The list must contain only allowed values');
    case 'pattern':
    case 'templateLiteral':
      if (p[code == 'pattern' ? 'regExp' : 'pattern'] is! String) return null;
      return it
          ? 'Il valore deve corrispondere al modello'
          : 'Value must match the pattern';
    case 'dependency':
      if (p['dependsOn'] is! String) return null;
      return it
          ? 'Dipendenza non soddisfatta: ${p['dependsOn']}'
          : 'Dependency not met: ${p['dependsOn']}';
    case 'variantGuard':
      if (p['name'] is! String) return null;
      return it
          ? 'La condizione della variante non è soddisfatta'
          : 'Variant guard did not match';
    case 'min':
    case 'max':
      if (value is! String || DateTime.tryParse(value) == null) return null;
      return code == 'min'
          ? (it
                ? 'La data deve essere successiva o uguale a $value'
                : 'The date must be on or after $value')
          : (it
                ? 'La data deve essere precedente o uguale a $value'
                : 'The date must be on or before $value');
    case 'differsFrom':
    case 'differsFromNow':
      final difference = p['difference'];
      final from = p['fromDate'];
      if (difference is! int ||
          (code == 'differsFrom' &&
              (from is! String || DateTime.tryParse(from) == null))) {
        return null;
      }
      final origin = code == 'differsFromNow' ? (it ? 'adesso' : 'now') : from;
      return it
          ? 'La data deve differire da $origin di almeno $difference microsecondi'
          : 'The date must differ from $origin by at least $difference microseconds';
    case 'letters':
    case 'digits':
    case 'alphanumeric':
    case 'alphanumericWithSpaces':
    case 'specialCharacters':
    case 'allCharacters':
      final strict = p['strict'];
      if (strict is! bool) return null;
      final kind = switch (code) {
        'letters' => it ? 'lettere' : 'letters',
        'digits' => it ? 'cifre' : 'digits',
        'alphanumeric' =>
          it ? 'caratteri alfanumerici' : 'alphanumeric characters',
        'alphanumericWithSpaces' =>
          it
              ? 'caratteri alfanumerici e spazi'
              : 'alphanumeric characters and spaces',
        'specialCharacters' => it ? 'caratteri speciali' : 'special characters',
        _ => it ? 'caratteri consentiti' : 'allowed characters',
      };
      return it
          ? 'Il valore deve contenere ${strict ? 'solo ' : ''}$kind'
          : 'Value must contain ${strict ? 'only ' : ''}$kind';
  }
  return null;
}
