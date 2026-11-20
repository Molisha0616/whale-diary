import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 媒体统一放在 App 私有目录：<documents>/media/yyyyMM/
/// 目录里放一个 .nomedia，系统图库不会扫到。
class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  Directory? _root;

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final media = Directory(p.join(docs.path, 'media'));
    if (!media.existsSync()) {
      media.createSync(recursive: true);
    }
    final nomedia = File(p.join(media.path, '.nomedia'));
    if (!nomedia.existsSync()) {
      nomedia.writeAsStringSync('');
    }
    _root = media;
    return media;
  }

  Future<String> importFile(String sourcePath, {String? ext}) async {
    final media = await root();
    final now = DateTime.now();
    final sub = Directory(p.join(media.path,
        '${now.year}${now.month.toString().padLeft(2, '0')}'));
    if (!sub.existsSync()) sub.createSync(recursive: true);

    final suffix = ext ?? p.extension(sourcePath);
    final name = '${now.millisecondsSinceEpoch}$suffix';
    final target = p.join(sub.path, name);
    await File(sourcePath).copy(target);
    return target;
  }

  Future<String> importPhoto(String sourcePath) =>
      importFile(sourcePath, ext: '.jpg');

  Future<void> delete(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}

