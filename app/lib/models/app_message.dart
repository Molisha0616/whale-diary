class AppMessage {
  final int? id;
  final int createdAt;
  final String kind; // plan_unconfirmed | weekly | monthly | yearly
  final String title;
  final String body;
  final int? entryId;
  final bool read;

  const AppMessage({
    this.id,
    required this.createdAt,
    required this.kind,
    required this.title,
    required this.body,
    this.entryId,
    this.read = false,
  });

  Map<String, Object?> toMap() => {
        'created_at': createdAt,
        'kind': kind,
        'title': title,
        'body': body,
        'entry_id': entryId,
        'read': read ? 1 : 0,
      };

  static AppMessage fromMap(Map<String, Object?> m) => AppMessage(
        id: m['id'] as int?,
        createdAt: m['created_at'] as int,
        kind: m['kind'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        entryId: m['entry_id'] as int?,
        read: (m['read'] as int? ?? 0) == 1,
      );
}
