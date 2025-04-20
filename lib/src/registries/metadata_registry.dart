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

  final Map<String, dynamic>? otherProperties;

  const MetadataEntry({
    this.description,
    this.id,
    this.title,
    this.examples,
    this.otherProperties,
  });

  Map<String, dynamic> toJson() {
    return {
      if(description != null) 'description': description,
      if(id != null) 'id': id,
      if(title != null) 'title': title,
      if(examples != null) 'examples': examples,
      if(otherProperties != null) 'otherProperties': otherProperties,
    };
  }

}