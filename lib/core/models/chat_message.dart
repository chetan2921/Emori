class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String sessionType; // 'chat' or 'capture'
  final List<String> imagePaths;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.sessionType,
    this.imagePaths = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser ? 1 : 0,
      'session_type': sessionType,
      'image_paths': imagePaths.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: (map['is_user'] as int) == 1,
      sessionType: map['session_type'] as String,
      imagePaths:
          map['image_paths'] != null &&
              (map['image_paths'] as String).isNotEmpty
          ? (map['image_paths'] as String).split(',')
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
