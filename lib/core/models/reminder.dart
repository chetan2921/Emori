class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final DateTime createdAt;
  final bool isCompleted;
  final bool isNotified;
  final String? relatedEntryId;

  const Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdAt,
    this.isCompleted = false,
    this.isNotified = false,
    this.relatedEntryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_completed': isCompleted ? 1 : 0,
      'is_notified': isNotified ? 1 : 0,
      'related_entry_id': relatedEntryId,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      isCompleted: (map['is_completed'] as int) == 1,
      isNotified: (map['is_notified'] as int) == 1,
      relatedEntryId: map['related_entry_id'] as String?,
    );
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? createdAt,
    bool? isCompleted,
    bool? isNotified,
    String? relatedEntryId,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isNotified: isNotified ?? this.isNotified,
      relatedEntryId: relatedEntryId ?? this.relatedEntryId,
    );
  }

  @override
  String toString() {
    return 'Reminder(title: $title, due: $dueDate, completed: $isCompleted)';
  }
}
