class EntryMedia {
  final int? id;
  final int entryId;
  final String kind; // photo
  final String path;
  final int createdAt;

  const EntryMedia({
    this.id,
    required this.entryId,
    required this.kind,
    required this.path,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'entry_id': entryId,
        'kind': kind,
        'path': path,
        'created_at': createdAt,
      };

  static EntryMedia fromMap(Map<String, Object?> m) => EntryMedia(
        id: m['id'] as int?,
        entryId: m['entry_id'] as int,
        kind: m['kind'] as String,
        path: m['path'] as String,
        createdAt: m['created_at'] as int,
      );
}
