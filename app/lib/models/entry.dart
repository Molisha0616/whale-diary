class Entry {
  final int? id;
  final String day; // yyyy-MM-dd
  final int createdAt; // ms
  final String body;
  final String type; // 'entry' | 'plan'
  final String? planState; // 'done' | 'undone'

  const Entry({
    this.id,
    required this.day,
    required this.createdAt,
    required this.body,
    this.type = 'entry',
    this.planState,
  });

  Map<String, Object?> toMap() => {
        'day': day,
        'created_at': createdAt,
        'body': body,
        'type': type,
        'plan_state': planState,
      };

  static Entry fromMap(Map<String, Object?> m) => Entry(
        id: m['id'] as int?,
        day: m['day'] as String,
        createdAt: m['created_at'] as int,
        body: m['body'] as String,
        type: m['type'] as String? ?? 'entry',
        planState: m['plan_state'] as String?,
      );
}
