import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../app_settings.dart';
import '../store/app_db.dart';

class FileOps {
  static const _channel = MethodChannel('whale_diary/asr');

  static Future<bool> unzip(String zipPath, String destDir) async {
    final ok = await _channel.invokeMethod<bool>(
      'unzip',
      {'zipPath': zipPath, 'destDir': destDir},
    );
    return ok ?? false;
  }
}

/// 从备份 zip 整体还原（覆盖本机现有数据）
class RestoreService {
  RestoreService._();

  static Future<String> restore(String zipPath) async {
    final tmp = await getTemporaryDirectory();
    final dest = Directory(
        p.join(tmp.path, 'restore-${DateTime.now().millisecondsSinceEpoch}'));
    dest.createSync(recursive: true);
    if (!await FileOps.unzip(zipPath, dest.path)) {
      throw '解压失败';
    }

    final jsonFile = File(p.join(dest.path, 'data.json'));
    if (!jsonFile.existsSync()) throw '备份里没有 data.json';
    final data = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;

    // 照片搬到 App 私有目录
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(
        docs.path, 'media', 'restored-${DateTime.now().millisecondsSinceEpoch}'));
    mediaDir.createSync(recursive: true);
    final byId = <int, String>{};
    final mediaZipDir = Directory(p.join(dest.path, 'media'));
    if (mediaZipDir.existsSync()) {
      for (final f in mediaZipDir.listSync().whereType<File>()) {
        final name = p.basename(f.path);
        final id = int.tryParse(name.split('-').first);
        if (id == null) continue;
        final target = p.join(mediaDir.path, name);
        f.copySync(target);
        byId[id] = target;
      }
    }

    final db = await AppDb.instance.db;
    final mediaRows =
        (data['media'] as List? ?? []).cast<Map<String, dynamic>>();
    await db.transaction((txn) async {
      for (final table in [
        'media',
        'comments',
        'entries',
        'reports',
        'messages',
      ]) {
        await txn.delete(table);
      }
      for (final e in (data['entries'] as List? ?? []).cast<Map<String, dynamic>>()) {
        await txn.insert('entries', {...e});
      }
      for (final c in (data['comments'] as List? ?? []).cast<Map<String, dynamic>>()) {
        await txn.insert('comments', {...c});
      }
      for (final m in mediaRows) {
        final id = m['id'] as int?;
        final path = id == null ? null : byId[id];
        await txn.insert('media', {
          ...m,
          if (path != null) 'path': path,
        });
      }
      for (final r in (data['reports'] as List? ?? []).cast<Map<String, dynamic>>()) {
        await txn.insert('reports', {...r});
      }
      for (final msg in (data['messages'] as List? ?? []).cast<Map<String, dynamic>>()) {
        await txn.insert('messages', {...msg});
      }
      for (final s in (data['settings'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final k = s['key'] as String?;
        if (k == null || k == 'asr_model_dir' || k == 'api_key') continue;
        await txn.insert('settings', {...s},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    await AppSettings.load();
    final count = (data['entries'] as List? ?? []).length;
    return '已恢复 $count 条记录';
  }
}
