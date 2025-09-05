class MetadataRegistry {
  static final MetadataRegistry _instance = MetadataRegistry._internal();

  factory MetadataRegistry() {
    return _instance;
  }

  MetadataRegistry._internal();

  final Map<String, MetadataEntry> _metadata = {};

  void add(String key, MetadataEntry metadata) {
    _metadata[key] = metadata;
  }

  MetadataEntry<O>? get<O>(String key) {
    return _metadata[key] as MetadataEntry<O>?;
  }

  bool has(String key) {
    return _metadata.containsKey(key);
  }

  void remove(String key) {
    _metadata.remove(key);
  }
}

final class MetadataEntry<T> {
  final String? description;

  final String? id;

  final String? title;

  final List<T>? examples;

  final String? comment;

  final bool? deprecated;

  final T? defaultValue;

  final String? format;

  final bool? readOnly;

  final bool? writeOnly;

  final Map<String, dynamic>? otherProperties;

  const MetadataEntry({
    this.description,
    this.id,
    this.title,
    this.examples,
    this.otherProperties,
    this.comment,
    this.deprecated,
    this.defaultValue,
    this.format,
    this.readOnly,
    this.writeOnly,
  });

  Map<String, dynamic> toJson() {
    return {
      if (description != null) 'description': description,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (examples != null)
        'examples':
            T == DateTime
                ? examples
                    ?.map((e) => (e as DateTime).toIso8601String())
                    .toList()
                : examples,
      if (comment != null) '$comment': comment,
      if (deprecated != null) 'deprecated': deprecated,
      if (defaultValue != null)
        'default':
            T == DateTime
                ? (defaultValue as DateTime).toIso8601String()
                : defaultValue,
      if (format != null) 'format': format,
      if (readOnly != null) 'readOnly': readOnly,
      if (writeOnly != null) 'writeOnly': writeOnly,
      if (otherProperties != null) 'otherProperties': otherProperties,
    };
  }
}
