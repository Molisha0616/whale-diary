class EntryComment {
  final int? id;
  final int entryId;
  final int createdAt;
  final String body;

  const EntryComment({
    this.id,
    required this.entryId,
    required this.createdAt,
    required this.body,
  });

  Map<String, Object?> toMap() => {
        'entry_id': entryId,
        'created_at': createdAt,
        'body': body,
      };

  static EntryComment fromMap(Map<String, Object?> m) => EntryComment(
        id: m['id'] as int?,
        entryId: m['entry_id'] as int,
        createdAt: m['created_at'] as int,
        body: m['body'] as String,
      );
}
