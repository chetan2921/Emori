import 'dart:typed_data';

class Entry {
  final String id;
  final String rawText;
  final String summary;
  final List<String> emotions;
  final String lifeArea;
  final String type;
  final List<String> themes;
  final List<String> people;
  final Uint8List embeddingBytes; // stored as bytes in SQLite
  final List<String> imagePaths; // local file paths
  final DateTime createdAt;

  Entry({
    required this.id,
    required this.rawText,
    required this.summary,
    required this.emotions,
    required this.lifeArea,
    required this.type,
    required this.themes,
    required this.people,
    required this.embeddingBytes,
    this.imagePaths = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'raw_text': rawText,
      'summary': summary,
      'emotions': emotions.join(','),
      'life_area': lifeArea,
      'type': type,
      'themes': themes.join(','),
      'people': people.join(','),
      'embedding': embeddingBytes,
      'image_paths': imagePaths.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    return Entry(
      id: map['id'] as String,
      rawText: map['raw_text'] as String,
      summary: map['summary'] as String,
      emotions: _splitSafe(map['emotions'] as String),
      lifeArea: map['life_area'] as String,
      type: map['type'] as String,
      themes: _splitSafe(map['themes'] as String),
      people: _splitSafe(map['people'] as String),
      embeddingBytes: map['embedding'] as Uint8List,
      imagePaths:
          map['image_paths'] != null &&
              (map['image_paths'] as String).isNotEmpty
          ? (map['image_paths'] as String).split(',')
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Safely split a comma-separated string, returning empty list for empty strings.
  static List<String> _splitSafe(String value) {
    if (value.isEmpty) return [];
    return value.split(',');
  }

  @override
  String toString() =>
      'Entry(id: $id, summary: $summary, emotions: $emotions, createdAt: $createdAt)';
}
