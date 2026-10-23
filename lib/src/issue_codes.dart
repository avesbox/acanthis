/// Stable built-in string codes. Application codes remain open strings.
/// Reserve unprefixed codes and `acanthis.*`; use `app.*` for custom rules.
abstract final class AcanthisIssueCodes {
  static const String minLength = 'minLength';
  static const String maxLength = 'maxLength';
  static const String exactLength = 'exactLength';
  static const String email = 'email';
  static const String uri = 'uri';
  static const String url = 'url';
  static const String uncompromised = 'uncompromised';
  static const String letters = 'letters';
  static const String digits = 'digits';
  static const String alphanumeric = 'alphanumeric';
  static const String alphanumericWithSpaces = 'alphanumericWithSpaces';
  static const String specialCharacters = 'specialCharacters';
  static const String allCharacters = 'allCharacters';
  static const String cuid = 'cuid';
  static const String cuid2 = 'cuid2';
  static const String ulid = 'ulid';
  static const String uuid = 'uuid';
  static const String nanoid = 'nanoid';
  static const String jwt = 'jwt';
  static const String base64 = 'base64';
  static const String time = 'time';
  static const String hexColor = 'hexColor';
  static const String enumerated = 'enumerated';
  static const String required = 'required';
  static const String notEmpty = 'notEmpty';
  static const String contains = 'contains';
  static const String startsWith = 'startsWith';
  static const String endsWith = 'endsWith';
  static const String card = 'card';
  static const String upperCase = 'upperCase';
  static const String lowerCase = 'lowerCase';
  static const String mixedCase = 'mixedCase';
  static const String dateTime = 'dateTime';
  static const String pattern = 'pattern';
  static const String lte = 'lte';
  static const String gte = 'gte';
  static const String gt = 'gt';
  static const String lt = 'lt';
  static const String between = 'between';
  static const String positive = 'positive';
  static const String negative = 'negative';
  static const String nonpositive = 'nonpositive';
  static const String nonnegative = 'nonnegative';
  static const String multipleOf = 'multipleOf';
  static const String integer = 'integer';
  static const String doubleType = 'double';
  static const String finite = 'finite';
  static const String infinite = 'infinite';
  static const String nan = 'nan';
  static const String notNaN = 'notNaN';
  static const String isTrue = 'isTrue';
  static const String isFalse = 'isFalse';
  static const String exact = 'exact';
  static const String minItems = 'minItems';
  static const String maxItems = 'maxItems';
  static const String length = 'length';
  static const String uniqueItems = 'uniqueItems';
  static const String anyOf = 'anyOf';
  static const String everyOf = 'everyOf';
  static const String minProperties = 'minProperties';
  static const String maxProperties = 'maxProperties';
  static const String lengthProperties = 'lengthProperties';
  static const String min = 'min';
  static const String max = 'max';
  static const String differsFromNow = 'differsFromNow';
  static const String differsFrom = 'differsFrom';
  static const String type = 'type';
  static const String date = 'date';
  static const String unknownKey = 'unknownKey';
  static const String passthrough = 'passthrough';
  static const String dependency = 'dependency';
  static const String literal = 'literal';
  static const String templateLiteral = 'templateLiteral';
  static const String tuple = 'tuple';
  static const String union = 'union';
  static const String variantGuard = 'variantGuard';
  static const String transform = 'transform';
  static const String custom = 'custom';
  static const String containsItem = 'containsItem';
  static const String duplicateKey = 'duplicateKey';
  static const String jsonSchemaFalse = 'jsonSchema.false';
  static const String jsonSchemaNot = 'jsonSchema.not';

  /// All built-in codes, including the fallback for unnamed custom checks.
  static const Set<String> values = {
    minLength,
    maxLength,
    exactLength,
    email,
    uri,
    url,
    uncompromised,
    letters,
    digits,
    alphanumeric,
    alphanumericWithSpaces,
    specialCharacters,
    allCharacters,
    cuid,
    cuid2,
    ulid,
    uuid,
    nanoid,
    jwt,
    base64,
    time,
    hexColor,
    enumerated,
    required,
    notEmpty,
    contains,
    startsWith,
    endsWith,
    card,
    upperCase,
    lowerCase,
    mixedCase,
    dateTime,
    pattern,
    lte,
    gte,
    gt,
    lt,
    between,
    positive,
    negative,
    nonpositive,
    nonnegative,
    multipleOf,
    integer,
    doubleType,
    finite,
    infinite,
    nan,
    notNaN,
    isTrue,
    isFalse,
    exact,
    minItems,
    maxItems,
    length,
    uniqueItems,
    anyOf,
    everyOf,
    minProperties,
    maxProperties,
    lengthProperties,
    min,
    max,
    differsFromNow,
    differsFrom,
    type,
    date,
    unknownKey,
    passthrough,
    dependency,
    literal,
    templateLiteral,
    tuple,
    union,
    variantGuard,
    transform,
    custom,
    containsItem,
    duplicateKey,
    jsonSchemaFalse,
    jsonSchemaNot,
  };
}
