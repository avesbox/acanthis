class LazyObjectMapper {
  static final LazyObjectMapper _instance = LazyObjectMapper._internal();

  factory LazyObjectMapper() {
    return _instance;
  }

  LazyObjectMapper._internal();

  final Map<String, bool> _lazyCounter = {};

  void add(String key) {
    _lazyCounter[key] = true;
  }

  void remove(String key) {
    _lazyCounter.remove(key);
  }

  bool get(String key) {
    return _lazyCounter[key] ?? false;
  }
}
