import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../store/app_db.dart';

/// 备份：把全部文字数据与照片打成一个 zip（不落 key，不落语音模型路径）
class BackupService {
  BackupService._();

  static Future<File> create() async {
    final db = AppDb.instance;
    final media = await db.dumpTable('media');
    final settings = await db.dumpTable('settings');
    final data = <String, Object?>{
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'entries': await db.dumpTable('entries'),
      'media': media,
      'comments': await db.dumpTable('comments'),
      'reports': await db.dumpTable('reports'),
      'messages': await db.dumpTable('messages'),
      'settings': settings
          .where((s) =>
              s['key'] != 'asr_model_dir' && s['key'] != 'api_key')
          .toList(),
    };

    final tmp = await getTemporaryDirectory();
    final name =
        'whale-diary-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
    final file = File(p.join(tmp.path, name));

    final encoder = ZipFileEncoder();
    encoder.create(file.path);
    final jsonBytes =
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    encoder.addArchiveFile(
        ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    var i = 0;
    for (final m in media) {
      final path = m['path'] as String?;
      if (path == null) continue;
      final f = File(path);
      if (!f.existsSync()) continue;
      i++;
      final id = m['id'] ?? i;
      encoder.addFile(f, 'media/$id-${p.basename(path)}');
    }
    await encoder.close();
    return file;
  }
}


