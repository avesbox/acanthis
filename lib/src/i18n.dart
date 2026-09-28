import 'dart:async';

import 'results.dart';
import 'i18n/catalogs.dart';

export 'i18n/catalogs.dart';

/// Immutable presentation settings. A null resolver preserves schema messages.
class AcanthisLocaleConfig {
  const AcanthisLocaleConfig({required this.locale, this.resolver});

  /// Selects a bundled catalog, with region-to-language fallback.
  factory AcanthisLocaleConfig.forLocale(String locale) => AcanthisLocaleConfig(
    locale: locale,
    resolver: AcanthisMessageCatalogs.forLocale(locale),
  );

  final String locale;
  final AcanthisMessageResolver? resolver;
}

/// Presentation defaults, local to the current Dart isolate.
abstract final class AcanthisI18n {
  static final Object _zoneKey = Object();
  static AcanthisLocaleConfig _defaults = const AcanthisLocaleConfig(
    locale: '',
  );

  static AcanthisLocaleConfig get defaults => _defaults;

  static AcanthisLocaleConfig get current =>
      Zone.current[_zoneKey] as AcanthisLocaleConfig? ?? _defaults;

  /// Configure at application startup; returns the previous settings for reset.
  /// Use [runWith] for concurrent requests instead of changing global defaults.
  static AcanthisLocaleConfig configure(AcanthisLocaleConfig config) {
    final previous = _defaults;
    _defaults = config;
    return previous;
  }

  /// Runs in a nested locale scope, including asynchronous continuations.
  /// The caller's scope is unchanged, even when [action] throws.
  static T runWith<T>(AcanthisLocaleConfig config, T Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: config});
}
